ThisBuild / scalaVersion := "2.13.12"
ThisBuild / version      := "0.1.0"
ThisBuild / organization := "ooo.spike"

val spinalVersion = "1.12.0"

lazy val root = (project in file("."))
  .settings(
    name := "renamerob-spinal",
    fork := true,   // required by SpinalSim (Verilator backend) under sbt
    libraryDependencies ++= Seq(
      "com.github.spinalhdl" %% "spinalhdl-core" % spinalVersion,
      "com.github.spinalhdl" %% "spinalhdl-lib"  % spinalVersion,
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion)
    )
  )
