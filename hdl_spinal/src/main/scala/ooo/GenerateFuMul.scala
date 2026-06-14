package ooo

import spinal.core._
import ooo.execute.FuMul

/** Emit `gen/fu_mul.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateFuMul"
  */
object GenerateFuMul extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FuMul(cfg))
  println("[ooo] wrote gen/fu_mul.v")
}
