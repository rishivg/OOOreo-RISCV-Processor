package ooo

import spinal.core._

/** Preserve a balanced reduction tree for an arbitrary positive input count. */
object BalancedOr {
  def apply(inputs: collection.Seq[Bits]): Bits = {
    require(inputs.nonEmpty)
    val values = inputs.toIndexedSeq
    def reduce(first: Int, limit: Int): Bits = {
      if (limit - first == 1) values(first)
      else {
        val middle = first + (limit - first) / 2
        reduce(first, middle) | reduce(middle, limit)
      }
    }
    reduce(0, values.length)
  }
}
