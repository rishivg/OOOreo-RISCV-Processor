package ooo

import spinal.core._
import ooo.frontend.IcacheCtrl

/** Emit `gen/icache_ctrl_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateIcacheCtrl"
  */
object GenerateIcacheCtrl extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new IcacheCtrl(cfg))
  println("[ooo] wrote gen/icache_ctrl_spinal.v")
}
