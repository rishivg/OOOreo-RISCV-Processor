// Module-swap shim (ROADMAP Phase 3) for hdl/backend/execute/prf.sv. Carries the
// SV interfaces (rs_prf_itf.prf[CDB_WIDTH], cdb_itf.prf[CDB_WIDTH]) and the
// bypass_network_t[NUM_FAST_BYPASS] unpacked-struct array, flattened onto
// prf_spinal. Used only by sim/build_swap.sh; hdl/ stays pristine.
module prf
import cpu_params::*;
import prf_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    rs_prf_itf.prf              from_rs[CDB_WIDTH],
    cdb_itf.prf                 cdb[CDB_WIDTH],
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    localparam BPW = $bits(bypass_t);          // 14
    localparam BNW = $bits(bypass_network_t);  // 39

    logic [CDB_WIDTH*PRF_IDX-1:0] rs1_phy_flat, rs2_phy_flat, cdb_rd_phy_flat;
    logic [CDB_WIDTH*BPW-1:0]     rs_bypass_flat;
    logic [CDB_WIDTH*32-1:0]      rs1_value_flat, rs2_value_flat, cdb_rd_value_flat;
    logic [CDB_WIDTH-1:0]         cdb_valid_flat;
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin
        assign rs1_phy_flat[k*PRF_IDX +: PRF_IDX] = from_rs[k].rs1_phy;
        assign rs2_phy_flat[k*PRF_IDX +: PRF_IDX] = from_rs[k].rs2_phy;
        assign rs_bypass_flat[k*BPW +: BPW]       = from_rs[k].rs_bypass;
        assign from_rs[k].rs1_value = rs1_value_flat[k*32 +: 32];
        assign from_rs[k].rs2_value = rs2_value_flat[k*32 +: 32];
        assign cdb_valid_flat[k]                   = cdb[k].valid;
        assign cdb_rd_phy_flat[k*PRF_IDX +: PRF_IDX] = cdb[k].rd_phy;
        assign cdb_rd_value_flat[k*32 +: 32]       = cdb[k].rd_value;
    end endgenerate

    logic [NUM_FAST_BYPASS*BNW-1:0] alu_bypass_flat;
    generate for (genvar k = 0; k < NUM_FAST_BYPASS; k++) begin
        assign alu_bypass_flat[k*BNW +: BNW] = alu_bypass[k];
    end endgenerate

    prf_spinal prf_spinal_i (
        .clk                    (clk),
        .from_rs_rs1_phy_flat   (rs1_phy_flat),
        .from_rs_rs2_phy_flat   (rs2_phy_flat),
        .from_rs_rs_bypass_flat (rs_bypass_flat),
        .from_rs_rs1_value_flat (rs1_value_flat),
        .from_rs_rs2_value_flat (rs2_value_flat),
        .cdb_valid_flat         (cdb_valid_flat),
        .cdb_rd_phy_flat        (cdb_rd_phy_flat),
        .cdb_rd_value_flat      (cdb_rd_value_flat),
        .alu_bypass_flat        (alu_bypass_flat)
    );
endmodule
