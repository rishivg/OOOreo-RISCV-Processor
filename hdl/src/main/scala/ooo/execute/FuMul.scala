package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Port-compatible SpinalHDL twin of `hdl/backend/execute/intm_rs/fu_mul.sv`.
  *
  * Parallel pipelined 33x33 signed multiplier feeding the CDB, fronted by a skid
  * buffer (the SV instantiates a generic skid_buffer; here it is inlined). MUL_LATENCY
  * register stages; the pipeline FREEZES on output_stall so a result held off by a
  * div CDB broadcast is not lost. Cycle-exact with the SV is required for IPC parity.
  *
  * Drops into intm_rs.sv by-name. Struct ports as packed Bits (first field = MSB):
  *   intm_rs_reg_t (iss_in, 85b): rob_id[6] rd_arch[5] rd_phy[6] fu_opcode[4] rs1_value[32] rs2_value[32]
  *   fu_cdb_reg_t  (cdb_out,113b): rob_id[6] rd_arch[5] rd_phy[6] rd_value[32] rs1_dbg[32] rs2_dbg[32]
  */
class FuMul(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_mul")

  val MUL_LATENCY = 1   // was 2: 2nd stage was pure delay (multiply is fully combinational into stage 0)

  // mdopc_t (only the MUL family is handled here)
  def MD_MUL    = B"4'b0000"
  def MD_MULH   = B"4'b0001"
  def MD_MULHSU = B"4'b0010"
  def MD_MULHU  = B"4'b0011"

  val regW = 6 + 5 + 6 + 4 + 32 + 32   // intm_rs_reg_t = 85
  val cdbW = 6 + 5 + 6 + 32 + 32 + 32  // fu_cdb_reg_t  = 113

  val io = new Bundle {
    val clk       = in  Bool()
    val rst       = in  Bool()
    val prv_valid = in  Bool()
    val prv_ready = out Bool()
    val nxt_valid = out Bool()
    val nxt_ready = in  Bool()
    val iss_in    = in  Bits (regW bits)
    val cdb_out   = out Bits (cdbW bits)
    // debug-only observability for hvl/common/perf_monitor.sv (taps fu_mul_i.mul_start);
    // not in the SV module's port list -> left unconnected by the SV instantiation.
    val mul_start = out Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(
    clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  new ClockingArea(domain) {
    // ===== skid buffer (DATA_T = intm_rs_reg_t) =====
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

    // ===== fu_mul control =====
    val prv_reg_valid = RegNext(reg_valid) init(False)
    val prv_mul_ready = RegNext(mul_ready) init(False)
    val mulStart = (reg_valid && !prv_reg_valid) || (reg_valid && prv_mul_ready)
    io.mul_start := mulStart
    mul_ready := nxt_valid && io.nxt_ready

    // unpack intm_rs_reg (LSB-first: rs2[31:0] rs1[63:32] fu_op[67:64] rd_phy[73:68] rd_arch[78:74] rob_id[84:79])
    val rs2_value = intm_rs_reg(31 downto 0)
    val rs1_value = intm_rs_reg(63 downto 32)
    val fu_op     = intm_rs_reg(67 downto 64)
    val rd_phy    = intm_rs_reg(73 downto 68)
    val rd_arch   = intm_rs_reg(78 downto 74)
    val rob_id    = intm_rs_reg(84 downto 79)

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
    val product_comb = (a.asSInt * b.asSInt).asBits   // 66b signed product
    // Select the 32-bit result BEFORE the pipe so the pipeline carries 32b not 66b
    // (and the unused product bits [65:64] + the dropped half prune). Bit-identical.
    val outcome_comb = Mux(isLow, product_comb(31 downto 0), product_comb(63 downto 32))

    // ===== pipeline (MUL_LATENCY stages), freezes on output_stall =====
    val output_stall = nxt_valid && !io.nxt_ready
    val outcome_pipe = Vec.fill(MUL_LATENCY)(Reg(Bits(32 bits)))
    val valid_pipe   = Vec.fill(MUL_LATENCY)(RegInit(False))
    when(!output_stall) {
      outcome_pipe(0) := outcome_comb
      valid_pipe(0)   := mulStart
      for (i <- 1 until MUL_LATENCY) {
        outcome_pipe(i) := outcome_pipe(i - 1)
        valid_pipe(i)   := valid_pipe(i - 1)
      }
    }
    val outcome = outcome_pipe(MUL_LATENCY - 1)
    val complete = valid_pipe(MUL_LATENCY - 1)

    nxt_valid := reg_valid && complete && !mulStart
    io.nxt_valid := nxt_valid

    // pack cdb_out (MSB-first): rob_id rd_arch rd_phy rd_value rs1_dbg rs2_dbg
    io.cdb_out := rob_id ## rd_arch ## rd_phy ## outcome ## rs1_value ## rs2_value
  }
}
