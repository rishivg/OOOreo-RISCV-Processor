// Module-swap shim for hdl/common/bmem_arbiter.sv. Carries the three cacheline
// interfaces (icache/dcache slave, adapter master) onto bmem_arbiter_spinal.
// Used only by sim/build_swap.sh; hdl/ stays pristine.
module bmem_arbiter
(
    input   logic               clk,
    input   logic               rst,
    cacheline_itf.slave         icache,
    cacheline_itf.slave         dcache,
    cacheline_itf.master        adapter
);
    bmem_arbiter_spinal bmem_arbiter_spinal_i (
        .clk(clk), .rst(rst),
        .icache_addr(icache.addr), .icache_read(icache.read), .icache_write(icache.write), .icache_wdata(icache.wdata),
        .icache_ready(icache.ready), .icache_rdata(icache.rdata), .icache_raddr(icache.raddr), .icache_rvalid(icache.rvalid),
        .dcache_addr(dcache.addr), .dcache_read(dcache.read), .dcache_write(dcache.write), .dcache_wdata(dcache.wdata),
        .dcache_ready(dcache.ready), .dcache_rdata(dcache.rdata), .dcache_raddr(dcache.raddr), .dcache_rvalid(dcache.rvalid),
        .adapter_addr(adapter.addr), .adapter_read(adapter.read), .adapter_write(adapter.write), .adapter_wdata(adapter.wdata),
        .adapter_ready(adapter.ready), .adapter_raddr(adapter.raddr), .adapter_rdata(adapter.rdata), .adapter_rvalid(adapter.rvalid)
    );
endmodule
