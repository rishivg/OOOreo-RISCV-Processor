package ooo

import spinal.core._
import ooo.memory.HitDetection

/** Emit `gen/hit_detection_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateHitDetection"
  */
object GenerateHitDetection extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new HitDetection(cfg))
  println("[ooo] wrote gen/hit_detection_spinal.v")
}
