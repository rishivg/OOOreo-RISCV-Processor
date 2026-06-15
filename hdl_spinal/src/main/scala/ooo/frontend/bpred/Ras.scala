package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/branch_predictor/ras.sv` -- the return address
  * stack. Two stacks with a speculative/committed split: `ras_spec_mem`/`tos_spec`
  * drive prediction and are corrupted freely by wrong-path fetch; `ras_commit_mem`/
  * `tos_commit` move only on committed calls/returns, so resyncing spec<-commit on
  * every flush undoes the corruption.
  *
  * Named ras_spinal; sim/swap_shims/ras.sv carries the `cb_bp_itf.bp from_cb` SV
  * interface (mapped to the from_cb_* flattened ports) and passes the packed-2D
  * array ports straight through (Verilator connects [IF_WIDTH-1:0][31:0] to a flat
  * Bits by name). The SV clock-gate is modelled as plain enabled Regs (the write
  * conditions are exactly the gate enable, so it is a transparent ICG).
  */
class Ras(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ras_spinal")
  val IFW   = cfg.ifWidth      // 4
  val DEPTH = cfg.rasDepth     // 16
  val IDX   = cfg.rasIdx       // 4

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val flush      = in Bool()
    val fetch_fire = in Bool()
    val inst_pc    = in Bits (IFW * 32 bits)
    val seq_next   = in Bits (IFW * 32 bits)
    val inst_valid = in Bits (IFW bits)
    val insts      = in Bits (IFW * 32 bits)
    val predict_taken_in   = in Bits (IFW bits)
    val predict_target_in  = in Bits (IFW * 32 bits)
    val predict_taken_out  = out Bits (IFW bits)
    val predict_target_out = out Bits (IFW * 32 bits)
    // cb_bp_itf.bp from_cb (only the fields ras.sv reads)
    val from_cb_update_en     = in Bool()
    val from_cb_pc            = in Bits (32 bits)
    val from_cb_is_call       = in Bool()
    val from_cb_is_ret        = in Bool()
    val from_cb_is_compressed = in Bool()
  }
  noIoPrefix()

  val insts     = io.insts.subdivideIn(IFW slices)
  val seqNext   = io.seq_next.subdivideIn(IFW slices)
  val ptgtIn    = io.predict_target_in.subdivideIn(IFW slices)

  // Per-slot predecode of RAS actions (link registers are x1/x5).
  val callSlot = Vec(Bool(), IFW)
  val retSlot  = Vec(Bool(), IFW)
  for (i <- 0 until IFW) {
    val op  = insts(i)(6 downto 0)
    val rd  = insts(i)(11 downto 7)
    val rs1 = insts(i)(19 downto 15)
    val linkRd  = (rd === 1) || (rd === 5)
    val linkRs1 = (rs1 === 1) || (rs1 === 5)
    callSlot(i) := ((op === B"7'b1101111") || (op === B"7'b1100111")) && linkRd
    retSlot(i)  := (op === B"7'b1100111") && linkRs1 && !linkRd
  }

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val rasSpecMem   = Vec(Reg(Bits(32 bits)), DEPTH)
    val rasCommitMem = Vec(Reg(Bits(32 bits)), DEPTH)
    val tosSpec   = RegInit(U(0, IDX bits))
    val tosCommit = RegInit(U(0, IDX bits))

    // ---- speculative stack update across the fetched slots, in program order ----
    val ptOut   = Vec(Bool(), IFW)
    val ptgtOut = Vec(Bits(32 bits), IFW)
    val pushEn  = Vec(Bool(), IFW)
    val pushIdx = Vec(UInt(IDX bits), IFW)
    val pushVal = Vec(Bits(32 bits), IFW)

    var t: UInt = tosSpec
    var takenSeen: Bool = False
    for (i <- 0 until IFW) {
      val active = io.inst_valid(i) && !takenSeen
      val doRet  = active && retSlot(i)
      val doCall = active && callSlot(i)
      ptOut(i)   := Mux(doRet, True, io.predict_taken_in(i))
      ptgtOut(i) := Mux(doRet, rasSpecMem(t), ptgtIn(i))
      val tAfterRet  = Mux(doRet, t - 1, t)
      val tAfterCall = Mux(doCall, tAfterRet + 1, tAfterRet)
      pushEn(i)  := doCall
      pushIdx(i) := tAfterCall
      pushVal(i) := seqNext(i)
      // next running state for the following slot
      t = tAfterCall
      takenSeen = takenSeen || (active && ptOut(i))
    }
    val tosNext = t

    io.predict_taken_out  := ptOut.asBits
    io.predict_target_out := ptgtOut.asBits

    // ---- committed stack: advanced only by resolved (in-order) calls/returns ----
    val commitRetAddr = (io.from_cb_pc.asUInt + Mux(io.from_cb_is_compressed, U(2, 32 bits), U(4, 32 bits))).asBits
    val tosCommitNext = UInt(IDX bits); tosCommitNext := tosCommit
    when(io.from_cb_update_en && io.from_cb_is_ret)  { tosCommitNext := tosCommit - 1 }
    when(io.from_cb_update_en && io.from_cb_is_call) { tosCommitNext := tosCommit + 1 }

    // ---- pointer flops (ungated) ----
    tosCommit := tosCommitNext
    when(io.flush)            { tosSpec := tosCommitNext }
    .elsewhen(io.fetch_fire)  { tosSpec := tosNext }

    // ---- spec/commit memories (gated in SV -> plain enabled Regs here) ----
    when(io.from_cb_update_en && io.from_cb_is_call) {
      rasCommitMem(tosCommitNext) := commitRetAddr
    }
    when(io.flush) {
      for (i <- 0 until DEPTH) {
        rasSpecMem(i) := Mux(
          io.from_cb_update_en && io.from_cb_is_call && (U(i, IDX bits) === tosCommitNext),
          commitRetAddr, rasCommitMem(i))
      }
    }.elsewhen(io.fetch_fire) {
      for (i <- 0 until IFW) {
        when(pushEn(i)) { rasSpecMem(pushIdx(i)) := pushVal(i) }
      }
    }
  }
}
