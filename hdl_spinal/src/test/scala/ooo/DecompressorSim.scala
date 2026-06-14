package ooo

import spinal.core._
import spinal.core.sim._
import ooo.frontend.Decompressor
import org.scalatest.funsuite.AnyFunSuite

/** Directed SpinalSim vectors for the RV32C->RV32I decompressor vs hand-computed
  * base-ISA expansions. Quick gate before the full module-swap on coremark_imc.
  *   sbt "testOnly ooo.DecompressorSim"
  */
class DecompressorSim extends AnyFunSuite {
  test("rv32c decompress vectors") {
    SimConfig.compile(new Decompressor()).doSim { dut =>
      def check(name: String, cInst: Long, expOut: Long, expComp: Boolean): Unit = {
        dut.io.inst_in #= cInst
        sleep(1)
        val got  = dut.io.inst_out.toBigInt & 0xFFFFFFFFL
        val comp = dut.io.is_compressed.toBoolean
        assert(got == (BigInt(expOut) & 0xFFFFFFFFL),
          f"$name: out got 0x$got%08x want 0x$expOut%08x (cinst=0x$cInst%04x)")
        assert(comp == expComp, f"$name: is_compressed got $comp want $expComp")
      }

      // compressed forms (cinst is the 16-bit parcel; upper bits ignored)
      check("c.addi  x1,1",   0x0085L, 0x00108093L, true) // addi x1,x1,1
      check("c.nop",          0x0001L, 0x00000013L, true) // addi x0,x0,0
      check("c.li    x5,-1",  0x52FDL, 0xFFF00293L, true) // addi x5,x0,-1
      check("c.srai  x8,3",   0x840DL, 0x40345413L, true) // srai x8,x8,3  (arith bit!)
      check("c.srli  x8,3",   0x800DL, 0x00345413L, true) // srli x8,x8,3
      check("c.add   x1,x2",  0x908AL, 0x002080B3L, true) // add  x1,x1,x2
      check("c.mv    x1,x2",  0x808AL, 0x002000B3L, true) // add  x1,x0,x2
      check("c.jr    x5",     0x8282L, 0x00028067L, true) // jalr x0,0(x5)
      check("c.jalr  x5",     0x9282L, 0x000280E7L, true) // jalr x1,0(x5)
      check("c.ebreak",       0x9002L, 0x00100073L, true)
      check("c.jal   +0",     0x2001L, 0x000000EFL, true) // jal x1,0
      check("c.j     +0",     0xA001L, 0x0000006FL, true) // jal x0,0
      check("c.lwsp  x1",     0x4082L, 0x00012083L, true) // lw x1,0(x2)
      check("c.addi4spn rsvd", 0x0000L, 0x00000000L, true) // reserved -> illegal, still compressed

      // 32-bit pass-through (quad==11): not compressed, out == in
      check("passthrough add", 0x002080B3L, 0x002080B3L, false)

      println("[DecompressorSim] all vectors passed")
    }
  }
}
