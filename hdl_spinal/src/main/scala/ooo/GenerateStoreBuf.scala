package ooo

import spinal.core._
import ooo.memory.StoreBuf

/** Emit `gen/store_buf_spinal.v` for module-swap co-validation (Phase 3).
  *   sbt "runMain ooo.GenerateStoreBuf"
  */
object GenerateStoreBuf extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new StoreBuf(cfg))
  println("[ooo] wrote gen/store_buf_spinal.v")
}
