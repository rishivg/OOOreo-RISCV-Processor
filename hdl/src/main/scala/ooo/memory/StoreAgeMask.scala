package ooo.memory

import spinal.core._

/** Exact circular interval, including tracker zero and unused encodings. */
object StoreAgeMask {
  def apply(head: UInt, tracker: UInt, depth: Int, lookup: Boolean): Bits = {
    val idx = log2Up(depth)
    require(depth >= 2 && (depth & (depth - 1)) == 0)
    require(head.getWidth == idx + 1 && tracker.getWidth == idx + 1)
    val result = Bits(depth bits)
    if (lookup && depth <= 8) {
      val selector = (tracker.asBits ## head(idx - 1 downto 0).asBits).asUInt
      val entries = 1 << selector.getWidth
      for (slot <- 0 until depth) {
        val table = (0 until entries).foldLeft(BigInt(0)) { (bits, entry) =>
          val rd = entry & (depth - 1)
          val count = entry >> idx
          val tail = (rd + count - 1) & (2 * depth - 1)
          val last = tail & (depth - 1)
          val present = if ((tail & depth) == 0) rd <= slot && slot <= last
                        else rd <= slot || slot <= last
          if (present) bits.setBit(entry) else bits
        }
        result(slot) := B(table, entries bits)(selector)
      }
    } else {
      val tail = (head + tracker - 1).resize(idx + 1)
      for (slot <- 0 until depth) {
        val afterHead = head(idx - 1 downto 0) <= U(slot, idx bits)
        val beforeTail = U(slot, idx bits) <= tail(idx - 1 downto 0)
        result(slot) := Mux(tail(idx) === head(idx), afterHead && beforeTail,
          afterHead || beforeTail)
      }
    }
    result
  }
}
