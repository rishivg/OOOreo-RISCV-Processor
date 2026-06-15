package ooo

import spinal.core._
import ooo.execute.BranchTop

/** Emit `gen/branch_top_spinal.v` for module-swap co-validation (Phase 3 cluster).
  *   sbt "runMain ooo.GenerateBranchTop"
  */
object GenerateBranchTop extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new BranchTop(cfg))
  println("[ooo] wrote gen/branch_top_spinal.v")
}
