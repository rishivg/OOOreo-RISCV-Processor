package ooo

import spinal.core.sim._
import ooo.memory.FuAgu
import org.scalatest.funsuite.AnyFunSuite
import scala.util.Random

class FuAguProductSim extends AnyFunSuite {
  for ((signed,forward,native,orCarry) <- Seq((false,false,false,false),(true,false,false,false),
      (true,true,false,false),(true,true,true,false),(false,false,false,true),
      (true,true,false,true),(true,true,true,true))) {
  test(s"selected addresses, masks and device classification: signed=$signed forward=$forward native=$native orCarry=$orCarry") {
    val cfg = CpuConfig(rvfi=true, aExt=true, zicsr=true, mmio=true, lsuWaySpeculation=true,
      lsuResponsePredecode=forward,lsuForwardSpeculation=forward,
      aguSignedImmediate=signed,fpgaNativeAdd=native,aguOrCarry=orCarry)
    TestSimulation.config.compile(new FuAgu(cfg)).doSim { d =>
      val random = new Random(600)
      val mask32 = (BigInt(1) << 32) - 1
      val boundary = Seq(0L,0x01ffffffL,0x02000000L,0x0200ffffL,0x02010000L,
        0x0fffffffL,0x10000000L,0x1fffffffL,0x20000000L,0xffffffffL).map(BigInt(_))
      d.io.clk #= false; d.io.rst #= false
      for (i <- 0 until 4096) {
        def operand(): BigInt = if (i % 3 == 0) boundary(random.nextInt(boundary.size)) else BigInt(32,random)
        def immediate(): BigInt = if (!signed) operand() else {
          val value = if (i % 4 == 0) Seq(-2048,-1,0,2047)(i % 16 / 4) else random.nextInt(4096)-2048
          BigInt(value) & mask32
        }
        val base = operand(); val imm = immediate(); val offset = immediate(); val store = operand()
        val ways = (0 until cfg.lsuBypassCandidates).map(_ => operand())
        val way = i % cfg.lsuBypassCandidates; val alt = (i & 4) != 0
        val op = Seq(0,1,2,4,5,8,9,10)(i % 8)
        val addr = ((if (alt) ways(way) + offset else base + imm) & mask32)
        d.io.prv_valid #= (i % 5 != 0)
        d.io.agu_reg_in #= (BigInt(op) << 96) | (imm << 64) | (base << 32) | store
        d.io.alt_sel #= alt; d.io.alt_imm #= offset; d.io.alt_rs1_value #= ways(way)
        d.io.alt_way_select #= BigInt(1) << way
        d.io.alt_way_rs1_flat #= ways.zipWithIndex.map { case (v,w) => v << (32*w) }.reduce(_ | _)
        sleep(1)
        val result = d.io.to_lsq.toBigInt
        val lane = (addr & 3).toInt
        val byteMask = if (op == 0 || op == 4 || op == 8) (1 << lane) else if (op == 1 || op == 5 || op == 9) ((3 << lane) & 15) else 15
        val data = op match {
          case 8 => (store & 255) << (8*lane)
          case 9 => (store & 65535) << (if ((lane & 2) != 0) 16 else 0)
          case 10 => store
          case _ => BigInt(0)
        }
        assert(((result >> 100) & mask32) == addr)
        assert(((result >> 68) & mask32) == data)
        assert(((result >> 64) & 15) == byteMask)
        assert(((result >> 32) & mask32) == (if (alt) ways(way) else base))
        assert((result & mask32) == store)
        val split = if (d.io.agu_c16.toBoolean) d.io.agu_hi1.toBigInt else d.io.agu_hi0.toBigInt
        assert(split == (addr >> 16))
        assert(d.io.agu_clint.toBoolean == ((addr >> 16) == cfg.clintHi16))
        val half = Set(1,5,9).contains(op); val word = Set(2,10).contains(op)
        assert(d.io.agu_misaligned.toBoolean == ((half && (lane & 1) != 0) || (word && lane != 0)))
        assert(d.io.agu_is_store.toBoolean == ((op & 8) != 0))
        val selectedRegister = ooo.memory.Clint.offsets.zipWithIndex.filter { case (off,_) => (addr & 0xfffc) == off }.map { case (_,w) => BigInt(1) << w }.foldLeft(BigInt(0))(_ | _)
        assert(d.io.agu_clint_read_sel.toBigInt == selectedRegister)
        assert(d.io.agu_ordered.toBoolean == (((addr & BigInt("f0000000",16)) == BigInt("10000000",16)) || ((addr >> 16) == 0x0200)))
      }
    }
  }

  }

  for ((atomics, csrs) <- Seq((false,false), (true,false), (false,true), (true,true))) {
    test(s"product AGU preserves AMO operands without queue debug storage: A=$atomics Zicsr=$csrs") {
      val cfg = CpuConfig(rvfi=false, aExt=atomics, zicsr=csrs)
      TestSimulation.config.compile(new FuAgu(cfg)).doSim { dut =>
        val mask32 = (BigInt(1) << 32) - 1
        val random = new Random(20261012)
        dut.io.clk #= false; dut.io.rst #= false; dut.io.prv_valid #= true
        dut.io.alt_imm #= 0
        for (iteration <- 0 until 256) {
          val rs1 = BigInt(32,random)
          val rs2 = BigInt(32,random)
          val alternate = BigInt(32,random)
          val select = iteration % 2 != 0
          // MEM_LW; raw rs2 still serves AMO even though load wdata is unused.
          dut.io.agu_reg_in #= (BigInt(2) << 96) | (rs1 << 32) | rs2
          dut.io.alt_rs1_value #= alternate
          dut.io.alt_sel #= select
          sleep(1)
          val payload = dut.io.to_lsq.toBigInt
          val chosenRs1 = if (select) alternate else rs1
          assert((payload & mask32) == (if (atomics) rs2 else BigInt(0)), "AMO operand lost")
          assert(((payload >> 32) & mask32) == 0, "unused rs1 debug storage survived")
          assert(((payload >> 100) & mask32) == chosenRs1, "effective-address/CSR operand changed")
        }
      }
    }
  }
}
