// Module-swap shim (ROADMAP Phase 3) for hdl/backend/branch/br_rs/br_rs.sv.
// Carries the SV interfaces and flattens them onto br_rs_spinal; extracts
// uop->br_rs_entry_t. Recreates the `fu_br_i` scope so perf_monitor's
// br_rs_i.fu_br_i.{fu_br_valid,miss_predict,fu_br_reg_out} taps resolve.
module br_rs
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    br_cdb_itf.fu               br_cdb_out,
    input   logic               branch_ready,
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    localparam EW = $bits(br_rs_entry_t);

    br_rs_entry_t           from_ds_entry;
    logic [EW-1:0]          from_ds_entry_flat;
    always_comb begin
        from_ds_entry.rob_id         = from_ds.uop.rob_id;
        from_ds_entry.rs1_phy        = from_ds.uop.rs1_phy;
        from_ds_entry.rs1_valid      = from_ds.uop.rs1_valid;
        from_ds_entry.rs2_phy        = from_ds.uop.rs2_phy;
        from_ds_entry.rs2_valid      = from_ds.uop.rs2_valid;
        from_ds_entry.rd_phy         = from_ds.uop.rd_phy;
        from_ds_entry.rd_arch        = from_ds.uop.rd_arch;
        from_ds_entry.imm            = from_ds.uop.imm;
        from_ds_entry.pc             = from_ds.uop.pc;
        from_ds_entry.fu_opcode      = from_ds.uop.fu_opcode;
        from_ds_entry.is_compressed  = from_ds.uop.is_compressed;
        from_ds_entry.predict_taken  = from_ds.uop.predict_taken;
        from_ds_entry.predict_target = from_ds.uop.predict_target;
    end
    assign from_ds_entry_flat = from_ds_entry;

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

    // debug taps surfaced into a fu_br_i scope for perf_monitor
    logic        dbg_fu_br_valid, dbg_miss_predict;
    logic [$bits(fu_br_reg_t)-1:0] dbg_reg_out;
    if (1) begin : fu_br_i
        logic        fu_br_valid;
        logic        miss_predict;
        fu_br_reg_t  fu_br_reg_out;
        assign fu_br_valid   = dbg_fu_br_valid;
        assign miss_predict  = dbg_miss_predict;
        assign fu_br_reg_out = dbg_reg_out;
    end

    br_rs_spinal br_rs_spinal_i (
        .clk(clk), .rst(rst),
        .from_ds_entry_flat(from_ds_entry_flat),
        .from_ds_valid(from_ds.valid),
        .from_ds_ready(from_ds.ready),
        .branch_ready(branch_ready),
        .to_prf_rs1_phy(to_prf.rs1_phy),
        .to_prf_rs2_phy(to_prf.rs2_phy),
        .to_prf_rs_bypass(to_prf.rs_bypass),
        .to_prf_rs1_value(to_prf.rs1_value),
        .to_prf_rs2_value(to_prf.rs2_value),
        .cdb_rd_phy_flat(cdb_rd_phy_flat),
        .cdb_valid(cdb_valid_flat),
        .alu_bypass_flat(alu_bypass_flat),
        .fu_cdb_rob_id(fu_cdb_out.rob_id),
        .fu_cdb_rd_phy(fu_cdb_out.rd_phy),
        .fu_cdb_rd_arch(fu_cdb_out.rd_arch),
        .fu_cdb_rd_value(fu_cdb_out.rd_value),
        .fu_cdb_rs1_dbg(fu_cdb_out.rs1_value_dbg),
        .fu_cdb_rs2_dbg(fu_cdb_out.rs2_value_dbg),
        .fu_cdb_valid(fu_cdb_out.valid),
        .br_cdb_rob_id(br_cdb_out.rob_id),
        .br_cdb_miss_predict(br_cdb_out.miss_predict),
        .br_cdb_target_address(br_cdb_out.target_address),
        .br_cdb_valid(br_cdb_out.valid),
        .br_cdb_branch_taken(br_cdb_out.branch_taken),
        .dbg_fu_br_valid(dbg_fu_br_valid),
        .dbg_miss_predict(dbg_miss_predict),
        .dbg_reg_out(dbg_reg_out)
    );
endmodule
