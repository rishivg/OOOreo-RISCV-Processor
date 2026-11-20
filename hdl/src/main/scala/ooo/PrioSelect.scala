package ooo

import spinal.core._

/** Balanced priority selection; the lowest requesting index wins.
  * If no request is set, the data output is the last input and must be ignored.
  */
object PrioSelect {
  def apply(req: collection.Seq[Bool], data: collection.Seq[Bits]): (Bool, Seq[Bool], Bits) = {
    require(req.length == data.length && req.nonEmpty)
    val dataWidth = data.head.getWidth
    require(dataWidth > 0 && data.forall(_.getWidth == dataWidth),
      "Priority data inputs need equal positive widths")
    val requests = req.toIndexedSeq
    val values = data.toIndexedSeq
    // Validate/convert once; recursive branches use ranges instead of copying inputs.
    def select(first: Int, limit: Int): (Bool, Seq[Bool], Bits) = {
      if (limit - first == 1) (requests(first), Seq(requests(first)), values(first))
      else {
        val middle = first + (limit - first) / 2
        val (lowAny, lowMask, lowData) = select(first, middle)
        val (highAny, highMask, highData) = select(middle, limit)
        (lowAny | highAny, lowMask ++ highMask.map(_ && !lowAny), Mux(lowAny, lowData, highData))
      }
    }
    select(0, requests.length)
  }
}

/** Balanced OR of masked inputs: no selection returns zero; multiple selections OR.
  * MuxOH.apply is not interchangeable: it assumes a valid one-hot selector.
  */
object OhSel {
  def apply(sel: Bits, data: collection.Seq[Bits]): Bits = {
    require(sel.getWidth == data.length && data.nonEmpty)
    val w = data.head.getWidth
    require(w > 0 && data.forall(_.getWidth == w), "Masked data inputs need equal positive widths")
    BalancedOr(data.zipWithIndex.map { case (d, i) => d & B(w bits, default -> sel(i)) })
  }
  def bool(sel: Bits, data: collection.Seq[Bool]): Bool = apply(sel, data.map(_.asBits)).asBool
}
