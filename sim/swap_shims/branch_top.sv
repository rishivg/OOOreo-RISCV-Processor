// Module-swap shim for hdl/backend/branch/branch_top.sv. Carries the external SV
// interfaces, builds the br_rs_entry_t + control-buffer uop fields from from_ds.uop,
// flattens cdb/bypass, and recreates the perf-tapped br_rs_i.fu_br_i scope.
// branch_top_spinal re-emits br_rs_spinal/control_buffer_spinal/fu_br_spinal
// (distinct from the SV names -> no exclude). Used only by sim/build_swap.sh.
module branch_top
import cpu_params::*, uop_types::*, int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,
    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    cb_bp_itf.cb                to_bp,
    cb_rob_itf.cb               to_rob,
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    localparam EW = $bits(br_rs_entry_t);   // 133

    br_rs_entry_t   ds_entry;
    logic [EW-1:0]  ds_entry_flat;
    always_comb begin
        ds_entry.rob_id         = from_ds.uop.rob_id;
        ds_entry.rs1_phy        = from_ds.uop.rs1_phy;
        ds_entry.rs1_valid      = from_ds.uop.rs1_valid;
        ds_entry.rs2_phy        = from_ds.uop.rs2_phy;
        ds_entry.rs2_valid      = from_ds.uop.rs2_valid;
        ds_entry.rd_phy         = from_ds.uop.rd_phy;
        ds_entry.rd_arch        = from_ds.uop.rd_arch;
        ds_entry.imm            = from_ds.uop.imm;
        ds_entry.pc             = from_ds.uop.pc;
        ds_entry.fu_opcode      = from_ds.uop.fu_opcode;
        ds_entry.is_compressed  = from_ds.uop.is_compressed;
        ds_entry.predict_taken  = from_ds.uop.predict_taken;
        ds_entry.predict_target = from_ds.uop.predict_target;
    end
    assign ds_entry_flat = ds_entry;

    logic [CDB_WIDTH*PRF_IDX-1:0] cdb_rd_phy_flat;
    logic [CDB_WIDTH-1:0]         cdb_valid_flat;
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin
        assign cdb_rd_phy_flat[k*PRF_IDX +: PRF_IDX] = cdb[k].rd_phy;
        assign cdb_valid_flat[k] = cdb[k].valid;
    end endgenerate
    logic [NUM_FAST_BYPASS*$bits(bypass_network_t)-1:0] alu_bypass_flat;
    generate for (genvar k = 0; k < NUM_FAST_BYPASS; k++) begin
        assign alu_bypass_flat[k*$bits(bypass_network_t) +: $bits(bypass_network_t)] = alu_bypass[k];
    end endgenerate

    // perf taps recreated as br_rs_i.fu_br_i.*
    logic        dbg_fu_br_valid, dbg_miss_predict;
    logic [$bits(fu_br_reg_t)-1:0] dbg_reg_out;
    if (1) begin : br_rs_i
        if (1) begin : fu_br_i
            logic        fu_br_valid;
            logic        miss_predict;
            fu_br_reg_t  fu_br_reg_out;
            assign fu_br_valid   = dbg_fu_br_valid;
            assign miss_predict  = dbg_miss_predict;
            assign fu_br_reg_out = dbg_reg_out;
        end
    end

    branch_top_spinal branch_top_spinal_i (
        .clk(clk), .rst(rst), .backend_flush(backend_flush),
        .from_ds_valid(from_ds.valid), .from_ds_ready(from_ds.ready),
        .from_ds_entry_flat(ds_entry_flat),
        .uop_rob_id(from_ds.uop.rob_id), .uop_pc(from_ds.uop.pc),
        .uop_fu_opcode(from_ds.uop.fu_opcode), .uop_ghr(from_ds.uop.ghr),
        .uop_is_compressed(from_ds.uop.is_compressed), .uop_inst(from_ds.uop.inst),
        .to_prf_rs1_phy(to_prf.rs1_phy), .to_prf_rs2_phy(to_prf.rs2_phy),
        .to_prf_rs_bypass(to_prf.rs_bypass),
        .to_prf_rs1_value(to_prf.rs1_value), .to_prf_rs2_value(to_prf.rs2_value),
        .cdb_rd_phy_flat(cdb_rd_phy_flat), .cdb_valid(cdb_valid_flat),
        .alu_bypass_flat(alu_bypass_flat),
        .fu_cdb_rob_id(fu_cdb_out.rob_id), .fu_cdb_rd_phy(fu_cdb_out.rd_phy),
        .fu_cdb_rd_arch(fu_cdb_out.rd_arch), .fu_cdb_rd_value(fu_cdb_out.rd_value),
        .fu_cdb_rs1_dbg(fu_cdb_out.rs1_value_dbg), .fu_cdb_rs2_dbg(fu_cdb_out.rs2_value_dbg),
        .fu_cdb_valid(fu_cdb_out.valid),
        .to_bp_update_en(to_bp.update_en), .to_bp_pc(to_bp.pc), .to_bp_fu_opcode(to_bp.fu_opcode),
        .to_bp_branch_taken(to_bp.branch_taken), .to_bp_target(to_bp.target_address),
        .to_bp_ghr(to_bp.ghr), .to_bp_is_call(to_bp.is_call), .to_bp_is_ret(to_bp.is_ret),
        .to_bp_is_compressed(to_bp.is_compressed),
        .to_rob_rob_id(to_rob.rob_id), .to_rob_miss_predict(to_rob.miss_predict),
        .to_rob_target(to_rob.target_address), .to_rob_ready(to_rob.ready), .to_rob_dequeue(to_rob.dequeue),
        .dbg_fu_br_valid(dbg_fu_br_valid), .dbg_miss_predict(dbg_miss_predict), .dbg_reg_out(dbg_reg_out)
    );
endmodule
