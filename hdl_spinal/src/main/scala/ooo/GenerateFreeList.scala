package ooo

import spinal.core._
import ooo.rename.FreeList

/** Emit `gen/free_list_spinal.v` for module-swap co-validation (ROADMAP Phase 3).
  *   sbt "runMain ooo.GenerateFreeList"
  */
object GenerateFreeList extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FreeList(cfg))
  println("[ooo] wrote gen/free_list_spinal.v")
}
