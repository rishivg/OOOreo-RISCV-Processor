package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** Physical-register free list with two-wide allocation and retirement returns. */
class FreeList(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("free_list_spinal")
  val IDW    = cfg.idWidth
  val PIDX   = cfg.prfIdx
  val ADEP   = cfg.arfDepth
  val FDEP   = cfg.prfDepth - cfg.arfDepth
  val FIDX   = log2Up(FDEP)
  val NW     = log2Up(IDW) + 1    // n_valids width = 2

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    val from_id_valid    = in  Bits (IDW bits)
    val from_id_ready    = out Bool()
    val from_id_free_idx_flat = out Bits (IDW * PIDX bits)
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

    // prefix counts + per-slot pointers
    val wrPtrs = Vec(UInt(FIDX bits), IDW)
    var nId: UInt = U(0, NW bits)
    for (i <- 0 until IDW) {
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

    // pointer / counter update (reset via RegInit; flush == reset values)
    when(io.backend_flush) {
      wrPtr := 0; rdPtr := 0; counter := U(FDEP, FIDX + 1 bits)
    }.otherwise {
      wrPtr := (wrPtr + nValidsRrf.resize(FIDX bits)).resize(FIDX bits)
      when(ready) { rdPtr := (rdPtr + nValidsId.resize(FIDX bits)).resize(FIDX bits) }
      counter := counterNxt
    }

    // FIFO push from rrf (flush and normal do the identical write)
    for (i <- 0 until IDW) {
      when(io.from_rrf_valid(i)) { freeList(wrPtrs(i)) := fromRrfStale(i) }
    }

    // Allocate each valid dispatch slot at rd_ptr plus the count of earlier valid slots.
    val readAt = Vec(Bits(PIDX bits), IDW)
    for (k <- 0 until IDW) readAt(k) := freeList((rdPtr + U(k, FIDX bits)).resize(FIDX bits))
    val freeIdx = Vec(Bits(PIDX bits), IDW)
    freeIdx(0) := readAt(0)
    for (i <- 1 until IDW) {
      var pfx: UInt = U(0, log2Up(IDW + 1) bits)
      for (j <- 0 until i) pfx = (pfx + io.from_id_valid(j).asUInt).resize(log2Up(IDW + 1) bits)
      freeIdx(i) := readAt(pfx.resize(log2Up(IDW) bits))
    }
    io.from_id_free_idx_flat := freeIdx.asBits
  }
}
