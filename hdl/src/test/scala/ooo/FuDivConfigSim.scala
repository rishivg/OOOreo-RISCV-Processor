package ooo

import spinal.core.sim._
import ooo.execute.FuDiv
import org.scalatest.funsuite.AnyFunSuite

class FuDivConfigSim extends AnyFunSuite {
  for (native <- Seq(false,true)) {
    test(s"queued divisions restart after held completion with randomized output backpressure native=$native") {
      val cfg=CpuConfig(divCycles=3,rvfi=true)
      TestSimulation.config.addRtl(if(native) "src/main/verilog/dw_div_seq_iterative.v" else "../hvl/common/dw_mock.sv").compile(new FuDiv(cfg)).doSim { d =>
        d.io.clk #= false; d.io.rst #= true; d.io.prv_valid #= false; d.io.nxt_ready #= false; d.io.iss_in #= 0
        def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
        tick(); tick(); d.io.rst #= false; tick()
        val random=new scala.util.Random(9207); val mask=(BigInt(1)<<32)-1
        def signed(v: BigInt): BigInt = if(v.testBit(31)) v-(BigInt(1)<<32) else v
        val jobs=(0 until 240).map { n =>
          val op=4+random.nextInt(4); val a=BigInt(32,random)
          val b=if(n%7==0) BigInt(0) else if(n%11==0) mask else BigInt(32,random)
          val lhs=if(op%2==0) signed(a) else a; val rhs=if(op%2==0) signed(b) else b
          val result=if(b==0) { if(op<6) mask else a } else { if(op<6) lhs/rhs else lhs%rhs }
          val payload=(BigInt(n%cfg.robDepth)<<79)|(BigInt(1)<<74)|(BigInt(33)<<68)|(BigInt(op)<<64)|(a<<32)|b
          (payload,(result&mask),a,b)
        }
        val expected=scala.collection.mutable.Queue[(Int,BigInt,BigInt,BigInt,Int)]()
        var sent=0; var received=0; var cycle=0; var stalled: Option[BigInt]=None
        while(received<jobs.size && cycle<12000) {
          val offer=sent<jobs.size && random.nextInt(5)!=0
          val ready=cycle%41>=12 && random.nextBoolean()
          d.io.prv_valid #= offer; d.io.nxt_ready #= ready
          if(offer) d.io.iss_in #= jobs(sent)._1
          sleep(1)
          val valid=d.io.nxt_valid.toBoolean
          stalled.foreach(value=>assert(valid && d.io.cdb_out.toBigInt==value,"held completion must remain stable"))
          if(valid) {
            assert(expected.nonEmpty,"completion must belong to an accepted operation")
            val (id,value,a,b,accepted)=expected.front
            val payload=d.io.cdb_out.toBigInt
            assert(cycle-accepted>=cfg.divCycles,"a retained completion must not complete the next operation early")
            assert((payload>>(64+32+cfg.prfIdx+cfg.arfIdx))==id)
            assert(((payload>>64)&mask)==value && ((payload>>32)&mask)==a && (payload&mask)==b)
            if(ready) { expected.dequeue(); received+=1 }
          }
          stalled=if(valid && !ready) Some(d.io.cdb_out.toBigInt) else None
          if(offer && d.io.prv_ready.toBoolean) {
            val (_,value,a,b)=jobs(sent); expected.enqueue((sent%cfg.robDepth,value,a,b,cycle)); sent+=1
          }
          tick(); cycle+=1
        }
        assert(received==jobs.size && expected.isEmpty)
        d.io.prv_valid #= false; d.io.nxt_ready #= true
        for(_ <- 0 until 30) { tick(); assert(!d.io.nxt_valid.toBoolean) }
      }
    }
  }
  for (native <- Seq(false,true); latency <- Seq(3,12,20)) test(s"divider latency=$latency preserves signed/unsigned results and held completion native=$native") {
    val cfg=CpuConfig(divCycles=latency,rvfi=false)
    TestSimulation.config.addRtl(if(native) "src/main/verilog/dw_div_seq_iterative.v" else "../hvl/common/dw_mock.sv").compile(new FuDiv(cfg)).doSim { d =>
      d.io.clk #= false; d.io.rst #= true; d.io.prv_valid #= false; d.io.nxt_ready #= false; d.io.iss_in #= 0
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      tick(); tick(); d.io.rst #= false; tick()
      val mask=BigInt("ffffffff",16)
      val cases=Seq((4,BigInt(-17),BigInt(5),BigInt(-3)),(6,BigInt(-17),BigInt(5),BigInt(-2)),
        (5,mask,BigInt(3),BigInt(1431655765)),(7,mask,BigInt(3),BigInt(0)),
        (4,BigInt(-2147483648L),BigInt(-1),BigInt(-2147483648L)),
        (4,BigInt(91),BigInt(0),mask),(6,BigInt(-91),BigInt(0),BigInt(-91)))
      for (((op,a,b,result),id) <- cases.zipWithIndex) {
        var wait=0
        while (!d.io.prv_ready.toBoolean && wait<20) { tick(); wait+=1 }
        assert(d.io.prv_ready.toBoolean)
        d.io.iss_in #= (BigInt(id) << 79)|(BigInt(1) << 74)|(BigInt(33) << 68)|(BigInt(op) << 64)|((a&mask) << 32)|(b&mask)
        d.io.prv_valid #= true; tick(); d.io.prv_valid #= false
        wait=0
        while (!d.io.nxt_valid.toBoolean && wait<latency+12) { tick(); wait+=1 }
        assert(d.io.nxt_valid.toBoolean,"divider must complete within its configured latency")
        val payload=d.io.cdb_out.toBigInt
        assert(((payload >> 64)&mask)==(result&mask))
        assert((payload&((BigInt(1) << 64)-1))==0,"product build must omit debug operands")
        for (_ <- 0 until 7) { tick(); assert(d.io.nxt_valid.toBoolean && d.io.cdb_out.toBigInt==payload) }
        d.io.nxt_ready #= true; tick(); d.io.nxt_ready #= false; tick(); tick()
        assert(!d.io.nxt_valid.toBoolean)
      }
    }
  }
}
