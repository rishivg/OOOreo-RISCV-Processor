package ooo

import spinal.core._
import ooo.memory.DmemArbiter

/** Emit `gen/dmem_arbiter_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateDmemArbiter"
  */
object GenerateDmemArbiter extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new DmemArbiter(cfg))
  println("[ooo] wrote gen/dmem_arbiter_spinal.v")
}
