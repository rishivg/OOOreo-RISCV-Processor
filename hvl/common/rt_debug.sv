module rt_debug
import cpu_params::*;
(
    input logic clk,
    input logic rst
);

    // Enabled via plusarg +DEBUG
    logic enabled;
    int fh;
    longint unsigned cycle_cnt;
    initial enabled = $test$plusargs("DEBUG");
    initial begin
        if (enabled) begin
            fh = $fopen("rt_debug.log", "w");
            if (fh == 0) begin
                if ($test$plusargs("DEBUG_CONSOLE")) $display("rt_debug: failed to open rt_debug.log");
            end else begin
                if ($test$plusargs("DEBUG_CONSOLE")) $display("rt_debug: logging to rt_debug.log");
            end
        end else begin
            fh = 0;
        end
    end

    final begin
        if (fh != 0) $fclose(fh);
    end

    // local proxies to avoid deep hierarchical reads inside always blocks
    logic backend_flush_p;
    logic [ROB_PTR_IDX-1:0] rob_head_p;
    logic [ROB_PTR_IDX-1:0] rob_tail_p;
    logic [ID_WIDTH-1:0] uops_valid_p;
    logic [CDB_WIDTH-1:0] cdb_valid_p;
    // free-list counter width isn't globally defined (FREELIST_IDX is local to free_list),
    // use a safe width here.
    logic [PRF_IDX:0] fl_counter_p;
    logic rvfi_commit_p [ID_WIDTH];
    logic [ARF_IDX-1:0] rvfi_rd_addr_p [ID_WIDTH];
    logic [31:0] rvfi_rd_wdata_p [ID_WIDTH];
    logic [31:0] rvfi_pc_p [ID_WIDTH];
    // dispatch/uop probes
    logic dispatch_valid_p;
    logic dispatch_ready_p;
    logic [31:0] uop_pc_p [ID_WIDTH];
    logic [3:0]  uop_fuop_p [ID_WIDTH];
    // load/store queue probes
    logic [STQ_IDX:0] stq_counter_p;
    logic ldq_valid_p [LDQ_DEPTH];
    // PRF / RAT probes
    logic [PRF_IDX-1:0] rrf_mem_p [ARF_DEPTH];
    // RS valid arrays (per-entry RS internals are inside generated blocks and
    // may not be addressable from the testbench in a stable way). We keep
    // placeholder arrays for compatibility but do not try to probe internal
    // instance names directly.
    logic int_rs_valid_p [INTRS_DEPTH];
    logic intm_rs_valid_p [INTMRS_DEPTH];
    logic mem_rs_valid_p [MEMRS_DEPTH];
    logic br_rs_valid_p [BRRS_DEPTH];
    // cache stall probes
    logic dcache_stall_p;
    // temporary counters/strings used by the debug proc
    int dbg_n_commits;
    int dbg_ldq_count;
    int dbg_int_rs_count;
    int dbg_intm_rs_count;
    int dbg_mem_rs_count;
    int dbg_br_rs_count;
    int dbg_rrf_nonzero;
    string dbg_per_commit_str;
    string dbg_uop_summary;

    // assign from top-level DUT (Verilator-friendly shallow access)
    // these signal paths are expected to exist in the DUT
    assign backend_flush_p = top_tb.dut.backend_i.backend_flush;
    assign rob_head_p = top_tb.dut.backend_i.rob_i.head_ptr;
    assign rob_tail_p = top_tb.dut.backend_i.rob_i.tail_ptr;
    // free list counter proxy (number of free physical regs)
    assign fl_counter_p = top_tb.dut.backend_i.free_list_i.counter;
    generate for (genvar i=0; i<ID_WIDTH; i++) begin : UOPS_V
        assign uops_valid_p[i] = top_tb.dut.backend_i.uops_valid[i];
    end endgenerate
    assign dispatch_valid_p = top_tb.dut.backend_i.dispatch_valid;
    assign dispatch_ready_p = top_tb.dut.backend_i.dispatch_ready;
    generate for (genvar u=0; u<ID_WIDTH; u++) begin : UOPS_PC
        assign uop_pc_p[u] = top_tb.dut.backend_i.uops[u].pc;
        assign uop_fuop_p[u] = top_tb.dut.backend_i.uops[u].fu_opcode;
    end endgenerate
    // PRF / RAT mapping
    generate for (genvar a = 0; a < ARF_DEPTH; a++) begin : RRF
        assign rrf_mem_p[a] = top_tb.dut.backend_i.rrf_mem[a];
    end endgenerate
    // RS valid proxies (instances named in backend/top components)
    // The reservation-station internal signals are instantiated inside
    // generate blocks and may have generated scope names (genblkN). To avoid
    // depending on those, skip direct probing here. Keep arrays but leave
    // them zeroed by default; higher-level occupancy can be inferred from
    // other interfaces if needed.
    // (No direct assigns for int_rs_valid_p/intm_rs_valid_p)
    generate for (genvar m = 0; m < MEMRS_DEPTH; m++) begin : MEMRS
        assign mem_rs_valid_p[m] = top_tb.dut.backend_i.lsu_i.mem_rs_i.rs_valid[m];
    end endgenerate
    generate for (genvar b = 0; b < BRRS_DEPTH; b++) begin : BRRS
        assign br_rs_valid_p[b] = top_tb.dut.backend_i.branch_i.br_rs_i.rs_valid[b];
    end endgenerate
    assign dcache_stall_p = top_tb.dut.backend_i.lsu_i.dcache_i.stall;
    generate for (genvar c=0; c<CDB_WIDTH; c++) begin : CDBV
        assign cdb_valid_p[c] = top_tb.dut.backend_i.rob_i.cdb_rob[c].valid;
    end endgenerate

    // RVFI proxies for commit information (head entries)
    generate for (genvar r=0; r<ID_WIDTH; r++) begin : RVFI
        assign rvfi_commit_p[r] = top_tb.dut.backend_i.rob_i.rvfi_itf[r].commit;
        assign rvfi_rd_addr_p[r] = top_tb.dut.backend_i.rob_i.rvfi_itf[r].rd_addr;
        assign rvfi_rd_wdata_p[r] = top_tb.dut.backend_i.rob_i.rvfi_itf[r].rd_wdata;
        assign rvfi_pc_p[r] = top_tb.dut.backend_i.rob_i.rvfi_itf[r].pc_wdata;
    end endgenerate

    // LSQ probes
    assign stq_counter_p = top_tb.dut.backend_i.lsu_i.stq_i.counter;
    generate for (genvar l=0; l<LDQ_DEPTH; l++) begin : LDQ_V
        assign ldq_valid_p[l] = top_tb.dut.backend_i.lsu_i.ldq_i.ldq_arr[l].valid;
    end endgenerate

    // (declared above)

    // Temporarily disable BLKSEQ warnings for this debug printing block
    // since it uses blocking updates for convenience of immediate string
    // formatting and counters used only for display.
    /* verilator lint_off BLKSEQ */
    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_cnt <= 0;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            if (enabled) begin
                // print a concise snapshot each cycle
                dbg_n_commits = 0;
                for (int i = 0; i < ID_WIDTH; i++) begin
                    if (rvfi_commit_p[i]) dbg_n_commits++;
                end
                dbg_ldq_count = 0;
                for (int i = 0; i < LDQ_DEPTH; i++) begin
                    if (ldq_valid_p[i]) dbg_ldq_count++;
                end
                // show a brief console snapshot including dispatch, PRF and LSQ counts
                // RS internals are not probed directly here; set counters to 0.
                dbg_int_rs_count = 0;
                dbg_intm_rs_count = 0;
                dbg_mem_rs_count = 0;
                for (int i = 0; i < MEMRS_DEPTH; i++) if (mem_rs_valid_p[i]) dbg_mem_rs_count++;
                dbg_br_rs_count = 0;
                for (int i = 0; i < BRRS_DEPTH; i++) if (br_rs_valid_p[i]) dbg_br_rs_count++;
                dbg_rrf_nonzero = 0;
                for (int i = 0; i < ARF_DEPTH; i++) if (rrf_mem_p[i] != '0) dbg_rrf_nonzero++;
                if ($test$plusargs("DEBUG_CONSOLE")) begin
                    $display("DBG C=%0d DV=%0b DR=%0b FL=%0d STQ=%0d LDQ=%0d RS=%0d/%0d MRS=%0d BRS=%0d PRF=%0d HEAD=%0d TAIL=%0d UOPS=%b CDB=%b CMTS=%0d DCS=%0b",
                             cycle_cnt, dispatch_valid_p, dispatch_ready_p, fl_counter_p, stq_counter_p, dbg_ldq_count, dbg_int_rs_count, dbg_intm_rs_count, dbg_mem_rs_count, dbg_br_rs_count, dbg_rrf_nonzero, rob_head_p, rob_tail_p, uops_valid_p, cdb_valid_p, dbg_n_commits, dcache_stall_p);
                end
                if (fh != 0) begin
                    // write a detailed line to the log file
                    // Format: cycle,fl,head,tail,uops,cdb,n_commits,[per-commit:commit,rd,rd_data,pc]
                    dbg_per_commit_str = "";
                    for (int j = 0; j < ID_WIDTH; j++) begin
                        if (rvfi_commit_p[j]) begin
                            $sformat(dbg_per_commit_str, "%s C%d:R%d=0x%08x@0x%08x;", dbg_per_commit_str, j, rvfi_rd_addr_p[j], rvfi_rd_wdata_p[j], rvfi_pc_p[j]);
                        end
                    end
                    // uop summary
                    dbg_uop_summary = "";
                    for (int k = 0; k < ID_WIDTH; k++) begin
                        $sformat(dbg_uop_summary, "%s U%d:0x%08x/0x%01x;", dbg_uop_summary, k, uop_pc_p[k], uop_fuop_p[k]);
                    end
                    // include RS and PRF summary in file log
                    // include RS and PRF summary in file log
                    $fdisplay(fh, "C=%0d DV=%0b DR=%0b FL=%0d STQ=%0d LDQ=%0d RS_int=%0d RS_intm=%0d RS_mem=%0d RS_br=%0d PRF_nonzero=%0d HEAD=%0d TAIL=%0d UOPS=%b CDB=%0b CMTS=%0d DCS=%0b %s %s",
                              cycle_cnt, dispatch_valid_p, dispatch_ready_p, fl_counter_p, stq_counter_p, dbg_ldq_count, dbg_int_rs_count, dbg_intm_rs_count, dbg_mem_rs_count, dbg_br_rs_count, dbg_rrf_nonzero, rob_head_p, rob_tail_p, uops_valid_p, cdb_valid_p, dbg_n_commits, dcache_stall_p, dbg_per_commit_str, dbg_uop_summary);
                end
            end
        end
    end
    /* verilator lint_on BLKSEQ */

endmodule
