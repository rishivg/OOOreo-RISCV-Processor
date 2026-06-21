package ooo.execute

import spinal.core._
import ooo.CpuConfig
import ooo.backend.decode.DecodeConsts._

/** SpinalHDL port of `hdl/backend/execute/int_rs/fu_alu.sv` -- the single-cycle
  * ALU FU. Two register stages: stage 1 (fu_alu_reg_out + fu_alu_valid) feeds the
  * fast-bypass net and computes alu_out; stage 2 (cdb_reg + cdb_valid) drives the CDB.
  *
  * The SV module's `cdb` port is the `cdb_itf.fu` SystemVerilog interface, which
  * SpinalHDL cannot emit. So this module is named `fu_alu_spinal` and presents the
  * CDB as FLATTENED ports; a thin SV shim (sim/swap_shims/fu_alu.sv) named `fu_alu`
  * carries the real interface port and adapts it, keeping hdl/ pristine.
  *
  * Struct ports as packed Bits (first field = MSB):
  *   fu_alu_reg_t (in, 119b): rob_id[6] rd_arch[5] rd_phy[6] fu_opcode[4] op1_sel[1]
  *                            op2_sel[1] imm[32] rs1_value[32] rs2_value[32]
  *   bypass_network_t (out, 39b): valid[1] rd_phy[6] rd_value[32]
  */
class FuAlu(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_alu_spinal")

  val regW    = cfg.fuAluRegW   // fu_alu_reg_t (119)
  val bypassW = cfg.bypassNetW  // bypass_network_t (39)

  val io = new Bundle {
    val clk          = in  Bool()
    val rst          = in  Bool()
    val int_rs_valid = in  Bool()
    val fu_alu_ready = out Bool()
    val fu_alu_reg_in = in  Bits (regW bits)
    val bypass        = out Bits (bypassW bits)
    // flattened cdb_itf.fu (all outputs)
    val cdb_rob_id        = out Bits (6 bits)
    val cdb_rd_phy        = out Bits (6 bits)
    val cdb_rd_arch       = out Bits (5 bits)
    val cdb_rd_value      = out Bits (32 bits)
    val cdb_rs1_value_dbg = out Bits (32 bits)
    val cdb_rs2_value_dbg = out Bits (32 bits)
    val cdb_valid         = out Bool()
  }
  noIoPrefix()

  // ALU is single-cycle and always ready (result on the fast-bypass net)
  io.fu_alu_ready := True
  val cdb_ready = True

  val domain = ClockDomain(
    clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  new ClockingArea(domain) {
    // ===== stage 1 register =====
    val fu_alu_valid   = RegInit(False)
    when(io.fu_alu_ready) { fu_alu_valid := io.int_rs_valid }
    val fu_alu_reg_out = Reg(Bits(regW bits))
    when(io.int_rs_valid && io.fu_alu_ready) { fu_alu_reg_out := io.fu_alu_reg_in }

    // unpack fu_alu_reg_out (LSB-first):
    //   rs2[31:0] rs1[63:32] imm[95:64] op2_sel[96] op1_sel[97] fu_opcode[101:98]
    //   rd_phy[107:102] rd_arch[112:108] rob_id[118:113]
    val rs2_value = fu_alu_reg_out(31 downto 0)
    val rs1_value = fu_alu_reg_out(63 downto 32)
    val imm       = fu_alu_reg_out(95 downto 64)
    val op2_sel   = fu_alu_reg_out(96)
    val op1_sel   = fu_alu_reg_out(97)
    val fu_opcode = fu_alu_reg_out(101 downto 98)
    val rd_phy    = fu_alu_reg_out(107 downto 102)
    val rd_arch   = fu_alu_reg_out(112 downto 108)
    val rob_id    = fu_alu_reg_out(118 downto 113)

    val a = Mux(op1_sel === OP1_RS1(0), rs1_value, B(0, 32 bits))   // OP1_ZERO -> 0
    val b = Mux(op2_sel === OP2_RS2(0), rs2_value, imm)            // OP2_IMM -> imm
    val sh = b(4 downto 0).asUInt

    val alu_out = Bits(32 bits)
    switch(fu_opcode) {
      is(ALU_ADD)  { alu_out := (a.asUInt + b.asUInt).asBits }
      is(ALU_SLL)  { alu_out := a |<< sh }
      is(ALU_SRA)  { alu_out := (a.asSInt >> sh).asBits }
      is(ALU_SUB)  { alu_out := (a.asUInt - b.asUInt).asBits }
      is(ALU_XOR)  { alu_out := a ^ b }
      is(ALU_SRL)  { alu_out := a |>> sh }
      is(ALU_OR)   { alu_out := a | b }
      is(ALU_AND)  { alu_out := a & b }
      is(ALU_SLT)  { alu_out := B(0, 31 bits) ## (a.asSInt < b.asSInt) }
      is(ALU_SLTU) { alu_out := B(0, 31 bits) ## (a.asUInt < b.asUInt) }
      default      { alu_out := B(0, 32 bits) }
    }

    // bypass_network_t (MSB-first: valid rd_phy rd_value)
    io.bypass := fu_alu_valid.asBits ## rd_phy ## alu_out

    // ===== stage 2: CDB register =====
    val cdb_valid = RegInit(False)
    when(cdb_ready) { cdb_valid := fu_alu_valid }
    io.cdb_valid := cdb_valid

    val r_rob_id  = Reg(Bits(6 bits))  init(0)
    val r_rd_arch = Reg(Bits(5 bits))  init(0)
    val r_rd_phy  = Reg(Bits(6 bits))  init(0)
    val r_rd_val  = Reg(Bits(32 bits)) init(0)
    val r_rs1_dbg = Reg(Bits(32 bits)) init(0)
    val r_rs2_dbg = Reg(Bits(32 bits)) init(0)
    when(fu_alu_valid && cdb_ready) {
      r_rob_id  := rob_id
      r_rd_arch := rd_arch
      r_rd_phy  := rd_phy
      r_rd_val  := alu_out
      r_rs1_dbg := rs1_value
      r_rs2_dbg := rs2_value
    }
    io.cdb_rob_id        := r_rob_id
    io.cdb_rd_arch       := r_rd_arch
    io.cdb_rd_phy        := r_rd_phy
    io.cdb_rd_value      := r_rd_val
    io.cdb_rs1_value_dbg := r_rs1_dbg
    io.cdb_rs2_value_dbg := r_rs2_dbg
  }
}
