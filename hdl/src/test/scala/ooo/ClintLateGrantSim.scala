package ooo

import spinal.core.sim._
import ooo.memory.Clint
import org.scalatest.funsuite.AnyFunSuite

class ClintLateGrantSim extends AnyFunSuite {
  test("blocked timer writes preserve counting, byte masks and software interrupts") {
    val cfg = CpuConfig(zicsr=true,clintEarlyWrite=true,clintLateWriteGrant=true)
    TestSimulation.config.compile(new Clint(cfg,predecodedWrites=true)).doSim { d =>
      d.io.clk #= false; d.io.rst #= true
      d.io.req_valid #= false; d.io.req_addr #= 0; d.io.req_rmask #= 0
      d.io.req_wmask #= 0; d.io.req_wdata #= 0; d.io.write_sel #= 0; d.io.write_block #= false
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2) }
      tick(); tick(); d.io.rst #= false
      def write(slot: Int, mask: Int, data: BigInt, blocked: Boolean=false): Unit = {
        d.io.write_sel #= 1 << slot; d.io.req_wmask #= mask
        d.io.req_wdata #= data; d.io.write_block #= blocked; tick()
        d.io.write_sel #= 0; d.io.req_wmask #= 0; d.io.write_block #= false
      }
      def read(offset: Int): BigInt = {
        d.io.req_valid #= true; d.io.req_addr #= offset; d.io.req_rmask #= 15
        tick(); val value=d.io.rdata.toBigInt
        d.io.req_valid #= false; d.io.req_rmask #= 0; value
      }
      write(1,15,0,blocked=true)
      assert(read(0x4000)==BigInt("ffffffff",16))
      write(1,5,BigInt("1234abcd",16))
      assert(read(0x4000)==BigInt("ff34ffcd",16))
      write(0,1,1,blocked=true); assert(!d.io.irq_soft.toBoolean)
      write(0,1,1); assert(d.io.irq_soft.toBoolean)
      val before=d.io.mtime.toBigInt
      for (_ <- 0 until 4) write(3,15,0,blocked=true)
      assert(d.io.mtime.toBigInt==before+4)
      write(4,15,0); write(3,15,BigInt("ffffffff",16))
      write(3,15,0,blocked=true)
      assert(d.io.mtime.toBigInt==BigInt("100000000",16))
    }
  }
}
