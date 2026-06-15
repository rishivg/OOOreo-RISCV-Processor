package ooo

import spinal.core._
import ooo.frontend.Icache

/** Emit `gen/icache_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateIcache"
  */
object GenerateIcache extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Icache(cfg))
  println("[ooo] wrote gen/icache_spinal.v")
}
