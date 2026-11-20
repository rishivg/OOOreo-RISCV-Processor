ThisBuild / scalaVersion := "2.13.12"
ThisBuild / version      := "0.1.0"
ThisBuild / organization := "ooo"

val spinalVersion = "1.12.0"   // Verilator 5.x simulation support

lazy val root = (project in file("."))
  .settings(
    name := "ooo-spinal",
    fork := true,   // required by SpinalSim
    Compile / scalacOptions ++= Seq("-deprecation", "-Wunused:imports,privates,locals,params"),
    Test / scalacOptions += "-language:reflectiveCalls", // Anonymous IO bundles in SpinalSim tests
    libraryDependencies ++= Seq(
      "com.github.spinalhdl" %% "spinalhdl-core" % spinalVersion,
      "com.github.spinalhdl" %% "spinalhdl-lib"  % spinalVersion,
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion),
      "org.scalatest" %% "scalatest" % "3.2.18" % Test
    )
  )
