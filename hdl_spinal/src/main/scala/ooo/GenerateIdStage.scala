package ooo

import spinal.core._
import ooo.backend.IdStage

/** Emit `gen/id_stage_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateIdStage"
  */
object GenerateIdStage extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new IdStage(cfg))
  println("[ooo] wrote gen/id_stage_spinal.v")
}
