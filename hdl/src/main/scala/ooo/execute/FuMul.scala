package ooo.execute

import spinal.core._
import ooo.{CpuConfig, FastAdd}

/** Two-stage signed/unsigned multiplier with queued inputs and output backpressure. */
class FuMul(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_mul")

  val MUL_LATENCY = 2   // Partial-product reduction, then 64-bit add and half-select.

  // mdopc_t (only the MUL family is handled here)
  def MD_MUL    = B"4'b0000"
  def MD_MULH   = B"4'b0001"
  def MD_MULHSU = B"4'b0010"
  def MD_MULHU  = B"4'b0011"

  val regW = cfg.intmRsRegW
  val cdbW = cfg.fuCdbRegW

  val io = new Bundle {
    val clk       = in  Bool()
    val rst       = in  Bool()
    val prv_valid = in  Bool()
    val prv_ready = out Bool()
    val nxt_valid = out Bool()
    val nxt_ready = in  Bool()
    val iss_in    = in  Bits (regW bits)
    val cdb_out   = out Bits (cdbW bits)
    // Multiplier launch observation for performance counters.
    val mul_start = out Bool()
  }
  noIoPrefix()

  // Sparse carry wiring reduces area in the column-compressed ASIC multiplier.
  private val carryTopology =
    if (cfg.mulDaddaReduction && cfg.mulCarryTopology == "auto") "brent-kung"
    else cfg.mulCarryTopology

  def tripleValue(value: Bits): Bits =
    FastAdd.bits(value.asUInt, (value |<< 1).asUInt, keepPrefix = cfg.mulDaddaReduction,
      prefixTopology = carryTopology, keepPropagate = cfg.mulKeepPropagate,
      orPropagate = cfg.mulOrCarry)

  def boothRow(select: Bits, sources: Seq[Bits], negative: Bool,
               shift: Int, isLow: Bool): Bits = {
    val highSelect = select & B(4 bits, default -> !isLow)
    val highNegative = negative && !isLow
    if (cfg.implementation.multiplier != "dsp-karatsuba") {
      highSelect.addAttribute("keep"); highNegative.addAttribute("keep")
    }
    val lowMagnitude = ooo.OhSel(select, sources)
    val highMagnitude = ooo.OhSel(highSelect, sources)
    val low = (Mux(negative, ~lowMagnitude, lowMagnitude) |<< shift)(31 downto 0)
    val high = (Mux(highNegative, ~highMagnitude, highMagnitude) |<< shift)(63 downto 32)
    high ## low
  }

  val domain = ClockDomain(
    clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  new ClockingArea(domain) {
    // skid buffer (DATA_T = intm_rs_reg_t)
    val EMPTY = B"3'b001"; val BUSY = B"3'b010"; val FULL = B"3'b100"
    val sbState     = RegInit(EMPTY)
    val reg_valid   = RegInit(False)            // skid nxt_valid
    val prvReady    = RegInit(False)
    val intm_rs_reg = Reg(Bits(regW bits))      // skid nxt_data
    val buffer      = Reg(Bits(regW bits))
    io.prv_ready := prvReady

    // mul_ready / nxt_valid are defined below; forward-declare
    val mul_ready = Bool()
    val nxt_valid = Bool()

    val accept   = io.prv_valid && prvReady
    val transmit = reg_valid && mul_ready

    val state_nxt = cloneOf(sbState)            // fully driven by the switch (has default)
    switch(sbState) {
      is(EMPTY) { state_nxt := EMPTY; when(accept) { state_nxt := BUSY } }
      is(BUSY)  { state_nxt := BUSY
                  when(accept && !transmit) { state_nxt := FULL }
                  .elsewhen(!accept && transmit) { state_nxt := EMPTY } }
      is(FULL)  { state_nxt := FULL; when(transmit) { state_nxt := BUSY } }
      default   { state_nxt := EMPTY }
    }
    sbState   := state_nxt
    prvReady  := state_nxt =/= FULL
    reg_valid := state_nxt =/= EMPTY

    val buf_we  = sbState === BUSY && accept && !transmit
    val data_we = (sbState === EMPTY && accept && !transmit) ||
                  (sbState === BUSY  && accept && transmit) ||
                  (sbState === FULL  && !accept && transmit)
    when(data_we) { intm_rs_reg := Mux(sbState === FULL, buffer, io.iss_in) }
    when(buf_we)  { buffer := io.iss_in }

    // fu_mul control
    val prv_reg_valid = RegNext(reg_valid) init(False)
    val prv_mul_ready = RegNext(mul_ready) init(False)
    val mulStart = (reg_valid && !prv_reg_valid) || (reg_valid && prv_mul_ready)
    io.mul_start := mulStart
    mul_ready := nxt_valid && io.nxt_ready

    // unpack intm_rs_reg (LSB-first: rs2[31:0] rs1[63:32] fu_op[67:64] rd_phy[73:68] rd_arch[78:74] rob_id[84:79])
    val rs2_value = IntmRsReg.rs2Value(intm_rs_reg)
    val rs1_value = IntmRsReg.rs1Value(intm_rs_reg)
    val fu_op     = IntmRsReg.fuOpcode(intm_rs_reg)
    val rd_phy    = IntmRsReg.rdPhy(intm_rs_reg, cfg)
    val rd_arch   = IntmRsReg.rdArch(intm_rs_reg, cfg)
    val rob_id    = IntmRsReg.robId(intm_rs_reg, cfg)

    val au = B"1'b0" ## rs1_value                  // {1'b0, rs1} 33b
    val bu = B"1'b0" ## rs2_value
    val as = rs1_value(31) ## rs1_value            // sign-extend 33b
    val bs = rs2_value(31) ## rs2_value

    val a = Bits(33 bits)
    val b = Bits(33 bits)
    val isLow = Bool()                              // MD_MUL -> low 32 product bits; MULH* -> high 32
    switch(fu_op) {
      is(MD_MUL)    { a := as; b := bs; isLow := True }
      is(MD_MULH)   { a := as; b := bs; isLow := False }
      is(MD_MULHSU) { a := as; b := bu; isLow := False }
      is(MD_MULHU)  { a := au; b := bu; isLow := False }
      default       { a := B(0, 33 bits); b := B(0, 33 bits); isLow := True }
    }
    // Radix-8 signed Booth recoding: eleven digits plus one correction row.
    // The shared triple uses 35 signed bits, enough for 3 * any 33-bit input.
    val a64 = a.asSInt.resize(64 bits).asBits
    val a35 = a.asSInt.resize(35 bits).asBits
    val triple35 = tripleValue(a35)
    val triple64 = triple35.asSInt.resize(64 bits).asBits
    val rows = collection.mutable.ArrayBuffer[Bits]()
    val corrections = Bits(64 bits); corrections := 0
    def bbit(index: Int): Bool = if (index < 0) False else if (index >= 33) b(32) else b(index)
    for (k <- 0 until 11) {
      val code = bbit(3*k+2).asBits ## bbit(3*k+1).asBits ## bbit(3*k).asBits ## bbit(3*k-1).asBits
      val magnitudeCode = Mux(code(3), ~code(2 downto 0), code(2 downto 0))
      val one = magnitudeCode === B(1,3 bits) || magnitudeCode === B(2,3 bits)
      val two = magnitudeCode === B(3,3 bits) || magnitudeCode === B(4,3 bits)
      val three = magnitudeCode === B(5,3 bits) || magnitudeCode === B(6,3 bits)
      val four = magnitudeCode === B(7,3 bits)
      val select = Bits(4 bits)
      select(0) := one; select(1) := two; select(2) := three; select(3) := four
      val negative = code(3) && magnitudeCode.orR
      // Suppress unused upper reduction activity during low-half MUL.
      val row = boothRow(select, Seq(a64, a64 |<< 1, triple64, a64 |<< 2),
        negative, 3*k, isLow)
      row.setName(s"partial_product_$k")
      rows += row
      corrections(3*k) := negative
    }
    corrections.setName("partial_product_corrections")
    rows += corrections

    val (sumComb, carComb) = if (cfg.mulDaddaReduction) {
      // A repeated sign above bit k contributes -sign * 2^k modulo 2^64.
      // Encode it as !sign at k and the constant -2^k instead of repeating it.
      val signCorrection = (0 until 10).map(k => -(BigInt(1) << (3*k + 35)))
        .sum & ((BigInt(1) << 64) - 1)
      val columns = (0 until 64).map { bit =>
        val terms = rows.zipWithIndex.flatMap { case (row, index) =>
          if (index == 11) {
            if (bit <= 30 && bit % 3 == 0) Seq(row(bit)) else Seq.empty[Bool]
          } else {
            val first = 3 * index
            val top = first + 35
            if (bit < first) Seq.empty[Bool]
            else if (!cfg.mulCompactSigns || bit < top) Seq(row(bit))
            else if (bit == top) Seq(!row(bit - 1))
            else Seq.empty[Bool]
          }
        }.toSeq
        if (cfg.mulCompactSigns && signCorrection.testBit(bit)) terms :+ True else terms
      }
      ooo.DaddaTree(columns)
    } else {
      def csa(x: Bits, y: Bits, z: Bits): (Bits, Bits) =
        (x ^ y ^ z, ((x & y) | (x & z) | (y & z)) |<< 1)
      var layer: Seq[Bits] = rows.toSeq
      while (layer.length > 2) {
        layer = layer.grouped(3).flatMap { g =>
          if (g.length == 3) { val (s, c) = csa(g(0), g(1), g(2)); Seq(s, c) } else g
        }.toSeq
      }
      (layer(0), layer(1))
    }

    sumComb.setName("reduction_sum")
    carComb.setName("reduction_carry")

    // pipeline (MUL_LATENCY stages), freezes on output_stall
    val output_stall = nxt_valid && !io.nxt_ready
    val isLowReg = Reg(Bool())
    val outcomeReg = Reg(Bits(32 bits))
    val valid_pipe = Vec.fill(MUL_LATENCY)(RegInit(False))
    val product64 = Bits(64 bits)
    if (cfg.implementation.multiplier == "dsp-karatsuba") {
      val native = new DspMulProduct
      native.io.clk := io.clk
      native.io.capture := mulStart && !output_stall
      native.io.a := a; native.io.b := b
      product64 := native.io.product
    } else {
      val sumReg = Reg(Bits(64 bits)); val carReg = Reg(Bits(64 bits))
      when(!output_stall && mulStart) {
        sumReg(31 downto 0) := sumComb(31 downto 0)
        carReg(31 downto 0) := carComb(31 downto 0)
        when(!isLow) {
          sumReg(63 downto 32) := sumComb(63 downto 32)
          carReg(63 downto 32) := carComb(63 downto 32)
        }
      }
      // Preserve both carry trees in column-reduction variants: collapsing
      // either tree into a ripple can erase the compressor's timing gain.
      product64 := FastAdd.bits(sumReg.asUInt, carReg.asUInt, keepPrefix = cfg.mulDaddaReduction,
        prefixTopology = carryTopology, keepPropagate = cfg.mulKeepPropagate,
        orPropagate = cfg.mulOrCarry)
    }
    when(!output_stall) {
      valid_pipe(0) := mulStart
      valid_pipe(1) := valid_pipe(0)
      when(mulStart) { isLowReg := isLow }
      when(valid_pipe(0)) {
        outcomeReg := Mux(isLowReg, product64(31 downto 0), product64(63 downto 32))
      }
    }
    val outcome = outcomeReg
    val complete = valid_pipe(MUL_LATENCY - 1)

    nxt_valid := reg_valid && complete && !mulStart
    io.nxt_valid := nxt_valid

    // pack cdb_out (MSB-first): rob_id rd_arch rd_phy rd_value rs1_dbg rs2_dbg
    // Source operands are retained only for RVFI.
    io.cdb_out := FuCdbReg.pack(rob_id, rd_arch, rd_phy, outcome,
                                if (cfg.rvfi) rs1_value else B(0, 32 bits),
                                if (cfg.rvfi) rs2_value else B(0, 32 bits))
  }
}
