package ooo

import spinal.core.sim._
import ooo.execute.FuMul
import org.scalatest.funsuite.AnyFunSuite

class FuMulSim extends AnyFunSuite {
  private val implementations = for (debug <- Seq(false,true); target <- Seq("asic", "fpga");
       dadda <- (if (target == "asic") Seq(false, true) else Seq(false));
       compact <- (if (dadda) Seq(false, true) else Seq(false)))
    yield (debug, target, dadda, compact, "auto", true)
  private val carryVariants = for (debug <- Seq(false, true);
       topology <- Seq("brent-kung", "han-carlson", "sklansky"))
    yield (debug, "asic", true, true, topology, false)

  for ((debug, target, dadda, compact, topology, keepPropagate) <- implementations ++ carryVariants)
      test(s"multiply variants, queued inputs and held completion rvfi=$debug target=$target dadda=$dadda compact=$compact carry=$topology keepP=$keepPropagate") {
    val cfg=CpuConfig.forTarget(CpuConfig(rvfi=debug, mulDaddaReduction=dadda,
      mulCompactSigns=compact, mulCarryTopology=topology, mulKeepPropagate=keepPropagate), target)
    TestSimulation.config.compile(new FuMul(cfg)).doSim { d =>
      d.io.clk #= false; d.io.rst #= true; d.io.prv_valid #= false; d.io.nxt_ready #= false; d.io.iss_in #= 0
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      tick(); tick(); d.io.rst #= false; tick()
      val random=new scala.util.Random(822041)
      val mask=(BigInt(1)<<32)-1
      def signed(v: BigInt): BigInt = if(v.testBit(31)) v-(BigInt(1)<<32) else v
      val corners=Seq(BigInt(0),BigInt(1),BigInt(2),BigInt("7fffffff",16),BigInt("80000000",16),mask)
      val cases=(for(op<-0 until 4;a<-corners;b<-corners) yield (op,a,b)) ++
        (0 until 1600).map(_=>(random.nextInt(4),BigInt(32,random),BigInt(32,random)))
      val jobs=cases.zipWithIndex.map { case ((op,a,b),n) =>
        val lhs=if(op==3) a else signed(a); val rhs=if(op>=2) b else signed(b)
        val product=lhs*rhs
        val result=(if(op==0) product else product>>32)&mask
        val id=BigInt(n%(cfg.robDepth*cfg.idWidth)); val arch=BigInt(1+n%31); val phy=BigInt(1+n%(cfg.prfDepth-1))
        val meta=((id<<cfg.arfIdx)|arch)<<cfg.prfIdx|phy
        val input=((meta<<4)|op)<<64|(a<<32)|b
        val output=(meta<<96)|(result<<64)|(if(debug) (a<<32)|b else BigInt(0))
        (input,output)
      }
      val expected=scala.collection.mutable.Queue[BigInt]()
      var sent=0; var received=0; var cycles=0; var offering=false; var held: Option[BigInt]=None
      while(received<jobs.size && cycles<30000) {
        if(!offering && sent<jobs.size && random.nextInt(5)!=0) offering=true
        val ready=cycles%61>=19 && random.nextBoolean()
        d.io.prv_valid #= offering; d.io.nxt_ready #= ready
        if(offering) d.io.iss_in #= jobs(sent)._1
        sleep(1)
        val valid=d.io.nxt_valid.toBoolean
        held.foreach(p=>assert(valid && d.io.cdb_out.toBigInt==p,"completion must remain stable during backpressure"))
        if(valid) {
          assert(expected.nonEmpty,"result must correspond to an accepted multiply")
          assert(d.io.cdb_out.toBigInt==expected.front,s"multiply result/metadata mismatch at result $received")
          if(ready) { expected.dequeue(); received+=1 }
        }
        held=if(valid && !ready) Some(d.io.cdb_out.toBigInt) else None
        if(offering && d.io.prv_ready.toBoolean) { expected.enqueue(jobs(sent)._2); sent+=1; offering=false }
        tick(); cycles+=1
      }
      assert(received==jobs.size && expected.isEmpty)
      d.io.prv_valid #= false; d.io.nxt_ready #= true
      for(_<-0 until 30) { tick(); assert(!d.io.nxt_valid.toBoolean) }
    }
  }
}
