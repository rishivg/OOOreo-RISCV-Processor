// Module-swap shim (ROADMAP Phase 3) for hdl/memory/lsu_top.sv. Carries the
// external SV interfaces, builds mem_rs_entry + uop fields + flattened cdb/bypass,
// and recreates the perf_monitor-tapped sub-instance scopes (stb_i / stq_i / ldq_i /
// dcache_i.dcache_ctrl_i). lsu_top_spinal re-emits fu_agu + dcache_ctrl, dropped via
// EXTRA_EXCLUDE. Used only by sim/build_swap.sh; hdl/ stays pristine.
module lsu_top
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    ds_rs_mono_itf.rs           from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out,
    ldq_rob_itf.ldq             ld_to_rob,
    stq_rob_itf.stq             st_to_rob,
    cacheline_itf.master        dcache_itf,
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS],
    input   logic               backend_flush
);
    // ---- mem_rs entry extraction (mirrors mem_rs shim) ----
    localparam EW = $bits(mem_rs_entry_t);   // 56
    mem_rs_entry_t  ds_entry;
    logic [EW-1:0]  ds_entry_flat;
    always_comb begin
        ds_entry.rob_id    = from_ds.uop.rob_id;
        ds_entry.rs1_phy   = from_ds.uop.rs1_phy;
        ds_entry.rs1_valid = from_ds.uop.rs1_valid;
        ds_entry.rs2_phy   = from_ds.uop.rs2_phy;
        ds_entry.rs2_valid = from_ds.uop.rs2_valid;
        ds_entry.imm       = from_ds.uop.imm;
        ds_entry.fu_opcode = from_ds.uop.fu_opcode;
    end
    assign ds_entry_flat = ds_entry;

    // ---- cdb_itf.rs[CDB_WIDTH] + alu_bypass flatten ----
    logic [CDB_WIDTH*PRF_IDX-1:0] cdb_rd_phy_flat;
    logic [CDB_WIDTH-1:0]         cdb_valid_flat;
    generate for (genvar k = 0; k < CDB_WIDTH; k++) begin
        assign cdb_rd_phy_flat[k*PRF_IDX +: PRF_IDX] = cdb[k].rd_phy;
        assign cdb_valid_flat[k] = cdb[k].valid;
    end endgenerate
    logic [NUM_FAST_BYPASS*$bits(bypass_network_t)-1:0] alu_bypass_flat;
    generate for (genvar k = 0; k < NUM_FAST_BYPASS; k++) begin
        assign alu_bypass_flat[k*$bits(bypass_network_t) +: $bits(bypass_network_t)] = alu_bypass[k];
    end endgenerate

    // ---- perf-tapped internals ----
    logic                   dc_stall, dc_hit, stb_full, stq_wantdeq, ldq_issue_en, ld_dmem_resp;
    logic [3:0]             dc_rmask, dc_wmask;
    logic [STQ_IDX:0]       stq_counter;
    logic [STQ_IDX-1:0]     stq_rdp;
    logic [STQ_DEPTH-1:0]   stq_av;
    logic [LDQ_DEPTH-1:0]   ldq_v, ldq_av, ldq_iss;

    lsu_top_spinal lsu_top_spinal_i (
        .clk(clk), .rst(rst), .backend_flush(backend_flush),
        .from_ds_valid(from_ds.valid), .from_ds_ready(from_ds.ready),
        .mem_rs_entry_flat(ds_entry_flat),
        .uop_rob_id(from_ds.uop.rob_id), .uop_fu_opcode(from_ds.uop.fu_opcode),
        .uop_rd_arch(from_ds.uop.rd_arch), .uop_rd_phy(from_ds.uop.rd_phy),
        .to_prf_rs1_phy(to_prf.rs1_phy), .to_prf_rs2_phy(to_prf.rs2_phy),
        .to_prf_rs_bypass(to_prf.rs_bypass),
        .to_prf_rs1_value(to_prf.rs1_value), .to_prf_rs2_value(to_prf.rs2_value),
        .cdb_rd_phy_flat(cdb_rd_phy_flat), .cdb_valid(cdb_valid_flat),
        .alu_bypass_flat(alu_bypass_flat),
        .fu_cdb_rob_id(fu_cdb_out.rob_id), .fu_cdb_rd_phy(fu_cdb_out.rd_phy),
        .fu_cdb_rd_arch(fu_cdb_out.rd_arch), .fu_cdb_rd_value(fu_cdb_out.rd_value),
        .fu_cdb_rs1_value_dbg(fu_cdb_out.rs1_value_dbg), .fu_cdb_rs2_value_dbg(fu_cdb_out.rs2_value_dbg),
        .fu_cdb_valid(fu_cdb_out.valid),
        .ld_rob_rob_id(ld_to_rob.rob_id), .ld_rob_addr_dbg(ld_to_rob.addr_dbg),
        .ld_rob_rmask_dbg(ld_to_rob.rmask_dbg), .ld_rob_rdata_dbg(ld_to_rob.rdata_dbg),
        .ld_rob_valid(ld_to_rob.valid), .ld_rob_violation(ld_to_rob.violation),
        .ld_rob_violation_rob_id(ld_to_rob.violation_rob_id),
        .st_rob_rob_id(st_to_rob.rob_id), .st_rob_addr_dbg(st_to_rob.addr_dbg),
        .st_rob_wmask_dbg(st_to_rob.wmask_dbg), .st_rob_wdata_dbg(st_to_rob.wdata_dbg),
        .st_rob_rs1_value_dbg(st_to_rob.rs1_value_dbg), .st_rob_rs2_value_dbg(st_to_rob.rs2_value_dbg),
        .st_rob_valid(st_to_rob.valid), .st_rob_ready(st_to_rob.ready),
        .dfp_addr(dcache_itf.addr), .dfp_read(dcache_itf.read), .dfp_write(dcache_itf.write),
        .dfp_wdata(dcache_itf.wdata), .dfp_ready(dcache_itf.ready), .dfp_raddr(dcache_itf.raddr),
        .dfp_rdata(dcache_itf.rdata), .dfp_rvalid(dcache_itf.rvalid),
        .dbg_stb_full(stb_full),
        .dbg_stq_want_dequeue(stq_wantdeq), .dbg_stq_counter(stq_counter),
        .dbg_stq_rd_ptr_actual(stq_rdp), .dbg_stq_addr_valid_flat(stq_av),
        .dbg_ldq_valid_flat(ldq_v), .dbg_ldq_addr_valid_flat(ldq_av),
        .dbg_ldq_issued_flat(ldq_iss), .dbg_ldq_issue_en(ldq_issue_en),
        .dbg_dc_stall(dc_stall), .dbg_dc_hit(dc_hit), .dbg_dc_rmask(dc_rmask), .dbg_dc_wmask(dc_wmask),
        .dbg_ld_dmem_resp(ld_dmem_resp)
    );

    // ---- recreate perf_monitor sub-instance scopes ----
    if (1) begin : stb_i
        logic full; assign full = stb_full;
    end
    if (1) begin : stq_i
        logic               want_dequeue;
        logic [STQ_IDX:0]   counter;
        logic [STQ_IDX-1:0] rd_ptr_actual;
        stq_entry_t         fifo[STQ_DEPTH];
        assign want_dequeue  = stq_wantdeq;
        assign counter       = stq_counter;
        assign rd_ptr_actual = stq_rdp;
        for (genvar j = 0; j < STQ_DEPTH; j++) assign fifo[j].addr_valid = stq_av[j];
    end
    if (1) begin : ldq_i
        logic       issue_en;
        ldq_entry_t ldq_arr[LDQ_DEPTH];
        assign issue_en = ldq_issue_en;
        for (genvar i = 0; i < LDQ_DEPTH; i++) begin
            assign ldq_arr[i].valid      = ldq_v[i];
            assign ldq_arr[i].addr_valid = ldq_av[i];
            assign ldq_arr[i].issued     = ldq_iss[i];
        end
    end
    if (1) begin : ld_dmem_itf_i
        logic resp; assign resp = ld_dmem_resp;
    end
    if (1) begin : dcache_i
        if (1) begin : dcache_ctrl_i
            logic       stall, hit;
            logic [3:0] rmask, wmask;
            assign stall = dc_stall; assign hit = dc_hit;
            assign rmask = dc_rmask; assign wmask = dc_wmask;
        end
    end
endmodule
