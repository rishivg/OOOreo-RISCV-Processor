// Module-swap shim for hdl/backend/backend_top.sv. Carries the external SV
// interfaces (fifo_backend_itf, cacheline_itf.master, cb_bp_itf.cb), instantiates
// the real SV fu_div (externalised from intm_rs, keeps DW_div_seq + div_start tap),
// and recreates every perf_monitor-tapped sub-scope + the rob_i.rvfi_itf record.
// backend_top_spinal re-emits decoder/fu_agu/fu_mul/dcache_ctrl -> EXTRA_EXCLUDE.
// Used only by sim/build_swap.sh; hdl/ stays pristine.
module backend_top
import cpu_params::*, uop_types::*, lsu_types::*, int_rs_types::*, rvfi_types::*, fetch_types::*;
(
    input   logic               clk,
    input   logic               rst,
    fifo_backend_itf.backend    from_fifo,
    cacheline_itf.master        dcache_itf,
    output  logic               backend_flush,
    output  logic   [31:0]      backend_redirect_pc,
    cb_bp_itf.cb                to_bp
);
    localparam RVFIW = $bits(rvfi_dbg_t);

    // from_fifo decode_packet_t extraction
    logic [ID_WIDTH*32-1:0]      ff_inst, ff_inst_raw, ff_ptgt, ff_pc;
    logic [ID_WIDTH-1:0]         ff_comp, ff_pt, ff_valid;
    logic [ID_WIDTH*GHR_LEN-1:0] ff_ghr;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign ff_inst[i*32 +: 32]     = from_fifo.packet.inst[i];
        assign ff_inst_raw[i*32 +: 32] = from_fifo.packet.inst_raw[i];
        assign ff_ptgt[i*32 +: 32]     = from_fifo.packet.predict_target[i];
        assign ff_pc[i*32 +: 32]       = from_fifo.packet.pc[i];
        assign ff_comp[i]  = from_fifo.packet.is_compressed[i];
        assign ff_pt[i]    = from_fifo.packet.predict_taken[i];
        assign ff_valid[i] = from_fifo.packet.valid[i];
        assign ff_ghr[i*GHR_LEN +: GHR_LEN] = from_fifo.packet.ghr[i];
    end endgenerate

    // externalised div + all perf dbg
    logic                   div_prv_valid, div_prv_ready, div_nxt_valid, div_nxt_ready;
    intm_rs_reg_t           div_iss_in;
    fu_cdb_reg_t            div_cdb_out;
    logic        dbg_fu_br_valid, dbg_miss_predict; logic [$bits(fu_br_reg_t)-1:0] dbg_reg_out;
    logic [31:0] perf_int_rs_block, perf_intm_rs_block, perf_br_rs_block, perf_mem_rs_block;
    logic        idr_valid, idr_ready; logic [ID_WIDTH-1:0] idr_inst_valid;
    logic        mul_start_w, ldq_viol_w, stb_full_w, stq_wantdeq_w, ldq_issue_en_w, ld_dmem_resp_w;
    logic        dc_stall_w, dc_hit_w; logic [3:0] dc_rmask_w, dc_wmask_w;
    logic [STQ_IDX:0]     stq_counter_w; logic [STQ_IDX-1:0] stq_rdp_w; logic [STQ_DEPTH-1:0] stq_av_w;
    logic [LDQ_DEPTH-1:0] ldq_v_w, ldq_av_w, ldq_iss_w;
    logic        rb_viol, rb_pop, rb_empty, rb_bflush; logic [ID_WIDTH-1:0] rb_commit;
    logic [ROB_PTR_IDX:0] rb_head, rb_tail;
    logic [ID_WIDTH*RVFIW-1:0] rvfi_flat;

    backend_top_spinal backend_top_spinal_i (
        .clk(clk), .rst(rst),
        .backend_flush(backend_flush), .backend_redirect_pc(backend_redirect_pc),
        .from_fifo_valid(from_fifo.valid), .from_fifo_ready(from_fifo.ready),
        .ff_inst_flat(ff_inst), .ff_inst_raw_flat(ff_inst_raw), .ff_is_compressed(ff_comp),
        .ff_predict_taken(ff_pt), .ff_predict_target_flat(ff_ptgt), .ff_pc_flat(ff_pc),
        .ff_valid_slots(ff_valid), .ff_ghr_flat(ff_ghr),
        .dfp_addr(dcache_itf.addr), .dfp_read(dcache_itf.read), .dfp_write(dcache_itf.write), .dfp_wdata(dcache_itf.wdata),
        .dfp_ready(dcache_itf.ready), .dfp_raddr(dcache_itf.raddr), .dfp_rdata(dcache_itf.rdata), .dfp_rvalid(dcache_itf.rvalid),
        .to_bp_update_en(to_bp.update_en), .to_bp_pc(to_bp.pc), .to_bp_fu_opcode(to_bp.fu_opcode),
        .to_bp_branch_taken(to_bp.branch_taken), .to_bp_target(to_bp.target_address), .to_bp_ghr(to_bp.ghr),
        .to_bp_is_call(to_bp.is_call), .to_bp_is_ret(to_bp.is_ret), .to_bp_is_compressed(to_bp.is_compressed),
        .div_prv_valid(div_prv_valid), .div_prv_ready(div_prv_ready),
        .div_nxt_valid(div_nxt_valid), .div_nxt_ready(div_nxt_ready),
        .div_iss_in(div_iss_in), .div_cdb_out(div_cdb_out),
        .dbg_fu_br_valid(dbg_fu_br_valid), .dbg_miss_predict(dbg_miss_predict), .dbg_reg_out(dbg_reg_out),
        .dbg_perf_int(perf_int_rs_block), .dbg_perf_intm(perf_intm_rs_block),
        .dbg_perf_br(perf_br_rs_block), .dbg_perf_mem(perf_mem_rs_block),
        .dbg_id_rob_valid(idr_valid), .dbg_id_rob_ready(idr_ready), .dbg_id_rob_inst_valid(idr_inst_valid),
        .dbg_mul_start(mul_start_w), .dbg_ldq_violation(ldq_viol_w),
        .dbg_stb_full(stb_full_w), .dbg_stq_want_dequeue(stq_wantdeq_w), .dbg_stq_counter(stq_counter_w),
        .dbg_stq_rd_ptr_actual(stq_rdp_w), .dbg_stq_addr_valid_flat(stq_av_w),
        .dbg_ldq_valid_flat(ldq_v_w), .dbg_ldq_addr_valid_flat(ldq_av_w), .dbg_ldq_issued_flat(ldq_iss_w),
        .dbg_ldq_issue_en(ldq_issue_en_w),
        .dbg_dc_stall(dc_stall_w), .dbg_dc_hit(dc_hit_w), .dbg_dc_rmask(dc_rmask_w), .dbg_dc_wmask(dc_wmask_w),
        .dbg_ld_dmem_resp(ld_dmem_resp_w),
        .dbg_viol_flush(rb_viol), .dbg_pop(rb_pop), .dbg_empty(rb_empty), .dbg_branch_flush(rb_bflush),
        .dbg_commit_instr(rb_commit), .dbg_head_ptr_reg(rb_head), .dbg_tail_ptr_reg(rb_tail),
        .rvfi_itf_flat(rvfi_flat)
    );

    // ---- perf-tap sub-scopes ----
    if (1) begin : ds_stage_i
        logic [31:0] perf_int_rs_block, perf_intm_rs_block, perf_br_rs_block, perf_mem_rs_block;
        assign perf_int_rs_block  = backend_top.perf_int_rs_block;
        assign perf_intm_rs_block = backend_top.perf_intm_rs_block;
        assign perf_br_rs_block   = backend_top.perf_br_rs_block;
        assign perf_mem_rs_block  = backend_top.perf_mem_rs_block;
    end
    if (1) begin : id_rob_itf_i
        logic valid, ready; logic [ID_WIDTH-1:0] inst_valid;
        assign valid = idr_valid; assign ready = idr_ready; assign inst_valid = idr_inst_valid;
    end
    if (1) begin : branch_i
        if (1) begin : br_rs_i
            if (1) begin : fu_br_i
                logic fu_br_valid, miss_predict; fu_br_reg_t fu_br_reg_out;
                assign fu_br_valid = dbg_fu_br_valid; assign miss_predict = dbg_miss_predict; assign fu_br_reg_out = dbg_reg_out;
            end
        end
    end
    if (1) begin : intm_rs_gen
        if (1) begin : intm_rs_i
            if (1) begin : fu_mul_i
                logic mul_start; assign mul_start = mul_start_w;
            end
            fu_div fu_div_i (
                .clk(clk), .rst(rst || backend_flush),
                .prv_valid(div_prv_valid), .prv_ready(div_prv_ready),
                .nxt_valid(div_nxt_valid), .nxt_ready(div_nxt_ready),
                .iss_in(div_iss_in), .cdb_out(div_cdb_out)
            );
        end
    end
    if (1) begin : ldq_rob_itf
        logic violation; assign violation = ldq_viol_w;
    end
    if (1) begin : lsu_i
        if (1) begin : stb_i logic full; assign full = stb_full_w; end
        if (1) begin : stq_i
            logic want_dequeue; logic [STQ_IDX:0] counter; logic [STQ_IDX-1:0] rd_ptr_actual; stq_entry_t fifo[STQ_DEPTH];
            assign want_dequeue = stq_wantdeq_w; assign counter = stq_counter_w; assign rd_ptr_actual = stq_rdp_w;
            for (genvar j = 0; j < STQ_DEPTH; j++) assign fifo[j].addr_valid = stq_av_w[j];
        end
        if (1) begin : ldq_i
            logic issue_en; ldq_entry_t ldq_arr[LDQ_DEPTH];
            assign issue_en = ldq_issue_en_w;
            for (genvar i = 0; i < LDQ_DEPTH; i++) begin
                assign ldq_arr[i].valid = ldq_v_w[i]; assign ldq_arr[i].addr_valid = ldq_av_w[i]; assign ldq_arr[i].issued = ldq_iss_w[i];
            end
        end
        if (1) begin : dcache_i if (1) begin : dcache_ctrl_i
            logic stall, hit; logic [3:0] rmask, wmask;
            assign stall = dc_stall_w; assign hit = dc_hit_w; assign rmask = dc_rmask_w; assign wmask = dc_wmask_w;
        end end
        if (1) begin : ld_dmem_itf_i logic resp; assign resp = ld_dmem_resp_w; end
    end
    if (1) begin : rob_i
        logic viol_flush, pop, empty, branch_flush, backend_flush; logic [ID_WIDTH-1:0] commit_instr;
        logic [ROB_PTR_IDX:0] head_ptr_reg, tail_ptr_reg;
        rvfi_dbg_t rvfi_itf[ID_WIDTH];
        assign viol_flush = rb_viol; assign pop = rb_pop; assign empty = rb_empty; assign branch_flush = rb_bflush;
        assign backend_flush = backend_top.backend_flush;
        assign commit_instr = rb_commit; assign head_ptr_reg = rb_head; assign tail_ptr_reg = rb_tail;
        for (genvar i = 0; i < ID_WIDTH; i++) assign rvfi_itf[i] = rvfi_flat[i*RVFIW +: RVFIW];
    end
endmodule
