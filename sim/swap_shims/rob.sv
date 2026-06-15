// Module-swap shim (ROADMAP Phase 3) for hdl/backend/rename/rob.sv. Carries the six
// SV interfaces flattened onto rob_spinal, rebuilds the hierarchically-tapped
// `rvfi_dbg_t rvfi_itf[ID_WIDTH]` from rvfi_itf_flat (so the rvfi_reference taps
// dut.backend_i.rob_i.rvfi_itf[i].<field> resolve), and surfaces the perf_monitor-
// tapped internals (viol_flush/pop/empty/branch_flush/commit_instr/head_ptr_reg/
// tail_ptr_reg) by their exact names. Used only by sim/build_swap.sh.
module rob
import cpu_params::*;
import rvfi_types::*;
(
    input   logic               clk,
    input   logic               rst,
    output  logic               backend_flush,
    output  logic   [31:0]      backend_redirect_pc,
    id_rob_itf.rob              from_id,
    rob_rrf_itf.rob             to_rrf,
    cdb_itf.rob                 cdb[CDB_WIDTH],
    cb_rob_itf.rob              from_cb,
    stq_rob_itf.rob             from_stq,
    ldq_rob_itf.rob             from_ldq
);
    localparam RVFIW = $bits(rvfi_dbg_t);

    // ---- from_id (id_rob_itf.rob) ----
    logic [ID_WIDTH-1:0]          from_id_inst_valid, from_id_is_store;
    logic [ID_WIDTH*ROB_IDX-1:0]  from_id_rob_id_flat;
    logic [ID_WIDTH*PRF_IDX-1:0]  from_id_rd_phy_flat;
    logic [ID_WIDTH*ARF_IDX-1:0]  from_id_rd_arch_flat;
    logic [ID_WIDTH*RVFIW-1:0]    from_id_rvfi_dbg_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign from_id_inst_valid[i] = from_id.inst_valid[i];
        assign from_id_is_store[i]   = from_id.is_store[i];
        assign from_id_rd_phy_flat[i*PRF_IDX +: PRF_IDX]   = from_id.rd_phy[i];
        assign from_id_rd_arch_flat[i*ARF_IDX +: ARF_IDX]  = from_id.rd_arch[i];
        assign from_id_rvfi_dbg_flat[i*RVFIW +: RVFIW]     = from_id.rvfi_dbg[i];
        assign from_id.rob_id[i] = from_id_rob_id_flat[i*ROB_IDX +: ROB_IDX];
    end endgenerate

    // ---- to_rrf (rob_rrf_itf.rob) ----
    logic [ID_WIDTH-1:0]          to_rrf_valid_flat;
    logic [ID_WIDTH*PRF_IDX-1:0]  to_rrf_rd_phy_flat;
    logic [ID_WIDTH*ARF_IDX-1:0]  to_rrf_rd_arch_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign to_rrf.valid[i]   = to_rrf_valid_flat[i];
        assign to_rrf.rd_phy[i]  = to_rrf_rd_phy_flat[i*PRF_IDX +: PRF_IDX];
        assign to_rrf.rd_arch[i] = to_rrf_rd_arch_flat[i*ARF_IDX +: ARF_IDX];
    end endgenerate

    // ---- cdb (cdb_itf.rob[CDB_WIDTH]) ----
    logic [CDB_WIDTH-1:0]         cdb_valid_flat;
    logic [CDB_WIDTH*ROB_IDX-1:0] cdb_rob_id_flat;
    logic [CDB_WIDTH*32-1:0]      cdb_rd_value_flat, cdb_rs1_dbg_flat, cdb_rs2_dbg_flat;
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin
        assign cdb_valid_flat[k]                       = cdb[k].valid;
        assign cdb_rob_id_flat[k*ROB_IDX +: ROB_IDX]   = cdb[k].rob_id;
        assign cdb_rd_value_flat[k*32 +: 32]           = cdb[k].rd_value;
        assign cdb_rs1_dbg_flat[k*32 +: 32]            = cdb[k].rs1_value_dbg;
        assign cdb_rs2_dbg_flat[k*32 +: 32]            = cdb[k].rs2_value_dbg;
    end endgenerate

    // ---- rvfi_itf[ID_WIDTH] rebuilt from rvfi_itf_flat (hierarchical tap target) ----
    logic [ID_WIDTH*RVFIW-1:0] rvfi_itf_flat;
    rvfi_dbg_t rvfi_itf [ID_WIDTH];
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign rvfi_itf[i] = rvfi_itf_flat[i*RVFIW +: RVFIW];
    end endgenerate

    // ---- perf_monitor-tapped internals (surfaced by exact name) ----
    logic                   viol_flush, pop, empty, branch_flush;
    logic [ID_WIDTH-1:0]    commit_instr;
    logic [ROB_PTR_IDX:0]   head_ptr_reg, tail_ptr_reg;

    rob_spinal rob_spinal_i (
        .clk(clk), .rst(rst),
        .backend_flush(backend_flush),
        .backend_redirect_pc(backend_redirect_pc),
        .from_id_valid(from_id.valid),
        .from_id_ready(from_id.ready),
        .from_id_inst_valid(from_id_inst_valid),
        .from_id_rob_id_flat(from_id_rob_id_flat),
        .from_id_rd_phy_flat(from_id_rd_phy_flat),
        .from_id_rd_arch_flat(from_id_rd_arch_flat),
        .from_id_is_store(from_id_is_store),
        .from_id_rvfi_dbg_flat(from_id_rvfi_dbg_flat),
        .to_rrf_valid(to_rrf_valid_flat),
        .to_rrf_rd_phy_flat(to_rrf_rd_phy_flat),
        .to_rrf_rd_arch_flat(to_rrf_rd_arch_flat),
        .cdb_valid(cdb_valid_flat),
        .cdb_rob_id_flat(cdb_rob_id_flat),
        .cdb_rd_value_flat(cdb_rd_value_flat),
        .cdb_rs1_dbg_flat(cdb_rs1_dbg_flat),
        .cdb_rs2_dbg_flat(cdb_rs2_dbg_flat),
        .from_cb_rob_id(from_cb.rob_id),
        .from_cb_miss_predict(from_cb.miss_predict),
        .from_cb_target_address(from_cb.target_address),
        .from_cb_ready(from_cb.ready),
        .from_cb_dequeue(from_cb.dequeue),
        .from_stq_rob_id(from_stq.rob_id),
        .from_stq_addr_dbg(from_stq.addr_dbg),
        .from_stq_wmask_dbg(from_stq.wmask_dbg),
        .from_stq_wdata_dbg(from_stq.wdata_dbg),
        .from_stq_rs1_value_dbg(from_stq.rs1_value_dbg),
        .from_stq_rs2_value_dbg(from_stq.rs2_value_dbg),
        .from_stq_valid(from_stq.valid),
        .from_stq_ready(from_stq.ready),
        .from_ldq_rob_id(from_ldq.rob_id),
        .from_ldq_addr_dbg(from_ldq.addr_dbg),
        .from_ldq_rmask_dbg(from_ldq.rmask_dbg),
        .from_ldq_rdata_dbg(from_ldq.rdata_dbg),
        .from_ldq_valid(from_ldq.valid),
        .from_ldq_violation(from_ldq.violation),
        .from_ldq_violation_rob_id(from_ldq.violation_rob_id),
        .rvfi_itf_flat(rvfi_itf_flat),
        .dbg_viol_flush(viol_flush),
        .dbg_pop(pop),
        .dbg_empty(empty),
        .dbg_branch_flush(branch_flush),
        .dbg_commit_instr(commit_instr),
        .dbg_head_ptr_reg(head_ptr_reg),
        .dbg_tail_ptr_reg(tail_ptr_reg)
    );
endmodule
