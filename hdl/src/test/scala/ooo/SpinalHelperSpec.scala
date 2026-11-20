package ooo

import java.io.PrintWriter
import java.nio.file.{Files, Path}
import org.scalatest.funsuite.AnyFunSuite
import scala.sys.process._
import spinal.core._
import ooo.execute._

/** Independent legacy wire formats, not an encode/decode round trip alone. */
case class PayloadSource(cfg: CpuConfig) extends Bundle {
  val rob_id = Bits(cfg.robIdx bits)
  val rs1_phy, rs2_phy, rd_phy = Bits(cfg.prfIdx bits)
  val rs1_valid, rs2_valid = Bool()
  val rd_arch = Bits(cfg.arfIdx bits)
  val op1_sel, op2_sel = Bits(1 bit)
  val imm, pc, predict_target = Bits(32 bits)
  val fu_opcode = Bits(4 bits)
  val predict_taken, is_compressed = Bool()
  val unrelated = Bits(3 bits) // Real decoded uops also contain unused fields.
}

class PayloadFormatCheck(cfg: CpuConfig) extends Component {
  val io = new Bundle {
    val source = in(PayloadSource(cfg))
    val equal = out Bool()
  }
  val s = io.source
  val layouts = Seq(RsEntryLayout.int(cfg), RsEntryLayout.intm(cfg),
    RsEntryLayout.mem(cfg), RsEntryLayout.br(cfg))
  val expected = Seq(
    s.rob_id ## s.rs1_phy ## s.rs1_valid ## s.rs2_phy ## s.rs2_valid ## s.rd_phy ##
      s.rd_arch ## s.op1_sel ## s.op2_sel ## s.imm ## s.fu_opcode,
    s.rob_id ## s.rs1_phy ## s.rs1_valid ## s.rs2_phy ## s.rs2_valid ## s.rd_phy ##
      s.rd_arch ## s.fu_opcode,
    s.rob_id ## s.rs1_phy ## s.rs1_valid ## s.rs2_phy ## s.rs2_valid ## s.imm ## s.fu_opcode,
    s.rob_id ## s.rs1_phy ## s.rs1_valid ## s.rs2_phy ## s.rs2_valid ## s.rd_phy ##
      s.rd_arch ## s.imm ## s.pc ## s.fu_opcode ## s.is_compressed ## s.predict_taken ## s.predict_target)
  val packed = layouts.map(_.pack(s))
  val checks = collection.mutable.ArrayBuffer[Bool]()
  checks ++= packed.zip(expected).map { case (actual, reference) => actual === reference }
  for ((layout, payload) <- layouts.zip(packed)) {
    checks += (payload(layout.rs1PhyLsb, cfg.prfIdx bits) === s.rs1_phy)
    checks += (payload(layout.rs2PhyLsb, cfg.prfIdx bits) === s.rs2_phy)
    checks += (payload(layout.rs1ValidLsb) === s.rs1_valid)
    checks += (payload(layout.rs2ValidLsb) === s.rs2_valid)
  }
  val decoded = IntRsEntry.fromBits(packed.head, cfg)
  val sourceFields = s.elements.toMap
  checks ++= decoded.elements.map { case (name, value) => value.asBits === sourceFields(name).asBits }
  checks ++= Seq(
    IntmRsEntry.rdArch(packed(1), cfg) === s.rd_arch,
    IntmRsEntry.rdPhy(packed(1), cfg) === s.rd_phy,
    IntmRsEntry.rs1Phy(packed(1), cfg) === s.rs1_phy,
    IntmRsEntry.rs2Phy(packed(1), cfg) === s.rs2_phy,
    IntmRsEntry.robId(packed(1), cfg) === s.rob_id,
    MemRsEntry.rs1Phy(packed(2), cfg) === s.rs1_phy,
    MemRsEntry.rs2Phy(packed(2), cfg) === s.rs2_phy,
    MemRsEntry.robId(packed(2), cfg) === s.rob_id,
    BrRsEntry.rdArch(packed(3), cfg) === s.rd_arch,
    BrRsEntry.rdPhy(packed(3), cfg) === s.rd_phy,
    BrRsEntry.rs1Phy(packed(3), cfg) === s.rs1_phy,
    BrRsEntry.rs2Phy(packed(3), cfg) === s.rs2_phy,
    BrRsEntry.robId(packed(3), cfg) === s.rob_id)
  io.equal := Vec(checks).asBits.andR
}

class PriorityMaskReference(depth: Int) extends Component {
  val io = new Bundle {
    val requests = in Bits(depth bits)
    val any = out Bool()
    val selected = out Bits(depth bits)
  }
  var seen: Bool = False
  for (i <- 0 until depth) {
    io.selected(i) := io.requests(i) && !seen
    seen = seen || io.requests(i)
  }
  io.any := seen
}

class SelectionCheck(depth: Int) extends Component {
  val io = new Bundle {
    val requests = in Bits(depth bits)
    val data = in Bits(depth * 7 bits)
    val equal = out Bool()
  }
  val data = io.data.subdivideIn(7 bits)
  val (any, mask, selected) = PrioSelect(io.requests.asBools, data.toSeq)
  val reference = new PriorityMaskReference(depth)
  reference.io.requests := io.requests
  var referenceData: Bits = data.last
  for (i <- (0 until depth).reverse) referenceData = Mux(io.requests(i), data(i), referenceData)
  val maskedReference = data.zipWithIndex.map { case (value, i) =>
    Mux(io.requests(i), value, B(0, 7 bits))
  }.reduce(_ | _)
  val prefixes = RsUtil.exclusivePrefixOr(io.requests.asBools)
  val prefixChecks = (0 until depth).map { i =>
    val expected = if (i == 0) False else io.requests(i - 1 downto 0).orR
    prefixes(i) === expected
  }
  io.equal := (any === reference.io.any) &&
    (Vec(mask).asBits === reference.io.selected) &&
    (RsUtil.firstOneHot(io.requests.asBools).asBits === reference.io.selected) &&
    Vec(prefixChecks).asBits.andR &&
    (selected === referenceData) && (OhSel(io.requests, data.toSeq) === maskedReference)
}

class LoadResultFormatCheck extends Component {
  val io = new Bundle {
    val data = in Bits(32 bits)
    val operation = in Bits(4 bits)
    val offset = in UInt(2 bits)
    val equal = out Bool()
  }
  val byte = io.data.subdivideIn(8 bits)(io.offset)
  val half = io.data.subdivideIn(16 bits)(io.offset(1).asUInt)
  val expected = Bits(32 bits)
  expected := 0
  switch(io.operation) {
    is(0) { expected := byte.asSInt.resize(32).asBits }
    is(1) { expected := half.asSInt.resize(32).asBits }
    is(2) { expected := io.data }
    is(4) { expected := byte.asUInt.resize(32).asBits }
    is(5) { expected := half.asUInt.resize(32).asBits }
  }
  io.equal := memory.LoadResultFormat(io.data, io.operation, io.offset) === expected
}

class SpinalHelperSpec extends AnyFunSuite {
  private def prove(name: String)(component: => Component): Unit = {
    val directory = Path.of("target", "helper-checks", name).toAbsolutePath
    Files.createDirectories(directory)
    val report = SpinalConfig(targetDirectory = directory.toString).generateVerilog(component)
    val rtl = report.generatedSourcesPaths.toSeq.map(path => s"\"$path\"").mkString(" ")
    val script = s"read_verilog $rtl; prep -top ${report.toplevel.definitionName} -flatten; " +
      "sat -verify -prove io_equal 1 -show-inputs"
    val log = new PrintWriter(directory.resolve("proof.log").toFile)
    val status = try Process(Seq("yosys", "-Q", "-T", "-p", script)).!(ProcessLogger(log.println(_)))
                 finally log.close()
    assert(status == 0, s"Unrestricted SAT comparison failed; see $directory/proof.log")
  }

