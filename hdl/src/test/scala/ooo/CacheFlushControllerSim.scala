package ooo

import spinal.core.sim._
import ooo.memory.CacheFlushController
import org.scalatest.funsuite.AnyFunSuite

class CacheFlushControllerSim extends AnyFunSuite {
  test("flush visits every way, holds dirty writes under backpressure and supports reset") {
    TestSimulation.config.compile(new CacheFlushController(4,2)).doSim { d =>
      d.io.clk #= false;d.io.rst #= true;d.io.request #= false;d.io.can_start #= false
      d.io.dirty #= false;d.io.write_ready #= false
      def tick():Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
      tick();tick();d.io.rst #= false
      for(round<-0 until 2) {
        val seen=scala.collection.mutable.Set[(Int,Int)]();var writes=0;var cycles=0
        d.io.can_start #= false;d.io.request #= true
        for(_<-0 until 8) { tick();assert(!d.io.busy.toBoolean && !d.io.done.toBoolean) }
        d.io.can_start #= true
        while(!d.io.done.toBoolean && cycles<2000) {
          val key=(d.io.set.toInt,d.io.way.toInt);val dirty=(key._1+key._2)%3==round
          d.io.dirty #= dirty;d.io.write_ready #= cycles%7==0;sleep(1)
          if(d.io.invalidate.toBoolean) { assert(!seen(key));seen+=key }
          if(d.io.writeback.toBoolean) {
            assert(dirty)
            if(d.io.write_ready.toBoolean) writes+=1
            else { tick();assert((d.io.set.toInt,d.io.way.toInt)==key && d.io.writeback.toBoolean);cycles+=1 }
          }
          tick();cycles+=1
        }
        assert(d.io.done.toBoolean && seen.size==64)
        val expectedWrites = (0 until 16).map(set =>
          (0 until 4).count(way => (set + way) % 3 == round)).sum
        assert(writes == expectedWrites)
        for(_<-0 until 4) { tick();assert(d.io.done.toBoolean && !d.io.writeback.toBoolean) }
        d.io.request #= false;tick();assert(!d.io.busy.toBoolean)
      }
      d.io.request #= true;tick();tick();d.io.rst #= true;tick();d.io.rst #= false;d.io.request #= false
      tick();assert(!d.io.busy.toBoolean && !d.io.done.toBoolean)
    }
  }
}
