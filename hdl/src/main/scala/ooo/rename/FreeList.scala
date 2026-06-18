package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/rename/free_list.sv` -- the physical-register
  * free list (circular FIFO of FREELIST_DEPTH = PRF_DEPTH-ARF_DEPTH entries).
  *
  * Pops up to ID_WIDTH free regs per cycle to dispatch (when ready); pushes the
  * retired stale regs from rrf. Reset/flush reinitialise the FIFO to the identity
  * tail (phys ARF_DEPTH..PRF_DEPTH-1) and zero the pointers. `ready` = at least
  * ID_WIDTH free entries available.
  *
  * Named free_list_spinal; sim/swap_shims/free_list.sv carries id_fl_itf.fl +
  * rrf_fl_itf.fl. (The SV `fl_no_overflow` assert is a sim checker, not RTL.)
  */
class FreeList(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("free_list_spinal")
  val IDW    = cfg.idWidth        // 2
  val PIDX   = cfg.prfIdx         // 6
  val ADEP   = cfg.arfDepth       // 32
  val FDEP   = cfg.prfDepth - cfg.arfDepth   // 32
  val FIDX   = log2Up(FDEP)       // 5
  val NW     = log2Up(IDW) + 1    // n_valids width = 2

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    // id_fl_itf.fl from_id
    val from_id_valid    = in  Bits (IDW bits)
    val from_id_ready    = out Bool()
    val from_id_free_idx_flat = out Bits (IDW * PIDX bits)
    // rrf_fl_itf.fl from_rrf
    val from_rrf_valid     = in Bits (IDW bits)
    val from_rrf_stale_idx_flat = in Bits (IDW * PIDX bits)
  }
  noIoPrefix()

  def fromRrfStale(i: Int) = io.from_rrf_stale_idx_flat(i * PIDX, PIDX bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val freeList = Vec((0 until FDEP).map(i => RegInit(B(ADEP + i, PIDX bits))))
    val wrPtr   = RegInit(U(0, FIDX bits))
    val rdPtr   = RegInit(U(0, FIDX bits))
    val counter = RegInit(U(FDEP, FIDX + 1 bits))

    // ---- prefix counts + per-slot pointers ----
    val rdPtrs = Vec(UInt(FIDX bits), IDW)
    val wrPtrs = Vec(UInt(FIDX bits), IDW)
    var nId: UInt = U(0, NW bits)
    for (i <- 0 until IDW) {
      rdPtrs(i) := (rdPtr + nId.resize(FIDX bits)).resize(FIDX bits)
      nId = (nId + Mux(io.from_id_valid(i), U(1, NW bits), U(0, NW bits))).resize(NW bits)
    }
    val nValidsId = nId
    var nRrf: UInt = U(0, NW bits)
    for (i <- 0 until IDW) {
      wrPtrs(i) := (wrPtr + nRrf.resize(FIDX bits)).resize(FIDX bits)
      nRrf = (nRrf + Mux(io.from_rrf_valid(i), U(1, NW bits), U(0, NW bits))).resize(NW bits)
    }
    val nValidsRrf = nRrf

    val ready = counter >= U(IDW, FIDX + 1 bits)
    io.from_id_ready := ready

    val counterNxt = Mux(ready,
      (counter + nValidsRrf.resize(FIDX + 1 bits) - nValidsId.resize(FIDX + 1 bits)).resize(FIDX + 1 bits),
      (counter + nValidsRrf.resize(FIDX + 1 bits)).resize(FIDX + 1 bits))

    // ---- pointer / counter update (reset via RegInit; flush == reset values) ----
    when(io.backend_flush) {
      wrPtr := 0; rdPtr := 0; counter := U(FDEP, FIDX + 1 bits)
    }.otherwise {
      wrPtr := (wrPtr + nValidsRrf.resize(FIDX bits)).resize(FIDX bits)
      when(ready) { rdPtr := (rdPtr + nValidsId.resize(FIDX bits)).resize(FIDX bits) }
      counter := counterNxt
    }

    // ---- FIFO push from rrf (flush and normal do the identical write) ----
    for (i <- 0 until IDW) {
      when(io.from_rrf_valid(i)) { freeList(wrPtrs(i)) := fromRrfStale(i) }
    }

    // ---- pop: free_idx[i] = free_list[rd_ptrs[i]] ----
    val freeIdx = Vec(Bits(PIDX bits), IDW)
    for (i <- 0 until IDW) { freeIdx(i) := freeList(rdPtrs(i)) }
    io.from_id_free_idx_flat := freeIdx.asBits
  }
}
