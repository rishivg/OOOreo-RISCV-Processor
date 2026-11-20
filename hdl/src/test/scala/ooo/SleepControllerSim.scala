package ooo

import spinal.core._
import spinal.core.sim._
import ooo.common.{SleepController,SafeClockGate}
import org.scalatest.funsuite.AnyFunSuite

class SleepGateHarness(fpga: Boolean = false) extends Component {
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val request = in Bool(); val wake = in Bool()
    val quiet = in Bool(); val scan = in Bool()
    val gated = out Bool(); val sleeping = out Bool(); val halt = out Bool()
  }
  val c = new SleepController; val g = new SafeClockGate(fpga)
  c.io.clk := io.clk; c.io.rst := io.rst; c.io.sleep_request := io.request; c.io.wake := io.wake; c.io.quiescent := io.quiet
  g.io.clk := io.clk; g.io.rst := io.rst; g.io.enable := c.io.clock_enable; g.io.scan_enable := io.scan
  io.gated := g.io.gated_clk; io.sleeping := g.io.closed; io.halt := c.io.halt
}
class SleepControllerSim extends AnyFunSuite {
  for(fpga <- Seq(false,true)) test(s"drain before stopping, no truncated clock pulse, wake and reset restore clock fpga=$fpga") {
    (if(fpga) TestSimulation.config.addRtl("../fpga/sim/clock_cells.v") else TestSimulation.config).compile(new SleepGateHarness(fpga)).doSim { d =>
      d.io.clk #= false; d.io.rst #= true; d.io.request #= false; d.io.wake #= false; d.io.quiet #= false; d.io.scan #= false
      def tick(): Unit = { d.io.clk #= false; sleep(3); d.io.clk #= true; sleep(3); d.io.clk #= false; sleep(3) }
      tick(); tick(); d.io.rst #= false
      d.io.request #= true; tick(); d.io.request #= false
      for (_ <- 0 until 8) { tick(); assert(!d.io.sleeping.toBoolean && d.io.halt.toBoolean) }
      d.io.quiet #= true; tick(); assert(!d.io.sleeping.toBoolean)
      d.io.quiet #= false; tick(); assert(!d.io.sleeping.toBoolean)
      d.io.quiet #= true; tick()
      d.io.clk #= true; sleep(3)
      // Controller closes at this rising edge, but gate must preserve its high phase.
      assert(d.io.gated.toBoolean)
      d.io.clk #= false; sleep(3); assert(d.io.sleeping.toBoolean)
      for (_ <- 0 until 32) { tick(); assert(!d.io.gated.toBoolean && d.io.sleeping.toBoolean) }
      d.io.clk #= true; sleep(1); d.io.wake #= true; sleep(1); assert(!d.io.gated.toBoolean)
      d.io.clk #= false; sleep(2); tick(); tick()
      assert(!d.io.sleeping.toBoolean && !d.io.halt.toBoolean)
      // Wake wins when requested on the same cycle as entry.
      d.io.request #= true; tick(); assert(!d.io.sleeping.toBoolean && !d.io.halt.toBoolean)
      d.io.wake #= false; tick(); d.io.request #= false; tick(); tick()
      assert(d.io.sleeping.toBoolean)
      d.io.scan #= true; tick(); assert(!d.io.sleeping.toBoolean)
      d.io.scan #= false; tick(); assert(d.io.sleeping.toBoolean)
      d.io.rst #= true; tick(); tick(); assert(!d.io.sleeping.toBoolean)
    }
  }
}
