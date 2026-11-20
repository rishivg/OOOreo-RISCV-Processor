package ooo

import spinal.core._
import spinal.core.sim._
import ooo.rename.FreeList
import org.scalatest.funsuite.AnyFunSuite

class FreeListLifetimeSim extends AnyFunSuite {
  for (depth <- Seq(8, 16, 32)) {
    test(s"free-list depth $depth idle, wrap, backpressure, concurrent release and flush") {
      val cfg = CpuProfiles.named("mcu-efficient").copy(prfDepth = 32 + depth)
      TestSimulation.config.compile(new FreeList(cfg)).doSim { d =>
        d.io.flatten.filter(_.isInput).foreach {
          case b: Bool => b #= false
          case b: Bits => b #= 0
          case _ =>
        }
        def tick(): Unit = {
          d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2)
        }
        d.io.rst #= true; tick(); tick(); d.io.rst #= false
        var rows = Array.tabulate(depth)(32 + _)
        var wr = 0; var rd = 0; var count = depth
        var blocked = 0; var idle = 0; var wraps = 0
        val random = new scala.util.Random(837 + depth)
        def pack(values: Seq[Int]): BigInt = values.zipWithIndex.foldLeft(BigInt(0)) {
          case (v, (x, i)) => v | (BigInt(x) << (i * cfg.prfIdx))
        }
        for (cycle <- 0 until 4200) {
          val reset = cycle % 701 == 700
          val flush = cycle % 257 == 256
          val ready = count >= cfg.idWidth
          val releaseCapacity = depth - count
          val phase = cycle % 96
          val ni = if (phase < 12 || !ready) 0 else if (phase < 48) cfg.idWidth else random.nextInt(cfg.idWidth + 1)
          val nr = if (phase < 48) 0 else random.nextInt(math.min(cfg.idWidth, releaseCapacity) + 1)
          val imask = if (ni == 1 && random.nextBoolean()) 2 else (1 << ni) - 1
          val rmask = if (nr == 1 && random.nextBoolean()) 2 else (1 << nr) - 1
          val returned = Seq.fill(cfg.idWidth)(random.nextInt(cfg.prfDepth))
          d.io.rst #= reset; d.io.backend_flush #= flush
          d.io.from_id_valid #= imask; d.io.from_rrf_valid #= rmask
          d.io.from_rrf_stale_idx_flat #= pack(returned)
          sleep(1)
          assert(d.io.from_id_ready.toBoolean == ready, s"ready cycle $cycle")
          for (i <- 0 until cfg.idWidth) {
            val prefix = (0 until i).count(j => (imask & (1 << j)) != 0)
            val actual = (d.io.from_id_free_idx_flat.toBigInt >> (i * cfg.prfIdx)) & ((1 << cfg.prfIdx) - 1)
            assert(actual == rows((rd + prefix) % depth), s"pop cycle $cycle slot $i")
          }
          if (!ready) blocked += 1
          if (ni == 0 && nr == 0) idle += 1
          val previousWr = wr; val previousRd = rd
          var push = 0
          for (i <- 0 until cfg.idWidth) if ((rmask & (1 << i)) != 0) {
            rows((wr + push) % depth) = returned(i); push += 1
          }
          if (reset) { rows = Array.tabulate(depth)(32 + _); wr = 0; rd = 0; count = depth }
          else if (flush) { wr = 0; rd = 0; count = depth }
          else {
            wr = (wr + nr) % depth
            if (ready) rd = (rd + ni) % depth
            count += nr - (if (ready) ni else 0)
          }
          if (wr < previousWr || rd < previousRd) wraps += 1
          tick()
        }
        assert(blocked > 100 && idle > 100 && wraps > 40)
      }
    }
  }
}
