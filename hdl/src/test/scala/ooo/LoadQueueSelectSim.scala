package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.{AguLsq, Clint, DeviceRegion, LoadQueue}
import org.scalatest.funsuite.AnyFunSuite

class LoadQueueSelectHarness(cfg: CpuConfig) extends LoadQueue(cfg) {
  setDefinitionName(s"load_queue_select_${cfg.ldqDepth}")
  val mismatch = out Bool()
  val external = DeviceRegion.external(io.dmem_addr, cfg)
  mismatch := (io.dmem_cache_valid =/= (io.dmem_valid && !external)) || (io.dmem_external =/= external)
}

class LoadQueueSelectSim extends AnyFunSuite {
  for (depth <- Seq(2, 4, 8); permission <- Seq(false,true)) {
    test(s"load classification matches the selected address at depth $depth permission=$permission") {
      val cfg = CpuProfiles.named("mcu").copy(ldqDepth=depth,lsuCachePermission=permission,rvfi=permission)
      TestSimulation.config.compile(new LoadQueueSelectHarness(cfg)).doSim { d =>
        val random = new scala.util.Random(600 + depth)
        val inputs = d.getAllIo.filter(s => s.isInput && s != d.io.clk && s != d.io.rst)
        def tick(): Unit = {
          d.io.clk #= false; sleep(2)
          val high = (d.io.from_agu_data.toBigInt >> (AguLsq.width(cfg) - cfg.robIdx - 16)) & 0xffff
          assert(high == (if (d.io.agu_c16.toBoolean) d.io.agu_hi1.toBigInt else d.io.agu_hi0.toBigInt))
          val addr = (d.io.from_agu_data.toBigInt >> (AguLsq.width(cfg) - cfg.robIdx - 32)) & 0xffffffffL
          assert(d.io.agu_ordered.toBoolean == (((addr & cfg.mmioMask) == cfg.mmioBase) || (high == cfg.clintHi16)))
          assert(!d.mismatch.toBoolean)
          d.io.clk #= true; sleep(2); assert(!d.mismatch.toBoolean)
        }
        for (i <- 0 until 10000) {
          inputs.foreach {
            case b: Bool => b #= random.nextBoolean()
            case b: Bits => b #= BigInt(b.getWidth, random)
            case b: UInt => b #= BigInt(b.getWidth, random)
          }
          // Match the AGU contract: selecting the conditional high sum reconstructs the address.
          val data = BigInt(d.io.from_agu_data.getWidth, random)
          val carry = random.nextBoolean()
          val high = (data >> (AguLsq.width(cfg) - cfg.robIdx - 16)) & 0xffff
          d.io.from_agu_data #= data; d.io.agu_c16 #= carry
          if (carry) d.io.agu_hi1 #= high else d.io.agu_hi0 #= high
          val addr = (data >> (AguLsq.width(cfg) - cfg.robIdx - 32)) & 0xffffffffL
          d.io.agu_ordered #= (((addr & cfg.mmioMask) == cfg.mmioBase) || (high == cfg.clintHi16))
          d.io.agu_clint #= (high == cfg.clintHi16)
          d.io.agu_clint_read_sel #= Clint.offsets.zipWithIndex.filter { case (off,_) => (addr & 0xfffc) == off }.map { case (_,n) => BigInt(1) << n }.foldLeft(BigInt(0))(_ | _)
          if(permission) {
            val deviceGo=random.nextBoolean()
            d.io.device_go #= deviceGo
            d.io.block_regular #= (deviceGo || random.nextBoolean())
          }
          d.io.rst #= (i < 2 || i % 257 == 0)
          tick()
        }
      }
    }
  }
}
