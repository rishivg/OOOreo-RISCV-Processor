package ooo.frontend

import spinal.core._
import spinal.lib._

/** Shared late direction decoder for precomputed fetch outcomes. */
class FetchOutcomeDecode(width:Int) extends Component {
  setDefinitionName("fetch_outcome_decode")
  addAttribute("keep_hierarchy","yes")
  val io=new Bundle {
    val direction=in Bits(width bits)
    val selected=out Bits((1 << width) bits)
  }
  noIoPrefix()
  io.selected:=UIntToOh(io.direction.asUInt,1 << width)
}
