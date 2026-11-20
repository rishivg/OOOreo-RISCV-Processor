package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** Committed architectural-to-physical register mapping. */
class Rrf(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("rrf_spinal")
  val IDW  = cfg.idWidth
  val ADEP = cfg.arfDepth
  val AIDX = cfg.arfIdx
  val PIDX = cfg.prfIdx
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val rrf_mem_flat = out Bits (ADEP * PIDX bits)
    val from_rob_valid       = in Bits (IDW bits)
    val from_rob_rd_phy_flat  = in Bits (IDW * PIDX bits)
    val from_rob_rd_arch_flat = in Bits (IDW * AIDX bits)
    val to_fl_valid          = out Bits (IDW bits)
    val to_fl_stale_idx_flat = out Bits (IDW * PIDX bits)
  }
  noIoPrefix()

  def robValid(i: Int) = io.from_rob_valid(i)
  def robRdPhy(i: Int)  = io.from_rob_rd_phy_flat(i * PIDX, PIDX bits)
  def robRdArch(i: Int) = io.from_rob_rd_arch_flat(i * AIDX, AIDX bits).asUInt

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val mem = Vec((0 until ADEP).map(i => RegInit(B(i, PIDX bits))))

    for (i <- 0 until IDW) {
      when(robValid(i) && (robRdArch(i) =/= 0)) { mem(robRdArch(i)) := robRdPhy(i) }
    }

    // stale phys for the free list (intra-bundle forward from older slots)
    val flValid = Vec(Bool(), IDW); val flStale = Vec(Bits(PIDX bits), IDW)
    for (i <- 0 until IDW) {
      flValid(i) := False; flStale(i) := 0
      when(robValid(i) && (robRdArch(i) =/= 0)) {
        flValid(i) := True
        flStale(i) := mem(robRdArch(i))
        for (j <- 0 until i) {
          when(robValid(j) && (robRdArch(j) === robRdArch(i))) { flStale(i) := robRdPhy(j) }
        }
      }
    }
    io.to_fl_valid := flValid.asBits
    io.to_fl_stale_idx_flat := flStale.asBits

    // combinational next-cycle map (RAT flush source)
    val nextMem = Vec(Bits(PIDX bits), ADEP)
    for (j <- 0 until ADEP) nextMem(j) := mem(j)
    for (i <- 0 until IDW) {
      when(robValid(i) && (robRdArch(i) =/= 0)) { nextMem(robRdArch(i)) := robRdPhy(i) }
    }
    io.rrf_mem_flat := nextMem.asBits
  }
}
