package ooo

import spinal.core.sim._
import ooo.execute.FuAlu
import org.scalatest.funsuite.AnyFunSuite

class FuAluLifetimeSim extends AnyFunSuite {
  for (target <- Seq("asic", "fpga"); rvfi <- Seq(false, true)) {
    test(s"ALU two-stage result lifetime, noisy bubbles and repeated reset target=$target RVFI=$rvfi") {
      val cfg = CpuConfig.forTarget(CpuProfiles.named("mcu-efficient"), target).copy(rvfi = rvfi)
      TestSimulation.config.compile(new FuAlu(cfg)).doSim { d =>
        d.io.clk #= false; d.io.rst #= true
        d.io.int_rs_valid #= false; d.io.fu_alu_reg_in #= 0
        def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
        tick(); tick(); d.io.rst #= false
        val mask = (BigInt(1) << 32) - 1
        def signed(v: BigInt): BigInt = if (v.testBit(31)) v - (BigInt(1) << 32) else v
        def result(op: Int, a: BigInt, b: BigInt): BigInt = (op match {
          case 0 => a + b
          case 1 => a << (b.toInt & 31)
          case 2 => signed(a) >> (b.toInt & 31)
          case 3 => a - b
          case 4 => a ^ b
          case 5 => a >> (b.toInt & 31)
          case 6 => a | b
          case 7 => a & b
          case 8 => if (signed(a) < signed(b)) BigInt(1) else BigInt(0)
          case 9 => if (a < b) BigInt(1) else BigInt(0)
          case _ => BigInt(0)
        }) & mask
        case class Entry(id: Int, arch: Int, phy: Int, op: Int, a: BigInt, b: BigInt, rs1: BigInt, rs2: BigInt) {
          def packed: BigInt = (BigInt(id) << 143) | (BigInt(arch) << 138) | (BigInt(phy) << 132) |
            (BigInt(op) << 128) | (a << 96) | (b << 64) | (rs1 << 32) | rs2
          def value: BigInt = result(op, a, b)
        }
        var first = Option.empty[Entry]; var second = Option.empty[Entry]
        val random = new scala.util.Random(470)
        var checked = 0; var resets = 0
        for (cycle <- 0 until 3600) {
          val reset = cycle % 181 >= 178
          val valid = cycle % 37 < 28 && random.nextInt(4) != 0
          val entry = Entry(random.nextInt(64), random.nextInt(32), random.nextInt(cfg.prfDepth),
            random.nextInt(16), BigInt(32, random), BigInt(32, random), BigInt(32, random), BigInt(32, random))
          d.io.rst #= reset; d.io.int_rs_valid #= valid; d.io.fu_alu_reg_in #= entry.packed
          sleep(1)
          assert(d.io.fu_alu_ready.toBoolean)
          assert(d.io.bypass.toBigInt.testBit(cfg.prfIdx + 32) == first.isDefined)
          assert(d.io.cdb_valid.toBoolean == second.isDefined)
          first.foreach { e =>
            assert((d.io.bypass.toBigInt & mask) == e.value)
            assert(((d.io.bypass.toBigInt >> 32) & ((1 << cfg.prfIdx) - 1)) == e.phy)
          }
          second.foreach { e =>
            assert(d.io.cdb_rd_value.toBigInt == e.value)
            assert(d.io.cdb_rob_id.toInt == e.id && d.io.cdb_rd_arch.toInt == e.arch && d.io.cdb_rd_phy.toInt == e.phy)
            assert(d.io.cdb_rs1_value_dbg.toBigInt == (if (rvfi) e.rs1 else BigInt(0)))
            assert(d.io.cdb_rs2_value_dbg.toBigInt == (if (rvfi) e.rs2 else BigInt(0)))
            checked += 1
          }
          if (reset) { first = None; second = None; resets += 1 }
          else { second = first; first = if (valid) Some(entry) else None }
          tick()
        }
        assert(checked > 1800 && resets > 30)
      }
    }
  }
}
