package ooo

import spinal.core._
import ooo.frontend.If1Stage

/** Emit `gen/if1_stage_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateIf1Stage"
  */
object GenerateIf1Stage extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new If1Stage(cfg))
  println("[ooo] wrote gen/if1_stage_spinal.v")
}
