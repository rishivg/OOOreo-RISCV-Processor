package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Branch execution, control-buffer tracking, and recovery. */
class BranchTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("branch_top_spinal")
  val CDBW = cfg.cdbWidth        // [CDB_WIDTH]
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val RIDX = cfg.robIdx
  val AIDX = cfg.arfIdx
  val PROV = cfg.bpProvW
  val EW   = RsEntryLayout.br(cfg).width   // 133 @ default
  val BNW  = cfg.bypassNetW      // bypass_network_t
  val FBRW = cfg.fuBrRegW        // fu_br_reg_t
  val BPW  = BypassT.width(cfg)   // bypass_t width

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    val from_ds_valid = in Bool(); val from_ds_ready = out Bool()
    val from_ds_entry_flat = in Bits (EW bits)            // br_rs entry (built in shim)
    val uop_rob_id = in Bits (RIDX bits); val uop_pc = in Bits (32 bits)
    val uop_fu_opcode = in Bits (4 bits); val uop_kp = in Bits (log2Up(cfg.ifWidth) bits); val uop_prov = in Bits (PROV bits)
    val uop_is_compressed = in Bool(); val uop_inst = in Bits (32 bits)
    // to_prf -- PRF-3 pre-read group (see BrRs / Prf.bpre_*)
    val to_prf_bpre_select1 = if (cfg.brPrfSharedPredecode) out Bits(cfg.prfDepth - 1 bits) else null
    val to_prf_bpre_select2 = if (cfg.brPrfSharedPredecode) out Bits(cfg.prfDepth - 1 bits) else null
    val to_prf_bpre_phy1_flat   = out Bits (cfg.brrsDepth * PIDX bits)
    val to_prf_bpre_phy2_flat   = out Bits (cfg.brrsDepth * PIDX bits)
    val to_prf_bpre_bypass_flat = out Bits (cfg.brrsDepth * BPW bits)
    val to_prf_bpre_value1_flat = in  Bits (cfg.brrsDepth * 32 bits)
    val to_prf_bpre_value2_flat = in  Bits (cfg.brrsDepth * 32 bits)
    val cdb_lsu_value = in Bits (32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits); val cdb_valid = in Bits (CDBW bits)
    // alu_bypass
    val alu_bypass_flat = in Bits (NFB * BNW bits)
    // fu_cdb_out (cdb_itf.fu)
    val fu_cdb_rob_id = out Bits (RIDX bits); val fu_cdb_rd_phy = out Bits (PIDX bits)
    val fu_cdb_rd_arch = out Bits (AIDX bits); val fu_cdb_rd_value = out Bits (32 bits)
    val fu_cdb_rs1_dbg = out Bits (32 bits); val fu_cdb_rs2_dbg = out Bits (32 bits)
    val fu_cdb_valid = out Bool()
    val to_bp_update_en = out Bool(); val to_bp_pc = out Bits (32 bits)
    val to_bp_fu_opcode = out Bits (4 bits); val to_bp_branch_taken = out Bool()
    val to_bp_target = out Bits (32 bits); val to_bp_kp = out Bits (log2Up(cfg.ifWidth) bits)
    val to_bp_is_call = out Bool(); val to_bp_is_ret = out Bool(); val to_bp_is_compressed = out Bool()
    val to_bp_prov = out Bits (PROV bits)
    val to_rob_rob_id = out Bits (RIDX bits); val to_rob_miss_predict = out Bool()
    val to_rob_target = out Bits (32 bits); val to_rob_ready = out Bool(); val to_rob_dequeue = in Bool()
    // perf taps (br_rs_i.fu_br_i.*)
    val dbg_fu_br_valid = out Bool(); val dbg_miss_predict = out Bool(); val dbg_reg_out = out Bits (FBRW bits)
  }
  noIoPrefix()

  val subRst = io.rst || io.backend_flush

  val brRs = new BrRs(cfg)
  val cb   = new ControlBuffer(cfg)
  brRs.io.clk := io.clk; brRs.io.rst := subRst
  cb.io.clk := io.clk;   cb.io.rst := subRst

  // dispatch fan-out + shared ready
  val branchReady = brRs.io.from_ds_ready && cb.io.from_ds_ready
  io.from_ds_ready := branchReady
  brRs.io.from_ds_valid := io.from_ds_valid
  brRs.io.from_ds_entry_flat := io.from_ds_entry_flat
  brRs.io.branch_ready := branchReady
  cb.io.from_ds_valid := io.from_ds_valid
  cb.io.uop_rob_id := io.uop_rob_id; cb.io.uop_pc := io.uop_pc; cb.io.uop_fu_opcode := io.uop_fu_opcode
  cb.io.uop_kp := io.uop_kp; cb.io.uop_is_compressed := io.uop_is_compressed; cb.io.uop_inst := io.uop_inst
  cb.io.uop_prov := io.uop_prov
  cb.io.branch_ready := branchReady

  // internal br_cdb (br_rs -> control_buffer)
  cb.io.br_cdb_valid := brRs.io.br_cdb_valid
  cb.io.br_cdb_rob_id := brRs.io.br_cdb_rob_id
  cb.io.br_cdb_miss_predict := brRs.io.br_cdb_miss_predict
  cb.io.br_cdb_target := brRs.io.br_cdb_target_address
  cb.io.br_cdb_branch_taken := brRs.io.br_cdb_branch_taken

  // to_prf / cdb / bypass
  if (cfg.brPrfSharedPredecode) {
    io.to_prf_bpre_select1 := brRs.io.to_prf_bpre_select1
    io.to_prf_bpre_select2 := brRs.io.to_prf_bpre_select2
  }
  io.to_prf_bpre_phy1_flat   := brRs.io.to_prf_bpre_phy1_flat
  io.to_prf_bpre_phy2_flat   := brRs.io.to_prf_bpre_phy2_flat
  io.to_prf_bpre_bypass_flat := brRs.io.to_prf_bpre_bypass_flat
  brRs.io.to_prf_bpre_value1_flat := io.to_prf_bpre_value1_flat
  brRs.io.to_prf_bpre_value2_flat := io.to_prf_bpre_value2_flat
  brRs.io.cdb_lsu_value := io.cdb_lsu_value
  brRs.io.cdb_rd_phy_flat := io.cdb_rd_phy_flat; brRs.io.cdb_valid := io.cdb_valid
  brRs.io.alu_bypass_flat := io.alu_bypass_flat

  // fu_cdb_out
  io.fu_cdb_rob_id := brRs.io.fu_cdb_rob_id; io.fu_cdb_rd_phy := brRs.io.fu_cdb_rd_phy
  io.fu_cdb_rd_arch := brRs.io.fu_cdb_rd_arch; io.fu_cdb_rd_value := brRs.io.fu_cdb_rd_value
  io.fu_cdb_rs1_dbg := brRs.io.fu_cdb_rs1_dbg; io.fu_cdb_rs2_dbg := brRs.io.fu_cdb_rs2_dbg
  io.fu_cdb_valid := brRs.io.fu_cdb_valid

  // to_bp / to_rob
  io.to_bp_update_en := cb.io.to_bp_update_en; io.to_bp_pc := cb.io.to_bp_pc
  io.to_bp_fu_opcode := cb.io.to_bp_fu_opcode; io.to_bp_branch_taken := cb.io.to_bp_branch_taken
  io.to_bp_target := cb.io.to_bp_target; io.to_bp_kp := cb.io.to_bp_kp
  io.to_bp_is_call := cb.io.to_bp_is_call; io.to_bp_is_ret := cb.io.to_bp_is_ret
  io.to_bp_is_compressed := cb.io.to_bp_is_compressed; io.to_bp_prov := cb.io.to_bp_prov
  io.to_rob_rob_id := cb.io.to_rob_rob_id; io.to_rob_miss_predict := cb.io.to_rob_miss_predict
  io.to_rob_target := cb.io.to_rob_target; io.to_rob_ready := cb.io.to_rob_ready
  cb.io.to_rob_dequeue := io.to_rob_dequeue

  // perf taps
  io.dbg_fu_br_valid := brRs.io.dbg_fu_br_valid
  io.dbg_miss_predict := brRs.io.dbg_miss_predict
  io.dbg_reg_out := brRs.io.dbg_reg_out
}
