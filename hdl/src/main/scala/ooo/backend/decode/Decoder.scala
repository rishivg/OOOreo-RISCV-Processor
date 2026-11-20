package ooo.backend.decode

import spinal.core._
import ooo.CpuConfig

/** Instruction encodings and internal operation codes. */
object DecodeConsts {
  // Opcodes
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
  def OP_SYSTEM = B"7'b1110011"  // Zicsr CSR ops + ecall/ebreak/mret/wfi (gated by cfg.zicsr)
  def OP_MISC   = B"7'b0001111"  // FENCE / FENCE.I (gated by cfg.zicsr)

  // Decode-time exception causes (mcause, 4 bits)
  val EXC_ILLEGAL = 2; val EXC_BREAK = 3; val EXC_ECALL_M = 11

  // AtomicUnit operation codes (4 bits)
  val AMO_LR = 0; val AMO_SC = 1; val AMO_SWAP = 2; val AMO_ADD = 3
  val AMO_XOR = 4; val AMO_AND = 5; val AMO_OR = 6
  val AMO_MIN = 7; val AMO_MAX = 8; val AMO_MINU = 9; val AMO_MAXU = 10

  // Arithmetic funct3
  def F3_ADD  = B"3'b000"
  def F3_SLT  = B"3'b010"
  def F3_SLTU = B"3'b011"
  def F3_SR   = B"3'b101"

  // Operand selects
  def OP1_RS1  = B"1'b0"
  def OP1_ZERO = B"1'b1"
  def OP2_RS2  = B"1'b0"
  def OP2_IMM  = B"1'b1"

  // Reservation-station types
  def RS_INT  = B"2'b00"
  def RS_INTM = B"2'b01"
  def RS_BR   = B"2'b10"
  def RS_MEM  = B"2'b11"

  // Functional-unit types
  def FU_ALU = B"2'b00"
  def FU_MDU = B"2'b01"
  def FU_BR  = B"2'b10"
  def FU_AGU = B"2'b11"

  // ALU operations
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

  // Branch operations
  def BR_JAL   = B"4'b1000"
  def BR_JALR  = B"4'b1001"
  def BR_AUIPC = B"4'b1111"
}

