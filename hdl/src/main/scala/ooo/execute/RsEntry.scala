package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Shared SpinalHDL Bundles for the RS datapaths. Field widths derive from the
  * CpuConfig index widths (prfIdx/arfIdx/robIdx) so PRF/ARF/ROB-depth retunes
  * propagate instead of going stale. toBits/fromBits mirror the packed layout
  * (first field = MSB); bit offsets are computed from the running field-width sums.
  */
case class IntRsEntry(cfg: CpuConfig) extends Bundle {   // int_rs_entry_t
  val rob_id    = Bits(cfg.robIdx bits)
  val rs1_phy   = Bits(cfg.prfIdx bits); val rs1_valid = Bool()
  val rs2_phy   = Bits(cfg.prfIdx bits); val rs2_valid = Bool()
  val rd_phy    = Bits(cfg.prfIdx bits); val rd_arch   = Bits(cfg.arfIdx bits)
  val op1_sel   = Bits(1 bit);  val op2_sel   = Bits(1 bit)
  val imm       = Bits(32 bits)
  val fu_opcode = Bits(4 bits)
}
object IntRsEntry {
  // LSB-first field order: fu_opcode imm op2_sel op1_sel rd_arch rd_phy rs2_valid
  // rs2_phy rs1_valid rs1_phy rob_id (mirrors BackendTop.intEntry / int_rs_entry_t).
  def fromBits(b: Bits, cfg: CpuConfig): IntRsEntry = {
    val P = cfg.prfIdx; val A = cfg.arfIdx; val R = cfg.robIdx
    val oImm = 4; val oOp2 = oImm + 32; val oOp1 = oOp2 + 1; val oRdA = oOp1 + 1
    val oRdP = oRdA + A; val oR2v = oRdP + P; val oR2p = oR2v + 1; val oR1v = oR2p + P
    val oR1p = oR1v + 1; val oRob = oR1p + P
    val e = IntRsEntry(cfg)
    e.fu_opcode := b(oImm - 1 downto 0);     e.imm := b(oOp2 - 1 downto oImm)
    e.op2_sel := b(oOp2).asBits;             e.op1_sel := b(oOp1).asBits
    e.rd_arch := b(oRdP - 1 downto oRdA);    e.rd_phy := b(oR2v - 1 downto oRdP)
    e.rs2_valid := b(oR2v);                  e.rs2_phy := b(oR1v - 1 downto oR2p)
    e.rs1_valid := b(oR1v);                  e.rs1_phy := b(oRob - 1 downto oR1p)
    e.rob_id := b(oRob + R - 1 downto oRob); e
  }
  def width(cfg: CpuConfig) = 4 + 32 + 1 + 1 + cfg.arfIdx + 3 * cfg.prfIdx + 2 + cfg.robIdx  // 69 @ default
}

case class CdbRs(cfg: CpuConfig) extends Bundle { val rd_phy = Bits(cfg.prfIdx bits); val valid = Bool() }

case class BypassNet(cfg: CpuConfig) extends Bundle {  // bypass_network_t: valid rd_phy rd_value
  val valid = Bool(); val rd_phy = Bits(cfg.prfIdx bits); val rd_value = Bits(32 bits)
}
object BypassNet { def fromBits(b: Bits, cfg: CpuConfig): BypassNet = {
  val P = cfg.prfIdx; val n = BypassNet(cfg)
  n.valid := b(32 + P); n.rd_phy := b(31 + P downto 32); n.rd_value := b(31 downto 0); n } }

