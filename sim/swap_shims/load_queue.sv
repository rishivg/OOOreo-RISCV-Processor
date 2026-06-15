// Module-swap shim for hdl/memory/load_queue.sv. Carries the seven SV interfaces
// flattened onto load_queue_spinal and surfaces the perf_monitor-tapped per-entry
// valid/addr_valid/issued (via a minimal ldq_entry_t ldq_arr[]) + issue_en. Used
// only by sim/build_swap.sh; hdl/ stays pristine.
module load_queue
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,
    ds_rs_mono_itf.rs           from_ds,
    agu_lsq_itf.lsq             from_agu,
    cdb_itf.fu                  cdb_out,
    ldq_rob_itf.ldq             to_rob,
    ldq_dmem_itf.ldq            dmem,
    ldq_stq_itf.ldq             from_stq,
    ldq_stb_itf.ldq             from_stb
);
    // perf-tapped per-entry fields + issue_en (by exact name)
    logic                   issue_en;
    logic [LDQ_DEPTH-1:0]   valid_flat, addr_valid_flat, issued_flat;
    ldq_entry_t             ldq_arr[LDQ_DEPTH];
    generate for (genvar i = 0; i < LDQ_DEPTH; i++) begin
        assign ldq_arr[i].valid      = valid_flat[i];
        assign ldq_arr[i].addr_valid = addr_valid_flat[i];
        assign ldq_arr[i].issued     = issued_flat[i];
    end endgenerate

    // ldq_stq / ldq_stb arrays
    logic [LDQ_DEPTH*(STQ_IDX+1)-1:0] ldq_tracker_flat;
    logic [LDQ_DEPTH*32-1:0]          ldq_addr_flat, stb_ldq_addr_flat, stq_fwd_wdata_flat;
    logic [LDQ_DEPTH*4-1:0]           ldq_rmask_flat, stb_ldq_rmask_flat;
    logic [LDQ_DEPTH-1:0]             stq_hcs, stq_known, stq_unk, stq_fwden, stb_hcs;
    generate for (genvar i = 0; i < LDQ_DEPTH; i++) begin
        assign from_stq.ldq_tracker[i] = ldq_tracker_flat[i*(STQ_IDX+1) +: (STQ_IDX+1)];
        assign from_stq.ldq_addr[i]    = ldq_addr_flat[i*32 +: 32];
        assign from_stq.ldq_rmask[i]   = ldq_rmask_flat[i*4 +: 4];
        assign from_stb.ldq_addr[i]    = stb_ldq_addr_flat[i*32 +: 32];
        assign from_stb.ldq_rmask[i]   = stb_ldq_rmask_flat[i*4 +: 4];
        assign stq_hcs[i]    = from_stq.has_conflicting_store[i];
        assign stq_known[i]  = from_stq.known_conflict[i];
        assign stq_unk[i]    = from_stq.unknown_older[i];
        assign stq_fwden[i]  = from_stq.forward_en[i];
        assign stq_fwd_wdata_flat[i*32 +: 32] = from_stq.forward_wdata[i];
        assign stb_hcs[i]    = from_stb.has_conflicting_store[i];
    end endgenerate

    load_queue_spinal load_queue_spinal_i (
        .clk(clk), .rst(rst), .backend_flush(backend_flush),
        .from_ds_valid(from_ds.valid),
        .from_ds_ready(from_ds.ready),
        .from_ds_uop_rob_id(from_ds.uop.rob_id),
        .from_ds_uop_fu_opcode(from_ds.uop.fu_opcode),
        .from_ds_uop_rd_arch(from_ds.uop.rd_arch),
        .from_ds_uop_rd_phy(from_ds.uop.rd_phy),
        .from_agu_valid(from_agu.valid),
        .from_agu_data(from_agu.data),
        .cdb_rob_id(cdb_out.rob_id),
        .cdb_rd_phy(cdb_out.rd_phy),
        .cdb_rd_arch(cdb_out.rd_arch),
        .cdb_rd_value(cdb_out.rd_value),
        .cdb_rs1_value_dbg(cdb_out.rs1_value_dbg),
        .cdb_rs2_value_dbg(cdb_out.rs2_value_dbg),
        .cdb_valid(cdb_out.valid),
        .to_rob_rob_id(to_rob.rob_id),
        .to_rob_addr_dbg(to_rob.addr_dbg),
        .to_rob_rmask_dbg(to_rob.rmask_dbg),
        .to_rob_rdata_dbg(to_rob.rdata_dbg),
        .to_rob_valid(to_rob.valid),
        .to_rob_violation(to_rob.violation),
        .to_rob_violation_rob_id(to_rob.violation_rob_id),
        .dmem_valid(dmem.valid),
        .dmem_ready(dmem.ready),
        .dmem_addr(dmem.addr),
        .dmem_rmask(dmem.rmask),
        .dmem_resp(dmem.resp),
        .dmem_rdata(dmem.rdata),
        .stq_tail(from_stq.stq_tail),
        .stq_deq(from_stq.stq_deq),
        .stq_has_conf(stq_hcs),
        .stq_known_conflict(stq_known),
        .stq_unknown_older(stq_unk),
        .stq_forward_en(stq_fwden),
        .stq_forward_wdata_flat(stq_fwd_wdata_flat),
        .ldq_tracker_flat(ldq_tracker_flat),
        .ldq_addr_flat(ldq_addr_flat),
        .ldq_rmask_flat(ldq_rmask_flat),
        .stb_has_conf(stb_hcs),
        .stb_ldq_addr_flat(stb_ldq_addr_flat),
        .stb_ldq_rmask_flat(stb_ldq_rmask_flat),
        .dbg_valid_flat(valid_flat),
        .dbg_addr_valid_flat(addr_valid_flat),
        .dbg_issued_flat(issued_flat),
        .dbg_issue_en(issue_en)
    );
endmodule
