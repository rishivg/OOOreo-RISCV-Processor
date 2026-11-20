package ooo

import spinal.core._
import scala.collection.mutable.ArrayBuffer

/** Reduce weighted bit columns to two rows without a carry-propagating adder. */
object DaddaTree {
  def apply(inputColumns: IndexedSeq[Seq[Bool]]): (Bits, Bits) = {
    require(inputColumns.nonEmpty)
    val width = inputColumns.length
    var columns = inputColumns.map(bits => ArrayBuffer.from(bits)).toArray
    val maximumHeight = columns.map(_.length).max
    val targets = ArrayBuffer(2)
    while (targets.last < maximumHeight) targets += (targets.last * 3) / 2
    for (target <- targets.dropRight(1).reverse) {
      val next = Array.fill(width)(ArrayBuffer.empty[Bool])
      for (column <- 0 until width) {
        val available = columns(column)
        // Carries produced at this level enter the next level, not another
        // compressor at the same level. Carry out of the last column is discarded modulo 2^width.
        while (available.length + next(column).length > target) {
          require(available.length >= 2, "Dadda column cannot meet its target")
          val a = available.remove(available.length - 1)
          val b = available.remove(available.length - 1)
          val useFullAdder = available.nonEmpty &&
            available.length + next(column).length + 2 - target >= 2
          val (sum, carry) = if (useFullAdder) {
            val c = available.remove(available.length - 1)
            (a ^ b ^ c, (a && b) || (a && c) || (b && c))
          } else (a ^ b, a && b)
          next(column) += sum
          if (column + 1 < width) next(column + 1) += carry
        }
        next(column) ++= available
        require(next(column).length <= target)
      }
      columns = next
    }
    val sum, carry = Bits(width bits)
    for (column <- 0 until width) {
      require(columns(column).length <= 2)
      sum(column) := columns(column).headOption.getOrElse(False)
      carry(column) := columns(column).drop(1).headOption.getOrElse(False)
    }
    (sum, carry)
  }
}
