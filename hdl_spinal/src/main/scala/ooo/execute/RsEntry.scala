package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL Bundles for the int_rs datapath. Internal to the int_rs subsystem
  * (not top ports), so layout is free EXCEPT toBits/fromBits which mirror the SV
  * packed-struct layout (first field = MSB) where they cross the top boundary or
  * feed a packed-port FU.
  */
case class IntRsEntry() extends Bundle {           // int_rs_entry_t (69b)
  val rob_id    = Bits(6 bits)
  val rs1_phy   = Bits(6 bits); val rs1_valid = Bool()
  val rs2_phy   = Bits(6 bits); val rs2_valid = Bool()
  val rd_phy    = Bits(6 bits); val rd_arch   = Bits(5 bits)
  val op1_sel   = Bits(1 bit);  val op2_sel   = Bits(1 bit)
  val imm       = Bits(32 bits)
  val fu_opcode = Bits(4 bits)

  /** SV packed layout, first field = MSB */
  def toBits: Bits =
    rob_id ## rs1_phy ## rs1_valid ## rs2_phy ## rs2_valid ##
    rd_phy ## rd_arch ## op1_sel ## op2_sel ## imm ## fu_opcode
}
object IntRsEntry {
  def fromBits(b: Bits): IntRsEntry = {  // inverse of toBits (LSB-first slices)
    val e = IntRsEntry()
    e.fu_opcode := b(3 downto 0)
    e.imm       := b(35 downto 4)
    e.op2_sel   := b(36).asBits
    e.op1_sel   := b(37).asBits
    e.rd_arch   := b(42 downto 38)
    e.rd_phy    := b(48 downto 43)
    e.rs2_valid := b(49)
    e.rs2_phy   := b(55 downto 50)
    e.rs1_valid := b(56)
    e.rs1_phy   := b(62 downto 57)
    e.rob_id    := b(68 downto 63)
    e
  }
  def width = 69
}

case class CdbRs() extends Bundle {   // wakeup view of cdb_itf.rs
  val rd_phy = Bits(6 bits)
  val valid  = Bool()
}

case class BypassNet() extends Bundle {  // bypass_network_t (39b): valid rd_phy rd_value
  val valid    = Bool()
  val rd_phy   = Bits(6 bits)
  val rd_value = Bits(32 bits)
}
object BypassNet { def fromBits(b: Bits): BypassNet = {
  val n = BypassNet(); n.valid := b(38); n.rd_phy := b(37 downto 32); n.rd_value := b(31 downto 0); n } }

case class BypassT() extends Bundle {  // bypass_t (14b)
  val rs1_bypass_en  = Bits(6 bits)   // [CDB_WIDTH:0]
  val rs2_bypass_en  = Bits(6 bits)
  val rs1_bypass_sel = Bits(1 bit)    // [INT_ISSUE_IDX-1:0]
  val rs2_bypass_sel = Bits(1 bit)
  def toBits: Bits = rs1_bypass_en ## rs2_bypass_en ## rs1_bypass_sel ## rs2_bypass_sel
}

/** SpinalHDL port of `hdl/common/rs_entry.sv` specialized to int_rs_entry_t.
  * Compacting-RS slot: clock-gated entry flop, CDB wakeup (5 CDBs), fast-bypass
  * (2 ALU outputs) readiness. Internal sub-component of int_rs (uses implicit
  * clock domain), so ports are Bundles -- no Verilator port matching needed.
  */
class RsEntry(cfg: CpuConfig = CpuConfig()) extends Component {
  val CDBW = cfg.cdbWidth          // 5
  val NFB  = cfg.numFastBypass     // 2

  val io = new Bundle {
    val valid       = out Bool()
    val request     = out Bool()
    val grant       = in  Bool()
    val push_en     = in  Bool()
    val entry_in    = in  (IntRsEntry())
    val entry_out   = out (IntRsEntry())
    val entry       = out (IntRsEntry())
    val clear       = in  Bool()
    val fast_bypass = in  Vec(BypassNet(), NFB)
    val rs_bypass   = out (BypassT())
    val wakeup_cdb  = in  Vec(CdbRs(), CDBW)
  }

