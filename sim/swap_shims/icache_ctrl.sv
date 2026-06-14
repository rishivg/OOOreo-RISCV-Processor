// Module-swap shim for hdl/frontend/icache/icache_ctrl.sv. Parameterized (absorbs
// the icache `#(...)` override) and un-flattens the unpacked-array inputs
// (tag_arr_out/valid_arr_out) onto the fixed-config SpinalHDL icache_ctrl_spinal.
// Used only by sim/build_swap.sh (icache_ctrl case); hdl/ stays pristine.
module icache_ctrl
import icache_types::*; #(
    parameter TAG_IDX = 21, parameter NUM_WAYS = 4, parameter WAY_BITS = 2,
    parameter OFFSET_IDX = 5, parameter SET_IDX = 6
)
(
    input   logic                   clk,
    input   logic                   rst,
    input   logic                   kill,
    input   logic                   read,
    input   logic   [TAG_IDX-1:0]   tag,
    input   logic   [SET_IDX-1:0]   set,
    input   logic   [TAG_IDX:0]     tag_arr_out[NUM_WAYS],
    input   logic                   valid_arr_out[NUM_WAYS],
    output  logic                   stall,
    output  logic                   allocate_done,
    output  logic   [WAY_BITS-1:0]  hit_way,
    output  logic   [31:0]          dfp_addr,
    output  logic                   dfp_read,
    output  logic                   dfp_write,
    input   logic                   dfp_ready,
    input   logic   [31:0]          dfp_raddr,
    input   logic                   dfp_rvalid
);
    localparam TAW = TAG_IDX + 1;
    logic [NUM_WAYS*TAW-1:0] tag_arr_flat;
    logic [NUM_WAYS-1:0]     valid_arr_flat;
    generate for (genvar k = 0; k < NUM_WAYS; k++) begin
        assign tag_arr_flat[k*TAW +: TAW] = tag_arr_out[k];
        assign valid_arr_flat[k] = valid_arr_out[k];
    end endgenerate

    icache_ctrl_spinal icache_ctrl_spinal_i (
        .clk            (clk),
        .rst            (rst),
        .kill           (kill),
        .read           (read),
        .tag            (tag),
        .set            (set),
        .tag_arr_flat   (tag_arr_flat),
        .valid_arr_flat (valid_arr_flat),
        .stall          (stall),
        .allocate_done  (allocate_done),
        .hit_way        (hit_way),
        .dfp_addr       (dfp_addr),
        .dfp_read       (dfp_read),
        .dfp_write      (dfp_write),
        .dfp_ready      (dfp_ready),
        .dfp_raddr      (dfp_raddr),
        .dfp_rvalid     (dfp_rvalid)
    );
endmodule
