// Module-swap shim for hdl/frontend/icache/icache.sv. Parameterized (absorbs the
// if1_stage `#(.IF_WIDTH(..))` override) and passes the packed-2D ufp_rdata + the
// cacheline_itf.master dfp onto icache_spinal. Used only by sim/build_swap.sh.
module icache
import icache_types::*, cpu_params::*; #(
    parameter IF_WIDTH = 2, parameter OFFSET_IDX = I_OFFSET_IDX, parameter SET_IDX = I_SET_IDX,
    parameter TAG_IDX = I_TAG_IDX, parameter NUM_WAYS = I_NUM_WAYS
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic   [31:0]                  ufp_addr,
    input   logic                           ufp_read,
    output  logic   [IF_WIDTH-1:0]  [31:0]  ufp_rdata,
    output  logic                           ufp_resp,
    input   logic                           kill,
    cacheline_itf.master    dfp
);
    icache_spinal icache_spinal_i (
        .clk(clk), .rst(rst),
        .ufp_addr(ufp_addr), .ufp_read(ufp_read), .ufp_rdata(ufp_rdata),
        .ufp_resp(ufp_resp), .kill(kill),
        .dfp_addr(dfp.addr), .dfp_read(dfp.read), .dfp_write(dfp.write), .dfp_wdata(dfp.wdata),
        .dfp_ready(dfp.ready), .dfp_raddr(dfp.raddr), .dfp_rdata(dfp.rdata), .dfp_rvalid(dfp.rvalid)
    );
endmodule
