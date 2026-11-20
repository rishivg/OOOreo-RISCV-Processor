package ooo

import spinal.core._
import spinal.core.sim._
import ooo.common.BmemArbiter
import org.scalatest.funsuite.AnyFunSuite

class BmemWriteHoldSim extends AnyFunSuite {
  for (bypass <- Seq(false, true)) test(s"held write ownership, competing reads, backpressure and reset (data bypass=$bypass)") {
    TestSimulation.config.compile(new BmemArbiter(CpuProfiles.named("mcu-efficient").copy(bmemWriteDataBypass=bypass))).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b:Bool => b #= false
        case b:Bits => b #= 0
        case _ =>
      }
      val random=new scala.util.Random(276)
      def tick():Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
      d.io.rst #= true;tick();tick();d.io.rst #= false
      var waiting=false;var heldAddr=BigInt(0);var heldData=BigInt(0)
      for(cycle<-0 until 2500) {
        val reset=cycle%97==96
        val ready=cycle%23>=11 && random.nextBoolean()
        val write=if(waiting)random.nextBoolean() else cycle%7==0
        val read=random.nextBoolean() && !write;val iread=random.nextBoolean()
        val da=if(waiting && write)heldAddr else BigInt(32,random)
        val dw=if(waiting && write)heldData else BigInt(256,random)
        val ia=BigInt(32,random);val iw=BigInt(256,random)
        val ra=BigInt(32,random);val rd=BigInt(256,random);val rv=random.nextBoolean()
        d.io.rst #= reset;d.io.adapter_ready #= ready
        d.io.dcache_write #= write;d.io.dcache_read #= read;d.io.dcache_addr #= da;d.io.dcache_wdata #= dw
        d.io.icache_read #= iread;d.io.icache_write #= false;d.io.icache_addr #= ia;d.io.icache_wdata #= iw
        d.io.adapter_rvalid #= rv;d.io.adapter_raddr #= ra;d.io.adapter_rdata #= rd
        sleep(1)
        if(!reset) {
          val expectWrite=waiting || write
          val expectRead= !waiting && (read || (!write && iread))
          val expectAddr=if(waiting)heldAddr else if(write||read)da else ia
          val expectData=if(waiting)heldData else if(write||read)dw else if(iread)iw else BigInt(0)
          assert(d.io.adapter_write.toBoolean==expectWrite)
          assert(d.io.adapter_read.toBoolean==expectRead)
          assert(d.io.adapter_addr.toBigInt==expectAddr)
          if (!bypass || expectWrite) assert(d.io.adapter_wdata.toBigInt==expectData)
          assert(d.io.dcache_ready.toBoolean==(ready && (waiting||write||read)))
          assert(d.io.icache_ready.toBoolean==(ready && !waiting && !write && !read && iread))
          assert(d.io.icache_rvalid.toBoolean==rv && d.io.dcache_rvalid.toBoolean==rv)
          assert(d.io.icache_rdata.toBigInt==rd && d.io.dcache_rdata.toBigInt==rd)
          assert(d.io.icache_raddr.toBigInt==ra && d.io.dcache_raddr.toBigInt==ra)
        }
        if(!waiting && write){heldAddr=da;heldData=dw}
        waiting=if(reset)false else if(waiting)!ready else write
        tick()
      }
    }
  }
}
