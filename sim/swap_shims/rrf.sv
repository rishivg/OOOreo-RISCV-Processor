// Module-swap shim for hdl/backend/rename/rrf.sv. Carries rob_rrf_itf.rrf +
// rrf_fl_itf.rrf and un-flattens the rrf_mem[ARF_DEPTH] unpacked-array output onto
// rrf_spinal. Used only by sim/build_swap.sh; hdl/ stays pristine.
module rrf
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,
    output  logic   [PRF_IDX-1:0] rrf_mem[ARF_DEPTH],
    rob_rrf_itf.rrf             from_rob,
    rrf_fl_itf.rrf              to_fl
);
    logic [ARF_DEPTH*PRF_IDX-1:0] rrf_mem_flat;
    generate for (genvar i = 0; i < ARF_DEPTH; i++) begin
        assign rrf_mem[i] = rrf_mem_flat[i*PRF_IDX +: PRF_IDX];
    end endgenerate

    logic [ID_WIDTH-1:0]         from_rob_valid_flat, to_fl_valid_flat;
    logic [ID_WIDTH*PRF_IDX-1:0] from_rob_rd_phy_flat, to_fl_stale_flat;
    logic [ID_WIDTH*ARF_IDX-1:0] from_rob_rd_arch_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign from_rob_valid_flat[i] = from_rob.valid[i];
        assign from_rob_rd_phy_flat[i*PRF_IDX +: PRF_IDX]  = from_rob.rd_phy[i];
        assign from_rob_rd_arch_flat[i*ARF_IDX +: ARF_IDX] = from_rob.rd_arch[i];
        assign to_fl.valid[i]     = to_fl_valid_flat[i];
        assign to_fl.stale_idx[i] = to_fl_stale_flat[i*PRF_IDX +: PRF_IDX];
    end endgenerate

    rrf_spinal rrf_spinal_i (
        .clk(clk), .rst(rst),
        .rrf_mem_flat(rrf_mem_flat),
        .from_rob_valid(from_rob_valid_flat),
        .from_rob_rd_phy_flat(from_rob_rd_phy_flat),
        .from_rob_rd_arch_flat(from_rob_rd_arch_flat),
        .to_fl_valid(to_fl_valid_flat),
        .to_fl_stale_idx_flat(to_fl_stale_flat)
    );
endmodule
