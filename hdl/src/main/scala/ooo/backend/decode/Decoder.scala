package ooo.backend.decode

import spinal.core._
import ooo.CpuConfig

/** Encoding constants -- the SpinalHDL port of the relevant enums in
  * `pkg/types.sv` (packages rv32i_types + uop_types). Values are EXACT so the
  * generated decoder is bit-for-bit interchangeable with hdl/backend/decode/decoder.sv.
  */
object DecodeConsts {
  // ---- opcodes (rv32i_types) ----
  def OP_LUI   = B"7'b0110111"
  def OP_AUIPC = B"7'b0010111"
  def OP_JAL   = B"7'b1101111"
  def OP_JALR  = B"7'b1100111"
  def OP_BR    = B"7'b1100011"
  def OP_LOAD  = B"7'b0000011"
  def OP_STORE = B"7'b0100011"
  def OP_IMM   = B"7'b0010011"
  def OP_REG   = B"7'b0110011"
  def OP_AMO   = B"7'b0101111"   // RV32A (gated by cfg.aExt)

  // ---- AMO op codes (amo_op, 4 bits) -- AtomicUnit decodes these ----
  val AMO_LR = 0; val AMO_SC = 1; val AMO_SWAP = 2; val AMO_ADD = 3
  val AMO_XOR = 4; val AMO_AND = 5; val AMO_OR = 6
  val AMO_MIN = 7; val AMO_MAX = 8; val AMO_MINU = 9; val AMO_MAXU = 10

  // ---- arith funct3 (rv32i_types) ----
  def F3_ADD  = B"3'b000"
  def F3_SLL  = B"3'b001"
  def F3_SLT  = B"3'b010"
  def F3_SLTU = B"3'b011"
  def F3_XOR  = B"3'b100"
  def F3_SR   = B"3'b101"
  def F3_OR   = B"3'b110"
  def F3_AND  = B"3'b111"

  // ---- op1/op2 select (uop_types) ----
  def OP1_RS1  = B"1'b0"
  def OP1_ZERO = B"1'b1"
  def OP2_RS2  = B"1'b0"
  def OP2_IMM  = B"1'b1"

  // ---- RS type (uop_types) ----
  def RS_INT  = B"2'b00"
  def RS_INTM = B"2'b01"
  def RS_BR   = B"2'b10"
  def RS_MEM  = B"2'b11"

  // ---- FU type (uop_types) ----
  def FU_ALU = B"2'b00"
  def FU_MDU = B"2'b01"
  def FU_BR  = B"2'b10"
  def FU_AGU = B"2'b11"

  // ---- ALU opcode (uop_types) ----
  def ALU_ADD  = B"4'b0000"
  def ALU_SLL  = B"4'b0001"
  def ALU_SRA  = B"4'b0010"
  def ALU_SUB  = B"4'b0011"
  def ALU_XOR  = B"4'b0100"
  def ALU_SRL  = B"4'b0101"
  def ALU_OR   = B"4'b0110"
  def ALU_AND  = B"4'b0111"
  def ALU_SLT  = B"4'b1000"
  def ALU_SLTU = B"4'b1001"

  // ---- branch opcode (uop_types) ----
  def BR_JAL   = B"4'b1000"
  def BR_JALR  = B"4'b1001"
  def BR_AUIPC = B"4'b1111"
}

/** Port-compatible SpinalHDL twin of `hdl/backend/decode/decoder.sv`.
  *
  * Pure combinational RV32IM decoder (inst -> uop fields). The module name is
  * forced to `decoder` with bare IO names (`noIoPrefix`), and every port name +
  * width matches the SV module so it drops straight into the SV core: id_stage.sv
  * instantiates `decoder decoder_i(...)` by-name (ROADMAP module-swap co-validation).
  *
  * Combinational-only => SpinalHDL emits no clk/reset ports.
  */
class Decoder(cfg: CpuConfig = CpuConfig()) extends Component {
  import DecodeConsts._

  setDefinitionName("decoder")

