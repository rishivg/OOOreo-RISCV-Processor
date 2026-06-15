// Module-swap shim for hdl/memory/store_buf.sv. Carries stq_stb_itf.stb,
// stb_dmem_itf.cache and the ldq_stb_itf.stb unpacked-array conflict ports,
// flattened onto store_buf_spinal. Used only by sim/build_swap.sh; hdl/ pristine.
module store_buf
import cpu_params::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,
    stq_stb_itf.stb             from_stq,
    stb_dmem_itf.stq            dmem,
    ldq_stb_itf.stb             from_ldq
);
    logic full;   // surfaced for perf_monitor tap stb_i.full
    logic [LDQ_DEPTH*32-1:0] ldq_addr_flat;
    logic [LDQ_DEPTH*4-1:0]  ldq_rmask_flat;
    logic [LDQ_DEPTH-1:0]    has_conflicting_store_flat;
    generate for (genvar i = 0; i < LDQ_DEPTH; i++) begin
        assign ldq_addr_flat[i*32 +: 32] = from_ldq.ldq_addr[i];
        assign ldq_rmask_flat[i*4 +: 4]  = from_ldq.ldq_rmask[i];
        assign from_ldq.has_conflicting_store[i] = has_conflicting_store_flat[i];
    end endgenerate

    store_buf_spinal store_buf_spinal_i (
        .clk(clk), .rst(rst),
        .from_stq_valid(from_stq.valid),
        .from_stq_ready(from_stq.ready),
        .from_stq_addr(from_stq.addr),
        .from_stq_wmask(from_stq.wmask),
        .from_stq_wdata(from_stq.wdata),
        .dmem_valid(dmem.valid),
        .dmem_ready(dmem.ready),
        .dmem_addr(dmem.addr),
        .dmem_wmask(dmem.wmask),
        .dmem_wdata(dmem.wdata),
        .ldq_addr_flat(ldq_addr_flat),
        .ldq_rmask_flat(ldq_rmask_flat),
        .has_conflicting_store(has_conflicting_store_flat),
        .dbg_full(full)
    );
endmodule
