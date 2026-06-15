// Module-swap shim for hdl/common/dmem_arbiter.sv. Carries ldq_dmem_itf.cache
// (load), stb_dmem_itf.cache (store) and dmem_itf.cpu (cache), flattened onto
// dmem_arbiter_spinal. Used only by sim/build_swap.sh; hdl/ stays pristine.
module dmem_arbiter
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,
    ldq_dmem_itf.cache          load,
    stb_dmem_itf.cache          store,
    dmem_itf.cpu                cache
);
    dmem_arbiter_spinal dmem_arbiter_spinal_i (
        .clk(clk), .rst(rst), .backend_flush(backend_flush),
        .load_valid(load.valid), .load_addr(load.addr), .load_rmask(load.rmask),
        .load_ready(load.ready), .load_resp(load.resp), .load_rdata(load.rdata),
        .store_valid(store.valid), .store_addr(store.addr),
        .store_wmask(store.wmask), .store_wdata(store.wdata), .store_ready(store.ready),
        .cache_addr(cache.addr), .cache_rmask(cache.rmask), .cache_wmask(cache.wmask),
        .cache_wdata(cache.wdata), .cache_rdata(cache.rdata), .cache_resp(cache.resp)
    );
endmodule
