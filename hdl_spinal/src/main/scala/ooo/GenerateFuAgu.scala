package ooo

import spinal.core._
import ooo.memory.FuAgu

/** Emit `gen/fu_agu.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateFuAgu"
  *
  * Clocked: explicit clk/rst ports via FuAgu's own ClockDomain (active-high sync).
  */
object GenerateFuAgu extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FuAgu(cfg))
  println("[ooo] wrote gen/fu_agu.v")
}
