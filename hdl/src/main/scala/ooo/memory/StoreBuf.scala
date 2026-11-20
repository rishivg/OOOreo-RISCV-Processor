package ooo.memory

import spinal.core._
import spinal.lib._
import ooo.CpuConfig

/** Post-retirement store buffer and load-forwarding source. */
class StoreBuf(cfg: CpuConfig = CpuConfig()) extends Component {
  require(!cfg.storeBufferPrecompute || cfg.storePairPrecompute,
    "Store-buffer precomputation requires load-address update signals")
  setDefinitionName("store_buf_spinal")
  val DEPTH = cfg.stbDepth     // [STB_DEPTH]
  val IDX   = cfg.stbIdx
  val LDQ   = cfg.ldqDepth
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_stq_valid = in  Bool()
    val from_stq_ready = out Bool()
    val from_stq_addr  = in  Bits (32 bits)
    val from_stq_wmask = in  Bits (4 bits)
    val from_stq_wdata = in  Bits (32 bits)
    val dmem_valid = out Bool()
    val dmem_ready = in  Bool()
    val dmem_addr  = out Bits (32 bits)
    val dmem_wmask = out Bits (4 bits)
    val dmem_wdata = out Bits (32 bits)
    val ldq_addr_flat  = in  Bits (LDQ * 32 bits)
    val ldq_rmask_flat = in  Bits (LDQ * 4 bits)
    val ldq_addr_write = if (cfg.storeBufferPrecompute) in Bits(LDQ bits) else null
    val agu_match_targets = if (cfg.lsuCarryFreeStoreMatch) out Bits((DEPTH+1)*32 bits) else null
    val load_agu_matches = if (cfg.lsuCarryFreeStoreMatch) in Bits(DEPTH+1 bits) else null
    val load_agu_addr = if (cfg.storeBufferPrecompute) in Bits(32 bits) else null
    val agu_hi0 = if (cfg.storeBufferPrecompute && cfg.storePairSplitTag) in Bits(16 bits) else null
    val agu_hi1 = if (cfg.storeBufferPrecompute && cfg.storePairSplitTag) in Bits(16 bits) else null
    val agu_c16 = if (cfg.storeBufferPrecompute && cfg.storePairSplitTag) in Bool() else null
    val load_agu_mask = if (cfg.storeBufferPrecompute) in Bits(4 bits) else null
    val has_conflicting_store = out Bits (LDQ bits)
    val forward_en            = out Bits (LDQ bits)
    val forward_wdata_flat    = out Bits (LDQ * 32 bits)
    val forward_store_data_flat = if (cfg.lsuBufferForwardLanes) out Bits(DEPTH * 32 bits) else null
    val forward_store_select_flat = if (cfg.lsuBufferForwardLanes) out Bits(LDQ * DEPTH bits) else null
    val dbg_full = out Bool()   // perf_monitor taps stb_i.full
  }
  noIoPrefix()

  def ldqAddr(i: Int)  = io.ldq_addr_flat(i * 32, 32 bits)
  def ldqRmask(i: Int) = io.ldq_rmask_flat(i * 4, 4 bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val valid = Vec(RegInit(False), DEPTH)
    val addr  = Vec(Reg(Bits(32 bits)), DEPTH)
    val mask  = Vec(Reg(Bits(4 bits)), DEPTH)
    val wdata = Vec(Reg(Bits(32 bits)), DEPTH)
    val wrPtr = RegInit(U(0, IDX + 1 bits))
    val rdPtr = RegInit(U(0, IDX + 1 bits))
    val wrActual = wrPtr(IDX - 1 downto 0); val wrFlag = wrPtr(IDX)
    val rdActual = rdPtr(IDX - 1 downto 0); val rdFlag = rdPtr(IDX)

    val full  = (wrActual === rdActual) && (wrFlag === !rdFlag)
    val empty = wrPtr === rdPtr
    io.from_stq_ready := !full

    val enqueue     = io.from_stq_valid && !full
    val wantDequeue = !empty
    val dequeue     = wantDequeue && io.dmem_ready

    when(enqueue) {
      valid(wrActual) := True
      addr(wrActual)  := io.from_stq_addr
      mask(wrActual)  := io.from_stq_wmask
      wdata(wrActual) := io.from_stq_wdata
      wrPtr := wrPtr + 1
    }
    when(dequeue) {
      valid(rdActual) := False
      rdPtr := rdPtr + 1
    }

    if (cfg.lsuCarryFreeStoreMatch) io.agu_match_targets:=io.from_stq_addr ## addr.asBits

    // D-cache drain port
    io.dmem_valid := wantDequeue
    io.dmem_wmask := mask(rdActual)
    io.dmem_addr  := addr(rdActual)(31 downto 2) ## B(0, 2 bits)
    io.dmem_wdata := wdata(rdActual)

    // All store-buffer entries are committed and older than any live load.
    // Forward matching bytes from the youngest covering store.
    val conflict = Vec(Bool(), LDQ)
    val fwdEn    = Vec(Bool(), LDQ)
    val fwdData  = Vec(Bits(32 bits), LDQ)
    val pairs = if (cfg.storeBufferPrecompute)
      new StorePairCache(cfg.copy(stqDepth=DEPTH, storeVerdictPrecompute=true), sharedWrite=false)
    else null
    if (cfg.storeBufferPrecompute) {
      pairs.io.clk := io.clk; pairs.io.rst := io.rst
      pairs.io.store_addr_flat := addr.asBits; pairs.io.store_mask_flat := mask.asBits
      pairs.io.load_addr_flat := io.ldq_addr_flat; pairs.io.load_mask_flat := io.ldq_rmask_flat
      pairs.io.load_write := io.ldq_addr_write
      pairs.io.agu_addr := io.load_agu_addr; pairs.io.agu_mask := io.load_agu_mask
      if (cfg.lsuCarryFreeStoreMatch) pairs.io.agu_word_matches:=io.load_agu_matches
      if (cfg.storePairSplitTag) {
        pairs.io.agu_hi0 := io.agu_hi0; pairs.io.agu_hi1 := io.agu_hi1
        pairs.io.agu_c16 := io.agu_c16
      }
      pairs.io.store_write_addr := io.from_stq_addr; pairs.io.store_write_mask := io.from_stq_wmask
      for (j <- 0 until DEPTH) pairs.io.store_write(j) := enqueue && wrActual === j
    }
    for (i <- 0 until LDQ) {
      val ovl = Vec(Bool(), DEPTH)
      val cov = Vec(Bool(), DEPTH)
      for (j <- 0 until DEPTH) {
        if (cfg.storeBufferPrecompute) {
          val nextValid = !io.rst && (valid(j) || pairs.io.store_write(j)) && !(dequeue && rdActual === j)
          val sameWord = nextValid && pairs.io.next_tag(i * DEPTH + j)
          ovl(j) := sameWord && pairs.io.next_overlap(i * DEPTH + j)
          cov(j) := sameWord && pairs.io.next_cover(i * DEPTH + j)
        } else {
          val sameWord = valid(j) && (addr(j)(31 downto 2) === ldqAddr(i)(31 downto 2))
          ovl(j) := sameWord && ((ldqRmask(i) & ~mask(j)) =/= ldqRmask(i))
          cov(j) := sameWord && ((ldqRmask(i) & ~mask(j)) === 0)
        }
      }
      if (cfg.storeBufferPrecompute) {
        val (forward, _) = StoreForwarding(True, False, ovl.asBits, cov.asBits, wdata.toSeq)
        conflict(i) := RegNext(ovl.asBits.orR)
        fwdEn(i) := RegNext(forward)
        val select = RegNext(ovl.asBits & cov.asBits)
        if (cfg.lsuBufferForwardLanes) io.forward_store_select_flat(i * DEPTH,DEPTH bits) := select
        fwdData(i) := Mux(fwdEn(i), ooo.OhSel(select, wdata.toSeq), B(0, 32 bits))
      } else {
        conflict(i) := ovl.asBits.orR
        fwdEn(i) := False; fwdData(i) := B(0, 32 bits)
        when(CountOne(ovl) === 1) {
          for (j <- 0 until DEPTH) {
            when(ovl(j) && cov(j)) { fwdEn(i) := True; fwdData(i) := wdata(j) }
          }
        }
      }
    }
    io.has_conflicting_store := conflict.asBits
    if (cfg.lsuBufferForwardLanes) io.forward_store_data_flat := wdata.asBits
    io.forward_en            := fwdEn.asBits
    io.forward_wdata_flat    := fwdData.asBits
    io.dbg_full := full
  }
}
