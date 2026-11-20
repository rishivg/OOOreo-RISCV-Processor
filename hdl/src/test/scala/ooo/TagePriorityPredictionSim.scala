package ooo

import spinal.core.sim._
import ooo.frontend.bpred.TagePriorityPrediction
import org.scalatest.funsuite.AnyFunSuite

class TagePriorityPredictionSim extends AnyFunSuite {
  for (decoded <- Seq(false, true)) test(s"all three-table combinations, decoded=$decoded") {
    TestSimulation.config.compile(new TagePriorityPrediction(CpuProfiles.named("mcu"), decoded)).doSim { d =>
      for (bits <- 0 until (1 << 17)) {
        val hits = bits & 7
        val counters = (bits >> 3) & 511
        val usefulness = (bits >> 12) & 7
        val base = (bits & (1 << 15)) != 0
        val useAlt = (bits & (1 << 16)) != 0
        d.io.hits #= hits
        if (decoded) {
          d.io.directions #= (0 until 3).filter(t => ((counters >> (3 * t)) & 7) < 4)
            .map(t => 1 << t).sum
          d.io.weak_flags #= (0 until 3).filter { t =>
            val counter = (counters >> (3 * t)) & 7
            (usefulness & (1 << t)) == 0 && (counter == 0 || counter == 7)
          }.map(t => 1 << t).sum
        } else {
          d.io.counters #= counters; d.io.usefulness #= usefulness
        }
        d.io.base #= base; d.io.use_alt #= useAlt
        sleep(1)
        val providers = (0 until 3).filter(t => (hits & (1 << t)) != 0).reverse
        def prediction(t: Int): Boolean = ((counters >> (3 * t)) & 7) < 4
        val expected = if (providers.isEmpty) base else {
          val provider = providers.head
          val counter = (counters >> (3 * provider)) & 7
          val weak = (usefulness & (1 << provider)) == 0 && (counter == 0 || counter == 7)
          if (weak && useAlt) providers.drop(1).headOption.map(prediction).getOrElse(base)
          else prediction(provider)
        }
        assert(d.io.prediction.toBoolean == expected, s"predictor inputs=$bits")
      }
    }
  }
}
