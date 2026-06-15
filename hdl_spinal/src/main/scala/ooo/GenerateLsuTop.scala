package ooo

import spinal.core._
import ooo.memory.LsuTop

/** Emit `gen/lsu_top_spinal.v` for module-swap co-validation (Phase 3 cluster).
  *   sbt "runMain ooo.GenerateLsuTop"
  */
object GenerateLsuTop extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new LsuTop(cfg))
  println("[ooo] wrote gen/lsu_top_spinal.v")
}
