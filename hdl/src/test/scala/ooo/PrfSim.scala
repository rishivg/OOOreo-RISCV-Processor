package ooo

import spinal.core._
import spinal.core.sim._
import ooo.execute.Prf
import org.scalatest.funsuite.AnyFunSuite

class PrfSim extends AnyFunSuite {
  for (depth <- Seq(48, 64, 96); style <- Seq("onehot", "binary", "lutram", "shared-decode")) {
    test(s"PRF $depth $style storage, collisions, forwarding and invalid addresses") {
      val cfg = CpuConfig.forTarget(CpuConfig(prfDepth = depth), "fpga").copy(
        prfLutRam = style == "lutram", prfBinaryRead = style == "binary" || style == "lutram",
        brPrfSharedPredecode = style == "shared-decode")
      TestSimulation.config.compile(new Prf(cfg)).doSim { d =>
        d.io.flatten.filter(_.isInput).foreach {
          case b: Bool => b #= false
          case b: Bits => b #= 0
          case _ =>
        }
        val random = new scala.util.Random(0x7072 + depth)
        val mem = Array.fill[BigInt](depth)(BigInt(0))
        val cdb = cfg.cdbWidth; val idx = cfg.prfIdx; val n = cfg.prfReadPorts
        val bpw = 2 * (cdb + 1) + 2 * log2Up(cfg.intIssueWidth)
        def pack(xs: Seq[BigInt], width: Int) = xs.zipWithIndex.foldLeft(BigInt(0)) {
          case (v, (x, i)) => v | (x << (i * width))
        }
        def tick(): Unit = { d.io.clk #= false; sleep(1); d.io.clk #= true; sleep(1); d.io.clk #= false; sleep(1) }
        for (r <- 1 until depth) {
          val value = BigInt(32, random)
          d.io.cdb_valid_flat #= 1; d.io.cdb_rd_phy_flat #= r; d.io.cdb_rd_value_flat #= value
          tick(); mem(r) = value
        }
        for (cycle <- 0 until 800) {
          val addressSpace = 1 << idx
          val phy = Seq.fill(cdb)(random.nextInt(addressSpace)).toArray
          if (cycle % 7 == 0) for (lane <- 1 until cdb) phy(lane) = phy(0)
          if (cycle % 11 == 0) phy(0) = 0
          if (cycle % 13 == 0 && depth < addressSpace) phy(0) = depth
          val values = Seq.fill(cdb)(BigInt(32, random))
          val valid = random.nextInt(1 << cdb)
          val fast = Seq.fill(cfg.numFastBypass)(BigInt(32, random))
          d.io.cdb_valid_flat #= valid
          d.io.cdb_rd_phy_flat #= pack(phy.toSeq.map(BigInt(_)), idx)
          d.io.cdb_rd_value_flat #= pack(values, 32)
          d.io.alu_bypass_flat #= pack(fast, cfg.bypassNetW)
          case class Read(a: Int, b: Int, e1: Int, e2: Int, s1: Int, s2: Int) {
            def bypass: BigInt = (BigInt(e1) << (cdb + 3)) | (BigInt(e2) << 2) | (s1 << 1) | s2
          }
          def reads(count: Int) = Seq.fill(count) {
            def en(): Int = random.nextInt(cdb + 3) match {
              case 0 => 0
              case x if x <= cdb + 1 => 1 << (x - 1)
              case _ => 3
            }
            Read(random.nextInt(addressSpace), random.nextInt(addressSpace), en(), en(), random.nextInt(2), random.nextInt(2))
          }
          val normal = reads(n); val memory = reads(cfg.memrsDepth)
          val integer = reads(cfg.intmrsDepth); val branch = reads(cfg.brrsDepth)
          d.io.from_rs_rs1_phy_flat #= pack(normal.map(r => BigInt(r.a)), idx)
          d.io.from_rs_rs2_phy_flat #= pack(normal.map(r => BigInt(r.b)), idx)
          d.io.from_rs_rs_bypass_flat #= pack(normal.map(_.bypass), bpw)
          d.io.pre_rs1_phy_flat #= pack(memory.map(r => BigInt(r.a)), idx)
          d.io.pre_rs1_bypass_flat #= pack(memory.map(_.bypass), bpw)
          d.io.ipre_phy1_flat #= pack(integer.map(r => BigInt(r.a)), idx)
          d.io.ipre_phy2_flat #= pack(integer.map(r => BigInt(r.b)), idx)
          d.io.ipre_bypass_flat #= pack(integer.map(_.bypass), bpw)
          d.io.bpre_phy1_flat #= pack(branch.map(r => BigInt(r.a)), idx)
          d.io.bpre_phy2_flat #= pack(branch.map(r => BigInt(r.b)), idx)
          d.io.bpre_bypass_flat #= pack(branch.map(_.bypass), bpw)
          def rowMask(address: Int): BigInt =
            if (address > 0 && address < depth) BigInt(1) << (address - 1) else BigInt(0)
          val decoded1 = if (random.nextInt(5) == 0) BigInt(depth - 1, random) else rowMask(branch.head.a)
          val decoded2 = if (random.nextInt(5) == 0) BigInt(depth - 1, random) else rowMask(branch.head.b)
          if (cfg.brPrfSharedPredecode) {
            d.io.bpre_select1 #= decoded1
            d.io.bpre_select2 #= decoded2
          }
          def decodedValue(mask: BigInt): BigInt = (1 until depth)
            .filter(row => mask.testBit(row - 1)).foldLeft(BigInt(0))((value, row) => value | mem(row))
          def value(address: Int, enable: Int, select: Int, decoded: Option[BigInt]): BigInt = {
            if (enable == 0) decoded.map(decodedValue).getOrElse {
              if (address > 0 && address < depth) mem(address) else BigInt(0)
            }
            else if (enable == (1 << cdb)) fast(select)
            else if ((enable & (enable - 1)) == 0 && enable < (1 << cdb)) values(Integer.numberOfTrailingZeros(enable))
            else BigInt(0)
          }
          def expected(rs: Seq[Read], second: Boolean, decoded: Option[BigInt] = None) =
            pack(rs.zipWithIndex.map { case (r, port) =>
              val rows = if (port == 0) decoded else None
              if (second) value(r.b, r.e2, r.s2, rows) else value(r.a, r.e1, r.s1, rows)
            }, 32)
          sleep(1)
          assert(d.io.from_rs_rs1_value_flat.toBigInt == expected(normal, false))
          assert(d.io.from_rs_rs2_value_flat.toBigInt == expected(normal, true))
          assert(d.io.pre_rs1_value_flat.toBigInt == expected(memory, false))
          assert(d.io.ipre_value1_flat.toBigInt == expected(integer, false))
          assert(d.io.ipre_value2_flat.toBigInt == expected(integer, true))
          assert(d.io.bpre_value1_flat.toBigInt == expected(branch, false, if (cfg.brPrfSharedPredecode) Some(decoded1) else None))
          assert(d.io.bpre_value2_flat.toBigInt == expected(branch, true, if (cfg.brPrfSharedPredecode) Some(decoded2) else None))
          tick()
          for (lane <- 0 until cdb if ((valid >> lane) & 1) != 0 && phy(lane) > 0 && phy(lane) < depth)
            mem(phy(lane)) = values(lane)
        }
      }
    }
  }
}
