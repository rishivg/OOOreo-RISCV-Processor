package ooo

import spinal.core._
import ooo.execute.FuAlu

/** Emit `gen/fu_alu_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateFuAlu"
  *
  * Named fu_alu_spinal (flattened CDB ports); the sim/swap_shims/fu_alu.sv shim
  * carries the cdb_itf SV interface and adapts it.
  */
object GenerateFuAlu extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FuAlu(cfg))
  println("[ooo] wrote gen/fu_alu_spinal.v")
}