// bypass_t: en widths = cdbWidth + 1 (one bit per CDB write lane + fast-bypass).
// sel widths = log2Up(intIssueWidth). Width = 2*(cdbWidth+1) + 2*sel.
case class BypassT(enW: Int = 6, selW: Int = 1) extends Bundle {
  val rs1_bypass_en  = Bits(enW bits); val rs2_bypass_en  = Bits(enW bits)
  val rs1_bypass_sel = Bits(selW bits); val rs2_bypass_sel = Bits(selW bits)
  def toBits: Bits = rs1_bypass_en ## rs2_bypass_en ## rs1_bypass_sel ## rs2_bypass_sel
}
object BypassT {
  def apply(cfg: CpuConfig): BypassT = BypassT(cfg.cdbWidth + 1, log2Up(cfg.intIssueWidth))
  def width(cfg: CpuConfig): Int = 2 * (cfg.cdbWidth + 1) + 2 * log2Up(cfg.intIssueWidth)
}

/** Field offsets (LSB-indexed) of rs1_phy/rs2_phy/rs1_valid/rs2_valid within a
  * *_rs_entry_t packed struct (rs_entry only touches these; the rest is opaque
  * payload). DERIVED from the LSB-first field-width list so PRF/ARF/ROB-depth
  * retunes propagate; field lists mirror BackendTop.{int,intm,br,mem}Entry().
  * Defaults reproduce 69/35/133/56 at prfIdx=6,arfIdx=5,robIdx=6.
  */
case class RsEntryLayout(width: Int, rs1PhyLsb: Int, rs2PhyLsb: Int, rs1ValidLsb: Int, rs2ValidLsb: Int)
object RsEntryLayout {
  private def build(fields: Seq[(String, Int)]): RsEntryLayout = {
    var off = 0; val lsb = collection.mutable.Map[String, Int]()
    for ((n, w) <- fields) { lsb(n) = off; off += w }
    RsEntryLayout(off, lsb("rs1_phy"), lsb("rs2_phy"), lsb("rs1_valid"), lsb("rs2_valid"))
  }
  def int(cfg: CpuConfig)  = build(Seq("fu_opcode"->4, "imm"->32, "op2_sel"->1, "op1_sel"->1,
    "rd_arch"->cfg.arfIdx, "rd_phy"->cfg.prfIdx, "rs2_valid"->1, "rs2_phy"->cfg.prfIdx,
    "rs1_valid"->1, "rs1_phy"->cfg.prfIdx, "rob_id"->cfg.robIdx))
  def intm(cfg: CpuConfig) = build(Seq("fu_opcode"->4, "rd_arch"->cfg.arfIdx, "rd_phy"->cfg.prfIdx,
    "rs2_valid"->1, "rs2_phy"->cfg.prfIdx, "rs1_valid"->1, "rs1_phy"->cfg.prfIdx, "rob_id"->cfg.robIdx))
  def br(cfg: CpuConfig)   = build(Seq("predict_target"->32, "predict_taken"->1, "is_compressed"->1,
    "fu_opcode"->4, "pc"->32, "imm"->32, "rd_arch"->cfg.arfIdx, "rd_phy"->cfg.prfIdx,
    "rs2_valid"->1, "rs2_phy"->cfg.prfIdx, "rs1_valid"->1, "rs1_phy"->cfg.prfIdx, "rob_id"->cfg.robIdx))
  def mem(cfg: CpuConfig)  = build(Seq("fu_opcode"->4, "imm"->32, "rs2_valid"->1, "rs2_phy"->cfg.prfIdx,
    "rs1_valid"->1, "rs1_phy"->cfg.prfIdx, "rob_id"->cfg.robIdx))
}

/** SpinalHDL port of `hdl/common/rs_entry.sv`, generic over the entry type via
  * RsEntryLayout (mirrors the SV `parameter type RS_ENTRY_T`). Compacting-RS slot:
  * clock-gated entry flop (transparent ICG => plain enabled Reg), CDB wakeup
  * (CDB_WIDTH, no rd_phy!=0 guard), fast-bypass readiness (NUM_FAST_BYPASS, with
  * the guard). Internal sub-component -> implicit clock domain, opaque Bits(width).
  */
class RsEntry(cfg: CpuConfig, lay: RsEntryLayout) extends Component {
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val W    = lay.width

