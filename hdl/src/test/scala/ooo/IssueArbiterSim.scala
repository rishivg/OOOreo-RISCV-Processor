package ooo

import spinal.core.sim._
import ooo.execute.IssueArbiter
import org.scalatest.funsuite.AnyFunSuite

class IssueArbiterSim extends AnyFunSuite {
  for (depth <- Seq(8, 12, 16)) {
    test(s"oldest two issue requests and compaction, exhaustive depth=$depth") {
      TestSimulation.config.compile(new IssueArbiter(CpuConfig(intrsDepth = depth))).doSim { dut =>
        for (requests <- 0 until (1 << depth)) {
          dut.io.rs_request #= requests
          sleep(1)
          val winners = (0 until depth).filter(i => ((requests >> i) & 1) != 0).take(2)
          val grant = winners.foldLeft(BigInt(0))((bits, i) => bits.setBit(i))
          val first = winners.headOption.map(i => BigInt(1) << i).getOrElse(BigInt(0))
          val second = winners.drop(1).headOption.map(i => BigInt(1) << i).getOrElse(BigInt(0))
          assert(dut.io.rs_grant.toBigInt == grant, s"grant mask=$requests")
          assert(dut.io.fu_issue_flat.toBigInt == (second << depth | first), s"issue mask=$requests")
          val compression = (0 until depth).foldLeft(BigInt(0)) { (bits, i) =>
            val issuedBefore = winners.count(_ <= i)
            val shift = if (issuedBefore > 0 && winners.contains(i+1)) 2 else issuedBefore
            bits | (BigInt(shift) << (2*i))
          }
          assert(dut.io.rs_compress_flat.toBigInt == compression, s"compression mask=$requests")
        }
      }
    }
  }
}
