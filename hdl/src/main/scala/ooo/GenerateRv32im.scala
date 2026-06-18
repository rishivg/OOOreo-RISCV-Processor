package ooo

import spinal.core._

/** Emit gen/cpu.v with the C extension DISABLED (rv32im) -- proves the `cExt` toggle
  * elaborates a leaner RV32I-aligned front-end (no Decompressor, fixed 32-bit fetch
  * stride, no span/carry). Validate with coremark_im ONLY (an rv32im core cannot
  * decode compressed instructions):
  *   CPU_GEN=ooo.GenerateRv32im PROGS=coremark_im sim/build_spinal.sh
  */
object GenerateRv32im extends App {
  val cfg = CpuConfig(cExt = false)
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Cpu(cfg))
  println("[ooo] wrote gen/cpu.v (rv32im, cExt=false)")
}
