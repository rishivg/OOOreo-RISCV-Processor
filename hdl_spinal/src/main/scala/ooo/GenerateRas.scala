package ooo

import spinal.core._
import ooo.frontend.bpred.Ras

/** Emit `gen/ras_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateRas"
  */
object GenerateRas extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Ras(cfg))
  println("[ooo] wrote gen/ras_spinal.v")
}