  val io = new Bundle {
    val inst      = in  Bits (32 bits)

    val rs_type   = out Bits (2 bits)
    val fu_type   = out Bits (2 bits)
    val fu_opcode = out Bits (4 bits)
    val op1_sel   = out Bits (1 bits)
    val op2_sel   = out Bits (1 bits)
    val imm       = out Bits (32 bits)
    val rd_arch   = out Bits (cfg.arfIdx bits)   // ARF_IDX = 5
    val rd_en     = out Bool ()
    val rs1_arch  = out Bits (cfg.arfIdx bits)
    val rs2_arch  = out Bits (cfg.arfIdx bits)
    val is_store  = out Bool ()
    val is_atomic = out Bool ()          // RV32A: this uop is an AMO/LR/SC (aExt only)
    val amo_op    = out Bits (4 bits)    // RV32A: AMO_* code (aExt only)
  }
  noIoPrefix()

  val opcode = io.inst(6 downto 0)
  val funct3 = io.inst(14 downto 12)
  val funct7 = io.inst(31 downto 25)
  val funct5 = io.inst(31 downto 27)   // AMO op selector

  // membership helper mirroring SV `opcode inside {...}`
  def isOneOf(ops: Bits*): Bool = ops.map(opcode === _).reduce(_ || _)

  // RV32A: an AMO/LR/SC reads rs1 (base) + rs2 (operand) and writes rd. Constant
  // False when aExt is off, so the rd_en/rs1/rs2 muxes below reduce bit-identically.
  val amoEn = if (cfg.aExt) (opcode === OP_AMO) else False

  // ---- register fields (concurrent, mirror the SV continuous assigns) ----
  io.rd_en := isOneOf(OP_LUI, OP_AUIPC, OP_IMM, OP_REG, OP_JAL, OP_JALR, OP_LOAD) || amoEn
  io.rd_arch  := Mux(io.rd_en, io.inst(11 downto 7), B(0, cfg.arfIdx bits))
  io.rs1_arch := Mux(isOneOf(OP_IMM, OP_REG, OP_JALR, OP_BR, OP_LOAD, OP_STORE) || amoEn,
                     io.inst(19 downto 15), B(0, cfg.arfIdx bits))
  io.rs2_arch := Mux(isOneOf(OP_REG, OP_BR, OP_STORE) || amoEn,
                     io.inst(24 downto 20), B(0, cfg.arfIdx bits))
  io.is_store := opcode === OP_STORE
  io.is_atomic := amoEn
  io.amo_op := B(0, 4 bits)

  // ---- rs_type / fu_type / fu_opcode / op selects ----
  io.rs_type   := RS_INT
  io.fu_type   := FU_ALU
  io.fu_opcode := B(0, 4 bits)
  io.op1_sel   := OP1_RS1
  io.op2_sel   := OP2_RS2

