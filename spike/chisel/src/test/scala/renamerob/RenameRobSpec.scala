package renamerob

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class RenameRobSpec extends AnyFlatSpec with Matchers {

  "RenameRob" should "forward intra-bundle and allocate distinct pregs" in {
    val p = RRParams(width = 2)
    simulate(new RenameRob(p)) { dut =>
      // assert reset so RegInit state (RAT / free-list / pointers) loads
      dut.io.dispatchFire.poke(false.B)
      dut.io.in.foreach { s =>
        s.valid.poke(false.B); s.rdWen.poke(false.B)
        s.rd.poke(0.U); s.rs1.poke(0.U); s.rs2.poke(0.U)
      }
      dut.io.commitReady.foreach(_.poke(false.B))
      dut.reset.poke(true.B)
      dut.clock.step()
      dut.reset.poke(false.B)

      // slot0: rd=x1, slot1: rd=x2 reading x1 -> slot1.prs1 must equal slot0.pdst
      dut.io.in(0).valid.poke(true.B);  dut.io.in(0).rdWen.poke(true.B)
      dut.io.in(0).rd.poke(1.U); dut.io.in(0).rs1.poke(0.U); dut.io.in(0).rs2.poke(0.U)
      dut.io.in(1).valid.poke(true.B);  dut.io.in(1).rdWen.poke(true.B)
      dut.io.in(1).rd.poke(2.U); dut.io.in(1).rs1.poke(1.U); dut.io.in(1).rs2.poke(0.U)
      dut.io.commitReady.foreach(_.poke(false.B))
      dut.io.dispatchFire.poke(true.B)

      dut.io.canDispatch.expect(true.B)
      val p0 = dut.io.renamed(0).pdst.peek().litValue
      val p1 = dut.io.renamed(1).pdst.peek().litValue
      assert(p0 != p1, s"pregs must differ: $p0 == $p1")
      dut.io.renamed(1).prs1.expect(p0.U)   // intra-bundle forward of x1
      dut.clock.step()

      // both now in the ROB; commit them and check oldPdst (x1/x2 were arch 1/2)
      dut.io.dispatchFire.poke(false.B)
      dut.io.commitReady(0).poke(true.B)
      dut.io.commitReady(1).poke(true.B)
      dut.io.committed(0).valid.expect(true.B)
      dut.io.committed(0).freed.expect(1.U)  // old map of x1 was phys 1
      dut.io.committed(1).freed.expect(2.U)  // old map of x2 was phys 2
      dut.clock.step()
    }
  }

  it should "elaborate at width 4" in {
    val p = RRParams(width = 4)
    simulate(new RenameRob(p)) { dut =>
      dut.io.dispatchFire.poke(false.B)
      dut.io.in.foreach(_.valid.poke(false.B))
      dut.io.commitReady.foreach(_.poke(false.B))
      dut.clock.step()
      dut.io.canDispatch.expect(true.B)
    }
  }
}
