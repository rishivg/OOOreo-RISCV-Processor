package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** The wire format is LSB-first, independently of a Bundle's declaration order. */
final class RsEntryLayout private (val fields: Vector[(String, Int)]) {
  require(fields.nonEmpty && fields.forall(_._2 > 0), "Payload fields need positive widths")
  require(fields.map(_._1).distinct.size == fields.size, "Payload field names must be unique")

  private val offsets = fields.map(_._2).scanLeft(0)(_ + _)
  private val positions = fields.zip(offsets).map { case ((name, width), offset) =>
    name -> (offset, width)
  }.toMap

  val width: Int = offsets.last
  def offset(name: String): Int = positions(name)._1
  val rs1PhyLsb: Int = offset("rs1_phy")
  val rs2PhyLsb: Int = offset("rs2_phy")
  val rs1ValidLsb: Int = offset("rs1_valid")
  val rs2ValidLsb: Int = offset("rs2_valid")

  def read(payload: Bits, name: String): Bits = {
    require(payload.getWidth == width, s"Payload needs $width bits, got ${payload.getWidth}")
    val (lsb, fieldWidth) = positions(name)
    payload(lsb, fieldWidth bits)
  }

  private def checkedFields(bundle: Bundle): Map[String, Data] = {
    val members = bundle.elements.toMap
    for ((name, fieldWidth) <- fields) {
      require(members.contains(name), s"Payload source is missing $name")
      require(members(name).getBitsWidth == fieldWidth,
        s"Payload field $name needs $fieldWidth bits, got ${members(name).getBitsWidth}")
    }
    members
  }

  /** Select fields from a larger decoded uop without duplicating concatenations. */
  def pack(source: Bundle): Bits = {
    val members = checkedFields(source)
    // Cat(Iterable) places its first element at the LSB; Cat(varargs) does not.
    Cat(fields.map { case (name, _) => members(name) })
  }

  /** Assign by name so Bundle.asBits ordering cannot silently reverse the format. */
  def assignTo(payload: Bits, target: Bundle): Unit = {
    val members = checkedFields(target)
    require(members.size == fields.size, "Payload destination has fields outside its wire format")
    for ((name, _) <- fields) members(name).assignFromBits(read(payload, name))
  }
}

object RsEntryLayout {
  private def build(fields: (String, Int)*): RsEntryLayout = new RsEntryLayout(fields.toVector)

  def int(cfg: CpuConfig): RsEntryLayout = build(
    "fu_opcode" -> 4, "imm" -> 32, "op2_sel" -> 1, "op1_sel" -> 1,
    "rd_arch" -> cfg.arfIdx, "rd_phy" -> cfg.prfIdx,
    "rs2_valid" -> 1, "rs2_phy" -> cfg.prfIdx,
    "rs1_valid" -> 1, "rs1_phy" -> cfg.prfIdx, "rob_id" -> cfg.robIdx)

  def intm(cfg: CpuConfig): RsEntryLayout = build(
    "fu_opcode" -> 4, "rd_arch" -> cfg.arfIdx, "rd_phy" -> cfg.prfIdx,
    "rs2_valid" -> 1, "rs2_phy" -> cfg.prfIdx,
    "rs1_valid" -> 1, "rs1_phy" -> cfg.prfIdx, "rob_id" -> cfg.robIdx)

  def br(cfg: CpuConfig): RsEntryLayout = build(
    "predict_target" -> 32, "predict_taken" -> 1, "is_compressed" -> 1,
    "fu_opcode" -> 4, "pc" -> 32, "imm" -> 32,
    "rd_arch" -> cfg.arfIdx, "rd_phy" -> cfg.prfIdx,
    "rs2_valid" -> 1, "rs2_phy" -> cfg.prfIdx,
    "rs1_valid" -> 1, "rs1_phy" -> cfg.prfIdx, "rob_id" -> cfg.robIdx)

  def mem(cfg: CpuConfig): RsEntryLayout = build(
    "fu_opcode" -> 4, "imm" -> 32,
    "rs2_valid" -> 1, "rs2_phy" -> cfg.prfIdx,
    "rs1_valid" -> 1, "rs1_phy" -> cfg.prfIdx, "rob_id" -> cfg.robIdx)
}
