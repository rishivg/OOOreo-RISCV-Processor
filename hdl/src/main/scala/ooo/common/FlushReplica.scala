package ooo.common

import spinal.core._

/** Local recovery decode; preserve replicas through synthesis to limit fanout. */
class FlushReplica extends Component {
  setDefinitionName("flush_replica")
  addAttribute("keep_hierarchy", "yes")
  addAttribute("keep", "true")
  val io = new Bundle { val causes = in Bits(6 bits); val flush = out Bool() }
  noIoPrefix()
  io.flush := io.causes.orR
}
