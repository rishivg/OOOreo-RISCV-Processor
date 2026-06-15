// Module-swap shim for hdl/memory/dcache/hit_detection.sv. Parameterized (absorbs
// the dcache `#(...)` override) and un-flattens the unpacked-array inputs onto the
// fixed-config hit_detection_spinal. Used only by sim/build_swap.sh; hdl/ pristine.
module hit_detection
import dcache_types::*; #(
    parameter TAG_IDX = 23, parameter NUM_WAYS = 4, parameter WAY_BITS = 2
)
(
    input   logic   [TAG_IDX-1:0]   tag,
    input   logic   [TAG_IDX:0]     tag_arr_out[NUM_WAYS],
    input   logic   [0:0]           valid_arr_out[NUM_WAYS],
    output  logic                   hit,
    output  logic   [WAY_BITS-1:0]  hit_way
);
    localparam TAW = TAG_IDX + 1;
    logic [NUM_WAYS*TAW-1:0] tag_arr_flat;
    logic [NUM_WAYS-1:0]     valid_arr_flat;
    generate for (genvar k = 0; k < NUM_WAYS; k++) begin
        assign tag_arr_flat[k*TAW +: TAW] = tag_arr_out[k];
        assign valid_arr_flat[k] = valid_arr_out[k];
    end endgenerate

    hit_detection_spinal hit_detection_spinal_i (
        .tag            (tag),
        .tag_arr_flat   (tag_arr_flat),
        .valid_arr_flat (valid_arr_flat),
        .hit            (hit),
        .hit_way        (hit_way)
    );
endmodule
