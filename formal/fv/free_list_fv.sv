// Formal wrapper for the rename free list.
//
// free_list uses SV interfaces (id_fl_itf / rrf_fl_itf), which open-source yosys
// cannot read. This wrapper exposes the interface fields as plain ports so the
// formal engine drives them freely; sv2v (see ../Makefile) then inlines both the
// interfaces and free_list into a single flat module. The inline assertion in
// free_list.sv (`fl_no_overflow`) comes along, plus the ones added below.
module free_list_fv
import cpu_params::*;
(
    input  logic                clk,
    input  logic                rst,
    input  logic                backend_flush,
    input  logic                id_valid       [ID_WIDTH],
    input  logic [PRF_IDX-1:0]  rrf_stale_idx  [ID_WIDTH],
    input  logic                rrf_valid      [ID_WIDTH]
);
    id_fl_itf  id_fl();
    rrf_fl_itf rrf_fl();

    always_comb begin
        for (int i = 0; i < ID_WIDTH; i++) begin
            id_fl.valid[i]      = id_valid[i];
            rrf_fl.valid[i]     = rrf_valid[i];
            rrf_fl.stale_idx[i] = rrf_stale_idx[i];
        end
    end

    free_list dut (
        .clk           (clk),
        .rst           (rst),
        .backend_flush (backend_flush),
        .from_id       (id_fl.fl),
        .from_rrf      (rrf_fl.fl)
    );

    // Environment constraint: rename only pops when it is ready (mirrors the
    // dispatch handshake in id_stage). Without it the BMC could pop an empty
    // free list -- not a reachable state in the real pipeline.
    logic any_id_valid;
    always_comb begin
        any_id_valid = 1'b0;
        for (int i = 0; i < ID_WIDTH; i++) if (id_fl.valid[i]) any_id_valid = 1'b1;
    end
    assume property (@(posedge clk) disable iff (rst)
        (any_id_valid |-> id_fl.ready));

    // Liveness-ish safety: a non-architectural physreg handed out as free_idx
    // must be in the non-architectural range [ARF_DEPTH, PRF_DEPTH).
    // (The reset initialization guarantees this; rename corruption would break it.)
    fv_free_idx_in_range: assert property (@(posedge clk) disable iff (rst)
        (id_fl.ready |-> (id_fl.free_idx[0] >= PRF_IDX'(ARF_DEPTH))));
endmodule
