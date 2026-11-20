package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.StoreAgeMask
import org.scalatest.funsuite.AnyFunSuite

class StoreAgeMaskSim extends AnyFunSuite {
  for (depth <- Seq(2, 4, 8, 16)) {
    test(s"store age mask depth $depth all head/tracker encodings") {
      val width = log2Up(depth) + 1
      def dut = new Component {
        val io = new Bundle {
          val head = in UInt(width bits)
          val tracker = in UInt(width bits)
          val lookup = out Bits(depth bits)
          val arithmetic = out Bits(depth bits)
        }
        io.lookup := StoreAgeMask(io.head, io.tracker, depth, lookup = true)
        io.arithmetic := StoreAgeMask(io.head, io.tracker, depth, lookup = false)
      }
      TestSimulation.config.compile(dut).doSim { d =>
        for (head <- 0 until 2 * depth; count <- 0 until 2 * depth) {
          d.io.head #= head; d.io.tracker #= count; sleep(1)
          val tail = (head + count - 1) & (2 * depth - 1)
          val first = head & (depth - 1); val last = tail & (depth - 1)
          val sameWrap = (head / depth) == (tail / depth)
          val expected = (0 until depth).foldLeft(BigInt(0)) { (bits, slot) =>
            val present = if (sameWrap) first <= slot && slot <= last
                          else first <= slot || slot <= last
            if (present) bits.setBit(slot) else bits
          }
          assert(d.io.lookup.toBigInt == expected, s"head=$head tracker=$count")
          assert(d.io.arithmetic.toBigInt == expected, s"head=$head tracker=$count")
        }
      }
    }
  }
}
