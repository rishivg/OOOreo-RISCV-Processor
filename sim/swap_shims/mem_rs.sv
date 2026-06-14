// Module-swap shim (ROADMAP Phase 3) for hdl/memory/mem_rs/mem_rs.sv. Carries the
// SV interfaces + flattens onto mem_rs_spinal; extracts uop->mem_rs_entry_t. fu_agu
// is re-emitted by mem_rs_spinal (real fu_agu.sv dropped via EXTRA_EXCLUDE).
module mem_rs
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    agu_lsq_itf.agu             to_lsq,
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    localparam EW = $bits(mem_rs_entry_t);   // 56

    mem_rs_entry_t  from_ds_entry;
    logic [EW-1:0]  from_ds_entry_flat;
    always_comb begin
        from_ds_entry.rob_id     = from_ds.uop.rob_id;
        from_ds_entry.rs1_phy    = from_ds.uop.rs1_phy;
        from_ds_entry.rs1_valid  = from_ds.uop.rs1_valid;
        from_ds_entry.rs2_phy    = from_ds.uop.rs2_phy;
        from_ds_entry.rs2_valid  = from_ds.uop.rs2_valid;
        from_ds_entry.imm        = from_ds.uop.imm;
        from_ds_entry.fu_opcode  = from_ds.uop.fu_opcode;
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

    mem_rs_spinal mem_rs_spinal_i (
        .clk(clk), .rst(rst),
        .from_ds_entry_flat(from_ds_entry_flat),
        .from_ds_valid(from_ds.valid),
        .from_ds_ready(from_ds.ready),
        .to_prf_rs1_phy(to_prf.rs1_phy),
        .to_prf_rs2_phy(to_prf.rs2_phy),
        .to_prf_rs_bypass(to_prf.rs_bypass),
        .to_prf_rs1_value(to_prf.rs1_value),
        .to_prf_rs2_value(to_prf.rs2_value),
        .cdb_rd_phy_flat(cdb_rd_phy_flat),
        .cdb_valid(cdb_valid_flat),
        .alu_bypass_flat(alu_bypass_flat),
        .to_lsq_valid(to_lsq.valid),
        .to_lsq_data(to_lsq.data)
    );
endmodule
