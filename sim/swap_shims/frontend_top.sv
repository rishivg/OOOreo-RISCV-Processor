// Module-swap shim for hdl/frontend/frontend_top.sv. Carries the external SV
// interfaces (frontend_fifo_itf.frontend to_fifo [fetch_packet_t], cacheline_itf.
// master icache_itf, cb_bp_itf.bp from_cb) onto frontend_top_spinal, assembles
// to_fifo.packet per-field, and recreates the perf-tapped if1_stage_i.
// icache_unresponsive scope. frontend_top_spinal re-emits fetch_align + decompressor
// (via FetchAlign) -> EXTRA_EXCLUDE those. Used only by sim/build_swap.sh.
module frontend_top
import cpu_params::*, fetch_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,
    input   logic   [31:0]      backend_redirect_pc,
    frontend_fifo_itf.frontend  to_fifo,
    cacheline_itf.master        icache_itf,
    cb_bp_itf.bp                from_cb
);
    logic [IF_WIDTH*32-1:0] tf_inst, tf_inst_raw, tf_ptgt, tf_pc;
    logic [IF_WIDTH-1:0]    tf_comp, tf_pt, tf_valid;
    logic [GHR_LEN-1:0]     tf_ghr;
    generate for (genvar i = 0; i < IF_WIDTH; i++) begin
        assign to_fifo.packet.inst[i]           = tf_inst[i*32 +: 32];
        assign to_fifo.packet.inst_raw[i]       = tf_inst_raw[i*32 +: 32];
        assign to_fifo.packet.predict_target[i] = tf_ptgt[i*32 +: 32];
        assign to_fifo.packet.pc[i]             = tf_pc[i*32 +: 32];
        assign to_fifo.packet.is_compressed[i]  = tf_comp[i];
        assign to_fifo.packet.predict_taken[i]  = tf_pt[i];
        assign to_fifo.packet.valid[i]          = tf_valid[i];
    end endgenerate
    assign to_fifo.packet.ghr = tf_ghr;

    logic icu;   // perf tap source (surfaced into if1_stage_i scope below)

    frontend_top_spinal frontend_top_spinal_i (
        .clk(clk), .rst(rst),
        .backend_flush(backend_flush), .backend_redirect_pc(backend_redirect_pc),
        .to_fifo_valid(to_fifo.valid), .to_fifo_ready(to_fifo.ready),
        .to_fifo_inst_flat(tf_inst), .to_fifo_inst_raw_flat(tf_inst_raw),
        .to_fifo_is_compressed(tf_comp), .to_fifo_predict_taken(tf_pt),
        .to_fifo_predict_target_flat(tf_ptgt), .to_fifo_pc_flat(tf_pc),
        .to_fifo_valid_slots(tf_valid), .to_fifo_ghr(tf_ghr),
        .icache_addr(icache_itf.addr), .icache_read(icache_itf.read), .icache_write(icache_itf.write),
        .icache_wdata(icache_itf.wdata), .icache_ready(icache_itf.ready), .icache_raddr(icache_itf.raddr),
        .icache_rdata(icache_itf.rdata), .icache_rvalid(icache_itf.rvalid),
        .from_cb_update_en(from_cb.update_en), .from_cb_pc(from_cb.pc),
        .from_cb_fu_opcode(from_cb.fu_opcode), .from_cb_branch_taken(from_cb.branch_taken),
        .from_cb_target_address(from_cb.target_address), .from_cb_ghr(from_cb.ghr),
        .from_cb_is_call(from_cb.is_call), .from_cb_is_ret(from_cb.is_ret),
        .from_cb_is_compressed(from_cb.is_compressed),
        .dbg_icache_unresponsive(icu)
    );

    // recreate if1_stage_i sub-scope for perf_monitor hierarchical tap
    if (1) begin : if1_stage_i
        logic icache_unresponsive;
        assign icache_unresponsive = icu;
    end
endmodule
