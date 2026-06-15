package ooo

import spinal.core._
import ooo.frontend.FetchAlign

/** Emit `gen/fetch_align.v` (incl. the inlined decompressor) for module-swap
  * co-validation (ROADMAP Phase 2).  sbt "runMain ooo.GenerateFetchAlign"
  */
object GenerateFetchAlign extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new FetchAlign(cfg))
  println("[ooo] wrote gen/fetch_align.v")
}
