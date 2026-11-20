package ooo

import spinal.core._
import spinal.core.sim._
import ooo.execute.{IntRs, IntRsEntry, RsEntry}
import org.scalatest.funsuite.AnyFunSuite
import scala.util.Random

class IntRsCompactionSim extends AnyFunSuite {
  for (depth <- Seq(2, 3, 8, 12, 16, 32)) {
    test(s"integer station compaction and dispatch capacity, depth=$depth") {
      val cfg = CpuConfig(intrsDepth = depth)
      var entries = Seq.empty[RsEntry]
      TestSimulation.config.compile {
        val dut = new IntRs(cfg)
        entries = dut.children.collect { case e: RsEntry => e }.toSeq
        entries.foreach { e =>
          e.io.valid.simPublic(); e.io.request.simPublic(); e.io.entry.simPublic()
        }
        dut
      }.doSim { dut =>
        dut.io.flatten.filter(_.isInput).foreach {
          case b: Bool => b #= false
          case b: Bits => b #= 0
          case _ =>
        }
        def tick(): Unit = {
          dut.io.clk #= false; sleep(2)
          dut.io.clk #= true; sleep(2)
          dut.io.clk #= false; sleep(2)
        }
        dut.io.rst #= true; tick(); tick(); dut.io.rst #= false
        val random = new Random(1401 + depth)
        var queue = Vector.empty[Int]
        var serial = 0
        var fullCycles = 0
        var simultaneous = 0
        var singleSecond = 0
        for (cycle <- 0 until 5000) {
          // Alternate filling with blocked operands and releasing them through
          // each wakeup lane, including the late LSU cofactor.
          val filling = cycle % 120 < 80
          val wake = if (filling) 0 else random.nextInt(16)
          dut.io.cdb_valid #= wake
          dut.io.cdb_rd_phy_flat #= (0 until cfg.cdbWidth).foldLeft(BigInt(0)) {
            (v, k) => v | (BigInt(1) << (k * cfg.prfIdx))
          }
          for (port <- Seq(dut.io.wk_intm_phy_br, dut.io.wk_intm_phy_div,
                           dut.io.wk_intm_phy_mul, dut.io.wk_lsu_phy_a, dut.io.wk_lsu_phy_l)) port #= 1
          dut.io.wk_intm_sel_br #= random.nextBoolean()
          dut.io.wk_intm_sel_div #= random.nextBoolean()
          dut.io.wk_lsu_sel_a #= random.nextBoolean()
          val incoming = random.nextInt(4)
          dut.io.from_ds_valid #= incoming
          val ids = (0 until 2).map { _ => serial += 1; serial % (cfg.robDepth * cfg.idWidth) }
          val layout = ooo.execute.RsEntryLayout.int(cfg)
          val payload = ids.zipWithIndex.foldLeft(BigInt(0)) { case (v, (id, slot)) =>
            val ready = !filling && random.nextBoolean()
            val e = (BigInt(id) << (IntRsEntry.width(cfg) - cfg.robIdx)) |
              (BigInt(1) << layout.rs1PhyLsb) | (BigInt(1) << layout.rs2PhyLsb) |
              (if (ready) (BigInt(1) << layout.rs1ValidLsb) | (BigInt(1) << layout.rs2ValidLsb) else BigInt(0))
            v | (e << (slot * IntRsEntry.width(cfg)))
          }
          dut.io.from_ds_entry_flat #= payload
          sleep(2)
          assert(entries.size == depth)
          assert(entries.map(_.io.valid.toBoolean) == (0 until depth).map(_ < queue.size), s"holes at cycle $cycle")
          val observed = entries.take(queue.size).map(e => (e.io.entry.toBigInt >> (IntRsEntry.width(cfg) - cfg.robIdx)).toInt)
          assert(observed == queue, s"entry order at cycle $cycle")
          val ready = queue.size <= depth - cfg.idWidth
          assert(dut.io.from_ds_ready.toBoolean == ready, s"capacity at cycle $cycle")
          val winners = entries.indices.filter(i => entries(i).io.request.toBoolean).take(2).toSet
          val pushes = if (ready) ids.zipWithIndex.collect { case (id, slot) if (incoming & (1 << slot)) != 0 => id } else Seq.empty
          if (queue.size == depth) fullCycles += 1
          if (winners.nonEmpty && pushes.nonEmpty) simultaneous += 1
          if (ready && incoming == 2) singleSecond += 1
          queue = queue.zipWithIndex.collect { case (id, i) if !winners(i) => id } ++ pushes
          tick()
          if (cycle % 211 == 210) {
            dut.io.rst #= true; tick(); dut.io.rst #= false; queue = Vector.empty
          }
        }
        assert(fullCycles > 50 && singleSecond > 50)
        assert(if (depth == 2) simultaneous == 0 else simultaneous > 50)
      }
    }
  }
}
