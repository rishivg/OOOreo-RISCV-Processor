package ooo

import spinal.core._
import ooo.memory.DcacheCtrl

/** Emit `gen/dcache_ctrl.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateDcacheCtrl"
  */
object GenerateDcacheCtrl extends App {
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new DcacheCtrl())
  println("[ooo] wrote gen/dcache_ctrl.v")
}
