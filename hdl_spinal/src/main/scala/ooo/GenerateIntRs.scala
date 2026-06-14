package ooo

import spinal.core._
import ooo.execute.IntRs

/** Emit `gen/int_rs_spinal.v` (+ sub-modules) for module-swap co-validation.
  *   sbt "runMain ooo.GenerateIntRs"
  */
object GenerateIntRs extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new IntRs(cfg))
  println("[ooo] wrote gen/int_rs_spinal.v")
}
