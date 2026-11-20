package ooo.backend.decode

import spinal.core._
import ooo.CpuConfig

/** Combinational decoder results carried through instruction-queue selection. */
case class DecoderPayload(cfg: CpuConfig) extends Bundle {
  val rs_type = Bits(2 bits)
  val fu_type = Bits(2 bits)
  val fu_opcode = Bits(4 bits)
  val op1_sel = Bits(1 bits)
  val op2_sel = Bits(1 bits)
  val imm = Bits(32 bits)
  val rd_arch = Bits(cfg.arfIdx bits)
  val rd_en = Bool()
  val rs1_arch = Bits(cfg.arfIdx bits)
  val rs2_arch = Bits(cfg.arfIdx bits)
  val is_store = Bool()
  val is_atomic = Bool()
  val amo_op = Bits(4 bits)
  val is_csr = if (cfg.zicsr) Bool() else null
  val csr_ctrl = if (cfg.zicsr) Bits(20 bits) else null
  val exc_valid = if (cfg.zicsr) Bool() else null
  val exc_cause = if (cfg.zicsr) Bits(4 bits) else null
}

object DecoderPayload {
  def width(cfg: CpuConfig): Int = 49 + 3 * cfg.arfIdx + (if (cfg.zicsr) 26 else 0)
  def decode(inst: Bits, cfg: CpuConfig): DecoderPayload = {
    val decoder = new Decoder(cfg)
    decoder.io.inst := inst
    val result = DecoderPayload(cfg)
    result.rs_type := decoder.io.rs_type
    result.fu_type := decoder.io.fu_type
    result.fu_opcode := decoder.io.fu_opcode
    result.op1_sel := decoder.io.op1_sel
    result.op2_sel := decoder.io.op2_sel
    result.imm := decoder.io.imm
    result.rd_arch := decoder.io.rd_arch
    result.rd_en := decoder.io.rd_en
    result.rs1_arch := decoder.io.rs1_arch
    result.rs2_arch := decoder.io.rs2_arch
    result.is_store := decoder.io.is_store
    result.is_atomic := decoder.io.is_atomic
    result.amo_op := decoder.io.amo_op
    if (cfg.zicsr) {
      result.is_csr := decoder.io.is_csr
      result.csr_ctrl := decoder.io.csr_ctrl
      result.exc_valid := decoder.io.exc_valid
      result.exc_cause := decoder.io.exc_cause
    }
    result
  }
}
