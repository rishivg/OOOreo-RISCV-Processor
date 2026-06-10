package renamerob

import spinal.core._
import spinal.core.sim._

/** SpinalSim (Verilator) directed test: `runMain renamerob.Sim` */
object Sim extends App {
  SimConfig.compile(new RenameRob(RRParams(width = 2))).doSim { dut =>
    dut.clockDomain.forkStimulus(10)

    def initIn(): Unit = {
      dut.io.dispatchFire #= false
      for (i <- 0 until 2) {
        dut.io.disp(i).valid #= false; dut.io.disp(i).rdWen #= false
        dut.io.disp(i).rd #= 0; dut.io.disp(i).rs1 #= 0; dut.io.disp(i).rs2 #= 0
      }
      dut.io.commitReady.foreach(_ #= false)
    }
    initIn()
    dut.clockDomain.waitSampling()
    assert(dut.io.canDispatch.toBoolean, "should be able to dispatch from reset")

    // slot0: rd=x1 ; slot1: rd=x2 reading x1 -> intra-bundle forward
    dut.io.disp(0).valid #= true; dut.io.disp(0).rdWen #= true; dut.io.disp(0).rd #= 1
    dut.io.disp(1).valid #= true; dut.io.disp(1).rdWen #= true; dut.io.disp(1).rd #= 2
    dut.io.disp(1).rs1 #= 1
    dut.io.dispatchFire #= true
    sleep(2) // settle comb within the cycle, before the edge
    val p0 = dut.io.renamed(0).pdst.toBigInt
    val p1 = dut.io.renamed(1).pdst.toBigInt
    assert(p0 != p1, s"pregs must differ: $p0 == $p1")
    assert(dut.io.renamed(1).prs1.toBigInt == p0, "slot1.prs1 must forward slot0.pdst")
    dut.clockDomain.waitSampling() // dispatch into ROB

    // commit both; freed pregs are the old maps of x1/x2 (phys 1 / phys 2)
    initIn()
    dut.io.commitReady(0) #= true; dut.io.commitReady(1) #= true
    sleep(2)
    assert(dut.io.committed(0).freed.toBigInt == 1, "x1 old map was phys 1")
    assert(dut.io.committed(1).freed.toBigInt == 2, "x2 old map was phys 2")
    dut.clockDomain.waitSampling()

    initIn()
    dut.clockDomain.waitSampling(3)
    assert(dut.io.canDispatch.toBoolean, "free list should have recovered")
    println("[spinal] sim OK")
  }
}
