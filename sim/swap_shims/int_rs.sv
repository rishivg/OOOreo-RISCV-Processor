// Module-swap shim (ROADMAP Phase 3) for hdl/backend/execute/int_rs/int_rs.sv.
// Same ports incl. the SV interfaces (ds_rs_itf, rs_prf_itf[2], cdb_itf.rs[5],
// cdb_itf.fu[2], bypass_network_t[2]); flattens them onto int_rs_spinal and does
// the uop->int_rs_entry_t field extraction (pure renaming). hdl/ stays pristine.
module int_rs
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    ds_rs_itf.rs                from_ds,
    rs_prf_itf.rs               to_prf[INT_ISSUE_WIDTH],
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out[INT_ISSUE_WIDTH],
    output bypass_network_t     alu_bypass[NUM_FAST_BYPASS]
);
    localparam EW  = $bits(int_rs_entry_t);    // 69
    localparam BPW = $bits(bypass_t);          // 14
    localparam BNW = $bits(bypass_network_t);  // 39

    // ---- dispatch: extract uop -> int_rs_entry_t (mirrors int_rs.sv) ----
    int_rs_entry_t              from_ds_entry [ID_WIDTH];
    logic [ID_WIDTH*EW-1:0]     from_ds_entry_flat;
    logic [ID_WIDTH-1:0]        from_ds_valid;
    logic                       from_ds_ready;

    always_comb begin
        for (int w = 0; w < ID_WIDTH; w++) begin
            from_ds_entry[w].rob_id     = from_ds.uop[w].rob_id;
            from_ds_entry[w].rs1_phy    = from_ds.uop[w].rs1_phy;
            from_ds_entry[w].rs1_valid  = from_ds.uop[w].rs1_valid;
            from_ds_entry[w].rs2_phy    = from_ds.uop[w].rs2_phy;
            from_ds_entry[w].rs2_valid  = from_ds.uop[w].rs2_valid;
            from_ds_entry[w].rd_phy     = from_ds.uop[w].rd_phy;
            from_ds_entry[w].rd_arch    = from_ds.uop[w].rd_arch;
            from_ds_entry[w].op1_sel    = from_ds.uop[w].op1_sel;
            from_ds_entry[w].op2_sel    = from_ds.uop[w].op2_sel;
            from_ds_entry[w].imm        = from_ds.uop[w].imm;
            from_ds_entry[w].fu_opcode  = from_ds.uop[w].fu_opcode;
        end
    end
    generate for (genvar w = 0; w < ID_WIDTH; w++) begin
        assign from_ds_entry_flat[w*EW +: EW] = from_ds_entry[w];
        assign from_ds_valid[w] = from_ds.valid[w];
    end endgenerate
    assign from_ds.ready = from_ds_ready;

    // ---- cdb_itf.rs[CDB_WIDTH] (wakeup inputs) ----
    logic [CDB_WIDTH*PRF_IDX-1:0]   cdb_rd_phy_flat;
    logic [CDB_WIDTH-1:0]           cdb_valid_flat;
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin
        assign cdb_rd_phy_flat[k*PRF_IDX +: PRF_IDX] = cdb[k].rd_phy;
        assign cdb_valid_flat[k] = cdb[k].valid;
    end endgenerate

    // ---- rs_prf_itf.rs[INT_ISSUE_WIDTH] ----
    logic [INT_ISSUE_WIDTH*PRF_IDX-1:0] rs1_phy_flat, rs2_phy_flat;
    logic [INT_ISSUE_WIDTH*BPW-1:0]     rs_bypass_flat;
    logic [INT_ISSUE_WIDTH*32-1:0]      rs1_value_flat, rs2_value_flat;
    generate for (genvar k = 0; k < INT_ISSUE_WIDTH; k++) begin
        assign to_prf[k].rs1_phy   = rs1_phy_flat[k*PRF_IDX +: PRF_IDX];
        assign to_prf[k].rs2_phy   = rs2_phy_flat[k*PRF_IDX +: PRF_IDX];
        assign to_prf[k].rs_bypass = rs_bypass_flat[k*BPW +: BPW];
        assign rs1_value_flat[k*32 +: 32] = to_prf[k].rs1_value;
        assign rs2_value_flat[k*32 +: 32] = to_prf[k].rs2_value;
    end endgenerate

    // ---- cdb_itf.fu[INT_ISSUE_WIDTH] (FU outputs) ----
    logic [INT_ISSUE_WIDTH*ROB_IDX-1:0] fu_cdb_rob_id_flat;
    logic [INT_ISSUE_WIDTH*PRF_IDX-1:0] fu_cdb_rd_phy_flat;
    logic [INT_ISSUE_WIDTH*ARF_IDX-1:0] fu_cdb_rd_arch_flat;
    logic [INT_ISSUE_WIDTH*32-1:0]      fu_cdb_rd_value_flat, fu_cdb_rs1_dbg_flat, fu_cdb_rs2_dbg_flat;
    logic [INT_ISSUE_WIDTH-1:0]         fu_cdb_valid_flat;
    generate for (genvar k = 0; k < INT_ISSUE_WIDTH; k++) begin
        assign fu_cdb_out[k].rob_id        = fu_cdb_rob_id_flat[k*ROB_IDX +: ROB_IDX];
        assign fu_cdb_out[k].rd_phy        = fu_cdb_rd_phy_flat[k*PRF_IDX +: PRF_IDX];
        assign fu_cdb_out[k].rd_arch       = fu_cdb_rd_arch_flat[k*ARF_IDX +: ARF_IDX];
        assign fu_cdb_out[k].rd_value      = fu_cdb_rd_value_flat[k*32 +: 32];
        assign fu_cdb_out[k].rs1_value_dbg = fu_cdb_rs1_dbg_flat[k*32 +: 32];
        assign fu_cdb_out[k].rs2_value_dbg = fu_cdb_rs2_dbg_flat[k*32 +: 32];
        assign fu_cdb_out[k].valid         = fu_cdb_valid_flat[k];
    end endgenerate

    // ---- bypass_network_t alu_bypass[NUM_FAST_BYPASS] ----
    logic [NUM_FAST_BYPASS*BNW-1:0] alu_bypass_flat;
    generate for (genvar k = 0; k < NUM_FAST_BYPASS; k++) begin
        assign alu_bypass[k] = alu_bypass_flat[k*BNW +: BNW];
    end endgenerate

    int_rs_spinal int_rs_spinal_i (
        .clk                   (clk),
        .rst                   (rst),
        .from_ds_entry_flat    (from_ds_entry_flat),
        .from_ds_valid         (from_ds_valid),
        .from_ds_ready         (from_ds_ready),
        .to_prf_rs1_phy_flat   (rs1_phy_flat),
        .to_prf_rs2_phy_flat   (rs2_phy_flat),
        .to_prf_rs_bypass_flat (rs_bypass_flat),
        .to_prf_rs1_value_flat (rs1_value_flat),
        .to_prf_rs2_value_flat (rs2_value_flat),
        .cdb_rd_phy_flat       (cdb_rd_phy_flat),
        .cdb_valid             (cdb_valid_flat),
        .fu_cdb_rob_id_flat    (fu_cdb_rob_id_flat),
        .fu_cdb_rd_phy_flat    (fu_cdb_rd_phy_flat),
        .fu_cdb_rd_arch_flat   (fu_cdb_rd_arch_flat),
        .fu_cdb_rd_value_flat  (fu_cdb_rd_value_flat),
        .fu_cdb_rs1_dbg_flat   (fu_cdb_rs1_dbg_flat),
        .fu_cdb_rs2_dbg_flat   (fu_cdb_rs2_dbg_flat),
        .fu_cdb_valid          (fu_cdb_valid_flat),
        .alu_bypass_flat       (alu_bypass_flat)
    );

endmodule
