package ooo

import spinal.core._
import ooo.backend.DsStage

/** Emit `gen/ds_stage_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateDsStage"
  */
object GenerateDsStage extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new DsStage(cfg))
  println("[ooo] wrote gen/ds_stage_spinal.v")
}
