package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Branch comparison, target generation, link result, and CDB output. */
class FuBr(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_br_spinal")

  // bropc_t
  def BR_BEQ  = B"4'b0000"; def BR_BNE  = B"4'b0001"
  def BR_BLT  = B"4'b0100"; def BR_BGE  = B"4'b0101"
  def BR_BLTU = B"4'b0110"; def BR_BGEU = B"4'b0111"
  def BR_JAL  = B"4'b1000"; def BR_JALR = B"4'b1001"; def BR_AUIPC = B"4'b1111"

  val regW = cfg.fuBrRegW
  val RIDX = cfg.robIdx
  val AIDX = cfg.arfIdx
  val PIDX = cfg.prfIdx

  val io = new Bundle {
    val clk         = in  Bool()
    val rst         = in  Bool()
    val br_rs_valid = in  Bool()
    val fu_br_ready = out Bool()
    val fu_br_reg_in = in Bits (regW bits)
    // flattened cdb_itf.fu
    val cdb_rob_id        = out Bits (RIDX bits)
    val cdb_rd_phy        = out Bits (PIDX bits)
    val cdb_rd_arch       = out Bits (AIDX bits)
    val cdb_rd_value      = out Bits (32 bits)
    val cdb_rs1_value_dbg = out Bits (32 bits)
    val cdb_rs2_value_dbg = out Bits (32 bits)
    val cdb_valid         = out Bool()
    // flattened br_cdb_itf.fu
    val br_cdb_rob_id         = out Bits (RIDX bits)
    val br_cdb_miss_predict   = out Bool()
    val br_cdb_target_address = out Bits (32 bits)
    val br_cdb_valid          = out Bool()
    val br_cdb_branch_taken   = out Bool()
    // Branch outcome observations for performance counters.
    val dbg_fu_br_valid  = out Bool()
    val dbg_miss_predict = out Bool()
    val dbg_reg_out      = out Bits (regW bits)
  }
  noIoPrefix()

  io.fu_br_ready := True
  val cdb_ready = True

  val domain = ClockDomain(
    clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  new ClockingArea(domain) {
    val fu_br_valid = RegInit(False)
    when(io.fu_br_ready) { fu_br_valid := io.br_rs_valid }
    val reg_out = Reg(Bits(regW bits))
    when(io.br_rs_valid && io.fu_br_ready) { reg_out := io.fu_br_reg_in }

    // unpack reg_out (LSB-first)
    val predict_target = FuBrReg.predictTarget(reg_out)
    val predict_taken  = FuBrReg.predictTaken(reg_out)
    val is_compressed  = FuBrReg.isCompressed(reg_out)
    val rs2_value      = FuBrReg.rs2Value(reg_out)
    val rs1_value      = FuBrReg.rs1Value(reg_out)
    val imm            = FuBrReg.imm(reg_out)
    val pc             = FuBrReg.pc(reg_out)
    val fu_opcode      = FuBrReg.fuOpcode(reg_out)
    val rd_phy         = FuBrReg.rdPhy(reg_out, cfg)
    val rd_arch        = FuBrReg.rdArch(reg_out, cfg)
    val rob_id         = FuBrReg.robId(reg_out, cfg)

    val pc_next_seq = ooo.FastAdd.pcNext(pc,is_compressed,cfg.fpgaNativeAdd)
    val pcTarget = ooo.FastAdd.withCout(pc.asUInt,imm.asUInt,nativeCarry=cfg.fpgaNativeAdd)._1.asBits
    val registerTarget = ooo.FastAdd.withCout(rs1_value.asUInt,imm.asUInt,nativeCarry=cfg.fpgaNativeAdd)._1.asBits

    val au = rs1_value.asUInt; val bu = rs2_value.asUInt
    val as = rs1_value.asSInt; val bs = rs2_value.asSInt
    val unsignedLess = ooo.FastAdd.lessThan(au,bu,cfg.fpgaNativeAdd)
    val signedLess = if (cfg.fpgaNativeAdd) as < bs
      else Mux(rs1_value(31) =/= rs2_value(31),rs1_value(31),unsignedLess)

    val branch_taken = Bool()
    switch(fu_opcode) {
      is(BR_BEQ)  { branch_taken := au === bu }
      is(BR_BNE)  { branch_taken := au =/= bu }
      is(BR_BLT)  { branch_taken := signedLess }
      is(BR_BGE)  { branch_taken := !signedLess }
      is(BR_BLTU) { branch_taken := unsignedLess }
      is(BR_BGEU) { branch_taken := !unsignedLess }
      is(BR_JAL)  { branch_taken := True }
      is(BR_JALR) { branch_taken := True }
      default     { branch_taken := False }
    }

    val target_address = Bits(32 bits)
    when(branch_taken) {
      when(fu_opcode === BR_JALR) {
        target_address := registerTarget & B"32'hfffffffe"
      } otherwise {
        target_address := pcTarget
      }
    } otherwise {
      target_address := pc_next_seq
    }

    val miss_predict = (branch_taken =/= predict_taken) || (target_address =/= predict_target)

    val rd_value = Mux(fu_opcode === BR_AUIPC, pcTarget, pc_next_seq)

    // CDB registers
    val cdb_valid    = RegInit(False)
    val br_cdb_valid = RegInit(False)
    when(cdb_ready) {
      cdb_valid    := fu_br_valid
      br_cdb_valid := fu_br_valid && !(fu_opcode === BR_AUIPC)
    }
    io.cdb_valid    := cdb_valid
    io.br_cdb_valid := br_cdb_valid

    val r_rob_id  = Reg(Bits(RIDX bits))
    val r_rd_arch = Reg(Bits(AIDX bits))
    val r_rd_phy  = Reg(Bits(PIDX bits))
    val r_rd_val  = Reg(Bits(32 bits))
    val r_rs1_dbg = Reg(Bits(32 bits))
    val r_rs2_dbg = Reg(Bits(32 bits))
    val r_taken   = Reg(Bool())
    val r_miss    = Reg(Bool())
    val r_target  = Reg(Bits(32 bits))
    when(fu_br_valid && cdb_ready) {
      r_rob_id  := rob_id;     r_rd_arch := rd_arch;  r_rd_phy := rd_phy
      r_rd_val  := rd_value;   r_rs1_dbg := rs1_value; r_rs2_dbg := rs2_value
      r_taken   := branch_taken; r_miss := miss_predict; r_target := target_address
    }

    io.cdb_rob_id        := r_rob_id
    io.cdb_rd_arch       := r_rd_arch
    io.cdb_rd_phy        := r_rd_phy
    io.cdb_rd_value      := r_rd_val
    // RVFI-only. Tying the OUTPUTS makes r_rs1_dbg/r_rs2_dbg dead in the
    // product config, so the two 32-bit capture registers are swept with them.
    io.cdb_rs1_value_dbg := (if (cfg.rvfi) r_rs1_dbg else B(0, 32 bits))
    io.cdb_rs2_value_dbg := (if (cfg.rvfi) r_rs2_dbg else B(0, 32 bits))

    io.br_cdb_rob_id         := r_rob_id
    io.br_cdb_miss_predict   := r_miss
    io.br_cdb_target_address := r_target
    io.br_cdb_branch_taken   := r_taken

    // debug taps
    io.dbg_fu_br_valid  := fu_br_valid
    io.dbg_miss_predict := miss_predict
    io.dbg_reg_out      := reg_out
  }
}
