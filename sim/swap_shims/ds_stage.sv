// Module-swap shim for hdl/backend/decode/ds_stage.sv. Carries the ds_rs_itf /
// ds_rs_mono_itf interfaces, routes the uop payload (per-slot to INT/INTM, the
// selected slot to BR/MEM), and surfaces the perf-tapped perf_*_rs_block counters
// by name. Used only by sim/build_swap.sh; hdl/ stays pristine.
module ds_stage
import cpu_params::*, uop_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               prv_valid,
    output  logic               prv_ready,
    input   logic               uops_valid[ID_WIDTH],
    input   logic   [1:0]       rs_type[ID_WIDTH],
    input   uop_t               uops[ID_WIDTH],
    ds_rs_itf.ds                to_int_rs,
    ds_rs_itf.ds                to_intm_rs,
    ds_rs_mono_itf.ds           to_br_rs,
    ds_rs_mono_itf.ds           to_mem_rs
);
    localparam SEL = $clog2(ID_WIDTH);

    logic [ID_WIDTH-1:0]   uops_valid_flat, int_v, intm_v;
    logic [ID_WIDTH*2-1:0] rs_type_flat, uop_rs_type_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign uops_valid_flat[i]            = uops_valid[i];
        assign rs_type_flat[i*2 +: 2]        = rs_type[i];
        assign uop_rs_type_flat[i*2 +: 2]    = uops[i].rs_type;
        assign to_int_rs.valid[i]  = int_v[i];
        assign to_intm_rs.valid[i] = intm_v[i];
        assign to_int_rs.uop[i]    = uops[i];
        assign to_intm_rs.uop[i]   = uops[i];
    end endgenerate

    logic [SEL-1:0] br_sel, mem_sel;
    assign to_br_rs.uop  = uops[br_sel];
    assign to_mem_rs.uop = uops[mem_sel];

    // perf counters surfaced by name for perf_monitor
    logic [31:0] perf_int_rs_block, perf_intm_rs_block, perf_br_rs_block, perf_mem_rs_block;

    ds_stage_spinal ds_stage_spinal_i (
        .clk(clk), .rst(rst),
        .prv_valid(prv_valid), .prv_ready(prv_ready),
        .uops_valid(uops_valid_flat),
        .rs_type_flat(rs_type_flat), .uop_rs_type_flat(uop_rs_type_flat),
        .to_int_rs_ready(to_int_rs.ready), .to_intm_rs_ready(to_intm_rs.ready),
        .to_br_rs_ready(to_br_rs.ready), .to_mem_rs_ready(to_mem_rs.ready),
        .to_int_rs_valid(int_v), .to_intm_rs_valid(intm_v),
        .to_br_rs_valid(to_br_rs.valid), .to_mem_rs_valid(to_mem_rs.valid),
        .br_sel(br_sel), .mem_sel(mem_sel),
        .dbg_perf_int(perf_int_rs_block), .dbg_perf_intm(perf_intm_rs_block),
        .dbg_perf_br(perf_br_rs_block), .dbg_perf_mem(perf_mem_rs_block)
    );
endmodule
