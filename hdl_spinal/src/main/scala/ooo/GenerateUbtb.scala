package ooo

import spinal.core._
import ooo.frontend.bpred.Ubtb

/** Emit `gen/ubtb_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateUbtb"
  */
object GenerateUbtb extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Ubtb(cfg))
  println("[ooo] wrote gen/ubtb_spinal.v")
}
