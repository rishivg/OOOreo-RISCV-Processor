module verification_top
import cpu_params::*, rvfi_types::*;
(
    input wire clk, rst, irq_ext,
    output wire [31:0] bmem_addr,
    output wire bmem_read, bmem_write,
    output wire [63:0] bmem_wdata,
    input wire bmem_ready,
    input wire [31:0] bmem_raddr,
    input wire [63:0] bmem_rdata,
    input wire bmem_rvalid,
    output wire mmio_req_valid,
    input wire mmio_req_ready,
    output wire [31:0] mmio_addr, mmio_wdata,
    output wire [3:0] mmio_rmask, mmio_wmask,
    input wire mmio_resp_valid, mmio_resp_error,
    input wire [31:0] mmio_resp_rdata,
    output wire sleeping,
    output wire [31:0] debug_state, debug_front_pc,
    output wire [11:0] debug_rob_ptrs,
    output wire [127:0] debug_load_addresses,
    output wire [31:0] debug_load_block,
    output wire [ID_WIDTH-1:0] retired,
    output wire [ID_WIDTH*64-1:0] orders,
    output wire [ID_WIDTH*32-1:0] pcs, instructions, results, next_pcs,
    output wire [ID_WIDTH*5-1:0] destinations,
    output wire [ID_WIDTH*32-1:0] memory_addresses, memory_data,
    output wire [ID_WIDTH*4-1:0] store_masks
);
    wire [ID_WIDTH*$bits(rvfi_dbg_t)-1:0] rvfi_flat;
    cpu dut(.* , .scan_enable(1'b0));
    assign debug_load_addresses = dut.backend.lsuTop.ldq.ldq_addr_flat;
    assign debug_load_block = {10'b0, dut.backend.lsuTop.ldq.stq_forward_en,
        dut.backend.lsuTop.ldq.stb_has_conf, dut.backend.lsuTop.ldq.stq_known_conflict,
        dut.backend.lsuTop.ldq.stq_has_conf, dut.backend.lsuTop.ldq.stq_tail,
        dut.backend.lsuTop.ldq.block_regular, dut.backend.lsuTop.ldq.dmem_ready,
        dut.backend.lsuTop.ldq.dmem_valid};
    assign debug_front_pc = dut.frontend.if1Stage_pc;
    assign debug_rob_ptrs = {dut.backend_dbg_head_ptr_reg, dut.backend_dbg_tail_ptr_reg};
    assign debug_state = {2'b0, dut.backend_dbg_stq_counter, dut.backend_dbg_ldq_addr_valid_flat,
        dut.backend_dbg_ldq_issued_flat, dut.backend_dbg_ldq_valid_flat,
        dut.backend_dbg_ld_dmem_resp, dut.backend_dbg_dc_stall, dut.backend_dbg_dc_hit,
        dut.backend_dbg_stb_full, dut.backend_dbg_empty, dut.backend_dbg_id_rob_valid,
        dut.backend_dbg_id_rob_ready, dut.backend_from_fifo_ready,
        dut.iq_out_ready, dut.iq_out_valid, dut.frontend_dbg_icache_unresponsive,
        dut.frontend_halt_fetch, dut.sleeping, dut.backend_backend_flush, dut.backend_dbg_pop};
    for (genvar i = 0; i < ID_WIDTH; i++) begin
        wire rvfi_dbg_t r = rvfi_flat[i*$bits(rvfi_dbg_t) +: $bits(rvfi_dbg_t)];
        assign retired[i] = r.commit;
        assign orders[i*64 +: 64] = r.order;
        assign pcs[i*32 +: 32] = r.pc_rdata;
        assign instructions[i*32 +: 32] = r.inst;
        assign results[i*32 +: 32] = r.rd_wdata;
        assign next_pcs[i*32 +: 32] = r.pc_wdata;
        assign destinations[i*5 +: 5] = r.rd_addr;
        assign memory_addresses[i*32 +: 32] = r.mem_addr;
        assign memory_data[i*32 +: 32] = r.mem_wdata;
        assign store_masks[i*4 +: 4] = r.mem_wmask;
    end
endmodule
