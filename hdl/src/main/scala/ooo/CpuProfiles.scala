package ooo

/** Core presets; environment overrides are applied afterwards.
  * MCU profiles share branch/multiply operands and the ALU shifter.
  */
object CpuProfiles {
  val names = Seq("benchmark", "mcu", "mcu-efficient")
  def named(name: String): CpuConfig = name.trim.toLowerCase match {
    case "benchmark" => CpuConfig()
    case "mcu" => CpuConfig(zicsr=true, lowPower=true, mmio=true, rvfi=false,
      fpgaSharedShift=true, prfReadSharing=6)
    case "mcu-efficient" => named("mcu").copy(instQueueDepth=4, atomicCamDepth=2,
      csrCamDepth=1, maxReadBursts=7)
    case other => throw new IllegalArgumentException(
      s"Unknown CPU_PROFILE '$other'; choose ${names.mkString(", ")}")
  }
}
