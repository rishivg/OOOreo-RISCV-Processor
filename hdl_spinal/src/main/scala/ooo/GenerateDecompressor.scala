package ooo

import spinal.core._
import ooo.frontend.Decompressor

/** Emit `gen/decompressor.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateDecompressor"
  *
  * Combinational-only, so no clock-domain config (no clk/reset ports).
  */
object GenerateDecompressor extends App {
  SpinalConfig(targetDirectory = "gen").generateVerilog(new Decompressor())
  println("[ooo] wrote gen/decompressor.v")
}
