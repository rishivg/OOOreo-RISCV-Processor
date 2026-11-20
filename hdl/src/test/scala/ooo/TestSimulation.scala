package ooo

import java.nio.file.Files
import scala.jdk.CollectionConverters._
import spinal.core.{Component, SpinalReport}
import spinal.core.sim.{SimCompiled, SpinalSimConfig}

/** Keep the linked simulator and diagnostics; discard large compiler-only headers. */
object TestSimulation {
  def config: SpinalSimConfig = {
    val cacheEntries = sys.env.get("TEST_SIM_CACHE_ENTRIES").map(_.toInt).getOrElse(256)
    require(cacheEntries > 0, "TEST_SIM_CACHE_ENTRIES must be positive")
    new TestConfig().maxCacheEntries(cacheEntries)
  }

  private class TestConfig extends SpinalSimConfig {
    private def retainSimulator[T <: Component](compiled: SimCompiled[T]): SimCompiled[T] = {
      if (!sys.env.get("TEST_KEEP_BUILD").contains("1")) {
        val paths = Files.walk(compiled.compiledPath.toPath)
        try paths.iterator().asScala.filter(_.toString.endsWith(".gch")).foreach(Files.delete(_))
        finally paths.close()
      }
      compiled
    }

    override def compile[T <: Component](rtl: => T): SimCompiled[T] = {
      // Verilator's cache hashes comments too. A commit-only banner change must
      // not rebuild an unchanged DUT; product RTL keeps its normal provenance.
      _spinalConfig = _spinalConfig.copy(headerWithRepoHash = false)
      retainSimulator(super.compile(rtl))
    }

    override def compile[T <: Component](report: SpinalReport[T]): SimCompiled[T] =
      retainSimulator(super.compile(report))
  }
}
