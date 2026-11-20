package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Select the oldest two ready integer entries and compact the survivors. */
class IssueArbiter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("issue_arbiter_spinal")
  val entryCount = cfg.intrsDepth
  val issueWidth = cfg.intIssueWidth
  require(entryCount > 0, "Integer reservation station must contain entries")
  require(issueWidth == 2, "Integer issue supports exactly two lanes")

  val shiftWidth = log2Up(issueWidth + 1)

  val io = new Bundle {
    val rs_request       = in  Bits (entryCount bits)
    val rs_grant         = out Bits (entryCount bits)
    val rs_compress_flat = out Bits (shiftWidth * entryCount bits)
    val fu_issue_flat    = out Bits (issueWidth * entryCount bits)
  }
  noIoPrefix()

  val requests = io.rs_request

  // A prefix summary is (at least one request, at least two requests).
  var atLeastOne: IndexedSeq[Bool] = (0 until entryCount).map(requests(_))
  var atLeastTwo: IndexedSeq[Bool] = IndexedSeq.fill(entryCount)(False)
  var distance = 1
  while (distance < entryCount) {
    val previousOne = atLeastOne
    val previousTwo = atLeastTwo
    val step = distance
    atLeastOne = IndexedSeq.tabulate(entryCount) { index =>
      if (index >= step) previousOne(index) || previousOne(index - step)
      else previousOne(index)
    }
    atLeastTwo = IndexedSeq.tabulate(entryCount) { index =>
      if (index >= step) previousTwo(index) || previousTwo(index - step) ||
        (previousOne(index) && previousOne(index - step))
      else previousTwo(index)
    }
    distance *= 2
  }
  val grant = Vec(Bool(), entryCount)
  val firstIssue = Vec(Bool(), entryCount)
  val secondIssue = Vec(Bool(), entryCount)
  val earlierOne = Vec(Bool(), entryCount)
  val earlierTwo = Vec(Bool(), entryCount)
  for (i <- 0 until entryCount) {
    earlierOne(i) := (if (i == 0) False else atLeastOne(i - 1))
    earlierTwo(i) := (if (i == 0) False else atLeastTwo(i - 1))
    grant(i) := requests(i) && !earlierTwo(i)
    firstIssue(i) := requests(i) && !earlierOne(i)
    secondIssue(i) := requests(i) && earlierOne(i) && !earlierTwo(i)
  }

  // A surviving entry shifts by the issued prefix, counting an adjacent next
  // winner only when at least one earlier entry has already issued.
  val compactionShift = Vec(Bits(shiftWidth bits), entryCount)
  for (i <- 0 until entryCount) {
    val twoRemoved = if (i + 1 < entryCount)
      atLeastTwo(i) || (atLeastOne(i) && requests(i + 1))
    else atLeastTwo(i)
    compactionShift(i) := twoRemoved ## (atLeastOne(i) && !twoRemoved)
  }

  io.rs_grant         := grant.asBits
  io.rs_compress_flat := compactionShift.asBits // Entry i occupies shiftWidth consecutive bits.
  io.fu_issue_flat    := secondIssue.asBits ## firstIssue.asBits // Low lane first.
}
