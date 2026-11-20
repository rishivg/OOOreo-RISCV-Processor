package ooo

import java.nio.file.{Files, Path}
import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._

class StableSimulationDut extends Component {
  val io = new Bundle {
    val input = in Bits(4 bits)
    val output = out Bits(4 bits)
  }
  io.output := io.input
}

class TestSimulationSpec extends AnyFunSuite {
  test("simulation configs retain caller options and omit commit-only RTL banners") {
    val compiled = TestSimulation.config.withConfig(SpinalConfig(
      headerWithRepoHash = true, oneFilePerComponent = true)).compile(new StableSimulationDut)
    assert(compiled.simConfig._spinalConfig.oneFilePerComponent)
    for (path <- compiled.report.generatedSourcesPaths) {
      assert(!Files.readString(Path.of(path)).contains("// Git hash"),
        s"Commit-only comments invalidate the native cache: $path")
    }
    compiled.doSim { dut =>
      for (value <- 0 until 16) {
        dut.io.input #= value
        sleep(1)
        assert(dut.io.output.toInt == value)
      }
    }
  }
}
