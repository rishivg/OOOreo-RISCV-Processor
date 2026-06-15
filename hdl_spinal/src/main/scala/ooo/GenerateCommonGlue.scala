package ooo

import spinal.core._
import ooo.common.{CacheAdapter, BmemArbiter}

/** Emit gen/cache_adapter_spinal.v and gen/bmem_arbiter_spinal.v.
  *   sbt "runMain ooo.GenerateCacheAdapter" / "runMain ooo.GenerateBmemArbiter"
  */
object GenerateCacheAdapter extends App {
  SpinalConfig(targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new CacheAdapter(CpuConfig()))
  println("[ooo] wrote gen/cache_adapter_spinal.v")
}
object GenerateBmemArbiter extends App {
  SpinalConfig(targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new BmemArbiter(CpuConfig()))
  println("[ooo] wrote gen/bmem_arbiter_spinal.v")
}
