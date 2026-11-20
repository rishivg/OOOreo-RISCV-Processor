package ooo

/** Target-specific bindings, independent of architectural resource sizes. */
case class CpuImplementation(
  target: String = "asic",
  multiplier: String = "booth",
  divider: String = "iterative",
  memory: String = "macro",
  clockGate: String = "inferred"
) {
  def isFpga: Boolean = target == "fpga-xilinx7"
  def validate(): Unit = {
    require(Set("asic", "fpga-xilinx7")(target), s"Unsupported target $target")
    require(Set("booth", "dsp-karatsuba")(multiplier), s"Unsupported multiplier $multiplier")
    require(Set("iterative", "mock")(divider), s"Unsupported divider $divider")
    require(Set("macro", "native")(memory), s"Unsupported memory $memory")
    require(Set("inferred", "bufgctrl")(clockGate), s"Unsupported clock gate $clockGate")
    require(isFpga || (multiplier == "booth" && clockGate == "inferred"),
      "DSP and BUFGCTRL implementations require an FPGA target")
  }
  def json: String = s"""{"target":"$target","multiplier":"$multiplier","divider":"$divider","memory":"$memory","clockGate":"$clockGate"}"""
}

object CpuImplementation {
  def named(name: String): CpuImplementation = name.trim.toLowerCase match {
    case "asic" => CpuImplementation()
    case "fpga" | "fpga-xilinx7" =>
      CpuImplementation("fpga-xilinx7", "dsp-karatsuba", "iterative", "native", "bufgctrl")
    case other => throw new IllegalArgumentException(s"Unsupported CPU_TARGET $other")
  }
}
