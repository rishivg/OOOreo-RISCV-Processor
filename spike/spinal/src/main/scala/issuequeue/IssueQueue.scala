package issuequeue

import spinal.core._
import spinal.lib._

case class IQParams(width: Int = 2, nEntries: Int = 16, nPhys: Int = 64, payloadW: Int = 6) {
  require(isPow2(nEntries))
  require(isPow2(width))
  val pregW = log2Up(nPhys)
  val idxW  = log2Up(nEntries)
  val cntW  = log2Up(nEntries + 1)
  val selW  = log2Up(width)
}

case class IQEntryIn(p: IQParams) extends Bundle {
  val rs1Tag  = UInt(p.pregW bits)
  val rs1Rdy  = Bool()
  val rs2Tag  = UInt(p.pregW bits)
  val rs2Rdy  = Bool()
  val payload = UInt(p.payloadW bits)
}

class IssueQueue(p: IQParams) extends Component {
  import p._
  val io = new Bundle {
    val allocFire  = in  Bool()
    val allocValid = in (Vec(Bool(), width))
    val allocData  = in (Vec(IQEntryIn(p), width))
    val allocReady = out Bool()
    val wakeValid  = in (Vec(Bool(), width))
    val wakeTag    = in (Vec(UInt(pregW bits), width))
    val issueValid   = out(Vec(Bool(), width))
    val issuePayload = out(Vec(UInt(payloadW bits), width))
    val full = out Bool()
  }

  val valid   = Vec.fill(nEntries)(RegInit(False))
  val rs1Tag  = Vec.fill(nEntries)(Reg(UInt(pregW bits)))
  val rs1Rdy  = Vec.fill(nEntries)(Reg(Bool()))
  val rs2Tag  = Vec.fill(nEntries)(Reg(UInt(pregW bits)))
  val rs2Rdy  = Vec.fill(nEntries)(Reg(Bool()))
  val payload = Vec.fill(nEntries)(Reg(UInt(payloadW bits)))

  // fixed cntW width so comparisons (< width) aren't flagged out-of-range
  def prefix(mask: Seq[Bool], i: Int): UInt =
    if (i == 0) U(0, cntW bits) else CountOne(mask.take(i)).resize(cntW)

  def anyWake(tag: UInt): Bool =
    (0 until width).map(w => io.wakeValid(w) && io.wakeTag(w) === tag).reduce(_ || _)

  // ---- combinational wakeup + request ----
  val woke1 = (0 until nEntries).map(e => rs1Rdy(e) || anyWake(rs1Tag(e)))
  val woke2 = (0 until nEntries).map(e => rs2Rdy(e) || anyWake(rs2Tag(e)))
  val req   = (0 until nEntries).map(e => valid(e) && woke1(e) && woke2(e))

  // ---- select up to `width`, lowest-index priority ----
  val reqPrefix = (0 until nEntries).map(e => prefix(req, e))
  val granted   = (0 until nEntries).map(e => req(e) && (reqPrefix(e) < U(width, cntW bits)))
  val numReq    = CountOne(req).resize(cntW)

  for (k <- 0 until width) {
    io.issueValid(k) := U(k, cntW bits) < numReq
    // one-hot OR-mux: exactly one entry has reqPrefix==k among requesters
    io.issuePayload(k) := (0 until nEntries)
      .map(e => Mux(req(e) && (reqPrefix(e) === U(k, cntW bits)), payload(e), U(0, payloadW bits)))
      .reduce(_ | _)
  }

  // ---- allocate into cycle-start-free slots (prefix-packed inputs) ----
  val freeMask   = (0 until nEntries).map(e => !valid(e))
  val freePrefix = (0 until nEntries).map(e => prefix(freeMask, e))
  val numFree    = CountOne(freeMask).resize(cntW)
  val numAlloc   = CountOne((0 until width).map(io.allocValid(_))).resize(cntW)
  io.allocReady := numAlloc <= numFree
  io.full       := numFree === 0
  val doAlloc = io.allocFire && io.allocReady

  // ---- state update ----
  for (e <- 0 until nEntries) {
    when(valid(e)) { rs1Rdy(e) := woke1(e); rs2Rdy(e) := woke2(e) }
    when(granted(e)) { valid(e) := False }
  }
  when(doAlloc) {
    for (e <- 0 until nEntries) {
      when(freeMask(e) && (freePrefix(e) < numAlloc)) {
        val j = freePrefix(e).resize(selW)
        valid(e)   := True
        rs1Tag(e)  := io.allocData(j).rs1Tag
        rs1Rdy(e)  := io.allocData(j).rs1Rdy
        rs2Tag(e)  := io.allocData(j).rs2Tag
        rs2Rdy(e)  := io.allocData(j).rs2Rdy
        payload(e) := io.allocData(j).payload
      }
    }
  }
}
