package ooo

import spinal.core._
import ooo.rename.Rat

/** Emit `gen/rat_spinal.v` for module-swap co-validation (ROADMAP Phase 3).
  *   sbt "runMain ooo.GenerateRat"
  */
object GenerateRat extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Rat(cfg))
  println("[ooo] wrote gen/rat_spinal.v")
}
