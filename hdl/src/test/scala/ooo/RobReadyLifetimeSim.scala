package ooo

import spinal.core._
import spinal.core.sim._
import ooo.rename.Rob
import org.scalatest.funsuite.AnyFunSuite

class RobReadyLifetimeSim extends AnyFunSuite {
  test("ROB allocation masks stale readiness after reset, flush and wrap") {
    val cfg=CpuProfiles.named("mcu-efficient")
    TestSimulation.config.compile(new Rob(cfg)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b:Bool=>b #= false
        case b:Bits=>b #= 0
        case u:UInt=>u #= 0
        case _=>
      }
      def tick():Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
      def broadcast(id:Int):Unit={d.io.cdb_valid #= 1;d.io.cdb_rob_id_flat #= id;tick();d.io.cdb_valid #= 0}
      def reset(n:Int):Unit={d.io.rst #= true;for(_<-0 until n)tick();d.io.rst #= false;tick()}
      reset(1)
      for(edges<-Seq(1,2,3,4)) {
        // Populate readiness for every physical ROB ID while the queue is empty.
        for(id<-0 until cfg.robDepth*cfg.idWidth){broadcast(id);assert(!d.io.dbg_pop.toBoolean)}
        reset(edges)
        for(row<-0 until cfg.robDepth*2) {
          assert(d.io.from_id_ready.toBoolean)
          d.io.from_id_valid #= true;d.io.from_id_inst_valid #= 3
          tick();d.io.from_id_valid #= false
          for(_<-0 until 3){assert(!d.io.dbg_pop.toBoolean && d.io.dbg_commit_instr.toInt==0);tick()}
          val id=2*(row%cfg.robDepth)
          broadcast(id);assert(!d.io.dbg_pop.toBoolean)
          broadcast(id+1);assert(d.io.dbg_pop.toBoolean && d.io.dbg_commit_instr.toInt==3)
          tick();assert(d.io.dbg_empty.toBoolean)
        }
      }
      // A resolved branch flush discards the row. On immediate reuse the new
      // unresolved row must wait for both of its own completions.
      reset(1)
      d.io.from_id_valid #= true;d.io.from_id_inst_valid #= 3;tick();d.io.from_id_valid #= false
      broadcast(0);broadcast(1)
      d.io.from_cb_ready #= true;d.io.from_cb_rob_id #= 0;d.io.from_cb_miss_predict #= true;d.io.from_cb_target_address #= 0x1000
      sleep(1);assert(d.io.backend_flush.toBoolean);tick()
      d.io.from_cb_ready #= false;d.io.from_cb_miss_predict #= false
      d.io.from_id_valid #= true;tick();d.io.from_id_valid #= false
      for(_<-0 until 4){assert(!d.io.dbg_pop.toBoolean && d.io.dbg_commit_instr.toInt==0);tick()}
      broadcast(0);assert(!d.io.dbg_pop.toBoolean);broadcast(1);assert(d.io.dbg_pop.toBoolean)
    }
  }
}
