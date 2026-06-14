package ooo

import spinal.core._
import ooo.execute.ControlBuffer

object GenerateControlBuffer extends App {
  val cfg = CpuConfig()
  SpinalConfig(
    targetDirectory = "gen",
    defaultConfigForClockDomains = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  ).generateVerilog(new ControlBuffer(cfg))
  println("[ooo] wrote gen/control_buffer_spinal.v")
}
