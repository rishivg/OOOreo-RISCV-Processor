package ooo

import spinal.core._
import ooo.memory.Dcache

/** Emit `gen/dcache_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateDcache"
  */
object GenerateDcache extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Dcache(cfg))
  println("[ooo] wrote gen/dcache_spinal.v")
}
