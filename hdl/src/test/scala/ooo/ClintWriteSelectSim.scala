package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.{Clint, DmemArbiter}
import org.scalatest.funsuite.AnyFunSuite

class ClintWriteDecodeHarness(cfg: CpuConfig) extends DmemArbiter(cfg) {
  setDefinitionName("clint_write_decode_test")
  val mismatch = out Bool()
  val early = Bits(Clint.offsets.size bits)
  val storeWrite = io.store_valid && io.store_ready && io.store_wmask.orR
  val atomicWrite = io.atomic_valid && io.atomic_ready && io.atomic_wmask.orR
  early := (Clint.writeSelect(io.store_addr, cfg) & B(Clint.offsets.size bits, default -> storeWrite)) |
    (Clint.writeSelect(io.atomic_addr, cfg) & B(Clint.offsets.size bits, default -> atomicWrite))
  val reference = Bits(Clint.offsets.size bits)
  val selected = Mux(io.cache_c16, io.cache_hi1, io.cache_hi0) === B(cfg.clintHi16, 16 bits)
  for ((offset, i) <- Clint.offsets.zipWithIndex)
    reference(i) := selected && io.cache_wmask.orR &&
      io.cache_addr(15 downto 2) === B(offset >> 2, 14 bits)
  val memMask = B(4 bits, default -> !selected)
  val readReference = Bits(Clint.offsets.size bits)
  for ((offset, i) <- Clint.offsets.zipWithIndex)
    readReference(i) := selected && io.cache_rmask.orR &&
      io.cache_addr(15 downto 2) === B(offset >> 2, 14 bits)
  mismatch := (early =/= reference) || (io.cache_mem_rmask =/= (io.cache_rmask & memMask)) ||
    (io.cache_mem_wmask =/= (io.cache_wmask & memMask)) || (io.clint_read_sel =/= readReference) ||
    (io.clint_read_fire =/= (selected && io.cache_rmask.orR)) ||
    (io.clint_req_fire =/= (selected && (io.cache_rmask.orR || io.cache_wmask.orR)))
}

class ClintWriteSelectSim extends AnyFunSuite {
  test("early CLINT and cache-mask decoding match merged decoding through stalls, flushes and arbitration") {
    TestSimulation.config.compile(new ClintWriteDecodeHarness(CpuProfiles.named("mcu"))).doSim { d =>
      val io = d.io
      io.clk #= false; io.rst #= true; io.backend_flush #= false
      io.load_valid #= false; io.load_valid_early #= false
      io.load_addr #= 0; io.load_rmask #= 0; io.load_word_oh #= 0
      io.load_hi0 #= 0; io.load_hi1 #= 0; io.load_c16 #= false
      io.store_valid #= false; io.store_addr #= 0; io.store_wmask #= 0; io.store_wdata #= 0
      io.atomic_valid #= false; io.atomic_addr #= 0; io.atomic_rmask #= 0
      io.atomic_wmask #= 0; io.atomic_wdata #= 0
      io.cache_resp #= false; io.cache_rdata #= 0
      def tick(): Unit = {
        io.clk #= false; sleep(1)
        io.load_clint #= ((if (io.load_c16.toBoolean) io.load_hi1.toBigInt else io.load_hi0.toBigInt) == 0x0200)
        val off = io.load_addr.toBigInt & 0xfffc
        io.load_clint_read_sel #= Clint.offsets.zipWithIndex.filter(_._1 == off).map { case (_,n) => BigInt(1) << n }.foldLeft(BigInt(0))(_ | _)
        sleep(1); assert(!d.mismatch.toBoolean)
        io.clk #= true; sleep(2); assert(!d.mismatch.toBoolean)
      }
      tick(); tick(); io.rst #= false
      val random = new scala.util.Random(550)
      def address(): BigInt = {
        val hi = Seq(0x0200, 0x0201, 0, 0xffff)(random.nextInt(4))
        val lo = (Clint.offsets :+ 0x1234)(random.nextInt(6)) + random.nextInt(4)
        (BigInt(hi) << 16) | lo
      }
      for (i <- 0 until 10000) {
        io.backend_flush #= (random.nextInt(19) == 0)
        io.cache_resp #= random.nextBoolean()
        io.atomic_valid #= ((i & 1) != 0); io.store_valid #= ((i & 2) != 0)
        io.load_valid #= ((i & 4) != 0); io.load_valid_early #= true
        io.store_addr #= address(); io.store_wmask #= random.nextInt(16)
        io.atomic_addr #= address(); io.atomic_wmask #= random.nextInt(16)
        io.atomic_rmask #= random.nextInt(16); io.load_rmask #= random.nextInt(16)
        io.load_addr #= address(); io.load_hi0 #= random.nextInt(65536)
        io.load_hi1 #= random.nextInt(65536); io.load_c16 #= random.nextBoolean()
        tick()
      }
    }
  }
}
