package ooo

import spinal.core._
import ooo.memory.StoreQueue

/** Emit `gen/store_queue_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateStoreQueue"
  */
object GenerateStoreQueue extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new StoreQueue(cfg))
  println("[ooo] wrote gen/store_queue_spinal.v")
}
