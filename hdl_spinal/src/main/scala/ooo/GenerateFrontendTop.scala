package ooo

import spinal.core._
import ooo.frontend.FrontendTop

/** Emit `gen/frontend_top_spinal.v` for module-swap co-validation (Phase 3 cluster).
  *   sbt "runMain ooo.GenerateFrontendTop"
  */
object GenerateFrontendTop extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FrontendTop(cfg))
  println("[ooo] wrote gen/frontend_top_spinal.v")
}
