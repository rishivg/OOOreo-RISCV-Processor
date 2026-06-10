package issuequeue

import chisel3._
import chisel3.util._

/** N-wide issue queue: wakeup CAM + priority select. `width` (= issue ports =
  * CDB wakeup ports) is the scaling axis; `nEntries` is fixed. */
case class IQParams(width: Int = 2, nEntries: Int = 16, nPhys: Int = 64, payloadW: Int = 6) {
  require(isPow2(nEntries))
  require(isPow2(width), "width pow2 keeps the alloc-slot index clean for the spike")
  val pregW = log2Ceil(nPhys)
  val idxW  = log2Ceil(nEntries)
  val cntW  = log2Ceil(nEntries + 1)
  val selW  = log2Ceil(width)
}

class IQEntryIn(p: IQParams) extends Bundle {
  val rs1Tag  = UInt(p.pregW.W)
  val rs1Rdy  = Bool()
  val rs2Tag  = UInt(p.pregW.W)
  val rs2Rdy  = Bool()
  val payload = UInt(p.payloadW.W)
}

class IQIO(p: IQParams) extends Bundle {
  val allocFire  = Input(Bool())
  val allocValid = Input(Vec(p.width, Bool()))          // prefix-packed
  val allocData  = Input(Vec(p.width, new IQEntryIn(p)))
  val allocReady = Output(Bool())
  val wakeValid  = Input(Vec(p.width, Bool()))          // CDB broadcast ports
  val wakeTag    = Input(Vec(p.width, UInt(p.pregW.W)))
  val issueValid   = Output(Vec(p.width, Bool()))
  val issuePayload = Output(Vec(p.width, UInt(p.payloadW.W)))
  val full = Output(Bool())
}

class IssueQueue(p: IQParams) extends Module {
  import p._
  val io = IO(new IQIO(p))

  val valid   = RegInit(VecInit(Seq.fill(nEntries)(false.B)))
  val rs1Tag  = Reg(Vec(nEntries, UInt(pregW.W)))
  val rs1Rdy  = Reg(Vec(nEntries, Bool()))
  val rs2Tag  = Reg(Vec(nEntries, UInt(pregW.W)))
  val rs2Rdy  = Reg(Vec(nEntries, Bool()))
  val payload = Reg(Vec(nEntries, UInt(payloadW.W)))

  private def prefix(mask: Seq[Bool], i: Int): UInt =
    if (i == 0) 0.U(cntW.W) else PopCount(mask.take(i))

  // CAM: does any wakeup port broadcast this tag this cycle?
  def anyWake(tag: UInt): Bool =
    (0 until width).map(w => io.wakeValid(w) && io.wakeTag(w) === tag).reduce(_ || _)

  // ---- combinational wakeup + request ----
  val woke1 = Wire(Vec(nEntries, Bool()))
  val woke2 = Wire(Vec(nEntries, Bool()))
  val req   = Wire(Vec(nEntries, Bool()))
  for (e <- 0 until nEntries) {
    woke1(e) := rs1Rdy(e) || anyWake(rs1Tag(e))
    woke2(e) := rs2Rdy(e) || anyWake(rs2Tag(e))
    req(e)   := valid(e) && woke1(e) && woke2(e)         // back-to-back: woken this cycle can issue
  }

  // ---- select up to `width` requesters, lowest-index priority ----
  val reqMask   = (0 until nEntries).map(req(_))
  val reqPrefix = Wire(Vec(nEntries, UInt(cntW.W)))
  for (e <- 0 until nEntries) reqPrefix(e) := prefix(reqMask, e)
  val granted = Wire(Vec(nEntries, Bool()))
  for (e <- 0 until nEntries) granted(e) := req(e) && (reqPrefix(e) < width.U)
  val numReq = PopCount(reqMask)

  for (k <- 0 until width) {
    io.issueValid(k)   := k.U < numReq
    io.issuePayload(k) := Mux1H((0 until nEntries).map(e =>
      (req(e) && (reqPrefix(e) === k.U)) -> payload(e)))
  }

  // ---- allocate into cycle-start-free slots (prefix-packed inputs) ----
  val freeMask   = (0 until nEntries).map(e => !valid(e))
  val freePrefix = Wire(Vec(nEntries, UInt(cntW.W)))
  for (e <- 0 until nEntries) freePrefix(e) := prefix(freeMask, e)
  val numFree  = PopCount(freeMask)
  val numAlloc = PopCount(io.allocValid)
  io.allocReady := numAlloc <= numFree
  io.full       := numFree === 0.U
  val doAlloc = io.allocFire && io.allocReady

  // ---- state update ----
  for (e <- 0 until nEntries) {
    when(valid(e)) { rs1Rdy(e) := woke1(e); rs2Rdy(e) := woke2(e) }  // latch wakeups
    when(granted(e)) { valid(e) := false.B }                         // issued -> free next cyc
  }
  when(doAlloc) {
    for (e <- 0 until nEntries) {
      when(freeMask(e) && (freePrefix(e) < numAlloc)) {
        val j = freePrefix(e)(selW - 1, 0)        // which (prefix-packed) alloc input
        valid(e)   := true.B
        rs1Tag(e)  := io.allocData(j).rs1Tag
        rs1Rdy(e)  := io.allocData(j).rs1Rdy
        rs2Tag(e)  := io.allocData(j).rs2Tag
        rs2Rdy(e)  := io.allocData(j).rs2Rdy
        payload(e) := io.allocData(j).payload
      }
    }
  }
}
