package issuequeue

import circt.stage.ChiselStage
import java.nio.file.{Files, Paths}

/** Emit SystemVerilog: `runMain issuequeue.Emit <width>` */
object Emit extends App {
  val width = if (args.nonEmpty) args(0).toInt else 2
  val sv = ChiselStage.emitSystemVerilog(
    new IssueQueue(IQParams(width = width)),
    firtoolOpts = Array(
      "-disable-all-randomization",
      "-strip-debug-info",
      "-lowering-options=disallowLocalVariables,disallowPackedArrays"
    )
  )
  val outDir = Paths.get("..", "gen"); Files.createDirectories(outDir)
  val out = outDir.resolve(s"IssueQueue_chisel_w$width.sv")
  Files.write(out, sv.getBytes)
  println(s"[chisel] wrote $out (${sv.linesIterator.size} lines)")
}
