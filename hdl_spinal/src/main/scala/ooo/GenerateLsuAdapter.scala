package ooo

import spinal.core._
import ooo.memory.LsuAdapter

/** Emit `gen/lsu_adapter_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateLsuAdapter"
  */
object GenerateLsuAdapter extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new LsuAdapter(cfg))
  println("[ooo] wrote gen/lsu_adapter_spinal.v")
}
