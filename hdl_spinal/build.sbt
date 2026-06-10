ThisBuild / scalaVersion := "2.13.12"
ThisBuild / version      := "0.1.0"
ThisBuild / organization := "ooo"

val spinalVersion = "1.12.0"   // 1.12+ required for Verilator 5.x sim (see spike notes)

lazy val root = (project in file("."))
  .settings(
    name := "ooo-spinal",
    fork := true,   // required by SpinalSim
    libraryDependencies ++= Seq(
      "com.github.spinalhdl" %% "spinalhdl-core" % spinalVersion,
      "com.github.spinalhdl" %% "spinalhdl-lib"  % spinalVersion,
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion),
      "org.scalatest" %% "scalatest" % "3.2.18" % Test
    )
  )
