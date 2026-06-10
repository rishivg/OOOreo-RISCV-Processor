package issuequeue

import spinal.core._
import spinal.core.sim._

/** SpinalSim directed test: `runMain issuequeue.Sim` */
object Sim extends App {
  SimConfig.compile(new IssueQueue(IQParams(width = 2))).doSim { dut =>
    dut.clockDomain.forkStimulus(10)

    dut.io.allocFire #= false
    dut.io.allocValid.foreach(_ #= false)
    dut.io.wakeValid.foreach(_ #= false)
    dut.clockDomain.waitSampling()

    def setAlloc(k: Int, r2t: Int, r2r: Boolean, pl: Int): Unit = {
      dut.io.allocValid(k) #= true
      dut.io.allocData(k).rs1Tag #= 0; dut.io.allocData(k).rs1Rdy #= true
      dut.io.allocData(k).rs2Tag #= r2t; dut.io.allocData(k).rs2Rdy #= r2r
      dut.io.allocData(k).payload #= pl
    }
    // e0 (payload 7) waits on tag 40 ; e1 (payload 8) ready
    setAlloc(0, 40, false, 7)
    setAlloc(1, 0, true, 8)
    dut.io.allocFire #= true
    sleep(2)
    assert(dut.io.allocReady.toBoolean, "should accept the alloc bundle")
    dut.clockDomain.waitSampling()

    dut.io.allocFire #= false
    dut.io.allocValid.foreach(_ #= false)
    sleep(2)
    assert(dut.io.issueValid(0).toBoolean, "e1 should request")
    assert(dut.io.issuePayload(0).toBigInt == 8, "e1 payload issues first")
    assert(!dut.io.issueValid(1).toBoolean, "only one requester")
    dut.clockDomain.waitSampling()

    dut.io.wakeValid(0) #= true; dut.io.wakeTag(0) #= 40
    sleep(2)
    assert(dut.io.issueValid(0).toBoolean, "e0 woken")
    assert(dut.io.issuePayload(0).toBigInt == 7, "e0 payload issues after wakeup")
    dut.clockDomain.waitSampling()

    println("[spinal] iq sim OK")
  }
}
