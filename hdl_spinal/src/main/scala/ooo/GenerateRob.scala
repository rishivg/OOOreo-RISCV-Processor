package ooo

import spinal.core._
import ooo.rename.Rob

/** Emit `gen/rob_spinal.v` for module-swap co-validation (ROADMAP Phase 3).
  *   sbt "runMain ooo.GenerateRob"
  */
object GenerateRob extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Rob(cfg))
  println("[ooo] wrote gen/rob_spinal.v")
}
