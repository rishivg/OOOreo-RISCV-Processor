package renamerob

import chisel3._
import chisel3.util._

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
  val pregW   = log2Ceil(nPhys)
  val aregW   = log2Ceil(nArch)
  val flIdxW  = log2Ceil(nFree)
  val robIdxW = log2Ceil(robDepth)
  val cntW    = log2Ceil(width + 1)
}

class DispatchSlot(p: RRParams) extends Bundle {
  val valid = Bool()
  val rd    = UInt(p.aregW.W)
  val rs1   = UInt(p.aregW.W)
  val rs2   = UInt(p.aregW.W)
  val rdWen = Bool()
}

class RenamedSlot(p: RRParams) extends Bundle {
  val valid   = Bool()
  val prs1    = UInt(p.pregW.W)
  val prs2    = UInt(p.pregW.W)
  val pdst    = UInt(p.pregW.W)
  val oldPdst = UInt(p.pregW.W)
}

class CommittedSlot(p: RRParams) extends Bundle {
  val valid = Bool()
  val freed = UInt(p.pregW.W)
}

class RenameRobIO(p: RRParams) extends Bundle {
  val in           = Input(Vec(p.width, new DispatchSlot(p)))
  val dispatchFire = Input(Bool())
  val canDispatch  = Output(Bool())
  val renamed      = Output(Vec(p.width, new RenamedSlot(p)))
  val commitReady  = Input(Vec(p.width, Bool()))
  val committed    = Output(Vec(p.width, new CommittedSlot(p)))
}

class RenameRob(p: RRParams) extends Module {
  import p._
  val io = IO(new RenameRobIO(p))

  // prefix popcount: number of set bits in mask[0..i)
  private def prefix(mask: Seq[Bool], i: Int): UInt =
    if (i == 0) 0.U(cntW.W) else PopCount(mask.take(i))

  // ---- architectural rename table ----
  val rat = RegInit(VecInit(Seq.tabulate(nArch)(i => i.U(pregW.W))))

  // ---- free list: circular queue of free pregs (depth nFree, pow2) ----
  val fl     = RegInit(VecInit(Seq.tabulate(nFree)(i => (nArch + i).U(pregW.W))))
  val flHead = RegInit(0.U((flIdxW + 1).W))           // pop side
  val flTail = RegInit(nFree.U((flIdxW + 1).W))        // push side (starts full)
  val flCount = flTail - flHead

  // ---- ROB: circular buffer (depth robDepth, pow2) ----
  val robRd   = Reg(Vec(robDepth, UInt(aregW.W)))
  val robPdst = Reg(Vec(robDepth, UInt(pregW.W)))
  val robOld  = Reg(Vec(robDepth, UInt(pregW.W)))
  val robWen  = Reg(Vec(robDepth, Bool()))
  val robHead = RegInit(0.U((robIdxW + 1).W))
  val robTail = RegInit(0.U((robIdxW + 1).W))
  val robCount = robTail - robHead

  // ---- combinational rename ----
  val writeMask = VecInit((0 until width).map(i => io.in(i).valid && io.in(i).rdWen))
  val validMask = VecInit((0 until width).map(i => io.in(i).valid))

  // physical reg each writer pops = free-list[head + (#writers before it)]
  val pdst = Wire(Vec(width, UInt(pregW.W)))
  for (i <- 0 until width) {
    pdst(i) := fl((flHead + prefix(writeMask, i))(flIdxW - 1, 0))
  }

  // intra-bundle forwarded lookup of an arch reg as seen by slot i
  def lookup(areg: UInt, i: Int): UInt = {
    val res = WireDefault(rat(areg))
    for (j <- 0 until i) {
      when(writeMask(j) && io.in(j).rd === areg) { res := pdst(j) }
    }
    res
  }
  val oldPdst = Wire(Vec(width, UInt(pregW.W)))
  for (i <- 0 until width) oldPdst(i) := lookup(io.in(i).rd, i)

  for (i <- 0 until width) {
    io.renamed(i).valid   := io.in(i).valid
    io.renamed(i).prs1    := lookup(io.in(i).rs1, i)
    io.renamed(i).prs2    := lookup(io.in(i).rs2, i)
    io.renamed(i).pdst    := pdst(i)
    io.renamed(i).oldPdst := oldPdst(i)
  }

  val allocCount = PopCount(writeMask)
  val validCount = PopCount(validMask)
  io.canDispatch := (allocCount <= flCount) && (validCount <= (robDepth.U - robCount))
  val doDispatch = io.dispatchFire && io.canDispatch

  // ---- commit: in-order prefix of commitReady, bounded by occupancy ----
  val commitMask = Wire(Vec(width, Bool()))
  var prevOk = true.B
  for (i <- 0 until width) {
    commitMask(i) := prevOk && io.commitReady(i) && (i.U < robCount)
    prevOk = commitMask(i)
  }
  val freeMask = Wire(Vec(width, Bool()))
  for (i <- 0 until width) {
    val idx = (robHead + i.U)(robIdxW - 1, 0)
    io.committed(i).valid := commitMask(i)
    io.committed(i).freed := robOld(idx)
    freeMask(i) := commitMask(i) && robWen(idx)
  }
  val commitCount = PopCount(commitMask)
  val freeCount   = PopCount(freeMask)

  // ---- sequential state updates ----
  when(doDispatch) {
    for (i <- 0 until width) {                      // RAT: youngest writer wins
      when(writeMask(i)) { rat(io.in(i).rd) := pdst(i) }
    }
    flHead := flHead + allocCount                   // pop free list
    for (i <- 0 until width) {                      // push ROB (one per valid slot)
      when(validMask(i)) {
        val idx = (robTail + prefix(validMask, i))(robIdxW - 1, 0)
        robRd(idx)   := io.in(i).rd
        robPdst(idx) := pdst(i)
        robOld(idx)  := oldPdst(i)
        robWen(idx)  := writeMask(i)
      }
    }
    robTail := robTail + validCount
  }

  when(commitCount =/= 0.U) {
    robHead := robHead + commitCount
    for (i <- 0 until width) {                      // push freed pregs back
      when(freeMask(i)) {
        fl((flTail + prefix(freeMask, i))(flIdxW - 1, 0)) := io.committed(i).freed
      }
    }
    flTail := flTail + freeCount
  }
}
