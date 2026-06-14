package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Shared SpinalHDL Bundles for the RS datapaths. toBits/fromBits mirror the SV
  * packed-struct layout (first field = MSB) where they cross a boundary.
  */
case class IntRsEntry() extends Bundle {           // int_rs_entry_t (69b)
  val rob_id    = Bits(6 bits)
  val rs1_phy   = Bits(6 bits); val rs1_valid = Bool()
  val rs2_phy   = Bits(6 bits); val rs2_valid = Bool()
  val rd_phy    = Bits(6 bits); val rd_arch   = Bits(5 bits)
  val op1_sel   = Bits(1 bit);  val op2_sel   = Bits(1 bit)
  val imm       = Bits(32 bits)
  val fu_opcode = Bits(4 bits)
}
object IntRsEntry {
  def fromBits(b: Bits): IntRsEntry = {
    val e = IntRsEntry()
    e.fu_opcode := b(3 downto 0);   e.imm := b(35 downto 4)
    e.op2_sel := b(36).asBits;      e.op1_sel := b(37).asBits
    e.rd_arch := b(42 downto 38);   e.rd_phy := b(48 downto 43)
    e.rs2_valid := b(49);           e.rs2_phy := b(55 downto 50)
    e.rs1_valid := b(56);           e.rs1_phy := b(62 downto 57)
    e.rob_id := b(68 downto 63);    e
  }
  def width = 69
}

case class CdbRs() extends Bundle { val rd_phy = Bits(6 bits); val valid = Bool() }

case class BypassNet() extends Bundle {  // bypass_network_t (39b): valid rd_phy rd_value
  val valid = Bool(); val rd_phy = Bits(6 bits); val rd_value = Bits(32 bits)
}
object BypassNet { def fromBits(b: Bits): BypassNet = {
  val n = BypassNet(); n.valid := b(38); n.rd_phy := b(37 downto 32); n.rd_value := b(31 downto 0); n } }

case class BypassT() extends Bundle {    // bypass_t (14b)
  val rs1_bypass_en  = Bits(6 bits); val rs2_bypass_en  = Bits(6 bits)
  val rs1_bypass_sel = Bits(1 bit);  val rs2_bypass_sel = Bits(1 bit)
  def toBits: Bits = rs1_bypass_en ## rs2_bypass_en ## rs1_bypass_sel ## rs2_bypass_sel
}

/** Field offsets (LSB-indexed) of rs1_phy/rs2_phy/rs1_valid/rs2_valid within a
  * given *_rs_entry_t packed struct (rs_entry only touches these; the rest is
  * opaque payload carried through). Computed = sum of widths of fields below.
  */
case class RsEntryLayout(width: Int, rs1PhyLsb: Int, rs2PhyLsb: Int, rs1ValidLsb: Int, rs2ValidLsb: Int)
object RsEntryLayout {
  val int  = RsEntryLayout(69, 57, 50, 56, 49)    // int_rs_entry_t
  val intm = RsEntryLayout(35, 23, 16, 22, 15)    // intm_rs_entry_t
  val br   = RsEntryLayout(133, 121, 114, 120, 113) // br_rs_entry_t
  val mem  = RsEntryLayout(56, 44, 37, 43, 36)    // mem_rs_entry_t (no rd fields)
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
    val fast_bypass = in  Vec(BypassNet(), NFB)
    val rs_bypass   = out (BypassT())
    val wakeup_cdb  = in  Vec(CdbRs(), CDBW)
  }

  def rs1Phy(b: Bits) = b(lay.rs1PhyLsb + 5 downto lay.rs1PhyLsb)
  def rs2Phy(b: Bits) = b(lay.rs2PhyLsb + 5 downto lay.rs2PhyLsb)

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
