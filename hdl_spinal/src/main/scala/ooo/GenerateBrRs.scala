package ooo

import spinal.core._
import ooo.execute.BrRs

object GenerateBrRs extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new BrRs(cfg))
  println("[ooo] wrote gen/br_rs_spinal.v")
}
