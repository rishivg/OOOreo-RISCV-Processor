package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.StorePairCache
import org.scalatest.funsuite.AnyFunSuite

class StorePairCacheHarness(cfg: CpuConfig) extends Component {
  setDefinitionName(s"pair_cache_test_${cfg.stqDepth}")
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val store_write = in Bits(cfg.stqDepth bits); val load_write = in Bits(cfg.ldqDepth bits)
    val agu_addr = in Bits(32 bits); val agu_mask = in Bits(4 bits)
    val hi_other = if (cfg.storePairSplitTag) in Bits(16 bits) else null
    val carry = if (cfg.storePairSplitTag) in Bool() else null
    val mismatch = out Bool()
  }
  noIoPrefix()
  val domain = ClockDomain(io.clk, io.rst,
    config=ClockDomainConfig(resetActiveLevel=HIGH, resetKind=SYNC))
  val state = new ClockingArea(domain) {
    val storeAddr = Vec(Reg(Bits(32 bits)), cfg.stqDepth)
    val storeMask = Vec(Reg(Bits(4 bits)), cfg.stqDepth)
    val loadAddr = Vec(Reg(Bits(32 bits)), cfg.ldqDepth)
    val loadMask = Vec(Reg(Bits(4 bits)), cfg.ldqDepth)
    for (j <- 0 until cfg.stqDepth) when(io.store_write(j)) {
      storeAddr(j) := io.agu_addr; storeMask(j) := io.agu_mask
    }
    for (i <- 0 until cfg.ldqDepth) when(io.load_write(i)) {
      loadAddr(i) := io.agu_addr; loadMask(i) := io.agu_mask
    }
  }
  val cache = new StorePairCache(cfg)
  cache.io.clk := io.clk; cache.io.rst := io.rst
  cache.io.store_write := io.store_write; cache.io.load_write := io.load_write
  cache.io.agu_addr := io.agu_addr; cache.io.agu_mask := io.agu_mask
  if (cfg.storePairSplitTag) {
    cache.io.agu_hi0 := Mux(io.carry,io.hi_other,io.agu_addr(31 downto 16))
    cache.io.agu_hi1 := Mux(io.carry,io.agu_addr(31 downto 16),io.hi_other)
    cache.io.agu_c16 := io.carry
  }
  cache.io.store_addr_flat := state.storeAddr.asBits; cache.io.store_mask_flat := state.storeMask.asBits
  cache.io.load_addr_flat := state.loadAddr.asBits; cache.io.load_mask_flat := state.loadMask.asBits
  io.mismatch := (for (i <- 0 until cfg.ldqDepth; j <- 0 until cfg.stqDepth) yield {
    val index = i * cfg.stqDepth + j
    (cache.io.tag_match(index) =/= (state.storeAddr(j)(31 downto 2) === state.loadAddr(i)(31 downto 2))) ||
      (cache.io.overlap(index) =/= (state.loadMask(i) & state.storeMask(j)).orR) ||
      (cache.io.cover(index) =/= ((state.loadMask(i) & ~state.storeMask(j)) === 0))
  }).reduce(_ || _)
}

class StorePairCacheSim extends AnyFunSuite {
  for (depth <- Seq(2, 4, 8); split <- Seq(false,true)) test(
    s"cached comparisons track simultaneous writes and reset: depth=$depth split=$split") {
    val cfg = CpuProfiles.named("mcu").copy(stqDepth=depth, ldqDepth=depth,
      storePairPrecompute=true,storePairSplitTag=split)
    TestSimulation.config.compile(new StorePairCacheHarness(cfg)).doSim { d =>
      val random = new scala.util.Random(601 + depth)
      for (cycle <- 0 until 5000) {
        d.io.clk #= false; d.io.rst #= (cycle == 0 || cycle % 97 == 0)
        d.io.store_write #= BigInt(depth, random); d.io.load_write #= BigInt(depth, random)
        d.io.agu_addr #= (if(cycle%4==0)BigInt(32,random) else (BigInt(random.nextInt(4))<<16)|BigInt(random.nextInt(64)))
        d.io.agu_mask #= random.nextInt(16)
        if(split) { d.io.hi_other #= random.nextInt(65536); d.io.carry #= random.nextBoolean() }
        sleep(2); d.io.clk #= true; sleep(2)
        assert(!d.io.mismatch.toBoolean)
      }
    }
  }
}
