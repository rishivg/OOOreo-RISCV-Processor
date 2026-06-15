package ooo

import spinal.core._
import ooo.frontend.bpred.Tage

/** Emit `gen/tage_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateTage"
  */
object GenerateTage extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Tage(cfg))
  println("[ooo] wrote gen/tage_spinal.v")
}
