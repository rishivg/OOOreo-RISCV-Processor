package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Arbitrate D-cache requests from atomic, load, and store paths. */
class DmemArbiter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("dmem_arbiter_spinal")
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    val load_valid = in  Bool(); val load_addr = in Bits (32 bits); val load_rmask = in Bits (4 bits)
    // Superset of load_valid for SRAM read enables; arbitration uses load_valid.
    val load_valid_early = in Bool()
    // word-in-line one-hot from the LDQ (== decode(load_addr(OFFW-1:2)), built
    // per issue cofactor there so the live AGU cone is one gate deep here)
    val load_word_oh = in Bits ((1 << (cfg.dOffsetIdx - 2)) bits)
    val load_ready = out Bool(); val load_resp = out Bool(); val load_rdata = out Bits (32 bits)
    // AGU hi16 split fields (load port only; store/atomic addrs are registered, so
    // their hi is sent pre-merged on both conditional-sum lanes with c16 = 0)
    val load_hi0 = in Bits (16 bits); val load_hi1 = in Bits (16 bits); val load_c16 = in Bool()
    val load_clint = if (cfg.zicsr) in Bool() else null
    val load_clint_read_sel = if (cfg.zicsr) in Bits(Clint.offsets.size bits) else null
    val store_valid = in Bool(); val store_addr = in Bits (32 bits)
    val store_wmask = in Bits (4 bits); val store_wdata = in Bits (32 bits)
    val store_ready = out Bool()
    // RV32A atomic port (highest priority; dormant/tied-off when aExt is disabled)
    val atomic_valid = in  Bool(); val atomic_addr = in Bits (32 bits)
    val atomic_rmask = in  Bits (4 bits); val atomic_wmask = in Bits (4 bits); val atomic_wdata = in Bits (32 bits)
    val atomic_ready = out Bool(); val atomic_resp = out Bool(); val atomic_rdata = out Bits (32 bits)
    val idle = if (cfg.zicsr || cfg.mmio || cfg.lowPower) out Bool() else null
    val cache_addr  = out Bits (32 bits); val cache_rmask = out Bits (4 bits)
    val cache_hi0 = out Bits (16 bits); val cache_hi1 = out Bits (16 bits); val cache_c16 = out Bool()
    val cache_wmask = out Bits (4 bits); val cache_wdata = out Bits (32 bits)
    val cache_mem_rmask = if (cfg.zicsr) out Bits(4 bits) else null
    val cache_mem_wmask = if (cfg.zicsr) out Bits(4 bits) else null
    val clint_req_fire = if (cfg.zicsr) out Bool() else null
    val clint_read_fire = if (cfg.zicsr) out Bool() else null
    val clint_read_sel = if (cfg.zicsr) out Bits(Clint.offsets.size bits) else null
    val cache_rdata = in  Bits (32 bits); val cache_resp = in Bool()
    // Enable SRAM reads before the request masks reach the arbiter output.
    val cache_req_fire = out Bool()
    // Decode the selected request’s word index per arbiter arm before combining bank enables.
    val cache_word_oh = out Bits ((1 << (cfg.dOffsetIdx - 2)) bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val dmemPending   = RegInit(False)
    val pendingStore  = RegInit(False)
    val pendingAtomic = RegInit(False)
    val dmemFlushed   = RegInit(False)
    val dmemBusy = dmemPending && !io.cache_resp

    // priority: atomic > load > store. atomic_valid is tied False when aExt is off.
    io.atomic_ready := !dmemBusy && !dmemFlushed
    io.load_ready   := !dmemBusy && !dmemFlushed && !io.atomic_valid
    io.store_ready  := !dmemBusy && !dmemFlushed && !io.atomic_valid && !io.load_valid
    if (cfg.zicsr || cfg.mmio || cfg.lowPower) io.idle := !dmemBusy && !dmemFlushed
    val atomicFire = io.atomic_valid && io.atomic_ready
    val loadFire   = io.load_valid && io.load_ready
    val storeFire  = io.store_valid && io.store_ready

    when(atomicFire || loadFire || storeFire) { dmemPending := True }.elsewhen(io.cache_resp) { dmemPending := False }
    when(storeFire)  { pendingStore := True }.elsewhen(io.cache_resp) { pendingStore := False }
    when(atomicFire) { pendingAtomic := True }.elsewhen(io.cache_resp) { pendingAtomic := False }
    when(dmemBusy && io.backend_flush) { dmemFlushed := True }.elsewhen(io.cache_resp) { dmemFlushed := False }

    // The early qualifier may overapproximate requests; it only enables memory reads and never grants a transaction.
    io.cache_req_fire := (io.atomic_valid || io.load_valid_early || io.store_valid) &&
                         !dmemBusy && !dmemFlushed
    io.cache_rmask := Mux(atomicFire, io.atomic_rmask, Mux(loadFire, io.load_rmask, B(0, 4 bits)))
    io.cache_wmask := Mux(atomicFire, io.atomic_wmask, Mux(storeFire, io.store_wmask, B(0, 4 bits)))
    if (cfg.zicsr) {
      // Filter CLINT requests before the late grant and address muxes.
      val atomicMem = io.atomic_addr(31 downto 16) =/= B(cfg.clintHi16, 16 bits)
      val storeMem = io.store_addr(31 downto 16) =/= B(cfg.clintHi16, 16 bits)
      val loadMem = !io.load_clint
      io.cache_mem_rmask := (io.atomic_rmask & B(4 bits, default -> (atomicFire && atomicMem))) |
        (io.load_rmask & B(4 bits, default -> (loadFire && loadMem)))
      io.cache_mem_wmask := (io.atomic_wmask & B(4 bits, default -> (atomicFire && atomicMem))) |
        (io.store_wmask & B(4 bits, default -> (storeFire && storeMem)))
      val atomicRead = atomicFire && !atomicMem && io.atomic_rmask.orR
      val loadRead = loadFire && !loadMem && io.load_rmask.orR
      io.clint_read_fire := atomicRead || loadRead
      io.clint_req_fire := io.clint_read_fire || (atomicFire && !atomicMem && io.atomic_wmask.orR) ||
        (storeFire && !storeMem && io.store_wmask.orR)
      io.clint_read_sel := (Clint.registerSelect(io.atomic_addr) & B(Clint.offsets.size bits, default -> atomicRead)) |
        (io.load_clint_read_sel & B(Clint.offsets.size bits, default -> loadRead))
    }
    io.cache_wdata := Mux(atomicFire, io.atomic_wdata, io.store_wdata)
    io.load_rdata   := io.cache_rdata
    io.atomic_rdata := io.cache_rdata
    // Request fires are mutually exclusive, so combine their masked address arms with a one-hot mux.
    val grants = atomicFire ## loadFire ## storeFire
    io.cache_addr := ooo.OhSel(grants, Seq(io.store_addr, io.load_addr, io.atomic_addr))
    io.cache_hi0 := ooo.OhSel(grants,
      Seq(io.store_addr(31 downto 16), io.load_hi0, io.atomic_addr(31 downto 16)))
    io.cache_hi1 := ooo.OhSel(grants,
      Seq(io.store_addr(31 downto 16), io.load_hi1, io.atomic_addr(31 downto 16)))
    io.cache_c16 := loadFire && io.load_c16
    val NWD = 1 << (cfg.dOffsetIdx - 2)
    val atomicWordDec = Bits(NWD bits); val storeWordDec = Bits(NWD bits)
    for (b <- 0 until NWD) {
      atomicWordDec(b) := io.atomic_addr(cfg.dOffsetIdx - 1 downto 2).asUInt === b
      storeWordDec(b)  := io.store_addr(cfg.dOffsetIdx - 1 downto 2).asUInt === b
    }
    // Use the store address on the no-fire arm; cache chip select makes that value unobservable.
    for (b <- 0 until NWD) {
      io.cache_word_oh(b) := (atomicFire && atomicWordDec(b)) ||
                             (loadFire && io.load_word_oh(b)) ||
                             (!atomicFire && !loadFire && storeWordDec(b))
    }
    io.load_resp    := io.cache_resp && dmemPending && !pendingStore && !pendingAtomic && !dmemFlushed
    io.atomic_resp  := io.cache_resp && dmemPending && pendingAtomic && !dmemFlushed
  }
}
