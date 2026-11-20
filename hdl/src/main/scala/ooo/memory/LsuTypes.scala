package ooo.memory

import spinal.core._
import ooo.CpuConfig

object AguLsq {
  def width(cfg: CpuConfig): Int = cfg.aguLsqW
  def pack(robId: Bits, addr: Bits, wdata: Bits, mask: Bits, rs1Dbg: Bits, rs2Dbg: Bits): Bits =
    robId ## addr ## wdata ## mask ## rs1Dbg ## rs2Dbg
  def robId(b: Bits, cfg: CpuConfig): Bits = {
    val l = 32 + 32 + 4 + 32 + 32
    b(l + cfg.robIdx - 1 downto l)
  }
  def addr(b: Bits): Bits = {
    val l = 32 + 4 + 32 + 32
    b(l + 31 downto l)
  }
  def wdata(b: Bits): Bits = b(99 downto 68)
  def mask(b: Bits): Bits = b(67 downto 64)
  def rs1Dbg(b: Bits): Bits = b(63 downto 32)
  def rs2Dbg(b: Bits): Bits = b(31 downto 0)
}

object AguReg {
  def rs2Value(b: Bits): Bits = b(31 downto 0)
  def rs1Value(b: Bits): Bits = b(63 downto 32)
  def imm(b: Bits): Bits = b(95 downto 64)
  def fuOpcode(b: Bits): Bits = b(99 downto 96)
  def robId(b: Bits, cfg: CpuConfig): Bits = b(100 + cfg.robIdx - 1 downto 100)
  def pack(robId: Bits, fuOpcode: Bits, imm: Bits, rs1Value: Bits, rs2Value: Bits): Bits =
    robId ## fuOpcode ## imm ## rs1Value ## rs2Value
}
