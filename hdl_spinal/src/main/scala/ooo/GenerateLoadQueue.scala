package ooo

import spinal.core._
import ooo.memory.LoadQueue

/** Emit `gen/load_queue_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateLoadQueue"
  */
object GenerateLoadQueue extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new LoadQueue(cfg))
  println("[ooo] wrote gen/load_queue_spinal.v")
}