  switch(opcode) {
    is(OP_LUI) {
      io.rs_type := RS_INT; io.fu_type := FU_ALU
      io.op1_sel := OP1_ZERO; io.op2_sel := OP2_IMM
      io.fu_opcode := ALU_ADD
    }
    is(OP_AUIPC) {
      io.rs_type := RS_BR; io.fu_type := FU_BR
      io.fu_opcode := BR_AUIPC
    }
    is(OP_JAL) {
      io.rs_type := RS_BR; io.fu_type := FU_BR
      io.fu_opcode := BR_JAL
    }
    is(OP_JALR) {
      io.rs_type := RS_BR; io.fu_type := FU_BR
      io.fu_opcode := BR_JALR
    }
    is(OP_BR) {
      io.rs_type := RS_BR; io.fu_type := FU_BR
      io.fu_opcode := B"1'b0" ## funct3
    }
    is(OP_LOAD) {
      io.rs_type := RS_MEM; io.fu_type := FU_AGU
      io.fu_opcode := B"1'b0" ## funct3
    }
    is(OP_STORE) {
      io.rs_type := RS_MEM; io.fu_type := FU_AGU
      io.fu_opcode := B"1'b1" ## funct3
    }
    is(OP_IMM) {
      io.rs_type := RS_INT; io.fu_type := FU_ALU
      io.op1_sel := OP1_RS1; io.op2_sel := OP2_IMM
      switch(funct3) {
        is(F3_SLT)  { io.fu_opcode := ALU_SLT }
        is(F3_SLTU) { io.fu_opcode := ALU_SLTU }
        is(F3_SR)   { io.fu_opcode := Mux(funct7(5), ALU_SRA, ALU_SRL) }
        default     { io.fu_opcode := B"1'b0" ## funct3 }
      }
    }
    is(OP_REG) {
      io.op1_sel := OP1_RS1; io.op2_sel := OP2_RS2
      when(funct7(0)) {
        io.rs_type := RS_INTM; io.fu_type := FU_MDU
        io.fu_opcode := B"1'b0" ## funct3
      } otherwise {
        io.rs_type := RS_INT; io.fu_type := FU_ALU
        switch(funct3) {
          is(F3_SLT)  { io.fu_opcode := ALU_SLT }
          is(F3_SLTU) { io.fu_opcode := ALU_SLTU }
          is(F3_SR)   { io.fu_opcode := Mux(funct7(5), ALU_SRA, ALU_SRL) }
          is(F3_ADD)  { io.fu_opcode := Mux(funct7(5), ALU_SUB, ALU_ADD) }
          default     { io.fu_opcode := B"1'b0" ## funct3 }
        }
      }
    }
    default { /* ignore -- keep defaults */ }
  }

  // RV32A atomics (opcode 0x2F). Routed to the mem RS / AGU like a word load (so the
  // AGU computes eff-addr = rs1+0 with a word mask); the AtomicUnit performs the RMW
  // non-speculatively at the ROB head and injects the result on the LSU CDB lane.
  if (cfg.aExt) {
    when(opcode === OP_AMO) {
      io.rs_type   := RS_MEM
      io.fu_type   := FU_AGU
      io.fu_opcode := B"4'b0010"        // MEM_LW: word addr + mask=1111
      switch(funct5) {
        is(B"5'b00010") { io.amo_op := B(AMO_LR,   4 bits) }
        is(B"5'b00011") { io.amo_op := B(AMO_SC,   4 bits) }
        is(B"5'b00001") { io.amo_op := B(AMO_SWAP, 4 bits) }
        is(B"5'b00000") { io.amo_op := B(AMO_ADD,  4 bits) }
        is(B"5'b00100") { io.amo_op := B(AMO_XOR,  4 bits) }
        is(B"5'b01100") { io.amo_op := B(AMO_AND,  4 bits) }
        is(B"5'b01000") { io.amo_op := B(AMO_OR,   4 bits) }
        is(B"5'b10000") { io.amo_op := B(AMO_MIN,  4 bits) }
        is(B"5'b10100") { io.amo_op := B(AMO_MAX,  4 bits) }
        is(B"5'b11000") { io.amo_op := B(AMO_MINU, 4 bits) }
        is(B"5'b11100") { io.amo_op := B(AMO_MAXU, 4 bits) }
        default         { io.amo_op := B(AMO_ADD,  4 bits) }
      }
    }
  }

  // ---- immediates (sign-extend mirrors the SV {{N{inst[31]}}, ...} concats) ----
  val iImm = io.inst(31 downto 20).asSInt.resize(32).asBits
  val sImm = (io.inst(31 downto 25) ## io.inst(11 downto 7)).asSInt.resize(32).asBits
  val bImm = (io.inst(31) ## io.inst(7) ## io.inst(30 downto 25) ##
              io.inst(11 downto 8) ## B"1'b0").asSInt.resize(32).asBits
  val uImm = io.inst(31 downto 12) ## B(0, 12 bits)
  val jImm = (io.inst(31) ## io.inst(19 downto 12) ## io.inst(20) ##
              io.inst(30 downto 21) ## B"1'b0").asSInt.resize(32).asBits

  // SV default is 'x; downstream never reads imm for those opcodes (op2_sel=RS2),
  // so 0 is functionally equivalent and synthesizable.
  io.imm := B(0, 32 bits)
  switch(opcode) {
    is(OP_JALR, OP_IMM, OP_LOAD) { io.imm := iImm }
    is(OP_STORE)                 { io.imm := sImm }
    is(OP_BR)                    { io.imm := bImm }
    is(OP_LUI, OP_AUIPC)         { io.imm := uImm }
    is(OP_JAL)                   { io.imm := jImm }
    // unlisted opcodes keep the pre-assigned 0 (SV uses 'x; imm unused there)
  }
}
