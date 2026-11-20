package ooo

import spinal.core._
import spinal.core.sim._
import ooo.rename.Rob
import org.scalatest.funsuite.AnyFunSuite

class RobMmioSim extends AnyFunSuite {
  for (stores <- Seq(false, true); serial <- Seq(false, true); parallel <- (if (stores) Seq(false,true) else Seq(false)))
    test(s"branch and device retirement is precise (store summary=$stores, serial summary=$serial, parallel=$parallel)") {
    val cfg=CpuConfig(zicsr=true,mmio=true,lowPower=true,robStqSummary=stores,robSerialSummary=serial,robDeviceParallel=parallel)
    TestSimulation.config.compile(new Rob(cfg)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case u: UInt => u #= 0
        case _ =>
      }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      def row(): Unit = {
        d.io.from_id_valid #= true; d.io.from_id_inst_valid #= 3
        d.io.from_id_memory #= 2; d.io.from_id_compressed #= 2
        d.io.from_id_rvfi_dbg_flat #= (BigInt(0x1004) << (cfg.rvfiDbgW+137)) | (BigInt(0x1000) << 137)
        tick(); d.io.from_id_valid #= false
        d.io.device_mark #= true; d.io.device_mark_id #= 1; tick(); d.io.device_mark #= false
      }
      d.io.rst #= true; tick(); tick(); d.io.rst #= false; row()
      d.io.from_cb_ready #= true; d.io.from_cb_rob_id #= 0; d.io.from_cb_miss_predict #= true
      d.io.from_cb_target_address #= 0x5000; sleep(1)
      for (_ <- 0 until 4) {
        assert(!d.io.dbg_pop.toBoolean && !d.io.backend_flush.toBoolean && !d.io.device_go.toBoolean)
        tick()
      }
      d.io.cdb_valid #= 1; d.io.cdb_rob_id_flat #= 0; tick(); d.io.cdb_valid #= 0
      assert(d.io.backend_flush.toBoolean && d.io.dbg_commit_instr.toInt==1)
      assert(!d.io.device_go.toBoolean && d.io.backend_redirect_pc.toBigInt==0x5000)
      tick(); assert(d.io.dbg_empty.toBoolean)
      d.io.from_cb_miss_predict #= false; d.io.from_cb_ready #= false; row()
      d.io.cdb_valid #= 1; d.io.cdb_rob_id_flat #= 0; tick(); d.io.cdb_valid #= 0
      d.io.irq_pending #= true; sleep(1)
      assert(d.io.device_go.toBoolean && d.io.device_go_id.toInt==1)
      assert(!d.io.trap_en.toBoolean,"interrupt cannot preempt an irreversible device operation")
      d.io.cdb_valid #= 1; d.io.cdb_rob_id_flat #= 1; tick(); d.io.cdb_valid #= 0
      assert(d.io.backend_flush.toBoolean && d.io.dbg_commit_instr.toInt==3)
      assert(d.io.backend_redirect_pc.toBigInt==0x1006,"compressed device load must resume at pc+2")
    }
  }
}
