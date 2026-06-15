package ooo

import spinal.core._
import ooo.execute.Prf

/** Emit `gen/prf_spinal.v` for module-swap co-validation (ROADMAP Phase 3).
  *   sbt "runMain ooo.GeneratePrf"
  */
object GeneratePrf extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Prf(cfg))
  println("[ooo] wrote gen/prf_spinal.v")
}
