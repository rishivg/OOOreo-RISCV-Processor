package ooo

import spinal.core._

/** Emit gen/cpu.v in the pure RV32IMC configuration (cExt=true, aExt=false) -- the
  * imc-optimal netlist. The A-extension is dead weight for CoreMark (zero atomics),
  * so dropping it removes the AtomicUnit (~5.2 Kbit of rob-id-indexed capture flops),
  * the ROB atomic-flush/go logic, and the 11-way AMO decode -- all cleanly `if(cfg.aExt)`
  * guarded, so IPC is bit-identical to the aExt=true core on coremark_imc.
  *
  * This is the config used for the imc PPA comparison (matches the pre-A-ext baseline's
  * feature set). The default `ooo.Generate` keeps aExt=true for the full-featured core.
  * Validate:  CPU_GEN=ooo.GenerateImc PROGS=coremark_imc sim/build_spinal.sh
  */
object GenerateImc extends App {
  val cfg = CpuConfig(cExt = true, aExt = false)
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Cpu(cfg))
  println("[ooo] wrote gen/cpu.v (rv32imc, aExt=false)")
}
