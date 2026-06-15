// Module-swap shim for hdl/memory/dcache/dcache.sv. Carries dmem_itf.cache (ufp) +
// cacheline_itf.master (dfp) flattened onto dcache_spinal, and recreates the
// perf_monitor-tapped dcache_ctrl_i.{stall,hit,rmask,wmask} sub-scope. Used only by
// sim/build_swap.sh; hdl/ stays pristine.
module dcache
import cpu_params::*;
(
    input   logic           clk,
    input   logic           rst,
    dmem_itf.cache          ufp,
    cacheline_itf.master    dfp
);
    logic       dc_stall, dc_hit;
    logic [3:0] dc_rmask, dc_wmask;

    dcache_spinal dcache_spinal_i (
        .clk(clk), .rst(rst),
        .ufp_addr(ufp.addr), .ufp_rmask(ufp.rmask), .ufp_wmask(ufp.wmask),
        .ufp_rdata(ufp.rdata), .ufp_wdata(ufp.wdata), .ufp_resp(ufp.resp),
        .dfp_addr(dfp.addr), .dfp_read(dfp.read), .dfp_write(dfp.write), .dfp_wdata(dfp.wdata),
        .dfp_ready(dfp.ready), .dfp_raddr(dfp.raddr), .dfp_rdata(dfp.rdata), .dfp_rvalid(dfp.rvalid),
        .dbg_stall(dc_stall), .dbg_hit(dc_hit), .dbg_rmask(dc_rmask), .dbg_wmask(dc_wmask)
    );

    // recreate dcache_ctrl_i sub-scope for perf_monitor hierarchical taps
    if (1) begin : dcache_ctrl_i
        logic       stall, hit;
        logic [3:0] rmask, wmask;
        assign stall = dc_stall;
        assign hit   = dc_hit;
        assign rmask = dc_rmask;
        assign wmask = dc_wmask;
    end
endmodule
