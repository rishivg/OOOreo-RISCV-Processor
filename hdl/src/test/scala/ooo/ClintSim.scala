package ooo

import spinal.core.sim._
import ooo.memory.Clint
import org.scalatest.funsuite.AnyFunSuite

class ClintSim extends AnyFunSuite {
  for (early <- Seq(false, true); earlyRead <- Seq(false, true); retimed <- Seq(false,true)) test(s"CLINT byte writes, reads, timer and interrupts, decoded writes=$early reads=$earlyRead retimed=$retimed") {
    TestSimulation.config.compile(new Clint(CpuProfiles.named("mcu-efficient"), predecodedWrites=early, predecodedReads=earlyRead, retimedRead=retimed)).doSim { d =>
      d.io.clk #= false; d.io.rst #= true
      d.io.req_valid #= false; d.io.req_addr #= 0; d.io.req_rmask #= 0; d.io.req_wmask #= 0; d.io.req_wdata #= 0
      if (early) d.io.write_sel #= 0
      if (earlyRead) { d.io.read_sel #= 0; d.io.read_fire #= false; d.io.request_fire #= false }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      tick(); tick(); d.io.rst #= false
      val wordMask=(BigInt(1)<<32)-1; val longMask=(BigInt(1)<<64)-1
      var timer=BigInt(0); var cmp=longMask; var msip=BigInt(0); var held=BigInt(0); var haveRead=false
      def merge(old: BigInt, mask: Int, value: BigInt): BigInt = (0 until 4).foldLeft(old) { (v,b) =>
        val bits=BigInt(255)<<(8*b)
        if ((mask&(1<<b))!=0) (v & (wordMask^bits)) | (value & bits) else v
      }
      def step(valid: Boolean, addr: Int, read: Int, write: Int, data: BigInt, reset: Boolean = false): Unit = {
        d.io.req_valid #= valid; d.io.req_addr #= addr; d.io.req_rmask #= read; d.io.req_wmask #= write; d.io.req_wdata #= data
        val off=addr & 0xfffc
        if (early) {
          val index=Clint.offsets.indexOf(off)
          d.io.write_sel #= (if(valid && write!=0 && index>=0) 1<<index else 0)
        }
        if (earlyRead) {
          val index=Clint.offsets.indexOf(off)
          d.io.read_sel #= (if(valid && read!=0 && index>=0) 1<<index else 0)
          d.io.read_fire #= (valid && read!=0)
          d.io.request_fire #= (valid && (read!=0 || write!=0))
        }
        val rd=off match {
          case 0 => msip
          case 0x4000 => cmp & wordMask
          case 0x4004 => cmp >> 32
          case 0xbff8 => timer & wordMask
          case 0xbffc => timer >> 32
          case _ => BigInt(0)
        }
        if(valid && read!=0) { held=rd; haveRead=true }
        val irq=timer>=cmp
        var next=(timer+1)&longMask
        if(valid && write!=0) off match {
          case 0 => msip=merge(msip,write,data)&1
          case 0x4000 => cmp=(cmp & (longMask^wordMask)) | merge(cmp&wordMask,write,data)
          case 0x4004 => cmp=(cmp & wordMask) | (merge(cmp>>32,write,data)<<32)
          case 0xbff8 => next=(next & (longMask^wordMask)) | merge(timer&wordMask,write,data)
          case 0xbffc => next=(next & wordMask) | (merge(timer>>32,write,data)<<32)
          case _ =>
        }
        if (reset) { next=0; cmp=longMask; msip=0 }
        d.io.rst #= reset; timer=next; tick(); d.io.rst #= false
        assert(d.io.mtime.toBigInt==timer)
        assert(d.io.resp.toBoolean==(!reset && valid && (read!=0 || write!=0)))
        assert(d.io.irq_timer.toBoolean==(!reset && irq))
        assert(d.io.irq_soft.toBoolean==(msip!=0))
        if(haveRead) assert(d.io.rdata.toBigInt==held)
      }
      step(true,0xbff8,0,15,wordMask-2)
      step(true,0xbffc,0,15,BigInt(5))
      step(true,0xbff8,15,0,BigInt(0))
      step(true,0xbffc,0,15,wordMask)
      step(true,0xbff8,0,15,wordMask)
      step(false,0,0,0,BigInt(0))
      step(true,0xbff8,15,0,BigInt(0),reset=true)
      step(false,0,0,0,BigInt(0))
      step(true,0x4004,15,0,BigInt(0),reset=true)
      step(false,0,0,0,BigInt(0))
      val random=new scala.util.Random(2841)
      val addresses=Seq(0,0x4000,0x4004,0xbff8,0xbffc,0x1234)
      for(_ <- 0 until 500) {
        val kind=random.nextInt(5)
        step(kind!=0,addresses(random.nextInt(addresses.size))+random.nextInt(4),
          if(kind==1 || kind==4) 15 else 0,if(kind==2) random.nextInt(16) else 0,BigInt(32,random))
      }
    }
  }
}
