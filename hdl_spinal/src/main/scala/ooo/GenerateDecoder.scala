package ooo

import spinal.core._
import ooo.backend.decode.Decoder

/** Emit `gen/decoder.v` -- the standalone combinational decoder for module-swap
  * co-validation against the SV core (ROADMAP Phase 2, first leaf).
  *   sbt "runMain ooo.GenerateDecoder"
  *
  * Combinational-only, so no clock-domain config is needed (no clk/reset ports).
  */
object GenerateDecoder extends App {
  val cfg = CpuConfig()
  SpinalConfig(targetDirectory = "gen").generateVerilog(new Decoder(cfg))
  println("[ooo] wrote gen/decoder.v")
}
