package ooo.memory

import spinal.core._

object StoreForwarding {
  private def anyTwo(terms: Seq[Bool]): (Bool, Bool) = {
    require(terms.nonEmpty)
    if (terms.size == 1) (terms.head, False)
    else {
      val (left, right) = terms.splitAt(terms.size / 2)
      val (a, aa) = anyTwo(left)
      val (b, bb) = anyTwo(right)
      (a || b, aa || bb || (a && b))
    }
  }

  /** A unique older overlap with complete byte coverage can forward. */
  def apply(tracked: Bool, unknown: Bool, overlap: Bits, cover: Bits,
            data: Seq[Bits]): (Bool, Bits) = {
    require(overlap.getWidth == cover.getWidth && data.size == overlap.getWidth)
    val (_, two) = anyTwo((0 until overlap.getWidth).map(overlap(_)))
    val mask = overlap & cover
    val eligible = if (overlap.getWidth == 2)
      (overlap(0) && cover(0) && !overlap(1)) || (overlap(1) && cover(1) && !overlap(0))
    else !two && mask.orR
    val enable = tracked && !unknown && eligible
    (enable, Mux(enable, ooo.OhSel(mask, data), B(0, data.head.getWidth bits)))
  }
}
