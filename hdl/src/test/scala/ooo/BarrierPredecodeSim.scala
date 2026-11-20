package ooo

import spinal.core._
import spinal.core.sim._
import ooo.frontend.InstQueue
import org.scalatest.funsuite.AnyFunSuite

class BarrierPredecodeSim extends AnyFunSuite {
  test("fetch metadata classifies FENCE and WFI as serial memory operations") {
    TestSimulation.config.compile(new InstQueue(CpuConfig(zicsr=true,lowPower=true,mmio=true),depth=8)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case u: UInt => u #= 0
        case _ =>
      }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      for (barrier <- Seq(BigInt("0ff0000f",16),BigInt("0000100f",16),BigInt("10500073",16))) {
        d.io.rst #= true; tick(); tick(); d.io.rst #= false
        d.io.in_inst_flat #= (barrier << 32) | BigInt("00541223",16)
        d.io.in_inst_raw_flat #= (barrier << 32) | BigInt("00541223",16)
        d.io.in_valid_slots #= 3; d.io.in_valid #= true; tick(); d.io.in_valid #= false
        assert(d.io.out_valid.toBoolean)
        assert((d.io.out_pre_rs_type_flat.toInt & 15)==15,"store/barrier dispatch row must be recognized as two memory operations")
        assert((d.io.out_pre_is_atomic.toInt & 2)!=0,"barrier must trigger serial-op dispatch filtering")
      }
    }
  }
}
