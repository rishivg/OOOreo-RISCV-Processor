// Module-swap shim for hdl/memory/store_queue.sv. Carries the five SV interfaces
// flattened onto store_queue_spinal and surfaces the perf_monitor-tapped internals
// (want_dequeue, counter, rd_ptr_actual, and fifo[rd_ptr_actual].addr_valid -- the
// tap indexes the fifo by rd_ptr_actual, so a minimal stq_entry_t fifo[] with only
// addr_valid driven is reconstructed). Used only by sim/build_swap.sh.
module store_queue
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,
    ds_rs_mono_itf.rs           from_ds,
    agu_lsq_itf.lsq             from_agu,
    stq_rob_itf.stq             to_rob,
    stq_stb_itf.stq             to_stb,
    ldq_stq_itf.stq             from_ldq
);
    // perf-tapped internals (surfaced by exact name)
    logic                   want_dequeue;
    logic [STQ_IDX:0]       counter;
    logic [STQ_IDX-1:0]     rd_ptr_actual;
    logic [STQ_DEPTH-1:0]   addr_valid_flat;
    stq_entry_t             fifo[STQ_DEPTH];
    generate for (genvar j = 0; j < STQ_DEPTH; j++) begin
        assign fifo[j].addr_valid = addr_valid_flat[j];
    end endgenerate

    // ldq_stq arrays
    logic [LDQ_DEPTH*(STQ_IDX+1)-1:0] ldq_tracker_flat;
    logic [LDQ_DEPTH*32-1:0]          ldq_addr_flat, forward_wdata_flat;
    logic [LDQ_DEPTH*4-1:0]           ldq_rmask_flat;
    logic [LDQ_DEPTH-1:0]             hcs_flat, known_flat, unk_flat, fwden_flat;
    generate for (genvar i = 0; i < LDQ_DEPTH; i++) begin
        assign ldq_tracker_flat[i*(STQ_IDX+1) +: (STQ_IDX+1)] = from_ldq.ldq_tracker[i];
        assign ldq_addr_flat[i*32 +: 32]  = from_ldq.ldq_addr[i];
        assign ldq_rmask_flat[i*4 +: 4]   = from_ldq.ldq_rmask[i];
        assign from_ldq.has_conflicting_store[i] = hcs_flat[i];
        assign from_ldq.known_conflict[i]        = known_flat[i];
        assign from_ldq.unknown_older[i]         = unk_flat[i];
        assign from_ldq.forward_en[i]            = fwden_flat[i];
        assign from_ldq.forward_wdata[i]         = forward_wdata_flat[i*32 +: 32];
    end endgenerate

    store_queue_spinal store_queue_spinal_i (
        .clk(clk), .rst(rst), .backend_flush(backend_flush),
        .from_ds_valid(from_ds.valid),
        .from_ds_ready(from_ds.ready),
        .from_ds_uop_rob_id(from_ds.uop.rob_id),
        .from_ds_uop_fu_opcode(from_ds.uop.fu_opcode),
        .from_agu_valid(from_agu.valid),
        .from_agu_data(from_agu.data),
        .to_rob_ready(to_rob.ready),
        .to_rob_valid(to_rob.valid),
        .to_rob_rob_id(to_rob.rob_id),
        .to_rob_addr_dbg(to_rob.addr_dbg),
        .to_rob_wmask_dbg(to_rob.wmask_dbg),
        .to_rob_wdata_dbg(to_rob.wdata_dbg),
        .to_rob_rs1_value_dbg(to_rob.rs1_value_dbg),
        .to_rob_rs2_value_dbg(to_rob.rs2_value_dbg),
        .to_stb_ready(to_stb.ready),
        .to_stb_valid(to_stb.valid),
        .to_stb_wmask(to_stb.wmask),
        .to_stb_addr(to_stb.addr),
        .to_stb_wdata(to_stb.wdata),
        .ldq_tracker_flat(ldq_tracker_flat),
        .ldq_addr_flat(ldq_addr_flat),
        .ldq_rmask_flat(ldq_rmask_flat),
        .stq_tail(from_ldq.stq_tail),
        .stq_deq(from_ldq.stq_deq),
        .has_conflicting_store(hcs_flat),
        .known_conflict(known_flat),
        .unknown_older(unk_flat),
        .forward_en(fwden_flat),
        .forward_wdata_flat(forward_wdata_flat),
        .dbg_want_dequeue(want_dequeue),
        .dbg_counter(counter),
        .dbg_rd_ptr_actual(rd_ptr_actual),
        .dbg_addr_valid_flat(addr_valid_flat)
    );
endmodule
