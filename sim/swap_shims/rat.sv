// Module-swap shim (ROADMAP Phase 3) for hdl/backend/rename/rat.sv. Carries the SV
// interfaces (id_rat_itf.rat, cdb_itf.rat[CDB_WIDTH]) and flattens the
// rrf_mem[ARF_DEPTH] unpacked-array input onto rat_spinal. hdl/ stays pristine.
module rat
import cpu_params::*;
import rat_types::*;
(
    input   logic                 clk,
    input   logic                 rst,
    input   logic                 backend_flush,
    input   logic   [PRF_IDX-1:0] rrf_mem[ARF_DEPTH],
    id_rat_itf.rat                from_id,
    cdb_itf.rat                   cdb[CDB_WIDTH]
);
    logic [ARF_DEPTH*PRF_IDX-1:0] rrf_mem_flat;
    generate for (genvar i = 0; i < ARF_DEPTH; i++) begin
        assign rrf_mem_flat[i*PRF_IDX +: PRF_IDX] = rrf_mem[i];
    end endgenerate

    logic [ID_WIDTH*ARF_IDX-1:0]  rs1_arch_flat, rs2_arch_flat, rd_arch_flat;
    logic [ID_WIDTH*PRF_IDX-1:0]  rd_phy_flat, rs1_phy_flat, rs2_phy_flat;
    logic [ID_WIDTH-1:0]          write_en_flat, rs1_valid_flat, rs2_valid_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign rs1_arch_flat[i*ARF_IDX +: ARF_IDX] = from_id.rs1_arch[i];
        assign rs2_arch_flat[i*ARF_IDX +: ARF_IDX] = from_id.rs2_arch[i];
        assign rd_arch_flat[i*ARF_IDX +: ARF_IDX]  = from_id.rd_arch[i];
        assign rd_phy_flat[i*PRF_IDX +: PRF_IDX]   = from_id.rd_phy[i];
        assign write_en_flat[i]                    = from_id.write_en[i];
        assign from_id.rs1_phy[i]   = rs1_phy_flat[i*PRF_IDX +: PRF_IDX];
        assign from_id.rs2_phy[i]   = rs2_phy_flat[i*PRF_IDX +: PRF_IDX];
        assign from_id.rs1_valid[i] = rs1_valid_flat[i];
        assign from_id.rs2_valid[i] = rs2_valid_flat[i];
    end endgenerate

    logic [CDB_WIDTH-1:0]         cdb_valid_flat;
    logic [CDB_WIDTH*PRF_IDX-1:0] cdb_rd_phy_flat;
    logic [CDB_WIDTH*ARF_IDX-1:0] cdb_rd_arch_flat;
    generate for (genvar j = 0; j < CDB_WIDTH; j++) begin
        assign cdb_valid_flat[j]                     = cdb[j].valid;
        assign cdb_rd_phy_flat[j*PRF_IDX +: PRF_IDX] = cdb[j].rd_phy;
        assign cdb_rd_arch_flat[j*ARF_IDX +: ARF_IDX] = cdb[j].rd_arch;
    end endgenerate

    rat_spinal rat_spinal_i (
        .clk(clk), .rst(rst),
        .backend_flush(backend_flush),
        .rrf_mem_flat(rrf_mem_flat),
        .from_id_rs1_arch_flat(rs1_arch_flat),
        .from_id_rs2_arch_flat(rs2_arch_flat),
        .from_id_write_en(write_en_flat),
        .from_id_rd_arch_flat(rd_arch_flat),
        .from_id_rd_phy_flat(rd_phy_flat),
        .from_id_rs1_phy_flat(rs1_phy_flat),
        .from_id_rs2_phy_flat(rs2_phy_flat),
        .from_id_rs1_valid(rs1_valid_flat),
        .from_id_rs2_valid(rs2_valid_flat),
        .cdb_valid(cdb_valid_flat),
        .cdb_rd_phy_flat(cdb_rd_phy_flat),
        .cdb_rd_arch_flat(cdb_rd_arch_flat)
    );
endmodule
