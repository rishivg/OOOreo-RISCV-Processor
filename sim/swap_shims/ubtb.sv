// Module-swap shim for hdl/frontend/branch_predictor/ubtb.sv. Carries the
// `cb_bp_itf.bp from_cb` SV interface (mapped to the from_cb_* flattened ports) and
// passes the packed-2D array ports straight through onto ubtb_spinal. Used only by
// sim/build_swap.sh (ubtb case); hdl/ stays pristine.
module ubtb
import cpu_params::*;
(
    input   logic                           clk,
    input   logic                           rst,
    cb_bp_itf.bp                            from_cb,
    input   logic [IF_WIDTH-1:0]            predict_taken_gshare,
    input   logic [IF_WIDTH-1:0]  [31:0]    inst_pc,
    input   logic [IF_WIDTH-1:0]  [31:0]    seq_next,
    output  logic [IF_WIDTH-1:0]  [31:0]    predict_target,
    output  logic [IF_WIDTH-1:0]            predict_taken
);
    ubtb_spinal ubtb_spinal_i (
        .clk                  (clk),
        .rst                  (rst),
        .from_cb_update_en      (from_cb.update_en),
        .from_cb_pc             (from_cb.pc),
        .from_cb_fu_opcode      (from_cb.fu_opcode),
        .from_cb_branch_taken   (from_cb.branch_taken),
        .from_cb_target_address (from_cb.target_address),
        .predict_taken_gshare (predict_taken_gshare),
        .inst_pc              (inst_pc),
        .seq_next             (seq_next),
        .predict_target       (predict_target),
        .predict_taken        (predict_taken)
    );
endmodule
