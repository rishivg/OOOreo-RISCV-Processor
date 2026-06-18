package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/common/dmem_arbiter.sv` -- arbitrates the load path and
  * the store-buffer drain onto the single D-cache port, with fixed LOAD priority
  * (loads are latency-critical). Tracks one outstanding access (dmem_pending) and
  * gates a flushed load's response (dmem_flushed).
  *
  * Named dmem_arbiter_spinal; sim/swap_shims/dmem_arbiter.sv carries ldq_dmem_itf.
  * cache (load), stb_dmem_itf.cache (store) and dmem_itf.cpu (cache).
  */
class DmemArbiter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("dmem_arbiter_spinal")
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    // ldq_dmem_itf.cache load
    val load_valid = in  Bool(); val load_addr = in Bits (32 bits); val load_rmask = in Bits (4 bits)
    val load_ready = out Bool(); val load_resp = out Bool(); val load_rdata = out Bits (32 bits)
    // stb_dmem_itf.cache store
    val store_valid = in Bool(); val store_addr = in Bits (32 bits)
    val store_wmask = in Bits (4 bits); val store_wdata = in Bits (32 bits)
    val store_ready = out Bool()
    // RV32A atomic port (highest priority; dormant/tied-off when aExt is disabled)
    val atomic_valid = in  Bool(); val atomic_addr = in Bits (32 bits)
    val atomic_rmask = in  Bits (4 bits); val atomic_wmask = in Bits (4 bits); val atomic_wdata = in Bits (32 bits)
    val atomic_ready = out Bool(); val atomic_resp = out Bool(); val atomic_rdata = out Bits (32 bits)
    // dmem_itf.cpu cache
    val cache_addr  = out Bits (32 bits); val cache_rmask = out Bits (4 bits)
    val cache_wmask = out Bits (4 bits); val cache_wdata = out Bits (32 bits)
    val cache_rdata = in  Bits (32 bits); val cache_resp = in Bool()
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
    val atomicFire = io.atomic_valid && io.atomic_ready
    val loadFire   = io.load_valid && io.load_ready
    val storeFire  = io.store_valid && io.store_ready

    when(atomicFire || loadFire || storeFire) { dmemPending := True }.elsewhen(io.cache_resp) { dmemPending := False }
    when(storeFire)  { pendingStore := True }.elsewhen(io.cache_resp) { pendingStore := False }
    when(atomicFire) { pendingAtomic := True }.elsewhen(io.cache_resp) { pendingAtomic := False }
    when(dmemBusy && io.backend_flush) { dmemFlushed := True }.elsewhen(io.cache_resp) { dmemFlushed := False }

    io.cache_rmask := Mux(atomicFire, io.atomic_rmask, Mux(loadFire, io.load_rmask, B(0, 4 bits)))
    io.cache_wmask := Mux(atomicFire, io.atomic_wmask, Mux(storeFire, io.store_wmask, B(0, 4 bits)))
    io.cache_wdata := Mux(atomicFire, io.atomic_wdata, io.store_wdata)
    io.load_rdata   := io.cache_rdata
    io.atomic_rdata := io.cache_rdata
    io.cache_addr  := Mux(atomicFire, io.atomic_addr, Mux(loadFire, io.load_addr, Mux(storeFire, io.store_addr, B(0, 32 bits))))
    io.load_resp    := io.cache_resp && dmemPending && !pendingStore && !pendingAtomic && !dmemFlushed
    io.atomic_resp  := io.cache_resp && dmemPending && pendingAtomic && !dmemFlushed
  }
}
