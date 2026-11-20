package ooo

import spinal.core._
import spinal.core.sim._
import ooo.rename.Rat
import org.scalatest.funsuite.AnyFunSuite

class RatOwnershipSim extends AnyFunSuite {
  test("RAT wakeup ownership, simultaneous rename, forwarding, x0 and flush") {
    val cfg=CpuProfiles.named("mcu-efficient")
    TestSimulation.config.compile(new Rat(cfg)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {case b:Bool=>b #= false;case b:Bits=>b #= 0;case _=>}
      def tick():Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
      d.io.rst #= true;tick();tick();d.io.rst #= false
      var mapping=(0 until cfg.arfDepth).toArray;var ready=Array.fill(cfg.arfDepth)(true)
      val random=new scala.util.Random(218)
      def pack(values:Seq[Int],width:Int)=values.zipWithIndex.foldLeft(BigInt(0)){case(v,(x,i))=>v|(BigInt(x)<<(i*width))}
      for(cycle<-0 until 4800) {
        val reset=cycle%257==256;val flush=random.nextInt(31)==0
        val rd=(0 until cfg.idWidth).map(_=>random.nextInt(cfg.arfDepth))
        val phy=(0 until cfg.idWidth).map(_=>random.nextInt(cfg.prfDepth))
        val writes=random.nextInt(1<<cfg.idWidth);val forward=random.nextInt(1<<cfg.idWidth)
        val ra1=(0 until cfg.idWidth).map(i=>if(i==1 && cycle%3==0)rd(0)else random.nextInt(cfg.arfDepth))
        val ra2=(0 until cfg.idWidth).map(i=>if(i==1 && cycle%4==0)rd(0)else random.nextInt(cfg.arfDepth))
        val ca=(0 until cfg.cdbWidth).map(_=>random.nextInt(cfg.arfDepth))
        val cp=ca.map(a=>if(random.nextBoolean())mapping(a)else random.nextInt(cfg.prfDepth))
        val cv=random.nextInt(1<<cfg.cdbWidth)
        val retired=(0 until cfg.arfDepth).map(_=>random.nextInt(cfg.prfDepth))
        d.io.rst #= reset;d.io.backend_flush #= flush;d.io.rrf_mem_flat #= pack(retired,cfg.prfIdx)
        d.io.from_id_rd_arch_flat #= pack(rd,cfg.arfIdx);d.io.from_id_rd_phy_flat #= pack(phy,cfg.prfIdx)
        d.io.from_id_write_en #= writes;d.io.from_id_fwd_en #= forward
        d.io.from_id_rs1_arch_flat #= pack(ra1,cfg.arfIdx);d.io.from_id_rs2_arch_flat #= pack(ra2,cfg.arfIdx)
        d.io.cdb_valid #= cv;d.io.cdb_rd_arch_flat #= pack(ca,cfg.arfIdx);d.io.cdb_rd_phy_flat #= pack(cp,cfg.prfIdx)
        sleep(1)
        def check(i:Int,arch:Int,values:Bits,valids:Bits):Unit={
          var p=mapping(arch);var v=ready(arch)
          for(j<-0 until i)if((forward&(1<<j))!=0 && rd(j)==arch){p=phy(j);v=false}
          v=v || cp.zipWithIndex.exists{case(x,k)=>(cv&(1<<k))!=0 && x==p}
          if(arch==0){p=0;v=true}
          assert(((values.toBigInt>>(i*cfg.prfIdx))&((1<<cfg.prfIdx)-1))==p,s"RAT phy cycle $cycle slot $i arch $arch")
          assert(valids.toBigInt.testBit(i)==v,s"RAT ready cycle $cycle slot $i arch $arch")
        }
        for(i<-0 until cfg.idWidth){check(i,ra1(i),d.io.from_id_rs1_phy_flat,d.io.from_id_rs1_valid);check(i,ra2(i),d.io.from_id_rs2_phy_flat,d.io.from_id_rs2_valid)}
        if(reset){mapping=(0 until cfg.arfDepth).toArray;ready=Array.fill(cfg.arfDepth)(true)}
        else if(flush){mapping=retired.toArray;ready=Array.fill(cfg.arfDepth)(true)}
        else {
          for(k<-0 until cfg.cdbWidth)if((cv&(1<<k))!=0 && mapping(ca(k))==cp(k))ready(ca(k))=true
          for(i<-0 until cfg.idWidth)if((writes&(1<<i))!=0){mapping(rd(i))=phy(i);ready(rd(i))=false}
        }
        tick()
      }
    }
  }
}
