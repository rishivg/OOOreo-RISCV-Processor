// Module-swap shim (ROADMAP Phase 3) for hdl/backend/execute/intm_rs/intm_rs.sv.
// Carries the SV interfaces + flattens them onto intm_rs_spinal; extracts
// uop->intm_rs_entry_t. fu_div stays SV: instantiated here as fu_div_i and wired to
// intm_rs_spinal's exposed div interface (so perf tap intm_rs_i.fu_div_i.div_start
// resolves). Recreates the fu_mul_i scope for intm_rs_i.fu_mul_i.mul_start.
module intm_rs
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    ds_rs_itf.rs                from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    localparam EW = $bits(intm_rs_entry_t);   // 35

    intm_rs_entry_t         from_ds_entry [ID_WIDTH];
    logic [ID_WIDTH*EW-1:0] from_ds_entry_flat;
    logic [ID_WIDTH-1:0]    from_ds_valid;
    always_comb begin
        for (int w = 0; w < ID_WIDTH; w++) begin
            from_ds_entry[w].rob_id     = from_ds.uop[w].rob_id;
            from_ds_entry[w].rs1_phy    = from_ds.uop[w].rs1_phy;
            from_ds_entry[w].rs1_valid  = from_ds.uop[w].rs1_valid;
            from_ds_entry[w].rs2_phy    = from_ds.uop[w].rs2_phy;
            from_ds_entry[w].rs2_valid  = from_ds.uop[w].rs2_valid;
            from_ds_entry[w].rd_phy     = from_ds.uop[w].rd_phy;
            from_ds_entry[w].rd_arch    = from_ds.uop[w].rd_arch;
            from_ds_entry[w].fu_opcode  = from_ds.uop[w].fu_opcode;
        end
    end
    generate for (genvar w = 0; w < ID_WIDTH; w++) begin
        assign from_ds_entry_flat[w*EW +: EW] = from_ds_entry[w];
        assign from_ds_valid[w] = from_ds.valid[w];
    end endgenerate

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

    // externalized fu_div interface
    logic                   div_prv_valid, div_prv_ready, div_nxt_valid, div_nxt_ready;
    intm_rs_reg_t           div_iss_in;
    fu_cdb_reg_t            div_cdb_out;
    logic                   dbg_mul_start;

    intm_rs_spinal intm_rs_spinal_i (
        .clk(clk), .rst(rst),
        .from_ds_entry_flat(from_ds_entry_flat),
        .from_ds_valid(from_ds_valid),
        .from_ds_ready(from_ds.ready),
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
        .div_prv_valid(div_prv_valid),
        .div_prv_ready(div_prv_ready),
        .div_nxt_valid(div_nxt_valid),
        .div_nxt_ready(div_nxt_ready),
        .div_iss_in(div_iss_in),
        .div_cdb_out(div_cdb_out),
        .dbg_mul_start(dbg_mul_start)
    );

    // real SV divider (DW_div_seq inside) -- keeps perf tap fu_div_i.div_start
    fu_div fu_div_i (
        .clk(clk), .rst(rst),
        .prv_valid(div_prv_valid),
        .prv_ready(div_prv_ready),
        .nxt_valid(div_nxt_valid),
        .nxt_ready(div_nxt_ready),
        .iss_in(div_iss_in),
        .cdb_out(div_cdb_out)
    );

    // recreate fu_mul_i scope for perf_monitor (intm_rs_i.fu_mul_i.mul_start)
    if (1) begin : fu_mul_i
        logic mul_start;
        assign mul_start = dbg_mul_start;
    end
endmodule
