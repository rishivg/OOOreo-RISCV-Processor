package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/branch/branch_top.sv` -- the branch cluster:
  * fans the dispatched uop to the branch RS (BrRs) and the control buffer
  * (ControlBuffer), wires the internal br_cdb between them, and exposes the
  * predictor-train (to_bp) + ROB-dequeue (to_rob) ports. Both sub-blocks reset on
  * rst||backend_flush.
  *
  * Named branch_top_spinal; sim/swap_shims/branch_top.sv carries the external SV
  * interfaces, builds the br_rs entry + control-buffer uop fields, and recreates
  * the perf-tapped br_rs_i.fu_br_i scope.
  */
class BranchTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("branch_top_spinal")
  val CDBW = cfg.cdbWidth        // [CDB_WIDTH]
  val NFB  = cfg.numFastBypass   // 2
  val PIDX = cfg.prfIdx          // 6
  val RIDX = cfg.robIdx          // 6
  val AIDX = cfg.arfIdx          // 5
  val GHR  = cfg.ghrLen          // [GHR_LEN]
  val PROV = cfg.tageNum * (1 + cfg.tageCtrBits + cfg.tageUBits) + 2   // +2 = forwarded bimodal counter
  val EW   = RsEntryLayout.br.width   // 133
  val BNW  = 1 + PIDX + 32       // bypass_network_t = 39
  val FBRW = 183                 // fu_br_reg_t
  val BPW  = BypassT.width(cfg)   // bypass_t width

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    val from_ds_valid = in Bool(); val from_ds_ready = out Bool()
    val from_ds_entry_flat = in Bits (EW bits)            // br_rs entry (built in shim)
    val uop_rob_id = in Bits (RIDX bits); val uop_pc = in Bits (32 bits)
    val uop_fu_opcode = in Bits (4 bits); val uop_ghr = in Bits (GHR bits); val uop_prov = in Bits (PROV bits)
    val uop_is_compressed = in Bool(); val uop_inst = in Bits (32 bits)
    // to_prf
    val to_prf_rs1_phy = out Bits (PIDX bits); val to_prf_rs2_phy = out Bits (PIDX bits)
    val to_prf_rs_bypass = out Bits (BPW bits)
    val to_prf_rs1_value = in Bits (32 bits); val to_prf_rs2_value = in Bits (32 bits)
    // cdb_itf.rs[CDB_WIDTH]
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits); val cdb_valid = in Bits (CDBW bits)
    // alu_bypass
    val alu_bypass_flat = in Bits (NFB * BNW bits)
    // fu_cdb_out (cdb_itf.fu)
    val fu_cdb_rob_id = out Bits (RIDX bits); val fu_cdb_rd_phy = out Bits (PIDX bits)
    val fu_cdb_rd_arch = out Bits (AIDX bits); val fu_cdb_rd_value = out Bits (32 bits)
    val fu_cdb_rs1_dbg = out Bits (32 bits); val fu_cdb_rs2_dbg = out Bits (32 bits)
    val fu_cdb_valid = out Bool()
    // cb_bp_itf.cb to_bp
    val to_bp_update_en = out Bool(); val to_bp_pc = out Bits (32 bits)
    val to_bp_fu_opcode = out Bits (4 bits); val to_bp_branch_taken = out Bool()
    val to_bp_target = out Bits (32 bits); val to_bp_ghr = out Bits (GHR bits)
    val to_bp_is_call = out Bool(); val to_bp_is_ret = out Bool(); val to_bp_is_compressed = out Bool()
    val to_bp_prov = out Bits (PROV bits)
    // cb_rob_itf.cb to_rob
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

  // ---- dispatch fan-out + shared ready ----
  val branchReady = brRs.io.from_ds_ready && cb.io.from_ds_ready
  io.from_ds_ready := branchReady
  brRs.io.from_ds_valid := io.from_ds_valid
  brRs.io.from_ds_entry_flat := io.from_ds_entry_flat
  brRs.io.branch_ready := branchReady
  cb.io.from_ds_valid := io.from_ds_valid
  cb.io.uop_rob_id := io.uop_rob_id; cb.io.uop_pc := io.uop_pc; cb.io.uop_fu_opcode := io.uop_fu_opcode
  cb.io.uop_ghr := io.uop_ghr; cb.io.uop_is_compressed := io.uop_is_compressed; cb.io.uop_inst := io.uop_inst
  cb.io.uop_prov := io.uop_prov
  cb.io.branch_ready := branchReady

  // ---- internal br_cdb (br_rs -> control_buffer) ----
  cb.io.br_cdb_valid := brRs.io.br_cdb_valid
  cb.io.br_cdb_rob_id := brRs.io.br_cdb_rob_id
  cb.io.br_cdb_miss_predict := brRs.io.br_cdb_miss_predict
  cb.io.br_cdb_target := brRs.io.br_cdb_target_address
  cb.io.br_cdb_branch_taken := brRs.io.br_cdb_branch_taken

  // ---- to_prf / cdb / bypass ----
  io.to_prf_rs1_phy := brRs.io.to_prf_rs1_phy; io.to_prf_rs2_phy := brRs.io.to_prf_rs2_phy
  io.to_prf_rs_bypass := brRs.io.to_prf_rs_bypass
  brRs.io.to_prf_rs1_value := io.to_prf_rs1_value; brRs.io.to_prf_rs2_value := io.to_prf_rs2_value
  brRs.io.cdb_rd_phy_flat := io.cdb_rd_phy_flat; brRs.io.cdb_valid := io.cdb_valid
  brRs.io.alu_bypass_flat := io.alu_bypass_flat

  // ---- fu_cdb_out ----
  io.fu_cdb_rob_id := brRs.io.fu_cdb_rob_id; io.fu_cdb_rd_phy := brRs.io.fu_cdb_rd_phy
  io.fu_cdb_rd_arch := brRs.io.fu_cdb_rd_arch; io.fu_cdb_rd_value := brRs.io.fu_cdb_rd_value
  io.fu_cdb_rs1_dbg := brRs.io.fu_cdb_rs1_dbg; io.fu_cdb_rs2_dbg := brRs.io.fu_cdb_rs2_dbg
  io.fu_cdb_valid := brRs.io.fu_cdb_valid

  // ---- to_bp / to_rob ----
  io.to_bp_update_en := cb.io.to_bp_update_en; io.to_bp_pc := cb.io.to_bp_pc
  io.to_bp_fu_opcode := cb.io.to_bp_fu_opcode; io.to_bp_branch_taken := cb.io.to_bp_branch_taken
  io.to_bp_target := cb.io.to_bp_target; io.to_bp_ghr := cb.io.to_bp_ghr
  io.to_bp_is_call := cb.io.to_bp_is_call; io.to_bp_is_ret := cb.io.to_bp_is_ret
  io.to_bp_is_compressed := cb.io.to_bp_is_compressed; io.to_bp_prov := cb.io.to_bp_prov
  io.to_rob_rob_id := cb.io.to_rob_rob_id; io.to_rob_miss_predict := cb.io.to_rob_miss_predict
  io.to_rob_target := cb.io.to_rob_target; io.to_rob_ready := cb.io.to_rob_ready
  cb.io.to_rob_dequeue := io.to_rob_dequeue

  // ---- perf taps ----
  io.dbg_fu_br_valid := brRs.io.dbg_fu_br_valid
  io.dbg_miss_predict := brRs.io.dbg_miss_predict
  io.dbg_reg_out := brRs.io.dbg_reg_out
}
