package ooo.common

import spinal.core._

/** Select the early beat independently in each way before the late way mux. */
object CacheWriteBeat {
  def apply(lines: Seq[Bits], beat: UInt, width: Int = 64): Vec[Bits] = {
    require(lines.nonEmpty && width > 0 && lines.forall(_.getWidth % width == 0))
    Vec(lines.map { line =>
      val selected = Bits(width bits)
      selected := line.subdivideIn(width bits)(beat)
      selected.addAttribute("keep")
      selected
    })
  }
}
