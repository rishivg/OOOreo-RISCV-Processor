// Module-swap shim for hdl/frontend/inst_queue.sv. Carries frontend_fifo_itf
// (fetch_packet_t in) + fifo_backend_itf (decode_packet_t out) via per-field
// extraction onto inst_queue_spinal, and surfaces the perf-tapped `empty`.
// Used only by sim/build_swap.sh; hdl/ stays pristine.
module inst_queue
import fetch_types::*, cpu_params::*; #(
    parameter DEPTH = 16
)
(
    input   logic               clk,
    input   logic               rst,
    frontend_fifo_itf.fifo      in,
    fifo_backend_itf.fifo       out
);
    logic [IF_WIDTH*32-1:0] in_inst_flat, in_inst_raw_flat, in_predict_target_flat, in_pc_flat;
    logic [IF_WIDTH-1:0]    in_is_compressed, in_predict_taken, in_valid_slots;
    generate for (genvar i = 0; i < IF_WIDTH; i++) begin
        assign in_inst_flat[i*32 +: 32]           = in.packet.inst[i];
        assign in_inst_raw_flat[i*32 +: 32]       = in.packet.inst_raw[i];
        assign in_predict_target_flat[i*32 +: 32] = in.packet.predict_target[i];
        assign in_pc_flat[i*32 +: 32]             = in.packet.pc[i];
        assign in_is_compressed[i] = in.packet.is_compressed[i];
        assign in_predict_taken[i] = in.packet.predict_taken[i];
        assign in_valid_slots[i]   = in.packet.valid[i];
    end endgenerate

    logic [ID_WIDTH*32-1:0]      out_inst_flat, out_inst_raw_flat, out_predict_target_flat, out_pc_flat;
    logic [ID_WIDTH-1:0]         out_is_compressed, out_predict_taken, out_valid_slots;
    logic [ID_WIDTH*GHR_LEN-1:0] out_ghr_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign out.packet.inst[i]           = out_inst_flat[i*32 +: 32];
        assign out.packet.inst_raw[i]       = out_inst_raw_flat[i*32 +: 32];
        assign out.packet.predict_target[i] = out_predict_target_flat[i*32 +: 32];
        assign out.packet.pc[i]             = out_pc_flat[i*32 +: 32];
        assign out.packet.ghr[i]            = out_ghr_flat[i*GHR_LEN +: GHR_LEN];
        assign out.packet.is_compressed[i]  = out_is_compressed[i];
        assign out.packet.predict_taken[i]  = out_predict_taken[i];
        assign out.packet.valid[i]          = out_valid_slots[i];
    end endgenerate

    logic empty;   // surfaced for perf_monitor tap inst_queue_i.empty

    inst_queue_spinal inst_queue_spinal_i (
        .clk(clk), .rst(rst),
        .in_valid(in.valid), .in_ready(in.ready),
        .in_inst_flat(in_inst_flat), .in_inst_raw_flat(in_inst_raw_flat),
        .in_is_compressed(in_is_compressed), .in_predict_taken(in_predict_taken),
        .in_predict_target_flat(in_predict_target_flat), .in_pc_flat(in_pc_flat),
        .in_valid_slots(in_valid_slots), .in_ghr(in.packet.ghr),
        .out_valid(out.valid), .out_ready(out.ready),
        .out_inst_flat(out_inst_flat), .out_inst_raw_flat(out_inst_raw_flat),
        .out_is_compressed(out_is_compressed), .out_predict_taken(out_predict_taken),
        .out_predict_target_flat(out_predict_target_flat), .out_pc_flat(out_pc_flat),
        .out_valid_slots(out_valid_slots), .out_ghr_flat(out_ghr_flat),
        .dbg_empty(empty)
    );
endmodule
