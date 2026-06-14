package ooo

import spinal.core._
import ooo.execute.IntmRs

object GenerateIntmRs extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new IntmRs(cfg))
  println("[ooo] wrote gen/intm_rs_spinal.v")
}