  val entry_valid = RegInit(False)
  val entry_reg   = Reg(IntRsEntry())   // no reset (gated flop; value is don't-care until valid)

  // next_valid
  val next_valid = CombInit(entry_valid)
  when(io.push_en) { next_valid := True } .elsewhen(io.grant) { next_valid := False }
  when(io.clear) { entry_valid := False } otherwise { entry_valid := next_valid }

  // CDB wakeup matches (no rd_phy!=0 guard, per SV)
  val m1 = (0 until CDBW).map(k => io.wakeup_cdb(k).valid && (entry_reg.rs1_phy === io.wakeup_cdb(k).rd_phy)).reduce(_ || _)
  val m2 = (0 until CDBW).map(k => io.wakeup_cdb(k).valid && (entry_reg.rs2_phy === io.wakeup_cdb(k).rd_phy)).reduce(_ || _)

  // next_entry + clock-gate enable (transparent => plain enabled Reg)
  val entry_wakeup = m1 || m2
  val next_entry = IntRsEntry()
  when(io.push_en) {
    next_entry := io.entry_in
  } otherwise {
    next_entry := entry_reg
    when(m1) { next_entry.rs1_valid := True }
    when(m2) { next_entry.rs2_valid := True }
  }
  when(io.push_en || entry_wakeup) { entry_reg := next_entry }

  // entry_out = CDB-forwarded view of entry_reg
  val eo = CombInit(entry_reg)
  when(m1) { eo.rs1_valid := True }
  when(m2) { eo.rs2_valid := True }
  io.entry_out := eo

  // rs_bypass: CDB bits [0..CDBW-1] (with rd_phy!=0 guard), fast bit [CDBW]
  val rs1_en = Bits(CDBW + 1 bits)
  val rs2_en = Bits(CDBW + 1 bits)
  for (k <- 0 until CDBW) {
    rs1_en(k) := io.wakeup_cdb(k).valid && (io.wakeup_cdb(k).rd_phy =/= 0) && (entry_reg.rs1_phy === io.wakeup_cdb(k).rd_phy)
    rs2_en(k) := io.wakeup_cdb(k).valid && (io.wakeup_cdb(k).rd_phy =/= 0) && (entry_reg.rs2_phy === io.wakeup_cdb(k).rd_phy)
  }
  // fast bypass (priority i=0 first); sel = first matching index
  val fm1 = (0 until NFB).map(i => io.fast_bypass(i).valid && (io.fast_bypass(i).rd_phy =/= 0) && (entry_reg.rs1_phy === io.fast_bypass(i).rd_phy))
  val fm2 = (0 until NFB).map(i => io.fast_bypass(i).valid && (io.fast_bypass(i).rd_phy =/= 0) && (entry_reg.rs2_phy === io.fast_bypass(i).rd_phy))
  rs1_en(CDBW) := fm1.reduce(_ || _)
  rs2_en(CDBW) := fm2.reduce(_ || _)
  // sel: lowest index with a match (PriorityMux-style); 1 bit for INT_ISSUE_WIDTH=2
  io.rs_bypass.rs1_bypass_sel := Mux(fm1(0), B(0, 1 bits), B(1, 1 bits))
  io.rs_bypass.rs2_bypass_sel := Mux(fm2(0), B(0, 1 bits), B(1, 1 bits))
  io.rs_bypass.rs1_bypass_en  := rs1_en
  io.rs_bypass.rs2_bypass_en  := rs2_en

  val src1_ready = entry_reg.rs1_valid || rs1_en.orR
  val src2_ready = entry_reg.rs2_valid || rs2_en.orR
  io.request := entry_valid && src1_ready && src2_ready
  io.valid   := entry_valid
  io.entry   := entry_reg
}
