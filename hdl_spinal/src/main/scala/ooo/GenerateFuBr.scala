package ooo

import spinal.core._
import ooo.execute.FuBr

/** Emit `gen/fu_br_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateFuBr"
  */
object GenerateFuBr extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FuBr(cfg))
  println("[ooo] wrote gen/fu_br_spinal.v")
}
