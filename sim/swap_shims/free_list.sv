// Module-swap shim (ROADMAP Phase 3) for hdl/backend/rename/free_list.sv. Carries
// the SV interfaces (id_fl_itf.fl, rrf_fl_itf.fl) flattened onto free_list_spinal.
// Used only by sim/build_swap.sh; hdl/ stays pristine.
module free_list
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,
    id_fl_itf.fl                from_id,
    rrf_fl_itf.fl               from_rrf
);
    logic [ID_WIDTH-1:0]          from_id_valid_flat, from_rrf_valid_flat;
    logic [ID_WIDTH*PRF_IDX-1:0]  from_id_free_idx_flat, from_rrf_stale_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign from_id_valid_flat[i]  = from_id.valid[i];
        assign from_rrf_valid_flat[i] = from_rrf.valid[i];
        assign from_rrf_stale_flat[i*PRF_IDX +: PRF_IDX] = from_rrf.stale_idx[i];
        assign from_id.free_idx[i] = from_id_free_idx_flat[i*PRF_IDX +: PRF_IDX];
    end endgenerate

    free_list_spinal free_list_spinal_i (
        .clk(clk), .rst(rst),
        .backend_flush(backend_flush),
        .from_id_valid(from_id_valid_flat),
        .from_id_ready(from_id.ready),
        .from_id_free_idx_flat(from_id_free_idx_flat),
        .from_rrf_valid(from_rrf_valid_flat),
        .from_rrf_stale_idx_flat(from_rrf_stale_flat)
    );
endmodule
