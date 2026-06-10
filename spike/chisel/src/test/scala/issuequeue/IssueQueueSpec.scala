package issuequeue

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class IssueQueueSpec extends AnyFlatSpec with Matchers {

  "IssueQueue" should "wake a waiting operand then select it" in {
    val p = IQParams(width = 2)
    simulate(new IssueQueue(p)) { dut =>
      dut.io.allocFire.poke(false.B)
      dut.io.allocValid.foreach(_.poke(false.B))
      dut.io.wakeValid.foreach(_.poke(false.B))
      dut.reset.poke(true.B); dut.clock.step(); dut.reset.poke(false.B)

      def setAlloc(k: Int, r2t: Int, r2r: Boolean, pl: Int): Unit = {
        dut.io.allocValid(k).poke(true.B)
        dut.io.allocData(k).rs1Tag.poke(0.U); dut.io.allocData(k).rs1Rdy.poke(true.B)
        dut.io.allocData(k).rs2Tag.poke(r2t.U); dut.io.allocData(k).rs2Rdy.poke(r2r.B)
        dut.io.allocData(k).payload.poke(pl.U)
      }
      // e0 (payload 7) waits on tag 40 ; e1 (payload 8) fully ready
      setAlloc(0, 40, false, 7)
      setAlloc(1, 0,  true,  8)
      dut.io.allocFire.poke(true.B)
      dut.io.allocReady.expect(true.B)
      dut.clock.step()

      // only e1 requests -> issues payload 8 on port 0
      dut.io.allocFire.poke(false.B); dut.io.allocValid.foreach(_.poke(false.B))
      dut.io.issueValid(0).expect(true.B)
      dut.io.issuePayload(0).expect(8.U)
      dut.io.issueValid(1).expect(false.B)
      dut.clock.step()

      // wake tag 40 -> e0 becomes ready and issues payload 7
      dut.io.wakeValid(0).poke(true.B); dut.io.wakeTag(0).poke(40.U)
      dut.io.issueValid(0).expect(true.B)
      dut.io.issuePayload(0).expect(7.U)
      dut.clock.step()
    }
  }

  it should "elaborate and select 2 at width 4" in {
    val p = IQParams(width = 4)
    simulate(new IssueQueue(p)) { dut =>
      dut.io.allocFire.poke(false.B)
      dut.io.allocValid.foreach(_.poke(false.B))
      dut.io.wakeValid.foreach(_.poke(false.B))
      dut.reset.poke(true.B); dut.clock.step(); dut.reset.poke(false.B)
      dut.io.allocReady.expect(true.B)
      dut.io.full.expect(false.B)
      dut.clock.step()
    }
  }
}