  for ((prfDepth, robDepth) <- Seq((64, 16), (96, 32), (160, 64))) {
    test(s"reservation payload ABI and decoding: PRF=$prfDepth ROB=$robDepth") {
      val cfg = CpuConfig(prfDepth = prfDepth, robDepth = robDepth)
      cfg.validate()
      prove(s"payload-$prfDepth-$robDepth")(new PayloadFormatCheck(cfg))
    }
  }

  for (depth <- Seq(1, 2, 3, 4, 5, 8, 17, 33, 64)) {
    test(s"priority and masked selection for every request/data value: depth=$depth") {
      prove(s"selection-$depth")(new SelectionCheck(depth))
    }
  }

  test("load formatting for every data word, opcode and byte offset") {
    prove("load-format")(new LoadResultFormatCheck)
  }

  test("priority selection rejects an empty request set") {
    intercept[IllegalArgumentException](PrioSelect(Seq.empty, Seq.empty))
  }

  test("packed fields and selectors reject incompatible widths during elaboration") {
    prove("invalid-parameters")(new Component {
      val io = new Bundle { val equal = out Bool() }
      val cfg = CpuConfig()
      val layout = RsEntryLayout.int(cfg)
      val source = PayloadSource(cfg)
      val wideSource = PayloadSource(cfg.copy(prfDepth = 96))
      val incomplete = new Bundle { val fu_opcode = Bits(4 bits) }
      intercept[IllegalArgumentException](layout.pack(incomplete))
      intercept[IllegalArgumentException](layout.pack(wideSource))
      intercept[IllegalArgumentException](layout.read(Bits(layout.width - 1 bits), "imm"))
      intercept[IllegalArgumentException](layout.assignTo(Bits(layout.width bits), source))
      intercept[IllegalArgumentException](OhSel(Bits(2 bits), Seq(Bits(4 bits), Bits(5 bits))))
      intercept[IllegalArgumentException](PrioSelect(Seq(Bool(), Bool()), Seq(Bits(4 bits), Bits(5 bits))))
      io.equal := True
    })
  }
}
