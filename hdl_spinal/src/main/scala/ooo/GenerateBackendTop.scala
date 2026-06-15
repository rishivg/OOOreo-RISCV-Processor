package ooo

import spinal.core._
import ooo.backend.BackendTop

/** Emit `gen/backend_top_spinal.v` for module-swap co-validation (Phase 3 cluster).
  *   sbt "runMain ooo.GenerateBackendTop"
  */
object GenerateBackendTop extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new BackendTop(cfg))
  println("[ooo] wrote gen/backend_top_spinal.v")
}
