package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.HitDetection
import org.scalatest.funsuite.AnyFunSuite

class HitDetectionPrioritySim extends AnyFunSuite {
  test("tag hit and highest-way priority including duplicate matches") {
    val cfg=CpuProfiles.named("mcu-efficient")
    TestSimulation.config.compile(new HitDetection(cfg)).doSim { d =>
      val ways=cfg.dNumWays;val tw=cfg.dTagIdx;val ew=tw+2
      val random=new scala.util.Random(617)
      val selected=d.io.elements.find(_._1=="hit_select").map(_._2.asInstanceOf[Bits])
      for(matches<-0 until (1<<ways); valid<-0 until (1<<ways); _<-0 until 12) {
        val target=BigInt(tw,random)
        var tags=BigInt(0)
        for(i<-0 until ways) {
          val tag=if((matches&(1<<i))!=0)target else target^1
          val metadata=BigInt(random.nextInt(4))<<tw
          tags|=(metadata|tag)<<(i*ew)
        }
        d.io.tag #= target;d.io.tag_arr_flat #= tags;d.io.valid_arr_flat #= valid
        sleep(1)
        val mask=matches&valid
        val winner=if(mask==0)0 else (0 until ways).filter(i=>(mask&(1<<i))!=0).last
        assert(d.io.hit.toBoolean==(mask!=0))
        assert(d.io.hit_way.toInt==winner)
        selected.foreach(x=>assert(x.toBigInt==(if(mask==0)BigInt(0) else BigInt(1)<<winner)))
      }
    }
  }
}