  val io = new Bundle {
    val valid       = out Bool()
    val request     = out Bool()
    val grant       = in  Bool()
    val push_en     = in  Bool()
    val entry_in    = in  Bits(W bits)
    val entry_out   = out Bits(W bits)
    val entry       = out Bits(W bits)
    val clear       = in  Bool()
    val fast_bypass = in  Vec(BypassNet(cfg), NFB)
    val rs_bypass   = out (BypassT(cfg))
    val wakeup_cdb  = in  Vec(CdbRs(cfg), CDBW)
  }

  val PIDX = cfg.prfIdx
  def rs1Phy(b: Bits) = b(lay.rs1PhyLsb + PIDX - 1 downto lay.rs1PhyLsb)
  def rs2Phy(b: Bits) = b(lay.rs2PhyLsb + PIDX - 1 downto lay.rs2PhyLsb)

  val entry_valid = RegInit(False)
  val entry_reg   = Reg(Bits(W bits))   // no reset (gated flop, don't-care until valid)

  val next_valid = CombInit(entry_valid)
  when(io.push_en) { next_valid := True } .elsewhen(io.grant) { next_valid := False }
  when(io.clear) { entry_valid := False } otherwise { entry_valid := next_valid }

  val m1 = (0 until CDBW).map(k => io.wakeup_cdb(k).valid && (rs1Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)).reduce(_ || _)
  val m2 = (0 until CDBW).map(k => io.wakeup_cdb(k).valid && (rs2Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)).reduce(_ || _)

  val next_entry = Bits(W bits)
  when(io.push_en) {
    next_entry := io.entry_in
  } otherwise {
    next_entry := entry_reg
    when(m1) { next_entry(lay.rs1ValidLsb) := True }
    when(m2) { next_entry(lay.rs2ValidLsb) := True }
  }
  when(io.push_en || m1 || m2) { entry_reg := next_entry }

  val eo = CombInit(entry_reg)
  when(m1) { eo(lay.rs1ValidLsb) := True }
  when(m2) { eo(lay.rs2ValidLsb) := True }
  io.entry_out := eo

  val rs1_en = Bits(CDBW + 1 bits)
  val rs2_en = Bits(CDBW + 1 bits)
  for (k <- 0 until CDBW) {
    rs1_en(k) := io.wakeup_cdb(k).valid && (io.wakeup_cdb(k).rd_phy =/= 0) && (rs1Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)
    rs2_en(k) := io.wakeup_cdb(k).valid && (io.wakeup_cdb(k).rd_phy =/= 0) && (rs2Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)
  }
  val fm1 = (0 until NFB).map(i => io.fast_bypass(i).valid && (io.fast_bypass(i).rd_phy =/= 0) && (rs1Phy(entry_reg) === io.fast_bypass(i).rd_phy))
  val fm2 = (0 until NFB).map(i => io.fast_bypass(i).valid && (io.fast_bypass(i).rd_phy =/= 0) && (rs2Phy(entry_reg) === io.fast_bypass(i).rd_phy))
  rs1_en(CDBW) := fm1.reduce(_ || _)
  rs2_en(CDBW) := fm2.reduce(_ || _)
  io.rs_bypass.rs1_bypass_sel := Mux(fm1(0), B(0, 1 bits), B(1, 1 bits))
  io.rs_bypass.rs2_bypass_sel := Mux(fm2(0), B(0, 1 bits), B(1, 1 bits))
  io.rs_bypass.rs1_bypass_en  := rs1_en
  io.rs_bypass.rs2_bypass_en  := rs2_en

  val src1_ready = entry_reg(lay.rs1ValidLsb) || rs1_en.orR
  val src2_ready = entry_reg(lay.rs2ValidLsb) || rs2_en.orR
  io.request := entry_valid && src1_ready && src2_ready
  io.valid   := entry_valid
  io.entry   := entry_reg
}
