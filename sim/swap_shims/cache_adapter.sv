// Module-swap shim for hdl/common/cache_adapter.sv. Carries cacheline_itf.slave ufp
// + the scalar bmem dfp onto cache_adapter_spinal. Used only by sim/build_swap.sh.
module cache_adapter
(
    input   logic           clk,
    input   logic           rst,
    cacheline_itf.slave     ufp,
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    output  logic   [63:0]  dfp_wdata,
    input   logic           dfp_ready,
    input   logic   [31:0]  dfp_raddr,
    input   logic   [63:0]  dfp_rdata,
    input   logic           dfp_rvalid
);
    cache_adapter_spinal cache_adapter_spinal_i (
        .clk(clk), .rst(rst),
        .ufp_addr(ufp.addr), .ufp_read(ufp.read), .ufp_write(ufp.write), .ufp_wdata(ufp.wdata),
        .ufp_ready(ufp.ready), .ufp_rdata(ufp.rdata), .ufp_raddr(ufp.raddr), .ufp_rvalid(ufp.rvalid),
        .dfp_addr(dfp_addr), .dfp_read(dfp_read), .dfp_write(dfp_write), .dfp_wdata(dfp_wdata),
        .dfp_ready(dfp_ready), .dfp_raddr(dfp_raddr), .dfp_rdata(dfp_rdata), .dfp_rvalid(dfp_rvalid)
    );
endmodule
