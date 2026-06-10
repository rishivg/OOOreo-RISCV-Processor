package issuequeue

import spinal.core._
import java.nio.file.{Files, Paths, StandardCopyOption}

/** Emit Verilog: `runMain issuequeue.Emit <width>` -> ../gen/IssueQueue_spinal_wN.v */
object Emit extends App {
  val width = if (args.nonEmpty) args(0).toInt else 2
  SpinalConfig(targetDirectory = "../gen").generateVerilog(new IssueQueue(IQParams(width = width)))
  val src = Paths.get("..", "gen", "IssueQueue.v")
  val dst = Paths.get("..", "gen", s"IssueQueue_spinal_w$width.v")
  Files.move(src, dst, StandardCopyOption.REPLACE_EXISTING)
  println(s"[spinal] wrote $dst")
}
