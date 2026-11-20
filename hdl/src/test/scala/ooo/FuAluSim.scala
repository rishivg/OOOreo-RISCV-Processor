package ooo

import spinal.core.sim._
import ooo.execute.FuAlu
import org.scalatest.funsuite.AnyFunSuite
import scala.util.Random

/** Check ALU bypass results against RV32I semantics. */
class FuAluSim extends AnyFunSuite {
  val ALU_ADD = 0x0; val ALU_SLL = 0x1; val ALU_SRA = 0x2; val ALU_SUB = 0x3
  val ALU_XOR = 0x4; val ALU_SRL = 0x5; val ALU_OR  = 0x6; val ALU_AND = 0x7
  val ALU_SLT = 0x8; val ALU_SLTU = 0x9

  val M = (BigInt(1) << 32) - 1
  def u32(x: BigInt): BigInt = x & M
  def s32(x: BigInt): BigInt = { val v = u32(x); if (v.testBit(31)) v - (BigInt(1) << 32) else v }

  // Operands are preselected in IntRs:
  //   rs2[31:0] rs1[63:32] opB[95:64] opA[127:96] fu_opcode[131:128]
  //   rd_phy[137:132] rd_arch[142:138] rob_id[148:143]
  def packReg(rob: Int, rdArch: Int, rdPhy: Int, op: Int,
              opA: BigInt, opB: BigInt, rs1: BigInt, rs2: BigInt): BigInt =
    (BigInt(rob & 0x3F) << 143) | (BigInt(rdArch & 0x1F) << 138) | (BigInt(rdPhy & 0x3F) << 132) |
      (BigInt(op & 0xF) << 128) | (u32(opA) << 96) | (u32(opB) << 64) |
      (u32(rs1) << 32) | u32(rs2)

  /** RV32I reference for the ALU result. */
  def model(op: Int, a: BigInt, b: BigInt): BigInt = op match {
    case x if x == ALU_ADD  => u32(a + b)
    case x if x == ALU_SUB  => u32(a - b)
    case x if x == ALU_XOR  => a ^ b
    case x if x == ALU_OR   => a | b
    case x if x == ALU_AND  => a & b
    case x if x == ALU_SLL  => u32(a << (b.toInt & 31))
    case x if x == ALU_SRL  => u32(a >> (b.toInt & 31))
    case x if x == ALU_SRA  => u32(s32(a) >> (b.toInt & 31))
    case x if x == ALU_SLT  => if (s32(a) < s32(b)) 1 else 0
    case x if x == ALU_SLTU => if (a < b) 1 else 0
    case _ => BigInt(0)
  }

  for (shared <- Seq(false, true)) test(s"fu_alu all opcodes vs RV32I reference, shared shift=$shared") {
    TestSimulation.config.compile(new FuAlu(CpuConfig(fpgaSharedShift = shared))).doSim { dut =>
      def tick(): Unit = { dut.io.clk #= false; sleep(1); dut.io.clk #= true; sleep(1) }
      dut.io.clk #= false; dut.io.rst #= true
      dut.io.int_rs_valid #= false; dut.io.fu_alu_reg_in #= 0
      sleep(1); tick(); tick()
      dut.io.rst #= false

      var checked = 0
      def run(op: Int, a0: BigInt, b0: BigInt): Unit = {
        val a = u32(a0); val b = u32(b0)
        dut.io.int_rs_valid #= true
        dut.io.fu_alu_reg_in #= packReg(0x2A, 0x15, 0x33, op, a, b, a, b)
        tick()          // latch into fu_alu_reg_out
        sleep(1)        // settle combinational result
        val exp = model(op, a, b)
        val got = dut.io.bypass.toBigInt & M
        assert(got == exp,
          f"op=$op%x a=0x$a%x b=0x$b%x got=0x$got%x exp=0x$exp%x")
        // rd_phy must ride the same bypass word
        assert(((dut.io.bypass.toBigInt >> 32) & 0x3F) == 0x33, "rd_phy mismatch on bypass")
        checked += 1
      }

      val ops = Seq(ALU_ADD, ALU_SLL, ALU_SRA, ALU_SUB, ALU_XOR,
                    ALU_SRL, ALU_OR, ALU_AND, ALU_SLT, ALU_SLTU)
      val corners = Seq[BigInt](0, 1, 2, 31, 32, M, M - 1,
                                BigInt("80000000", 16), BigInt("7fffffff", 16),
                                BigInt("aaaaaaaa", 16), BigInt("55555555", 16))
      // Opcode and operand corners
      for (op <- ops; x <- corners; y <- corners) {
        run(op, x, y)
        run(op, y, x)
        run(op, 0, y)      // the OP1_ZERO case IntRs now pre-selects
      }
      // shift-amount sweep (only b[4:0] matters, but prove the masking)
      for (op <- Seq(ALU_SLL, ALU_SRL, ALU_SRA); sh <- 0 until 32)
        run(op, BigInt("deadbeef", 16), BigInt(sh))
      val rnd = new Random(4242)
      for (_ <- 0 until 3000) {
        val op = ops(rnd.nextInt(ops.length))
        run(op, BigInt(32, rnd), BigInt(32, rnd))
      }
      println(s"[FuAluSim] checked $checked vectors")
    }
  }
}
