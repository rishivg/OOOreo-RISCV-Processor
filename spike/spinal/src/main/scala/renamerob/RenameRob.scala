package renamerob

import spinal.core._
import spinal.lib._

/** Parameters for the N-wide rename + ROB spike. `width` is the scaling axis. */
case class RRParams(
  width:    Int = 2,
  nArch:    Int = 32,
  nPhys:    Int = 64,
  robDepth: Int = 32
) {
  require(nPhys > nArch, "need physical regs beyond the architectural set")
  require(isPow2(nPhys - nArch), "keep free-list depth pow2 so the spike isolates width")
  require(isPow2(robDepth), "keep rob depth pow2 so the spike isolates width")
  val nFree   = nPhys - nArch
  val pregW   = log2Up(nPhys)
  val aregW   = log2Up(nArch)
  val flIdxW  = log2Up(nFree)
  val robIdxW = log2Up(robDepth)
}

case class DispatchSlot(p: RRParams) extends Bundle {
  val valid = Bool()
  val rd    = UInt(p.aregW bits)
  val rs1   = UInt(p.aregW bits)
  val rs2   = UInt(p.aregW bits)
  val rdWen = Bool()
}

case class RenamedSlot(p: RRParams) extends Bundle {
  val valid   = Bool()
  val prs1    = UInt(p.pregW bits)
  val prs2    = UInt(p.pregW bits)
  val pdst    = UInt(p.pregW bits)
  val oldPdst = UInt(p.pregW bits)
}

case class CommittedSlot(p: RRParams) extends Bundle {
  val valid = Bool()
  val freed = UInt(p.pregW bits)
}

class RenameRob(p: RRParams) extends Component {
  import p._
  val io = new Bundle {
    // `disp` not `in` -- `in`/`out` are SpinalHDL direction keywords (a field
    // named `in` self-references the direction function). The Chisel twin uses
    // `io.in`; this divergence is itself a small ergonomic data point.
    val disp         = in (Vec(DispatchSlot(p), width))
    val dispatchFire = in  Bool()
    val canDispatch  = out Bool()
    val renamed      = out(Vec(RenamedSlot(p), width))
    val commitReady  = in (Vec(Bool(), width))
    val committed    = out(Vec(CommittedSlot(p), width))
  }

  // prefix popcount of mask[0..i) -- mask is a plain Scala Seq[Bool] so CountOne
  // and .take work (a SpinalHDL Vec does not slice into a Seq[Bool]).
  def prefix(mask: Seq[Bool], i: Int): UInt =
    if (i == 0) U(0, log2Up(width + 1) bits) else CountOne(mask.take(i))

  // ---- architectural rename table ----
  val rat = Vec.tabulate(nArch)(i => RegInit(U(i, pregW bits)))

  // ---- free list: circular queue of free pregs (depth nFree, pow2) ----
  val fl     = Vec.tabulate(nFree)(i => RegInit(U(nArch + i, pregW bits)))
  val flHead = RegInit(U(0, flIdxW + 1 bits))
  val flTail = RegInit(U(nFree, flIdxW + 1 bits))
  val flCount = flTail - flHead

  // ---- ROB: circular buffer (depth robDepth, pow2) ----
  val robRd   = Vec.fill(robDepth)(Reg(UInt(aregW bits)))
  val robPdst = Vec.fill(robDepth)(Reg(UInt(pregW bits)))
  val robOld  = Vec.fill(robDepth)(Reg(UInt(pregW bits)))
  val robWen  = Vec.fill(robDepth)(Reg(Bool()))
  val robHead = RegInit(U(0, robIdxW + 1 bits))
  val robTail = RegInit(U(0, robIdxW + 1 bits))
  val robCount = robTail - robHead

  // ---- combinational rename ---- (masks are Scala Seqs for CountOne/.take)
  val writeMask: Seq[Bool] = (0 until width).map(i => io.disp(i).valid && io.disp(i).rdWen)
  val validMask: Seq[Bool] = (0 until width).map(i => io.disp(i).valid)

  val pdst = Vec(UInt(pregW bits), width)
  for (i <- 0 until width) {
    pdst(i) := fl((flHead + prefix(writeMask, i)).resize(flIdxW))
  }

  def lookup(areg: UInt, i: Int): UInt = {
    val res = UInt(pregW bits)
    res := rat(areg)
    for (j <- 0 until i) {
      when(writeMask(j) && io.disp(j).rd === areg) { res := pdst(j) }
    }
    res
  }
  val oldPdst = Vec(UInt(pregW bits), width)
  for (i <- 0 until width) oldPdst(i) := lookup(io.disp(i).rd, i)

  for (i <- 0 until width) {
    io.renamed(i).valid   := io.disp(i).valid
    io.renamed(i).prs1    := lookup(io.disp(i).rs1, i)
    io.renamed(i).prs2    := lookup(io.disp(i).rs2, i)
    io.renamed(i).pdst    := pdst(i)
    io.renamed(i).oldPdst := oldPdst(i)
  }

  val allocCount = CountOne(writeMask)
  val validCount = CountOne(validMask)
  io.canDispatch := (allocCount <= flCount) && (validCount <= (U(robDepth) - robCount))
  val doDispatch = io.dispatchFire && io.canDispatch

  // ---- commit: in-order prefix of commitReady, bounded by occupancy ----
  val commitMask = Array.fill(width)(Bool())
  var prevOk: Bool = True
  for (i <- 0 until width) {
    commitMask(i) := prevOk && io.commitReady(i) && (U(i) < robCount)
    prevOk = commitMask(i)
  }
  val freeMask = Array.fill(width)(Bool())
  for (i <- 0 until width) {
    val idx = (robHead + U(i)).resize(robIdxW)
    io.committed(i).valid := commitMask(i)
    io.committed(i).freed := robOld(idx)
    freeMask(i) := commitMask(i) && robWen(idx)
  }
  val commitCount = CountOne(commitMask.toSeq)
  val freeCount   = CountOne(freeMask.toSeq)

  // ---- sequential state updates ----
  when(doDispatch) {
    for (i <- 0 until width) {
      when(writeMask(i)) { rat(io.disp(i).rd) := pdst(i) }   // youngest writer wins
    }
    flHead := flHead + allocCount
    for (i <- 0 until width) {
      when(validMask(i)) {
        val idx = (robTail + prefix(validMask, i)).resize(robIdxW)
        robRd(idx)   := io.disp(i).rd
        robPdst(idx) := pdst(i)
        robOld(idx)  := oldPdst(i)
        robWen(idx)  := writeMask(i)
      }
    }
    robTail := robTail + validCount
  }

  when(commitCount =/= 0) {
    robHead := robHead + commitCount
    for (i <- 0 until width) {
      when(freeMask(i)) {
        fl((flTail + prefix(freeMask.toSeq, i)).resize(flIdxW)) := io.committed(i).freed
      }
    }
    flTail := flTail + freeCount
  }
}
