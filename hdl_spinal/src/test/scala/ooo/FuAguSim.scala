package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.FuAgu
import org.scalatest.funsuite.AnyFunSuite

/** Directed SpinalSim vectors for fu_agu's effective-address + store-alignment +
  * byte-mask logic (the non-trivial combinational part downstream of the register).
  * Drives clk/rst manually since the module owns its ClockDomain (clk/rst IO).
  *   sbt "testOnly ooo.FuAguSim"
  *
  * agu_reg_t packing (MSB->LSB): rob_id[6] fu_opcode[4] imm[32] rs1_value[32] rs2_value[32]
  * agu_lsq_t packing (MSB->LSB): rob_id[6] addr[32] wdata[32] mask[4] rs1_dbg[32] rs2_dbg[32]
  */
class FuAguSim extends AnyFunSuite {
  // memopc_t
  val SB = 0x8; val SH = 0x9; val SW = 0xA; val LW = 0x2; val LB = 0x0; val LH = 0x1

  def packReg(rob: Long, op: Int, imm: Long, rs1: Long, rs2: Long): BigInt = {
    def m32(x: Long) = BigInt(x) & 0xFFFFFFFFL
    (BigInt(rob & 0x3F) << 100) | (BigInt(op & 0xF) << 96) |
      (m32(imm) << 64) | (m32(rs1) << 32) | m32(rs2)
  }
  // unpack to_lsq
  def lsqRob(v: BigInt)   = (v >> 132) & 0x3F
  def lsqAddr(v: BigInt)  = (v >> 100) & 0xFFFFFFFFL
  def lsqWdata(v: BigInt) = (v >> 68)  & 0xFFFFFFFFL
  def lsqMask(v: BigInt)  = (v >> 64)  & 0xF

  test("fu_agu addr / store-align / mask vectors") {
    SimConfig.compile(new FuAgu()).doSim { dut =>
      // manual clock + sync reset
      def tick(): Unit = { dut.io.clk #= false; sleep(1); dut.io.clk #= true; sleep(1) }
      dut.io.clk #= false; dut.io.rst #= true; dut.io.prv_valid #= false; dut.io.agu_reg_in #= 0
      sleep(1); tick(); tick()
      dut.io.rst #= false

      def run(name: String, op: Int, imm: Long, rs1: Long, rs2: Long,
              expAddr: Long, expW: Long, expMask: Long, expRob: Long): Unit = {
        dut.io.prv_valid #= true
        dut.io.agu_reg_in #= packReg(expRob, op, imm, rs1, rs2)
        tick()                                  // latch into agu_reg
        sleep(1)                                // settle comb outputs
        val v = dut.io.to_lsq.toBigInt
        assert(dut.io.nxt_valid.toBoolean, s"$name: nxt_valid low")
        assert(lsqAddr(v)  == (BigInt(expAddr) & 0xFFFFFFFFL), f"$name addr  got 0x${lsqAddr(v)}%08x want 0x$expAddr%08x")
        assert(lsqMask(v)  == BigInt(expMask),                 f"$name mask  got ${lsqMask(v)} want $expMask")
        assert(lsqRob(v)   == BigInt(expRob),                  f"$name rob   got ${lsqRob(v)} want $expRob")
        // wdata only meaningful for stores; check masked lanes
        if (op == SB || op == SH || op == SW)
          assert(lsqWdata(v) == (BigInt(expW) & 0xFFFFFFFFL),  f"$name wdata got 0x${lsqWdata(v)}%08x want 0x$expW%08x")
      }

      // sw x?, 4(x1=0x1000) val 0xDEADBEEF -> addr 0x1004 aligned, mask 1111
      run("sw",  SW, 4,    0x1000, 0xDEADBEEFL, 0x1004, 0xDEADBEEFL, 0xF, 7)
      // sb at addr%4==2: byte placed in lane 2 -> wdata 0x00CC0000, mask 0100
      run("sb@2",SB, 2,    0x1000, 0x000000CCL, 0x1002, 0x00CC0000L, 0x4, 3)
      // sb at addr%4==3: lane 3 -> 0xAB000000, mask 1000
      run("sb@3",SB, 3,    0x1000, 0x000000ABL, 0x1003, 0xAB000000L, 0x8, 1)
      // sh at addr%4==2: half lane 1 -> 0x12340000, mask 1100
      run("sh@2",SH, 2,    0x1000, 0x00001234L, 0x1002, 0x12340000L, 0xC, 9)
      // sh at addr%4==0: half lane 0 -> 0x00005678, mask 0011
      run("sh@0",SH, 0,    0x1000, 0x00005678L, 0x1000, 0x00005678L, 0x3, 2)
      // lw: mask 1111, addr add with negative imm
      run("lw",  LW, -4,   0x1008, 0,           0x1004, 0,          0xF, 5)
      // lb @1: mask 0010
      run("lb@1",LB, 1,    0x1000, 0,           0x1001, 0,          0x2, 0)
      // lh @0: mask 0011
      run("lh@0",LH, 0,    0x2000, 0,           0x2000, 0,          0x3, 4)

      println("[FuAguSim] all vectors passed")
    }
  }
}
