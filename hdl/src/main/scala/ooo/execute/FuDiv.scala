package ooo.execute

import spinal.core._
import ooo.CpuConfig
import ooo.common.SkidBuffer

/** Divider interface shared by the synthesizable iterative implementation,
  * the simulation reference, and an externally supplied compatible ASIC macro.
  */
class DwDivSeq(aw: Int, bw: Int, cycles: Int = 12) extends BlackBox {
  setBlackBoxName("DW_div_seq")
  addGeneric("a_width", aw); addGeneric("b_width", bw); addGeneric("tc_mode", 1)
  addGeneric("num_cyc", cycles); addGeneric("rst_mode", 1); addGeneric("input_mode", 0)
  addGeneric("output_mode", 0); addGeneric("early_start", 0)
  val io = new Bundle {
    val clk = in Bool(); val rst_n = in Bool(); val hold = in Bool(); val start = in Bool()
    val a = in Bits(aw bits); val b = in Bits(bw bits)
    val complete = out Bool(); val divide_by_0 = out Bool()
    val quotient = out Bits(aw bits); val remainder = out Bits(bw bits)
  }
  noIoPrefix()
}

/** Buffered divide/remainder unit with signed, unsigned, and divide-by-zero handling. */
class FuDiv(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_div_spinal")
  val DW = 32; val AW = DW + 1
  def MD_DIV = B"4'b0100"; def MD_DIVU = B"4'b0101"; def MD_REM = B"4'b0110"; def MD_REMU = B"4'b0111"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val prv_valid = in Bool(); val prv_ready = out Bool()
    val nxt_valid = out Bool(); val nxt_ready = in Bool()
    val iss_in = in Bits(cfg.intmRsRegW bits)
    val cdb_out = out Bits(cfg.fuCdbRegW bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val skid = new SkidBuffer(io.iss_in.getWidth)
    skid.io.clk := io.clk; skid.io.rst := io.rst
    skid.io.prv_valid := io.prv_valid; io.prv_ready := skid.io.prv_ready
    skid.io.prv_data := io.iss_in
    val regValid = skid.io.nxt_valid
    val reg = skid.io.nxt_data                       // intm_rs_reg_t (MSB->LSB)
    // intm_rs_reg_t fields
    val rRobId = IntmRsReg.robId(reg, cfg); val rRdArch = IntmRsReg.rdArch(reg, cfg); val rRdPhy = IntmRsReg.rdPhy(reg, cfg)
    val rFuOp = IntmRsReg.fuOpcode(reg); val rRs1 = IntmRsReg.rs1Value(reg); val rRs2 = IntmRsReg.rs2Value(reg)

    val prvRegValid = RegNext(regValid) init(False)
    val dividerReady = io.nxt_valid && io.nxt_ready
    val prvDividerReady = RegNext(dividerReady) init(False)
    skid.io.nxt_ready := dividerReady
    val divStart = (regValid && !prvRegValid) || (regValid && prvDividerReady)

    val au = B"1'b0" ## rRs1; val bu = B"1'b0" ## rRs2
    val as = rRs1(31).asBits ## rRs1; val bs = rRs2(31).asBits ## rRs2

    val complete = Bool(); val divideBy0 = Bool()
    val quotient = Bits(AW bits); val remainder = Bits(AW bits)
    val a = Bits(AW bits); val b = Bits(AW bits); val outcome = Bits(DW bits)
    a := 0; b := 0; outcome := 0
    switch(rFuOp) {
      is(MD_DIV)  { a := as; b := bs; outcome := Mux(divideBy0, B(DW bits, default -> True), quotient(DW - 1 downto 0)) }
      is(MD_DIVU) { a := au; b := bu; outcome := Mux(divideBy0, B(DW bits, default -> True), quotient(DW - 1 downto 0)) }
      is(MD_REM)  { a := as; b := bs; outcome := Mux(divideBy0, rRs1, remainder(DW - 1 downto 0)) }
      is(MD_REMU) { a := au; b := bu; outcome := Mux(divideBy0, rRs1, remainder(DW - 1 downto 0)) }
      default     { }
    }

    val divider = new DwDivSeq(AW, AW, cfg.divCycles)
    divider.io.clk := io.clk; divider.io.rst_n := !io.rst
    divider.io.start := divStart; divider.io.a := a; divider.io.b := b
    complete := divider.io.complete; divideBy0 := divider.io.divide_by_0
    quotient := divider.io.quotient; remainder := divider.io.remainder

    // The completion pulse can coincide with branch ownership of the shared CDB.
    // Retain it until the consumer accepts the result.
    val completeHeld = RegInit(False)
    // Freeze the IP while idle or holding a completed result. A new start
    // releases hold even if the previous completion remains high while held.
    // Clear that retained completion before exposing the new transaction.
    divider.io.hold := !divStart && (!regValid || complete || completeHeld)
    when(divStart || dividerReady) { completeHeld := False }
      .elsewhen(regValid && complete) { completeHeld := True }
    io.nxt_valid := regValid && (complete || completeHeld) && !divStart
    // rRs1/rRs2 are the RVFI-only dbg fields; tying them lets the two 32-bit
    // capture registers themselves be swept in the product config.
    io.cdb_out := FuCdbReg.pack(rRobId, rRdArch, rRdPhy, outcome,
                                if (cfg.rvfi) rRs1 else B(0, 32 bits),
                                if (cfg.rvfi) rRs2 else B(0, 32 bits))
  }
}
