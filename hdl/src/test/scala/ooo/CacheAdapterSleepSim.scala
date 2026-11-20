package ooo

import spinal.core._
import spinal.core.sim._
import ooo.common.CacheAdapter
import org.scalatest.funsuite.AnyFunSuite

class CacheAdapterSleepSim extends AnyFunSuite {
  for (credits <- Seq(1,3,7,31)) test(s"sleep drain counts overlapping bursts and backpressures $credits exhausted credits") {
    TestSimulation.config.compile(new CacheAdapter(CpuConfig(zicsr=true,lowPower=true,maxReadBursts=credits))).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case _ =>
      }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      def burst(): Unit = {
        val beats=Seq(BigInt("fedcba9876543210",16),BigInt("1122334455667788",16),BigInt("8877665544332211",16),BigInt("0123456789abcdef",16))
        d.io.dfp_rvalid #= true
        for (i <- 0 until 4) {
          d.io.dfp_rdata #= beats(i); sleep(1)
          if (i==3) {
            assert(d.io.ufp_rvalid.toBoolean)
            assert(d.io.ufp_rdata.toBigInt==beats.zipWithIndex.map{case (v,n)=>v << (64*n)}.reduce(_|_))
          } else assert(!d.io.ufp_rvalid.toBoolean)
          tick()
        }
        d.io.dfp_rvalid #= false; sleep(1)
      }
      d.io.rst #= true; tick(); tick(); d.io.rst #= false; d.io.dfp_ready #= true
      d.io.ufp_read #= true; tick(); if (credits>1) tick(); d.io.ufp_read #= false
      assert(!d.io.idle.toBoolean)
      // Invalid data can change between responses and must never enter a line.
      for (i <- 0 until 9) { d.io.dfp_rdata #= BigInt(i+5)*BigInt("0101010101010101",16); tick(); assert(!d.io.ufp_rvalid.toBoolean) }
      if (credits>1) { burst(); assert(!d.io.idle.toBoolean,"first response must not hide the second outstanding burst") }
      burst(); assert(d.io.idle.toBoolean)
      d.io.ufp_read #= true
      for (_ <- 0 until credits) { sleep(1); assert(d.io.dfp_read.toBoolean && d.io.ufp_ready.toBoolean); tick() }
      sleep(1); assert(!d.io.dfp_read.toBoolean && !d.io.ufp_ready.toBoolean,"credit exhaustion must stop physical acceptance")
      tick(); tick(); d.io.ufp_read #= false
      for (_ <- 0 until (credits-1)) { burst(); assert(!d.io.idle.toBoolean) }
      burst(); assert(d.io.idle.toBoolean)
    }
  }
}
