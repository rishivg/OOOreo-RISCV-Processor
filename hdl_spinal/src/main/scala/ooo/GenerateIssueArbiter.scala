package ooo

import spinal.core._
import ooo.execute.IssueArbiter

/** Emit `gen/issue_arbiter_spinal.v` for module-swap co-validation (ROADMAP Phase 2).
  *   sbt "runMain ooo.GenerateIssueArbiter"
  *
  * Combinational -> no clock-domain config.
  */
object GenerateIssueArbiter extends App {
  val cfg = CpuConfig()
  SpinalConfig(targetDirectory = "gen").generateVerilog(new IssueArbiter(cfg))
  println("[ooo] wrote gen/issue_arbiter_spinal.v")
}
