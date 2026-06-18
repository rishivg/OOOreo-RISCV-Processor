package ooo

import spinal.core._
import spinal.core.sim._
import ooo.backend.decode.Decoder
import org.scalatest.funsuite.AnyFunSuite

/** Directed SpinalSim vectors for the combinational decoder vs known RV32IM
  * encodings. Quick gate before the full module-swap RVFI/CoreMark run.
  *   sbt "testOnly ooo.DecoderSim"
  *
  * Enum values (asserted as raw ints) mirror pkg/types.sv:
  *   RS_INT0 INTM1 BR2 MEM3 ; FU_ALU0 MDU1 BR2 AGU3
  *   ALU_ADD0 SLL1 SRA2 SUB3 XOR4 SRL5 OR6 AND7 SLT8 SLTU9
  *   BR_JAL8 JALR9 AUIPC15 ; OP1_RS1 0/ZERO 1 ; OP2_RS2 0/IMM 1
  */
class DecoderSim extends AnyFunSuite {

  /** expected uop fields for one instruction (None = don't-care) */
  case class Exp(
    rsType: Int, fuType: Int, fuOp: Int, op1: Int, op2: Int,
    rdEn: Boolean, rd: Int, rs1: Int, rs2: Int, isStore: Boolean,
    imm: Option[Long] = None
  )

  test("rv32im decode vectors") {
    SimConfig.compile(new Decoder()).doSim { dut =>
      def check(name: String, inst: Long, e: Exp): Unit = {
        dut.io.inst #= inst
        sleep(1)
        def eq(field: String, got: BigInt, want: BigInt) =
          assert(got == want, f"$name [$field]: got $got%d want $want%d (inst=0x$inst%08x)")
        eq("rs_type",  dut.io.rs_type.toBigInt,  e.rsType)
        eq("fu_type",  dut.io.fu_type.toBigInt,  e.fuType)
        eq("fu_opcode",dut.io.fu_opcode.toBigInt,e.fuOp)
        eq("op1_sel",  dut.io.op1_sel.toBigInt,  e.op1)
        eq("op2_sel",  dut.io.op2_sel.toBigInt,  e.op2)
        eq("rd_en",    if (dut.io.rd_en.toBoolean) 1 else 0, if (e.rdEn) 1 else 0)
        eq("rd_arch",  dut.io.rd_arch.toBigInt,  e.rd)
        eq("rs1_arch", dut.io.rs1_arch.toBigInt, e.rs1)
        eq("rs2_arch", dut.io.rs2_arch.toBigInt, e.rs2)
        eq("is_store", if (dut.io.is_store.toBoolean) 1 else 0, if (e.isStore) 1 else 0)
        e.imm.foreach(w => eq("imm", dut.io.imm.toBigInt & 0xFFFFFFFFL, w & 0xFFFFFFFFL))
      }

      // addi x1, x2, 5
      check("addi", 0x00510093L,
        Exp(0, 0, 0 /*ADD*/, 0 /*RS1*/, 1 /*IMM*/, true, 1, 2, 0, false, Some(5)))
      // add x3, x4, x5
      check("add", 0x005201B3L,
        Exp(0, 0, 0 /*ADD*/, 0, 0, true, 3, 4, 5, false))
      // sub x3, x4, x5
      check("sub", 0x405201B3L,
        Exp(0, 0, 3 /*SUB*/, 0, 0, true, 3, 4, 5, false))
      // mul x3, x4, x5  (M-ext: RS_INTM / FU_MDU)
      check("mul", 0x025201B3L,
        Exp(1 /*INTM*/, 1 /*MDU*/, 0, 0, 0, true, 3, 4, 5, false))
      // srai x1, x2, 3  (the historical arith-bit bug: must be SRA not SRL)
      check("srai", 0x40315093L,
        Exp(0, 0, 2 /*SRA*/, 0, 1 /*IMM*/, true, 1, 2, 0, false, Some(0x403)))
      // srli x1, x2, 3
      check("srli", 0x00315093L,
        Exp(0, 0, 5 /*SRL*/, 0, 1, true, 1, 2, 0, false, Some(3)))
      // lw x6, 8(x7)
      check("lw", 0x0083A303L,
        Exp(3 /*MEM*/, 3 /*AGU*/, 2 /*{0,010}*/, 0, 0, true, 6, 7, 0, false, Some(8)))
      // sw x8, 12(x9)
      check("sw", 0x0084A623L,
        Exp(3, 3, 0xA /*{1,010}*/, 0, 0, false, 0, 9, 8, true, Some(12)))
      // beq x10, x11, +16
      check("beq", 0x00B50863L,
        Exp(2 /*BR*/, 2 /*FU_BR*/, 0 /*{0,000}*/, 0, 0, false, 0, 10, 11, false, Some(16)))
      // lui x5, 0x12345
      check("lui", 0x123452B7L,
        Exp(0, 0, 0 /*ADD*/, 1 /*ZERO*/, 1 /*IMM*/, true, 5, 0, 0, false, Some(0x12345000L)))
      // jal x1, .  (offset 0 -> imm 0); checks RS_BR/FU_BR/BR_JAL
      check("jal", 0x000000EFL,
        Exp(2, 2, 8 /*BR_JAL*/, 0, 0, true, 1, 0, 0, false, Some(0)))

      println("[DecoderSim] all vectors passed")
    }
  }
}
