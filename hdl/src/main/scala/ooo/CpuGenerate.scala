package ooo

import spinal.core._
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.{Files, Paths}
import java.security.MessageDigest

object CpuGenerate {
  def emit(cfg: CpuConfig): Unit = {
    cfg.validate()
    val destination = sys.env.getOrElse("RTL_OUT", "gen")
    val spinalCfg = SpinalConfig(
      targetDirectory = destination,
      defaultConfigForClockDomains = ClockDomainConfig(
        resetActiveLevel = HIGH,
        resetKind        = SYNC
      )
    )

    spinalCfg.generateVerilog(new Cpu(cfg))
    val rtl = Paths.get(destination, "cpu.v")
    val hash = MessageDigest.getInstance("SHA-256")
      .digest(Files.readAllBytes(rtl)).map(b => f"${b & 0xff}%02x").mkString
    val configJson = cfg.productElementNames.zip(cfg.productIterator).map {
      case (key, value: CpuImplementation) => s"    \"$key\": ${value.json}"
      case (key, value: String) => s"    \"$key\": \"$value\""
      case (key, values: Seq[_]) => s"    \"$key\": ${values.mkString("[",", ","]")}"
      case (key, value) => s"    \"$key\": $value"
    }.mkString(",\n")
    val configuration = s"""{
  "schema_version": 1,
  "rtl_sha256": "$hash",
  "config": {
$configJson
  }
}
"""
    Files.write(Paths.get(destination, "configuration.json"), configuration.getBytes(UTF_8))
    println(s"[ooo] wrote $rtl and configuration.json")
  }
}
