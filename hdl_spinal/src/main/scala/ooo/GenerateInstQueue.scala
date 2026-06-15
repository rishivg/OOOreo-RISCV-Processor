package ooo

import spinal.core._
import ooo.frontend.InstQueue

/** Emit `gen/inst_queue_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateInstQueue"   (DEPTH fixed to 8 -- the cpu override)
  */
object GenerateInstQueue extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new InstQueue(cfg, depth = 8))
  println("[ooo] wrote gen/inst_queue_spinal.v")
}
