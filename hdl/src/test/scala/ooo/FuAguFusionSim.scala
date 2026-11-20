package ooo

import spinal.core.sim._
import ooo.memory.FuAgu
import org.scalatest.funsuite.AnyFunSuite
import scala.util.Random

class FuAguFusionSim extends AnyFunSuite {
  for (native <- Seq(false,true); variant <- 0 until 4) test(
    s"fused bypass preserves addresses, payloads and regions: native=$native variant=$variant") {
    val speculate=variant>0;val baseSpec=variant>=2
    val cfg=CpuConfig(rvfi=true,zicsr=true,mmio=true,lsuWaySpeculation=true,
      lsuEntrySpeculation=true,lsuResponsePredecode=true,lsuForwardSpeculation=true,
      aguSignedImmediate=true,aluAguFusion=true,fpgaNativeAdd=native,aguOrCarry=variant==3,
      lsuSerialSpeculation=speculate,lsuOperandSpeculation=speculate,memCdbSpeculation=baseSpec)
    TestSimulation.config.compile(new FuAgu(cfg)).doSim { d =>
      val random=new Random(60032);val mask=(BigInt(1)<<32)-1
      val boundaries=Seq(0L,0x01ffffffL,0x02000000L,0x0200ffffL,0x0fffffffL,
        0x10000000L,0x1fffffffL,0xffffffffL).map(BigInt(_))
      def operand(i: Int): BigInt=if(i%3==0)boundaries(random.nextInt(boundaries.size)) else BigInt(32,random)
      d.io.clk #= false;d.io.rst #= false
      for(i <- 0 until 4096) {
        val immediate=if(i%4==0)Seq(-2048,-1,0,2047)(i%16/4) else random.nextInt(4096)-2048
        val offset=BigInt(immediate)&mask;val base=operand(i);val store=operand(i+1)
        val ways=(0 until cfg.lsuBypassCandidates).map(_=>operand(i+2));val way=i%ways.size
        val baseSources=(0 until 5).map(_=>operand(i+3));val baseIndex=i%7
        val baseValue=if(!baseSpec || baseIndex==0)base else if(baseIndex==6)BigInt(0) else baseSources(baseIndex-1)
        val mode=i%3;val alternate=(i&4)!=0;val eligible= !speculate || (i&8)!=0;val op=i%16
        val sources=(0 until cfg.numFastBypass).map { lane =>
          val a=operand(i+lane);val b=operand(i+lane+1);val other=operand(i+2)
          val kind=(i+lane)%4;val cin=random.nextBoolean();val comparison=random.nextBoolean()
          val add=kind==0||kind==1;val cmp=kind==2
          val value=if(add)(a+b+(if(cin)1 else 0))&mask else if(cmp)BigInt(if(comparison)1 else 0) else other
          val encoded=a|(b<<32)|(other<<64)|(BigInt(if(cin)1 else 0)<<96)|
            (BigInt(if(comparison)1 else 0)<<97)|(BigInt(if(add)1 else 0)<<98)|(BigInt(if(cmp)1 else 0)<<99)
          (encoded,value)
        }
        val chosen=if(mode==0){if(alternate && eligible)ways(way) else baseValue}else sources(mode-1)._2
        val address=(chosen+immediate)&mask;val lane=(address&3).toInt
        d.io.prv_valid #= (i%5!=0)
        d.io.agu_reg_in #= (BigInt(op)<<96)|(offset<<64)|(base<<32)|store
        d.io.alt_imm #= offset;d.io.alt_rs1_value #= (if(eligible)ways(way) else base);d.io.alt_sel #= alternate
        if(speculate)d.io.alt_operand_select #= eligible
        d.io.alt_way_select #= BigInt(1)<<way
        d.io.alt_way_rs1_flat #= ways.zipWithIndex.map{case(v,k)=>v<<(32*k)}.reduce(_|_)
        if(baseSpec) {
          d.io.base_source_select #= BigInt(1)<<baseIndex
          d.io.base_sources_flat #= baseSources.zipWithIndex.map{case(v,k)=>v<<(32*k)}.reduce(_|_)
        }
        d.io.fast_select #= (if(mode==0)BigInt(0)else BigInt(1)<<(mode-1))
        d.io.fast_sources_flat #= sources.zipWithIndex.map{case((v,_),k)=>v<<(100*k)}.reduce(_|_)
        d.io.fast_value #= (if(mode==0)BigInt(0)else sources(mode-1)._2)
        sleep(1)
        val packet=d.io.to_lsq.toBigInt
        val byte=Set(0,4,8).contains(op);val half=Set(1,5,9).contains(op);val word=Set(2,10).contains(op)
        val lanes=if(byte)1<<lane else if(half)(3<<lane)&15 else if(word)15 else 0
        val data=op match {
          case 8 => (store&255)<<(8*lane)
          case 9 => (store&65535)<<(if((lane&2)!=0)16 else 0)
          case 10 => store
          case _ => BigInt(0)
        }
        assert(((packet>>100)&mask)==address)
        assert(((packet>>68)&mask)==data)
        assert(((packet>>64)&15)==lanes)
        assert(((packet>>32)&mask)==chosen)
        assert((packet&mask)==store)
        assert((if(d.io.agu_c16.toBoolean)d.io.agu_hi1.toBigInt else d.io.agu_hi0.toBigInt)==(address>>16))
        assert(d.io.agu_misaligned.toBoolean==((half&&(lane&1)!=0)||(word&&lane!=0)))
        assert(d.io.agu_is_store.toBoolean==((op&8)!=0))
        assert(d.io.agu_clint.toBoolean==((address>>16)==cfg.clintHi16))
        val select=ooo.memory.Clint.offsets.zipWithIndex.filter{case(off,_) => (address&0xfffc)==off}
          .map{case(_,k)=>BigInt(1)<<k}.foldLeft(BigInt(0))(_|_)
        assert(d.io.agu_clint_read_sel.toBigInt==select)
        assert(d.io.agu_ordered.toBoolean==(((address&BigInt("f0000000",16))==BigInt("10000000",16))||((address>>16)==0x0200)))
      }
    }
  }
}
