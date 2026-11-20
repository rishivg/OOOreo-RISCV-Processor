package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.AtomicUnit
import org.scalatest.funsuite.AnyFunSuite

class AtomicUnitCaptureSim extends AnyFunSuite {
  for (depth <- Seq(2, 4)) test(s"atomic split-address capture, flush and slot reuse: depth=$depth") {
    val cfg = CpuProfiles.named("mcu").copy(atomicCamDepth = depth)
    TestSimulation.config.compile(new AtomicUnit(cfg)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case _ =>
      }
      d.io.stb_empty #= true
      d.io.cache_ready #= true
      val random = new scala.util.Random(2501)
      def tick(): Unit = {
        d.io.clk #= false; sleep(2)
        d.io.clk #= true; sleep(2)
        d.io.clk #= false; sleep(2)
      }
      def noise(valid: Boolean): Unit = {
        d.io.agu_valid #= valid
        d.io.agu_data #= (BigInt(63) << 132) | BigInt(132, random)
        d.io.agu_hi0 #= random.nextInt(65536)
        d.io.agu_hi1 #= random.nextInt(65536)
        d.io.agu_c16 #= random.nextBoolean()
        tick()
      }
      def dispatch(id: Int): Unit = {
        assert(d.io.disp_ready.toBoolean)
        d.io.disp_valid #= true; d.io.disp_rob_id #= id
        d.io.disp_amo_op #= 0 // LR
        d.io.disp_rd_arch #= id + 1; d.io.disp_rd_phy #= id + 1
        tick(); d.io.disp_valid #= false
      }
      def capture(id: Int, address: Long, carry: Boolean): Unit = {
        val hi = address >>> 16
        d.io.agu_valid #= true
        d.io.agu_data #= (BigInt(id) << 132) | (BigInt(address) << 100)
        d.io.agu_hi0 #= (if (carry) (hi - 1) & 65535 else hi)
        d.io.agu_hi1 #= (if (carry) hi else (hi + 1) & 65535)
        d.io.agu_c16 #= carry
        tick(); d.io.agu_valid #= false
      }
      def complete(id: Int, address: Long): Unit = {
        d.io.go #= true; d.io.go_rob_id #= id
        noise(false)
        assert(d.io.cache_valid.toBoolean && d.io.cache_addr.toLong == address)
        assert(d.io.cache_rmask.toInt == 15 && d.io.cache_wmask.toInt == 0)
        for (_ <- 0 until 3) {
          noise(true)
          assert(d.io.cache_valid.toBoolean && d.io.cache_addr.toLong == address)
        }
        d.io.cache_resp #= true; d.io.cache_rdata #= 0x12345678
        noise(false); d.io.cache_resp #= false
        assert(d.io.cdb_valid.toBoolean && d.io.cdb_rob_id.toInt == id)
        assert(d.io.cdb_rd_value.toLong == 0x12345678L)
        noise(false); d.io.go #= false; noise(false)
      }
      d.io.rst #= true; tick(); tick(); d.io.rst #= false
      // The first pending high-half write must die with the flush.
      dispatch(0); capture(0, 0x1234fff0L, carry = true)
      d.io.backend_flush #= true; noise(true); d.io.backend_flush #= false
      // Adjacent captures use different carry arms and survive unrelated AGU traffic.
      dispatch(1); dispatch(2)
      capture(1, 0xaaaafff0L, carry = true)
      capture(2, 0x87650004L, carry = false)
      noise(true)
      for (_ <- 0 until 20) noise(random.nextBoolean())
      complete(1, 0xaaaafff0L); complete(2, 0x87650004L)
      // Reuse the flushed ROB ID and the freed CAM slot.
      dispatch(0); capture(0, 0x56780000L, carry = false); noise(false)
      complete(0, 0x56780000L)
    }
  }
}
