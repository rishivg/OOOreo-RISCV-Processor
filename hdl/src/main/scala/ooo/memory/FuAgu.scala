package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Port-compatible SpinalHDL twin of `hdl/memory/mem_rs/fu_agu.sv`.
  *
  * Address-generation unit. SHORTCUT (load-to-use -1 cycle): the original 1-stage
  * AGU registered its input before the combinational eff-addr add, so the address
  * arrived the cycle AFTER mem-RS issue (load-to-use = AGU(1)+dcache(1) = 2). This
  * version is 0-stage / fully combinational: eff-addr add + store-align + byte mask
  * straight from the issued operands, so the LDQ's AGU-address bypass issues the
  * load the SAME cycle (load-to-use = dcache(1) = 1). Trades Fmax (issue->PRF->add->
  * disambig->dcache in one cycle) for IPC; under CoreMark/MHz (~IPC) that's a metric
  * win. clk/rst remain in the port list (mem_rs drives them) but are now unused.
  *
  *   agu_reg_t  (in,  106b): rob_id[ROB_IDX] fu_opcode[4] imm[32] rs1_value[32] rs2_value[32]
  *   agu_lsq_t  (out, 138b): rob_id[ROB_IDX] addr[32] wdata[32] mask[4] rs1_dbg[32] rs2_dbg[32]
  */
class FuAgu(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_agu")

  val robW = cfg.robIdx            // ROB_IDX = 6
  val aguRegW = robW + 4 + 32 + 32 + 32   // 106
  val aguLsqW = robW + 32 + 32 + 4 + 32 + 32 // 138

  // memopc_t (lsu_types) -- fu_opcode = {is_store, funct3}
  def MEM_LB  = B"4'b0000"; def MEM_LH  = B"4'b0001"; def MEM_LW  = B"4'b0010"
  def MEM_LBU = B"4'b0100"; def MEM_LHU = B"4'b0101"
  def MEM_SB  = B"4'b1000"; def MEM_SH  = B"4'b1001"; def MEM_SW  = B"4'b1010"

  val io = new Bundle {
    val clk         = in  Bool()
    val rst         = in  Bool()
    val prv_valid   = in  Bool()
    val prv_ready   = out Bool()
    val agu_reg_in  = in  Bits (aguRegW bits)
    val nxt_valid   = out Bool()
    val to_lsq      = out Bits (aguLsqW bits)
  }
  noIoPrefix()

  // AGU is single-cycle and always ready; now 0-stage (combinational pass-through).
  io.prv_ready := True
  io.nxt_valid := io.prv_valid

  // unpack agu_reg_in directly (no input register) -- LSB-first:
  //   rs2_value[31:0] rs1_value[63:32] imm[95:64] fu_opcode[99:96] rob_id[105:100]
  val rs2_value = io.agu_reg_in(31 downto 0)
  val rs1_value = io.agu_reg_in(63 downto 32)
  val imm       = io.agu_reg_in(95 downto 64)
  val fu_op     = io.agu_reg_in(99 downto 96)
  val rob       = io.agu_reg_in(105 downto 100)

  val unaligned_addr = (rs1_value.asUInt + imm.asUInt).asBits        // 32b
  val a10 = unaligned_addr(1 downto 0).asUInt                        // byte offset

  // ---- store data alignment (unmasked lanes -> 0, matching x-assign fast) ----
  val wdata = Bits(32 bits)
  switch(fu_op) {
    is(MEM_SB) { wdata := (B(0, 24 bits) ## rs2_value(7 downto 0))  |<< (a10 * 8) }
    is(MEM_SH) { wdata := (B(0, 16 bits) ## rs2_value(15 downto 0)) |<< (unaligned_addr(1).asUInt * 16) }
    is(MEM_SW) { wdata := rs2_value }
    default    { wdata := B(0, 32 bits) }
  }

  // ---- byte mask ----
  val mask = Bits(4 bits)
  switch(fu_op) {
    is(MEM_LB, MEM_LBU, MEM_SB) { mask := B"4'b0001" |<< a10 }
    is(MEM_LH, MEM_LHU, MEM_SH) { mask := B"4'b0011" |<< a10 }
    is(MEM_LW, MEM_SW)          { mask := B"4'b1111" }
    default                     { mask := B(0, 4 bits) }
  }

  // ---- pack to_lsq (first field = MSB) ----
  io.to_lsq := rob ## unaligned_addr ## wdata ## mask ## rs1_value ## rs2_value
}
