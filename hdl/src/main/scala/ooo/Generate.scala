package ooo

/** Generate the configured core and its configuration manifest. */
object Generate extends App {
  CpuGenerate.emit(CpuConfig.fromEnv())
}
