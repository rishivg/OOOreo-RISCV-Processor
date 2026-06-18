package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/rename/rrf.sv` -- the retirement register file
  * (committed arch->phys map). Reset to identity; updated at commit (rd_arch->rd_phy)
  * for each retiring slot. Outputs the stale phys (for the free list) with
  * intra-bundle forwarding, and the combinational next-cycle map rrf_mem (used by
  * the RAT on flush).
  *
  * Named rrf_spinal; sim/swap_shims/rrf.sv carries rob_rrf_itf.rrf + rrf_fl_itf.rrf
  * and un-flattens the rrf_mem[ARF_DEPTH] unpacked-array output.
  */
class Rrf(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("rrf_spinal")
  val IDW  = cfg.idWidth       // 2
  val ADEP = cfg.arfDepth      // 32
  val AIDX = cfg.arfIdx        // 5
  val PIDX = cfg.prfIdx        // 6

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val rrf_mem_flat = out Bits (ADEP * PIDX bits)
    // rob_rrf_itf.rrf from_rob
    val from_rob_valid       = in Bits (IDW bits)
    val from_rob_rd_phy_flat  = in Bits (IDW * PIDX bits)
    val from_rob_rd_arch_flat = in Bits (IDW * AIDX bits)
    // rrf_fl_itf.rrf to_fl
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
