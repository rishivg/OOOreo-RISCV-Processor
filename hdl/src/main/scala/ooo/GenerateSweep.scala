package ooo

import spinal.core._

/** Capacity right-sizing sweep generator. Emits gen/cpu.v for the full imca core
  * (cExt=true, aExt=true) with selected flop-array depths overridden from ENV vars
  * (env propagates to the forked sbt JVM; sys-props do not). Unset -> current
  * default. Used to find each structure's IPC knee for the area/power right-sizing
  * pass without editing Config.scala per run:
  *
  *   PRF_DEPTH=48 RAS_DEPTH=8 CPU_GEN=ooo.GenerateSweep PROGS=coremark_imc sim/build_spinal.sh
  */
object GenerateSweep extends App {
  def envI(name: String, dflt: Int): Int = sys.env.get(name).map(_.trim.toInt).getOrElse(dflt)
  val base = CpuConfig()
  val cfg = base.copy(
    robDepth    = envI("ROB_DEPTH",    base.robDepth),
    prfDepth    = envI("PRF_DEPTH",    base.prfDepth),
    intrsDepth  = envI("INTRS_DEPTH",  base.intrsDepth),
    intmrsDepth = envI("INTMRS_DEPTH", base.intmrsDepth),
    brrsDepth   = envI("BRRS_DEPTH",   base.brrsDepth),
    memrsDepth  = envI("MEMRS_DEPTH",  base.memrsDepth),
    cbDepth     = envI("CB_DEPTH",     base.cbDepth),
    ldqDepth    = envI("LDQ_DEPTH",    base.ldqDepth),
    stqDepth    = envI("STQ_DEPTH",    base.stqDepth),
    stbDepth    = envI("STB_DEPTH",    base.stbDepth),
    rasDepth    = envI("RAS_DEPTH",    base.rasDepth)
  )
  println(s"[sweep] rob=${cfg.robDepth} prf=${cfg.prfDepth} intrs=${cfg.intrsDepth} " +
          s"memrs=${cfg.memrsDepth} cb=${cfg.cbDepth} ldq=${cfg.ldqDepth} stq=${cfg.stqDepth} " +
          s"stb=${cfg.stbDepth} ras=${cfg.rasDepth}")
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new Cpu(cfg))
  println("[sweep] wrote gen/cpu.v")
}
