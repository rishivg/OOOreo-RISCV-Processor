// Module-swap shim for hdl/frontend/if1_stage.sv. Carries the cacheline_itf.master
// icache_itf + packed-2D insts onto if1_stage_spinal and surfaces the perf_monitor-
// tapped icache_unresponsive by name. if1_stage_spinal re-emits icache_spinal +
// icache_ctrl_spinal (distinct from the SV icache/icache_ctrl -> no exclude needed).
// Used only by sim/build_swap.sh; hdl/ stays pristine.
module if1_stage
import cpu_params::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           flush,
    input   logic           prv_valid,
    output  logic           prv_ready,
    output  logic           nxt_valid,
    input   logic           nxt_ready,
    input   logic   [31:0]  pc_next,
    output  logic   [31:0]                  pc,
    output  logic   [IF_WIDTH-1:0]  [31:0]  insts,
    cacheline_itf.master    icache_itf
);
    logic icache_unresponsive;   // surfaced for perf_monitor tap

    if1_stage_spinal if1_stage_spinal_i (
        .clk(clk), .rst(rst), .flush(flush),
        .prv_valid(prv_valid), .prv_ready(prv_ready),
        .nxt_valid(nxt_valid), .nxt_ready(nxt_ready),
        .pc_next(pc_next), .pc(pc), .insts(insts),
        .icache_addr(icache_itf.addr), .icache_read(icache_itf.read), .icache_write(icache_itf.write),
        .icache_wdata(icache_itf.wdata), .icache_ready(icache_itf.ready), .icache_raddr(icache_itf.raddr),
        .icache_rdata(icache_itf.rdata), .icache_rvalid(icache_itf.rvalid),
        .dbg_icache_unresponsive(icache_unresponsive)
    );
endmodule
