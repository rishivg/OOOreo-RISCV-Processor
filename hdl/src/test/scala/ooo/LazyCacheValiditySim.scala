package ooo

import spinal.core._
import spinal.core.sim._
import ooo.common.LazyCacheValidity
import org.scalatest.funsuite.AnyFunSuite

class LazyValidityHarness(width: Int) extends Component {
  val io = new Bundle {
    val clk=in Bool();val rst=in Bool();val capture=in Bool();val allocate=in Bool()
    val request=in UInt(width bits)
    val rowKnown=out Bool();val initialize=out Bool();val known=out Bits((1<<width) bits)
  }
  val domain=ClockDomain(io.clk,io.rst,config=ClockDomainConfig(resetKind=SYNC,resetActiveLevel=HIGH))
  new ClockingArea(domain) {
    val stage=Reg(UInt(width bits))
    when(io.capture) { stage:=io.request }
    val validity=new LazyCacheValidity(width,io.request,stage,io.capture,io.allocate)
    io.rowKnown:=validity.rowInitialized;io.initialize:=validity.initializeOnAllocate
    io.known:=validity.initialized.asBits
  }
}
class LazyCacheValiditySim extends AnyFunSuite {
  for(width<-Seq(4,6)) test(s"lazy row initialization width=$width preserves a redirect on publication") {
    TestSimulation.config.compile(new LazyValidityHarness(width)).doSim { d =>
      d.io.clk #= false;d.io.rst #= true;d.io.capture #= false;d.io.allocate #= false;d.io.request #= 0
      def tick(): Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
      tick();tick();d.io.rst #= false
      for(edges<-Seq(1,2,3,4)) {
        var expected=BigInt(0)
        for(row<-0 until (1<<width)) {
          val next=(row+1)%(1<<width)
          d.io.capture #= true;d.io.request #= row;tick()
          assert(d.io.rowKnown.toBoolean==expected.testBit(row))
          d.io.capture #= false;d.io.allocate #= true;sleep(1)
          val initialize= !expected.testBit(row)
          assert(d.io.initialize.toBoolean==initialize);tick()
          d.io.allocate #= false;d.io.capture #= true;d.io.request #= next;tick()
          // The completed refill publishes the old set; the redirected read
          // must still use the next set's prior initialization state.
          if(initialize) expected=expected.setBit(row)
          assert(d.io.known.toBigInt==expected)
          assert(d.io.rowKnown.toBoolean==expected.testBit(next))
          d.io.capture #= false;tick()
        }
        d.io.allocate #= true;sleep(1)
        assert(!d.io.initialize.toBoolean,"a later refill in an initialized row must preserve other ways")
        tick();d.io.allocate #= false;tick()
        d.io.rst #= true
        for(_<-0 until edges) tick()
        d.io.rst #= false;tick()
        assert(d.io.known.toBigInt==0 && !d.io.rowKnown.toBoolean)
      }
    }
  }
}
