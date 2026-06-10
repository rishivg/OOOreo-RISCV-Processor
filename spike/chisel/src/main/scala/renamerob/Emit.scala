package renamerob

import circt.stage.ChiselStage
import java.nio.file.{Files, Paths}

/** Emit synthesizable SystemVerilog: `runMain renamerob.Emit <width>` */
object Emit extends App {
  val width = if (args.nonEmpty) args(0).toInt else 2
  val p = RRParams(width = width)

  val sv = ChiselStage.emitSystemVerilog(
    new RenameRob(p),
    firtoolOpts = Array(
      "-disable-all-randomization",
      "-strip-debug-info",
      // emit plain-Verilog-friendly output so Yosys' Verilog-2005 frontend reads
      // it without an sv2v pass (hoist always-block locals, no packed arrays)
      "-lowering-options=disallowLocalVariables,disallowPackedArrays"
    )
  )

  val outDir = Paths.get("..", "gen")
  Files.createDirectories(outDir)
  val out = outDir.resolve(s"RenameRob_chisel_w$width.sv")
  Files.write(out, sv.getBytes)
  println(s"[chisel] wrote $out (${sv.linesIterator.size} lines)")
}
