package ooo

import spinal.core._
import ooo.rename.Rrf

/** Emit `gen/rrf_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateRrf"
  */
object GenerateRrf extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Rrf(cfg))
  println("[ooo] wrote gen/rrf_spinal.v")
}
