package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.DcacheTagArray
import org.scalatest.funsuite.AnyFunSuite

class TagModelHarness extends Component {
  val io = new Bundle {
    val clk = in Bool(); val csb = in Bool(); val web = in Bool()
    val addr = in Bits(4 bits); val data = in Bits(25 bits); val result = out Bits(25 bits)
  }
  val ram = new DcacheTagArray(4,25)
  ram.io.clk0 := io.clk; ram.io.csb0 := io.csb; ram.io.web0 := io.web
  ram.io.addr0 := io.addr; ram.io.din0 := io.data; io.result := ram.io.dout0
}
class DcacheTagModelSim extends AnyFunSuite {
  test("tag SRAM model preserves widened epoch/valid MSB on refill") {
    TestSimulation.config.addRtl("../sram/output/dcache_tag_array/dcache_tag_array.v").compile(new TagModelHarness).doSim { d =>
      d.io.clk #= false; d.io.csb #= false; d.io.web #= false; d.io.addr #= 3
      val word=BigInt("1801234",16)
      d.io.data #= word
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      tick(); tick(); d.io.web #= true; tick(); tick()
      assert(d.io.result.toBigInt==word,"epoch bit must be written with the tag")
    }
  }
}
