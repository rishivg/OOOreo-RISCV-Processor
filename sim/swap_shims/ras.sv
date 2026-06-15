// Module-swap shim for hdl/frontend/branch_predictor/ras.sv. Carries the
// `cb_bp_itf.bp from_cb` SV interface (mapped to the from_cb_* flattened ports) and
// passes the packed-2D array ports straight through onto ras_spinal (Verilator
// connects [IF_WIDTH-1:0][31:0] to a flat Bits port by name). Used only by
// sim/build_swap.sh (ras case); hdl/ stays pristine.
module ras
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,
    input   logic                   flush,
    input   logic                   fetch_fire,
    input   logic   [IF_WIDTH-1:0]  [31:0]  inst_pc,
    input   logic   [IF_WIDTH-1:0]  [31:0]  seq_next,
    input   logic   [IF_WIDTH-1:0]          inst_valid,
    input   logic   [IF_WIDTH-1:0]  [31:0]  insts,
    input   logic   [IF_WIDTH-1:0]          predict_taken_in,
    input   logic   [IF_WIDTH-1:0]  [31:0]  predict_target_in,
    output  logic   [IF_WIDTH-1:0]          predict_taken_out,
    output  logic   [IF_WIDTH-1:0]  [31:0]  predict_target_out,
    cb_bp_itf.bp                    from_cb
);
    ras_spinal ras_spinal_i (
        .clk                (clk),
        .rst                (rst),
        .flush              (flush),
        .fetch_fire         (fetch_fire),
        .inst_pc            (inst_pc),
        .seq_next           (seq_next),
        .inst_valid         (inst_valid),
        .insts              (insts),
        .predict_taken_in   (predict_taken_in),
        .predict_target_in  (predict_target_in),
        .predict_taken_out  (predict_taken_out),
        .predict_target_out (predict_target_out),
        .from_cb_update_en     (from_cb.update_en),
        .from_cb_pc            (from_cb.pc),
        .from_cb_is_call       (from_cb.is_call),
        .from_cb_is_ret        (from_cb.is_ret),
        .from_cb_is_compressed (from_cb.is_compressed)
    );
endmodule
