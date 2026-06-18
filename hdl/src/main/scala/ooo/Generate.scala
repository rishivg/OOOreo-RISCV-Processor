package ooo

import spinal.core._

/** Emit `gen/cpu.v` for the existing Verilator + RVFI + CoreMark harness.
  *   sbt "runMain ooo.Generate"
  *
  * Reset is active-high to match the SV `rst`. NOTE (ROADMAP Phase 0): SpinalHDL
  * names the reset port `reset`; the SV harness expects `rst`. Resolve by either
  * a thin Verilog wrapper or renaming at generation before wiring into sim.
  */
object Generate extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(
      resetActiveLevel = HIGH,
      resetKind        = SYNC
    )
  ).generateVerilog(new Cpu(cfg))
  println("[ooo] wrote gen/cpu.v")
}
