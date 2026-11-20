package ooo.frontend.bpred

import spinal.core._

/** Keep PC tag arithmetic outside the memory comparison cone. */
class UbtbTagMatch(tagWidth: Int) extends Component {
  setDefinitionName("ubtb_tag_match")
  addAttribute("keep_hierarchy", "yes")
  val io = new Bundle {
    val valid = in Bool()
    val tag, expected = in Bits(tagWidth bits)
    val hit = out Bool()
  }
  noIoPrefix()
  io.hit := io.valid && (io.tag === io.expected)
}
