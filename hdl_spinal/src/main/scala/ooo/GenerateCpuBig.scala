package ooo

import spinal.core._

/** Phase 5 (N-wide / config payoff) demonstration: emit gen/cpu.v from a DIFFERENT
  * CpuConfig -- the SAME SpinalHDL source as a generator. Bumps the flop-based
  * capacities (reservation stations, LSU queues, control buffer, branch predictors)
  * which are rvfi-invisible and do not touch the fu_div / bmem / rvfi boundary, so
  * the bigger core stays RVFI-clean (at a different IPC -- the proof of more
  * resources). Width (ifWidth/idWidth) and prf/rob depths are held (the latter feed
  * the still-SV fu_div's reg widths).
  *   sbt "runMain ooo.GenerateCpuBig"
  */
object GenerateCpuBig extends App {
  val cfg = CpuConfig(
    intrsDepth  = 32,
    intmrsDepth = 8,
    brrsDepth   = 8,
    memrsDepth  = 16,
    cbDepth     = 16,
    ldqDepth    = 16,
    stqDepth    = 16,
    stbDepth    = 8,
    phtDepth    = 2048,
    ubtbDepth   = 128,
    tageDepth   = 512,
    rasDepth    = 32
  )
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Cpu(cfg))
  println("[ooo] wrote gen/cpu.v (BIG config)")
}
