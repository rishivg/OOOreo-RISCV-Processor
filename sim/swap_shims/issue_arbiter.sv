// Module-swap shim (ROADMAP Phase 2 / subsystem start). Drop-in for
// hdl/backend/execute/int_rs/issue_arbiter.sv: same ports (incl. the unpacked-array
// outputs rs_compress/fu_issue), body un-flattens the packed outputs of the SpinalHDL
// `issue_arbiter_spinal`. Used only by sim/build_swap.sh (issue_arbiter case).
module issue_arbiter
import cpu_params::*;
(
    input   logic   [INTRS_DEPTH-1:0]       rs_request,
    output  logic   [INTRS_DEPTH-1:0]       rs_grant,
    output  logic   [INT_ISSUE_WIDTH-1:0]   rs_compress  [INTRS_DEPTH],
    output  logic   [INTRS_DEPTH-1:0]       fu_issue     [INT_ISSUE_WIDTH]
);

    logic [2*INTRS_DEPTH-1:0]            rs_compress_flat;
    logic [INT_ISSUE_WIDTH*INTRS_DEPTH-1:0] fu_issue_flat;

    issue_arbiter_spinal issue_arbiter_spinal_i (
        .rs_request       (rs_request),
        .rs_grant         (rs_grant),
        .rs_compress_flat (rs_compress_flat),
        .fu_issue_flat    (fu_issue_flat)
    );

    // un-flatten: rs_compress[i] = bits [2i+1:2i] ; fu_issue[w] = bits [16w+15:16w]
    always_comb begin
        for (int i = 0; i < INTRS_DEPTH; i++)
            rs_compress[i] = rs_compress_flat[2*i +: 2];
        for (int w = 0; w < INT_ISSUE_WIDTH; w++)
            fu_issue[w] = fu_issue_flat[INTRS_DEPTH*w +: INTRS_DEPTH];
    end

endmodule
