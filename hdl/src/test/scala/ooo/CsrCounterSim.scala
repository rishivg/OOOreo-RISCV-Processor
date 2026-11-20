package ooo

import spinal.core._
import spinal.core.sim._
import ooo.csr.Csr
import org.scalatest.funsuite.AnyFunSuite

class CsrCounterSim extends AnyFunSuite {
  private lazy val compiledCsr = TestSimulation.config.compile(new Csr(CpuProfiles.named("mcu-efficient")))
  test("banked cycle/instret counters preserve inhibition, carries, writes and read adjustment") {
    compiledCsr.doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case u: UInt => u #= 0
        case _ =>
      }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      d.io.rst #= true; tick(); tick(); d.io.rst #= false
      val wordMask=(BigInt(1)<<32)-1; val longMask=(BigInt(1)<<64)-1
      var counter=BigInt(0); var inhibited=false
      var cycleCounter=BigInt(0); var cycleInhibited=false
      def step(inc: Int, adj: Int, addr: Int, write: Boolean, value: BigInt): Unit = {
        d.io.instret_inc #= inc; d.io.acc_instret_adj #= adj
        d.io.acc_en #= true; d.io.acc_addr #= addr; d.io.acc_write #= write; d.io.acc_op #= 1; d.io.acc_wdata #= value
        val adjusted=(counter+(if(inhibited) 0 else adj))&longMask
        sleep(1)
        if(addr==0xb02) assert(d.io.acc_rdata.toBigInt==(adjusted&wordMask))
        if(addr==0xb82) assert(d.io.acc_rdata.toBigInt==(adjusted>>32))
        if(addr==0xb00) assert(d.io.acc_rdata.toBigInt==(cycleCounter&wordMask))
        if(addr==0xb80) assert(d.io.acc_rdata.toBigInt==(cycleCounter>>32))
        assert(!d.io.acc_illegal.toBoolean)
        var next=(counter+(if(inhibited) 0 else inc))&longMask
        var nextCycle=(cycleCounter+(if(cycleInhibited) 0 else 1))&longMask
        if(write) addr match {
          case 0xb02 => next=(counter&(longMask^wordMask))|value
          case 0xb82 => next=(counter&wordMask)|(value<<32)
          case 0xb00 => nextCycle=(cycleCounter&(longMask^wordMask))|value
          case 0xb80 => nextCycle=(cycleCounter&wordMask)|(value<<32)
          case 0x320 => inhibited=value.testBit(2); cycleInhibited=value.testBit(0)
          case _ =>
        }
        counter=next; cycleCounter=nextCycle; tick()
        d.io.acc_en #= false; d.io.acc_write #= false; d.io.acc_instret_adj #= 0
        d.io.acc_addr #= 0xb02; sleep(1); assert(d.io.acc_rdata.toBigInt==(counter&wordMask))
        d.io.acc_addr #= 0xb82; sleep(1); assert(d.io.acc_rdata.toBigInt==(counter>>32))
        d.io.acc_addr #= 0xb00; sleep(1); assert(d.io.acc_rdata.toBigInt==(cycleCounter&wordMask))
        d.io.acc_addr #= 0xb80; sleep(1); assert(d.io.acc_rdata.toBigInt==(cycleCounter>>32))
      }
      step(0,0,0xb02,true,wordMask)
      step(2,0,0xb02,false,BigInt(0))
      step(0,1,0xb82,false,BigInt(0))
      step(0,0,0xb80,true,wordMask)
      step(0,0,0xb00,true,wordMask)
      step(0,0,0xb00,false,BigInt(0))
      step(0,0,0xb82,true,wordMask)
      step(0,0,0xb02,true,wordMask)
      step(2,1,0xb82,false,BigInt(0))
      // Exercise every possible fine-bank boundary, including 64-bit wrap,
      // all two-bit retire-count encodings, and a CSR write on a carry edge.
      for (boundary <- 4 to 64 by 4; offset <- 1 to 3; inc <- 0 to 3) {
        step(0,0,0x320,true,BigInt(5))
        val start = ((BigInt(1) << boundary) - offset) & longMask
        val cycleStart = ((BigInt(1) << boundary) - 1) & longMask
        step(0,0,0xb82,true,start >> 32)
        step(0,0,0xb02,true,start & wordMask)
        step(0,0,0xb80,true,cycleStart >> 32)
        step(0,0,0xb00,true,cycleStart & wordMask)
        step(0,0,0x320,true,BigInt(0))
        step(inc,inc,0xb02,false,BigInt(0))
        step(0,0,0xb82,false,BigInt(0))
        if (offset == 1 && inc == 3) {
          step(0,0,0x320,true,BigInt(5))
          step(0,0,0xb82,true,start >> 32)
          step(0,0,0xb02,true,start & wordMask)
          step(0,0,0x320,true,BigInt(0))
          step(3,0,0xb02,true,BigInt("deadbeef",16))
        }
      }
      val random=new scala.util.Random(744)
      for(_ <- 0 until 500) {
        val addr=Seq(0xb02,0xb82,0x320,0xb00,0xb80)(random.nextInt(5))
        step(random.nextInt(4),random.nextInt(4),addr,random.nextInt(7)==0,BigInt(32,random))
      }
    }
  }
  test("mip writes preserve platform inputs while read-only CSR writes still trap") {
    compiledCsr.doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case u: UInt => u #= 0
        case _ =>
      }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      d.io.rst #= true; tick(); tick(); d.io.rst #= false
      d.io.acc_en #= true
      for (pending <- Seq(0, 8, 128, 2048, 2184); op <- Seq(1, 2, 3, 5, 6, 7); value <- Seq(BigInt(0), BigInt("ffffffff", 16))) {
        d.io.irq_soft #= ((pending & 8) != 0)
        d.io.irq_timer #= ((pending & 128) != 0)
        d.io.irq_ext #= ((pending & 2048) != 0)
        d.io.acc_addr #= 0x344; d.io.acc_op #= op
        d.io.acc_write #= true; d.io.acc_wdata #= value
        sleep(1)
        assert(!d.io.acc_illegal.toBoolean)
        assert(d.io.acc_rdata.toInt == pending)
        tick()
        assert(d.io.acc_rdata.toInt == pending)
      }
      for (address <- Seq(0xf11, 0xf12, 0xf13, 0xf14, 0xc00, 0xc01, 0xc02, 0xc80, 0xc81, 0xc82)) {
        d.io.acc_addr #= address; d.io.acc_write #= true; sleep(1)
        assert(d.io.acc_illegal.toBoolean)
        d.io.acc_write #= false; sleep(1)
        assert(!d.io.acc_illegal.toBoolean)
      }
    }
  }

}
