package ooo

import spinal.core._
import ooo.execute.MemRs

object GenerateMemRs extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new MemRs(cfg))
  println("[ooo] wrote gen/mem_rs_spinal.v")
}
