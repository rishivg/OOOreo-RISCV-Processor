// Module-swap shim for hdl/frontend/branch_predictor/tage.sv. Carries the
// `cb_bp_itf.bp from_cb` SV interface (mapped to the from_cb_* flattened ports) and
// passes the packed-2D inst_pc port straight through onto tage_spinal. Used only by
// sim/build_swap.sh (tage case); hdl/ stays pristine.
module tage
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,
    cb_bp_itf.bp                    from_cb,
    input   logic [IF_WIDTH-1:0] [31:0] inst_pc,
    input   logic                   flush,
    input   logic                   spec_update_en,
    input   logic [IF_WIDTH-1:0]    spec_br_valid,
    input   logic [IF_WIDTH-1:0]    spec_br_taken,
    output  logic [GHR_LEN-1:0]     ghr_snapshot,
    output  logic [IF_WIDTH-1:0]    predict_taken
);
    tage_spinal tage_spinal_i (
        .clk                  (clk),
        .rst                  (rst),
        .from_cb_update_en      (from_cb.update_en),
        .from_cb_pc             (from_cb.pc),
        .from_cb_branch_taken   (from_cb.branch_taken),
        .from_cb_ghr            (from_cb.ghr),
        .inst_pc              (inst_pc),
        .flush                (flush),
        .spec_update_en       (spec_update_en),
        .spec_br_valid        (spec_br_valid),
        .spec_br_taken        (spec_br_taken),
        .ghr_snapshot         (ghr_snapshot),
        .predict_taken        (predict_taken)
    );
endmodule