/** Decode RV32IMC/A instructions and optional machine-mode operations. */
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
    // Optional CSR operations serialize at the ROB head through the memory RS.
    // csr_ctrl = inst[31:12] = {csr_addr[12], uimm/rs1[5], funct3[3]}.
    val is_csr    = if (cfg.zicsr) out Bool() else null
    val csr_ctrl  = if (cfg.zicsr) out Bits (20 bits) else null
    // Exceptions occupy a ROB entry and trap at the head without executing.
    val exc_valid = if (cfg.zicsr) out Bool() else null
    val exc_cause = if (cfg.zicsr) out Bits (4 bits) else null
  }
  noIoPrefix()

  val opcode = io.inst(6 downto 0)
  val funct3 = io.inst(14 downto 12)
  val funct7 = io.inst(31 downto 25)
  val funct5 = io.inst(31 downto 27)   // AMO op selector

  def isOneOf(ops: Bits*): Bool = ops.map(opcode === _).reduce(_ || _)

  // Atomics read rs1 (base) and rs2 (operand), and write rd.
  val amoEn = if (cfg.aExt) (opcode === OP_AMO) else False
  // CSR immediate forms carry uimm5 in csr_ctrl and do not read rs1.
  val csrEn    = if (cfg.zicsr) (opcode === OP_SYSTEM) && (funct3 =/= 0) else null
  val csrRdRs1 = if (cfg.zicsr) csrEn && !funct3(2) else null

  // Register fields
  def rdEn0  = isOneOf(OP_LUI, OP_AUIPC, OP_IMM, OP_REG, OP_JAL, OP_JALR, OP_LOAD) || amoEn
  def rs1En0 = isOneOf(OP_IMM, OP_REG, OP_JALR, OP_BR, OP_LOAD, OP_STORE) || amoEn
  io.rd_en := (if (cfg.zicsr) rdEn0 || csrEn else rdEn0)
  io.rd_arch  := Mux(io.rd_en, io.inst(11 downto 7), B(0, cfg.arfIdx bits))
  io.rs1_arch := Mux(if (cfg.zicsr) rs1En0 || csrRdRs1 else rs1En0,
                     io.inst(19 downto 15), B(0, cfg.arfIdx bits))
  io.rs2_arch := Mux(isOneOf(OP_REG, OP_BR, OP_STORE) || amoEn,
                     io.inst(24 downto 20), B(0, cfg.arfIdx bits))
  io.is_store := opcode === OP_STORE
  io.is_atomic := amoEn
  io.amo_op := B(0, 4 bits)
  // Optional CSR and exception outputs
  val isCsr    = if (cfg.zicsr) { val b = Bool(); b := False; b } else null
  val csrCtrl  = if (cfg.zicsr) { val b = Bits(20 bits); b := 0; b } else null
  val excValid = if (cfg.zicsr) { val b = Bool(); b := False; b } else null
  val excCause = if (cfg.zicsr) { val b = Bits(4 bits); b := 0; b } else null
  if (cfg.zicsr) { io.is_csr := isCsr; io.csr_ctrl := csrCtrl; io.exc_valid := excValid; io.exc_cause := excCause }

  // Routing and operand defaults
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
    default {
      // Unknown opcodes trap with Zicsr; otherwise they retain ALU defaults.
      // SYSTEM and MISC-MEM are handled below.
      if (cfg.zicsr) { excValid := True; excCause := B(EXC_ILLEGAL, 4 bits) }
    }
  }

  // CSR and serialized system operations use the memory RS. MEM_LB prevents
  // the AGU from raising alignment faults for arbitrary rs1 values.
  if (cfg.zicsr) {
    when(opcode === OP_MISC) {
      excValid := False
      when(funct3 === 0 || funct3 === 1) {
        // Internal serial-op marker: 0 = FENCE, 0x00100 = FENCE.I.
        isCsr := True; csrCtrl := Mux(funct3 === 1,B(0x100,20 bits),B(0,20 bits))
        io.rs_type := RS_MEM; io.fu_type := FU_AGU; io.fu_opcode := B"4'b0000"
      }.otherwise { excValid := True; excCause := B(EXC_ILLEGAL,4 bits) }
    }
    when(opcode === OP_SYSTEM) {
      excValid := False
      csrCtrl  := io.inst(31 downto 12)
      when(funct3 =/= 0) {                               // csrrw/s/c + immediate forms
        isCsr := True
        io.rs_type := RS_MEM; io.fu_type := FU_AGU; io.fu_opcode := B"4'b0000"
      } otherwise {
        switch(io.inst(31 downto 20)) {
          is(B"12'h000") { excValid := True; excCause := B(EXC_ECALL_M, 4 bits) }   // ecall (M-mode)
          is(B"12'h001") { excValid := True; excCause := B(EXC_BREAK, 4 bits) }     // ebreak
          is(B"12'h302") {                                                                  // mret
            isCsr := True
            io.rs_type := RS_MEM; io.fu_type := FU_AGU; io.fu_opcode := B"4'b0000"
          }
          is(B"12'h105") {
            when(io.inst =/= B"32'h10500073") { excValid := True; excCause := B(EXC_ILLEGAL,4 bits) }
            .otherwise { if (cfg.lowPower) {
                isCsr := True
                io.rs_type := RS_MEM; io.fu_type := FU_AGU; io.fu_opcode := B"4'b0000"
              }
            }
          }
          default        { excValid := True; excCause := B(EXC_ILLEGAL, 4 bits) }
        }
      }
    }
  }

  // Atomics use AGU word-load addressing. AtomicUnit executes at the ROB head
  // and returns the result on the LSU CDB lane.
  if (cfg.aExt) {
    when(opcode === OP_AMO) {
      io.rs_type   := RS_MEM
      io.fu_type   := FU_AGU
      io.fu_opcode := B"4'b0010"        // MEM_LW: word addr + mask=1111
      if (cfg.zicsr) excValid := False   // owned here, not an illegal opcode
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

  if (cfg.zicsr) {
    val badLoad = opcode === OP_LOAD && !(funct3 === 0 || funct3 === 1 || funct3 === 2 || funct3 === 4 || funct3 === 5)
    val badStore = opcode === OP_STORE && !(funct3 === 0 || funct3 === 1 || funct3 === 2)
    val badBranch = opcode === OP_BR && (funct3 === 2 || funct3 === 3)
    val badJalr = opcode === OP_JALR && funct3 =/= 0
    val badShift = opcode === OP_IMM && ((funct3 === 1 && funct7 =/= 0) ||
      (funct3 === 5 && funct7 =/= 0 && funct7 =/= 32))
    val badReg = opcode === OP_REG && !(funct7 === 0 || funct7 === 1 ||
      (funct7 === 32 && (funct3 === 0 || funct3 === 5)))
    val badSystem = opcode === OP_SYSTEM && (funct3 === 4 || (funct3 === 0 &&
      io.inst =/= B(0x00000073,32 bits) && io.inst =/= B(0x00100073,32 bits) &&
      io.inst =/= B(0x30200073,32 bits) && io.inst =/= B(0x10500073,32 bits)))
    val badAtomic = if (cfg.aExt) opcode === OP_AMO && (funct3 =/= 2 ||
      !(funct5 === 0 || funct5 === 1 || funct5 === 2 || funct5 === 3 || funct5 === 4 ||
        funct5 === 8 || funct5 === 12 || funct5 === 16 || funct5 === 20 || funct5 === 24 || funct5 === 28) ||
      (funct5 === 2 && io.inst(24 downto 20) =/= 0)) else False
    when(badLoad || badStore || badBranch || badJalr || badShift || badReg || badSystem || badAtomic) {
      excValid := True; excCause := B(EXC_ILLEGAL,4 bits)
    }
  }

  // Sign-extended immediates
  val iImm = io.inst(31 downto 20).asSInt.resize(32).asBits
  val sImm = (io.inst(31 downto 25) ## io.inst(11 downto 7)).asSInt.resize(32).asBits
  val bImm = (io.inst(31) ## io.inst(7) ## io.inst(30 downto 25) ##
              io.inst(11 downto 8) ## B"1'b0").asSInt.resize(32).asBits
  val uImm = io.inst(31 downto 12) ## B(0, 12 bits)
  val jImm = (io.inst(31) ## io.inst(19 downto 12) ## io.inst(20) ##
              io.inst(30 downto 21) ## B"1'b0").asSInt.resize(32).asBits

  // Unlisted opcodes do not consume the immediate.
  io.imm := B(0, 32 bits)
  switch(opcode) {
    is(OP_JALR, OP_IMM, OP_LOAD) { io.imm := iImm }
    is(OP_STORE)                 { io.imm := sImm }
    is(OP_BR)                    { io.imm := bImm }
    is(OP_LUI, OP_AUIPC)         { io.imm := uImm }
    is(OP_JAL)                   { io.imm := jImm }
  }
}
