package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Typed integer payload. RsEntryLayout defines its external packed representation. */
case class IntRsEntry(cfg: CpuConfig) extends Bundle {
  val rob_id    = Bits(cfg.robIdx bits)
  val rs1_phy   = Bits(cfg.prfIdx bits); val rs1_valid = Bool()
  val rs2_phy   = Bits(cfg.prfIdx bits); val rs2_valid = Bool()
  val rd_phy    = Bits(cfg.prfIdx bits); val rd_arch   = Bits(cfg.arfIdx bits)
  val op1_sel   = Bits(1 bit);  val op2_sel   = Bits(1 bit)
  val imm       = Bits(32 bits)
  val fu_opcode = Bits(4 bits)
}
object IntRsEntry {
  def fromBits(b: Bits, cfg: CpuConfig): IntRsEntry = {
    val entry = IntRsEntry(cfg)
    RsEntryLayout.int(cfg).assignTo(b, entry)
    entry
  }
  def width(cfg: CpuConfig): Int = RsEntryLayout.int(cfg).width
}

object IntmRsEntry {
  def width(cfg: CpuConfig): Int = RsEntryLayout.intm(cfg).width
  def fuOpcode(b: Bits): Bits = b(3 downto 0)
  def rdArch(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.intm(cfg).read(b, "rd_arch")
  def rdPhy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.intm(cfg).read(b, "rd_phy")
  def rs2Phy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.intm(cfg).read(b, "rs2_phy")
  def rs1Phy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.intm(cfg).read(b, "rs1_phy")
  def robId(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.intm(cfg).read(b, "rob_id")
}

object MemRsEntry {
  def width(cfg: CpuConfig): Int = RsEntryLayout.mem(cfg).width
  def fuOpcode(b: Bits): Bits = b(3 downto 0)
  def imm(b: Bits): Bits = b(35 downto 4)
  def rs2Phy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.mem(cfg).read(b, "rs2_phy")
  def rs1Phy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.mem(cfg).read(b, "rs1_phy")
  def robId(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.mem(cfg).read(b, "rob_id")
}

object BrRsEntry {
  def width(cfg: CpuConfig): Int = RsEntryLayout.br(cfg).width
  def predictTarget(b: Bits): Bits = b(31 downto 0)
  def predictTaken(b: Bits): Bool = b(32)
  def isCompressed(b: Bits): Bool = b(33)
  def fuOpcode(b: Bits): Bits = b(37 downto 34)
  def pc(b: Bits): Bits = b(69 downto 38)
  def imm(b: Bits): Bits = b(101 downto 70)
  def rdArch(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.br(cfg).read(b, "rd_arch")
  def rdPhy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.br(cfg).read(b, "rd_phy")
  def rs2Phy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.br(cfg).read(b, "rs2_phy")
  def rs1Phy(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.br(cfg).read(b, "rs1_phy")
  def robId(b: Bits, cfg: CpuConfig): Bits = RsEntryLayout.br(cfg).read(b, "rob_id")
}

object IntmRsReg {
  def rs2Value(b: Bits): Bits = b(31 downto 0)
  def rs1Value(b: Bits): Bits = b(63 downto 32)
  def fuOpcode(b: Bits): Bits = b(67 downto 64)
  def rdPhy(b: Bits, cfg: CpuConfig): Bits = b(68 + cfg.prfIdx - 1 downto 68)
  def rdArch(b: Bits, cfg: CpuConfig): Bits = {
    val l = 68 + cfg.prfIdx
    b(l + cfg.arfIdx - 1 downto l)
  }
  def robId(b: Bits, cfg: CpuConfig): Bits = {
    val l = 68 + cfg.prfIdx + cfg.arfIdx
    b(l + cfg.robIdx - 1 downto l)
  }
  def pack(robId: Bits, rdArch: Bits, rdPhy: Bits, fuOpcode: Bits, rs1: Bits, rs2: Bits): Bits =
    robId ## rdArch ## rdPhy ## fuOpcode ## rs1 ## rs2
}

/** ALU payload stores preselected operands and RVFI source values.
  * LSB-first: rs2, rs1, opB, opA, opcode, rd_phy, rd_arch, rob_id.
  */
object FuAluReg {
  def rs2Value(b: Bits): Bits = b(31 downto 0)
  def rs1Value(b: Bits): Bits = b(63 downto 32)
  def opB(b: Bits): Bits = b(95 downto 64)
  def opA(b: Bits): Bits = b(127 downto 96)
  def fuOpcode(b: Bits): Bits = b(131 downto 128)
  def rdPhy(b: Bits, cfg: CpuConfig): Bits = b(132 + cfg.prfIdx - 1 downto 132)
  def rdArch(b: Bits, cfg: CpuConfig): Bits = {
    val l = 132 + cfg.prfIdx
    b(l + cfg.arfIdx - 1 downto l)
  }
  def robId(b: Bits, cfg: CpuConfig): Bits = {
    val l = 132 + cfg.prfIdx + cfg.arfIdx
    b(l + cfg.robIdx - 1 downto l)
  }
}

object FuBrReg {
  def predictTarget(b: Bits): Bits = b(31 downto 0)
  def predictTaken(b: Bits): Bool = b(32)
  def isCompressed(b: Bits): Bool = b(33)
  def rs2Value(b: Bits): Bits = b(65 downto 34)
  def rs1Value(b: Bits): Bits = b(97 downto 66)
  def imm(b: Bits): Bits = b(129 downto 98)
  def pc(b: Bits): Bits = b(161 downto 130)
  def fuOpcode(b: Bits): Bits = b(165 downto 162)
  def rdPhy(b: Bits, cfg: CpuConfig): Bits = b(166 + cfg.prfIdx - 1 downto 166)
  def rdArch(b: Bits, cfg: CpuConfig): Bits = {
    val l = 166 + cfg.prfIdx
    b(l + cfg.arfIdx - 1 downto l)
  }
  def robId(b: Bits, cfg: CpuConfig): Bits = {
    val l = 166 + cfg.prfIdx + cfg.arfIdx
    b(l + cfg.robIdx - 1 downto l)
  }
}

object FuCdbReg {
  def rs2Dbg(b: Bits): Bits = b(31 downto 0)
  def rs1Dbg(b: Bits): Bits = b(63 downto 32)
  def rdValue(b: Bits): Bits = b(95 downto 64)
  def rdPhy(b: Bits, cfg: CpuConfig): Bits = b(96 + cfg.prfIdx - 1 downto 96)
  def rdArch(b: Bits, cfg: CpuConfig): Bits = {
    val l = 96 + cfg.prfIdx
    b(l + cfg.arfIdx - 1 downto l)
  }
  def robId(b: Bits, cfg: CpuConfig): Bits = {
    val l = 96 + cfg.prfIdx + cfg.arfIdx
    b(l + cfg.robIdx - 1 downto l)
  }
  def pack(robId: Bits, rdArch: Bits, rdPhy: Bits, rdValue: Bits, rs1Dbg: Bits, rs2Dbg: Bits): Bits =
    robId ## rdArch ## rdPhy ## rdValue ## rs1Dbg ## rs2Dbg
}

case class CdbRs(cfg: CpuConfig) extends Bundle { val rd_phy = Bits(cfg.prfIdx bits); val valid = Bool() }

case class BypassNet(cfg: CpuConfig) extends Bundle {
  val valid = Bool(); val rd_phy = Bits(cfg.prfIdx bits); val rd_value = Bits(32 bits)
}
object BypassNet {
  def fromBits(payload: Bits, cfg: CpuConfig): BypassNet = {
    val bypass = BypassNet(cfg)
    bypass.valid := payload(32 + cfg.prfIdx)
    bypass.rd_phy := payload(31 + cfg.prfIdx downto 32)
    bypass.rd_value := payload(31 downto 0)
    bypass
  }
}

/** Each operand selects a CDB lane or a fast-bypass lane index. */
case class BypassT(enW: Int, selW: Int) extends Bundle {
  val rs1_bypass_en  = Bits(enW bits); val rs2_bypass_en  = Bits(enW bits)
  val rs1_bypass_sel = Bits(selW bits); val rs2_bypass_sel = Bits(selW bits)
  def toBits: Bits = rs1_bypass_en ## rs2_bypass_en ## rs1_bypass_sel ## rs2_bypass_sel
}
object BypassT {
  def apply(cfg: CpuConfig): BypassT = BypassT(cfg.cdbWidth + 1, log2Up(cfg.intIssueWidth))
  def width(cfg: CpuConfig): Int = 2 * (cfg.cdbWidth + 1) + 2 * log2Up(cfg.intIssueWidth)
}
