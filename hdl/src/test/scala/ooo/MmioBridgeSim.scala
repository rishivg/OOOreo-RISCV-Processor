package ooo

import spinal.core.sim._
import ooo.memory.MmioBridge
import org.scalatest.funsuite.AnyFunSuite

class MmioBridgeSim extends AnyFunSuite {
  for (idleCapture <- Seq(false, true)) test(s"MMIO holds payload, faults precisely and survives accepted-request flush (idle capture=$idleCapture)") {
    TestSimulation.config.compile(new MmioBridge(CpuConfig(zicsr=true,mmio=true,mmioIdleCapture=idleCapture))).doSim { d =>
      d.io.clk #= false; d.io.rst #= true; d.io.flush #= false; d.io.start #= false
      d.io.addr #= 0; d.io.wdata #= 0; d.io.rmask #= 0; d.io.wmask #= 0; d.io.rob_id #= 0
      d.io.bus.req_ready #= false; d.io.bus.resp_valid #= false; d.io.bus.resp_rdata #= 0; d.io.bus.resp_error #= false
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      tick(); tick(); d.io.rst #= false
      d.io.addr #= BigInt("10000003",16); d.io.wdata #= BigInt("ab000000",16); d.io.wmask #= 8; d.io.rob_id #= 7
      d.io.start #= true; sleep(1); assert(d.io.accepted.toBoolean); tick(); d.io.start #= false
      // Caller changes its payload after acceptance: bus must retain the snapshot.
      d.io.addr #= 0; d.io.wdata #= 0; d.io.wmask #= 0
      for (_ <- 0 until 17) {
        assert(d.io.bus.req_valid.toBoolean && d.io.busy.toBoolean)
        assert(d.io.bus.addr.toBigInt == BigInt("10000000",16))
        assert(d.io.bus.wdata.toBigInt == BigInt("ab000000",16) && d.io.bus.wmask.toInt == 8)
        assert(!d.io.done.toBoolean); tick()
      }
      d.io.bus.req_ready #= true; tick(); d.io.bus.req_ready #= false
      assert(!d.io.bus.req_valid.toBoolean)
      d.io.flush #= true; tick(); d.io.flush #= false
      assert(d.io.busy.toBoolean && !d.io.done.toBoolean)
      d.io.bus.resp_error #= true; d.io.bus.resp_valid #= true; tick(); d.io.bus.resp_valid #= false
      assert(d.io.done.toBoolean && d.io.error.toBoolean && d.io.is_write.toBoolean)
      assert(d.io.done_addr.toBigInt == BigInt("10000003",16) && d.io.done_rob_id.toInt == 7)
      tick(); assert(!d.io.done.toBoolean && !d.io.busy.toBoolean)
      // Zero-latency read response on the request acceptance edge.
      d.io.addr #= BigInt("10000004",16); d.io.rmask #= 15; d.io.start #= true
      tick(); d.io.start #= false; d.io.bus.req_ready #= true; d.io.bus.resp_valid #= true
      d.io.bus.resp_error #= false; d.io.bus.resp_rdata #= BigInt("76543210",16); tick()
      d.io.bus.resp_valid #= false; assert(d.io.done.toBoolean && !d.io.error.toBoolean)
      assert(d.io.result.toBigInt == BigInt("76543210",16)); tick()
      // A flush before external acceptance cancels with no device access.
      d.io.bus.req_ready #= false; d.io.start #= true; tick(); d.io.start #= false
      d.io.flush #= true; sleep(1); assert(!d.io.bus.req_valid.toBoolean); tick()
      assert(!d.io.busy.toBoolean)
    }
  }
}
