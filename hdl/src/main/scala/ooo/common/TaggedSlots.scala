package ooo.common

import spinal.core._

/** Shared control for serial operand captures. Payload registers stay in their
  * owner so CSR and split-address atomic paths keep their individual timing.
  * No slot reuse on a release edge: dispatch gets a conservative ready signal.
  * Capture/release use slot masks; flush wins over every update.
  */
class TaggedSlots(val depth: Int, keyWidth: Int) extends Area {
  require(depth > 0 && keyWidth > 0)
  val dispatch = Bool()
  val dispatchKey = Bits(keyWidth bits)
  val flush = Bool()
  val capture = Bits(depth bits); capture := 0
  val release = Bits(depth bits); release := 0
  capture.allowOverride(); release.allowOverride()
  val valid = Vec(RegInit(False),depth)
  val captured = Vec(Reg(Bool()),depth)
  val keys = Vec(Reg(Bits(keyWidth bits)),depth)
  val allocation = Bits(depth bits)
  var seenFree: Bool = False
  for (i <- 0 until depth) {
    allocation(i) := !valid(i) && !seenFree
    seenFree = seenFree || !valid(i)
  }
  val ready = seenFree
  val allocateFire = dispatch && ready && !flush
  for (i <- 0 until depth) {
    when(allocateFire && allocation(i)) {
      valid(i) := True; captured(i) := False; keys(i) := dispatchKey
    }
    when(capture(i) && valid(i)) { captured(i) := True }
    when(release(i)) { valid(i) := False }
    when(flush) { valid(i) := False }
  }
  def matching(key: Bits): Bits = {
    val mask = Bits(depth bits)
    for (i <- 0 until depth) mask(i) := valid(i) && (keys(i) === key)
    mask
  }
}
