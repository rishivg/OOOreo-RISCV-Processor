package ooo

import spinal.core.sim._
import ooo.execute._
import org.scalatest.funsuite.AnyFunSuite

// Only live payloads are architectural. Exercise release/reuse, simultaneous
// dispatch and grant, wakeup, fast bypass and clear with a software scoreboard.
class RsEntryLifetimeSim extends AnyFunSuite {
  val cfg=CpuProfiles.named("mcu-efficient")
  for((name,layout)<-Seq("int"->RsEntryLayout.int(cfg),"muldiv"->RsEntryLayout.intm(cfg),
      "branch"->RsEntryLayout.br(cfg),"memory"->RsEntryLayout.mem(cfg))) {
    test(s"reservation slot lifetime and live operand equivalence: $name") {
      TestSimulation.config.compile(new RsEntry(cfg,layout)).doSim { d =>
        d.io.push_en #= false;d.io.grant #= false;d.io.clear #= false;d.io.entry_in #= 0
        for(k<-0 until cfg.cdbWidth){d.io.wakeup_cdb(k).valid #= false;d.io.wakeup_cdb(k).rd_phy #= 0}
        for(k<-0 until cfg.numFastBypass){d.io.fast_bypass(k).valid #= false;d.io.fast_bypass(k).rd_phy #= 0;d.io.fast_bypass(k).rd_value #= 0}
        d.clockDomain.forkStimulus(10);d.clockDomain.waitSampling(3)
        var valid=false;var payload=BigInt(0)
        val random=new scala.util.Random(911+layout.width)
        val pmask=(BigInt(1)<<cfg.prfIdx)-1
        def phy(off:Int)=((payload>>off)&pmask).toInt
        for(cycle<-0 until 2200) {
          d.clockDomain.waitFallingEdge()
          val push=random.nextInt(5)==0;val grant=random.nextInt(4)==0;val clear=random.nextInt(29)==0
          val incoming=BigInt(layout.width,random)
          d.io.push_en #= push;d.io.grant #= grant;d.io.clear #= clear;d.io.entry_in #= incoming
          val cdb=(0 until cfg.cdbWidth).map { k =>
            val p=if(k==0 && cycle%3==0) phy(layout.rs1PhyLsb) else if(k==1 && cycle%4==0) phy(layout.rs2PhyLsb) else random.nextInt(cfg.prfDepth)
            val en=random.nextBoolean();d.io.wakeup_cdb(k).valid #= en;d.io.wakeup_cdb(k).rd_phy #= p;(en,p)
          }
          val fb=(0 until cfg.numFastBypass).map { k =>
            val p=if(k==0 && cycle%5==0) phy(layout.rs1PhyLsb) else random.nextInt(cfg.prfDepth)
            val en=random.nextBoolean();d.io.fast_bypass(k).valid #= en;d.io.fast_bypass(k).rd_phy #= p;d.io.fast_bypass(k).rd_value #= BigInt(32,random);(en,p)
          }
          sleep(1)
          assert(d.io.valid.toBoolean==valid)
          val m1=cdb.exists{case(en,p)=>en && p==phy(layout.rs1PhyLsb)}
          val m2=cdb.exists{case(en,p)=>en && p==phy(layout.rs2PhyLsb)}
          var woken=payload
          if(m1)woken=woken.setBit(layout.rs1ValidLsb)
          if(m2)woken=woken.setBit(layout.rs2ValidLsb)
          if(valid) {
            assert(d.io.entry.toBigInt==payload,s"live registered payload cycle $cycle")
            assert(d.io.entry_out.toBigInt==woken,s"live wakeup payload cycle $cycle")
            def bypass(off:Int)=cdb.zipWithIndex.foldLeft(BigInt(0)){case(b,((en,p),k))=>if(en && p!=0 && p==phy(off))b.setBit(k) else b} |
              (if(fb.exists{case(en,p)=>en && p!=0 && p==phy(off)})BigInt(1)<<cfg.cdbWidth else BigInt(0))
            val en1=bypass(layout.rs1PhyLsb);val en2=bypass(layout.rs2PhyLsb)
            assert(d.io.rs_bypass.rs1_bypass_en.toBigInt==en1)
            assert(d.io.rs_bypass.rs2_bypass_en.toBigInt==en2)
            assert(d.io.request.toBoolean==((payload.testBit(layout.rs1ValidLsb)||en1!=0)&&(payload.testBit(layout.rs2ValidLsb)||en2!=0)))
          } else assert(!d.io.request.toBoolean)
          payload=if(push)incoming else woken
          valid=if(clear)false else if(push)true else if(grant)false else valid
          d.clockDomain.waitSampling();sleep(1)
        }
      }
    }
  }
}
