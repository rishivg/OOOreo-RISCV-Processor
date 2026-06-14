package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/branch/br_rs/fu_br.sv` -- the branch FU.
  *
  * Connects through TWO SV interfaces (cdb_itf.fu + br_cdb_itf.fu), so this module
  * is named `fu_br_spinal` with both flattened, and sim/swap_shims/fu_br.sv carries
  * the real interface ports (same approach as fu_alu).
  *
  * fu_br_reg_t (in, 183b, first field = MSB):
  *   rob_id[6] rd_arch[5] rd_phy[6] fu_opcode[4] pc[32] imm[32] rs1_value[32]
  *   rs2_value[32] is_compressed[1] predict_taken[1] predict_target[32]
  */
class FuBr(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_br_spinal")

  // bropc_t
  def BR_BEQ  = B"4'b0000"; def BR_BNE  = B"4'b0001"
  def BR_BLT  = B"4'b0100"; def BR_BGE  = B"4'b0101"
  def BR_BLTU = B"4'b0110"; def BR_BGEU = B"4'b0111"
  def BR_JAL  = B"4'b1000"; def BR_JALR = B"4'b1001"; def BR_AUIPC = B"4'b1111"

  val regW = 6 + 5 + 6 + 4 + 32 + 32 + 32 + 32 + 1 + 1 + 32  // 183

  val io = new Bundle {
    val clk         = in  Bool()
    val rst         = in  Bool()
    val br_rs_valid = in  Bool()
    val fu_br_ready = out Bool()
    val fu_br_reg_in = in Bits (regW bits)
    // flattened cdb_itf.fu
    val cdb_rob_id        = out Bits (6 bits)
    val cdb_rd_phy        = out Bits (6 bits)
    val cdb_rd_arch       = out Bits (5 bits)
    val cdb_rd_value      = out Bits (32 bits)
    val cdb_rs1_value_dbg = out Bits (32 bits)
    val cdb_rs2_value_dbg = out Bits (32 bits)
    val cdb_valid         = out Bool()
    // flattened br_cdb_itf.fu
    val br_cdb_rob_id         = out Bits (6 bits)
    val br_cdb_miss_predict   = out Bool()
    val br_cdb_target_address = out Bits (32 bits)
    val br_cdb_valid          = out Bool()
    val br_cdb_branch_taken   = out Bool()
    // debug-only observability for hvl/common/perf_monitor.sv (taps fu_br_i.fu_br_valid,
    // .miss_predict, .fu_br_reg_out.fu_opcode); surfaced in the shim by those names.
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
    val predict_target = reg_out(31 downto 0)
    val predict_taken  = reg_out(32)
    val is_compressed  = reg_out(33)
    val rs2_value      = reg_out(65 downto 34)
    val rs1_value      = reg_out(97 downto 66)
    val imm            = reg_out(129 downto 98)
    val pc             = reg_out(161 downto 130)
    val fu_opcode      = reg_out(165 downto 162)
    val rd_phy         = reg_out(171 downto 166)
    val rd_arch        = reg_out(176 downto 172)
    val rob_id         = reg_out(182 downto 177)

    val pc_next_seq = (pc.asUInt + Mux(is_compressed, U(2, 32 bits), U(4, 32 bits))).asBits

    val au = rs1_value.asUInt; val bu = rs2_value.asUInt
    val as = rs1_value.asSInt; val bs = rs2_value.asSInt

    val branch_taken = Bool()
    switch(fu_opcode) {
      is(BR_BEQ)  { branch_taken := au === bu }
      is(BR_BNE)  { branch_taken := au =/= bu }
      is(BR_BLT)  { branch_taken := as < bs }
      is(BR_BGE)  { branch_taken := as >= bs }
      is(BR_BLTU) { branch_taken := au < bu }
      is(BR_BGEU) { branch_taken := au >= bu }
      is(BR_JAL)  { branch_taken := True }
      is(BR_JALR) { branch_taken := True }
      default     { branch_taken := False }
    }

    val target_address = Bits(32 bits)
    when(branch_taken) {
      when(fu_opcode === BR_JALR) {
        target_address := ((rs1_value.asUInt + imm.asUInt) & U"32'hfffffffe").asBits
      } otherwise {
        target_address := (pc.asUInt + imm.asUInt).asBits
      }
    } otherwise {
      target_address := pc_next_seq
    }

    val miss_predict = (branch_taken =/= predict_taken) || (target_address =/= predict_target)

    val rd_value = Mux(fu_opcode === BR_AUIPC, (pc.asUInt + imm.asUInt).asBits, pc_next_seq)

    // ===== CDB registers =====
    val cdb_valid    = RegInit(False)
    val br_cdb_valid = RegInit(False)
    when(cdb_ready) {
      cdb_valid    := fu_br_valid
      br_cdb_valid := fu_br_valid && !(fu_opcode === BR_AUIPC)
    }
    io.cdb_valid    := cdb_valid
    io.br_cdb_valid := br_cdb_valid

    val r_rob_id  = Reg(Bits(6 bits))
    val r_rd_arch = Reg(Bits(5 bits))
    val r_rd_phy  = Reg(Bits(6 bits))
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
    io.cdb_rs1_value_dbg := r_rs1_dbg
    io.cdb_rs2_value_dbg := r_rs2_dbg

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
