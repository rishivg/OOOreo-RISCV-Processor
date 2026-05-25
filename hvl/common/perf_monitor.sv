module perf_monitor
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    input   logic               clk,
    input   logic               rst
);

    ////////////////////////////////
    // Branch Performance Monitor //
    ////////////////////////////////

    logic   [31:0]              br_cnt;
    logic   [31:0]              br_mispredict_cnt;
    logic   [31:0]              br_cond_cnt;
    logic   [31:0]              br_cond_mispredict_cnt;
    logic   [31:0]              br_uncond_cnt;
    logic   [31:0]              br_uncond_mispredict_cnt;
    logic   [3:0]               fu_br_opcode;
    logic                       fu_br_valid;
    logic                       fu_br_mispredict;
    real                        br_mispredict_rate;
    real                        br_cond_mispredict_rate;
    real                        br_uncond_mispredict_rate;

    assign fu_br_valid = top_tb.dut.backend_i.branch_i.br_rs_i.fu_br_i.fu_br_valid;
    assign fu_br_mispredict = top_tb.dut.backend_i.branch_i.br_rs_i.fu_br_i.miss_predict;
    assign fu_br_opcode = top_tb.dut.backend_i.branch_i.br_rs_i.fu_br_i.fu_br_reg_out.fu_opcode;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            br_cnt             <= '0;
            br_mispredict_cnt  <= '0;
        end else if (fu_br_valid && fu_br_opcode != BR_AUIPC) begin 
            br_cnt             <= br_cnt + 1;
            br_mispredict_cnt  <= br_mispredict_cnt + 32'(fu_br_mispredict);
        end
    end

    always_ff @(posedge clk) begin 
        if (rst) begin 
            br_cond_cnt             <= '0;
            br_cond_mispredict_cnt  <= '0;
        end else if (fu_br_valid && !fu_br_opcode[3]) begin 
            br_cond_cnt             <= br_cond_cnt + 1;
            br_cond_mispredict_cnt  <= br_cond_mispredict_cnt + 32'(fu_br_mispredict);
        end
    end

    
    always_ff @(posedge clk) begin 
        if (rst) begin 
            br_uncond_cnt             <= '0;
            br_uncond_mispredict_cnt  <= '0;
        end else if (fu_br_valid && fu_br_opcode[3] && fu_br_opcode != BR_AUIPC) begin 
            br_uncond_cnt             <= br_uncond_cnt + 1;
            br_uncond_mispredict_cnt  <= br_uncond_mispredict_cnt + 32'(fu_br_mispredict);
        end
    end

    assign br_mispredict_rate = (br_cnt != 0) ? 
                                real'(br_mispredict_cnt) / real'(br_cnt) : 
                                0.0;

    assign br_cond_mispredict_rate = (br_cond_cnt != 0) ?
                                real'(br_cond_mispredict_cnt) / real'(br_cond_cnt) :
                                0.0;

    assign br_uncond_mispredict_rate = (br_uncond_cnt != 0) ?
                                real'(br_uncond_mispredict_cnt) / real'(br_uncond_cnt) :
                                0.0;

    //////////////////////////////////
    // Dispatch Performance Monitor //
    //////////////////////////////////

    logic   [31:0]              ds_int_rs_block;
    logic   [31:0]              ds_intm_rs_block;
    logic   [31:0]              ds_br_rs_block;
    logic   [31:0]              ds_mem_rs_block;

    assign ds_int_rs_block = top_tb.dut.backend_i.ds_stage_i.perf_int_rs_block;
    assign ds_intm_rs_block = top_tb.dut.backend_i.ds_stage_i.perf_intm_rs_block;
    assign ds_br_rs_block = top_tb.dut.backend_i.ds_stage_i.perf_br_rs_block;
    assign ds_mem_rs_block = top_tb.dut.backend_i.ds_stage_i.perf_mem_rs_block;

    //////////////////////////////////
    // Mul / Div population           //
    //////////////////////////////////

    logic           mul_start;
    logic           div1_start;
    logic           div2_start;
    logic   [31:0]  mul_cnt;
    logic   [31:0]  div_cnt;

    assign mul_start  = top_tb.dut.backend_i.intm_rs_gen.intm_rs_i.fu_mul_i.mul_start;
    assign div1_start = top_tb.dut.backend_i.intm_rs_gen.intm_rs_i.fu_div_i.fu_div_1_i.div_start;
    assign div2_start = top_tb.dut.backend_i.intm_rs_gen.intm_rs_i.fu_div_i.fu_div_2_i.div_start;

    always_ff @(posedge clk) begin
        if (rst) begin
            mul_cnt <= '0;
            div_cnt <= '0;
        end else begin
            if (mul_start)  mul_cnt <= mul_cnt + 1;
            if (div1_start) div_cnt <= div_cnt + 1;
            if (div2_start) div_cnt <= div_cnt + 1;
        end
    end

    //////////////////////////////////
    // DCache / Store buffer stalls   //
    //////////////////////////////////

    logic           dc_stall;       // dcache controller stalling the access
    logic           dc_hit;
    logic           dc_req;         // a load/store access is presented to the cache
    logic           dc_miss_stall;  // stalled because of a miss
    logic           dc_miss_prev;
    logic           stb_full;
    logic           stq_want_deq;
    logic   [31:0]  dc_miss_cnt;        // number of distinct misses
    logic   [31:0]  dc_miss_stall_cyc;  // cycles stalled servicing misses
    logic   [31:0]  stb_full_cyc;       // cycles a resolved store can't drain (store buffer full)

    assign dc_stall     = top_tb.dut.backend_i.lsu_i.dcache_i.dcache_ctrl_i.stall;
    assign dc_hit       = top_tb.dut.backend_i.lsu_i.dcache_i.dcache_ctrl_i.hit;
    assign dc_req       = (|top_tb.dut.backend_i.lsu_i.dcache_i.dcache_ctrl_i.rmask)
                       || (|top_tb.dut.backend_i.lsu_i.dcache_i.dcache_ctrl_i.wmask);
    assign dc_miss_stall = dc_req && dc_stall && ~dc_hit;
    assign stb_full     = top_tb.dut.backend_i.lsu_i.stb_i.full;
    assign stq_want_deq = top_tb.dut.backend_i.lsu_i.stq_i.want_dequeue;

    always_ff @(posedge clk) begin
        if (rst) begin
            dc_miss_cnt       <= '0;
            dc_miss_stall_cyc <= '0;
            stb_full_cyc      <= '0;
            dc_miss_prev      <= '0;
        end else begin
            dc_miss_prev <= dc_miss_stall;
            if (dc_miss_stall && ~dc_miss_prev) dc_miss_cnt <= dc_miss_cnt + 1;  // rising edge = new miss
            if (dc_miss_stall)                  dc_miss_stall_cyc <= dc_miss_stall_cyc + 1;
            if (stb_full && stq_want_deq)       stb_full_cyc <= stb_full_cyc + 1;
        end
    end

    //////////////////////////////////
    // LSU / Load Disambiguation     //
    //////////////////////////////////

    logic           ldq_addr_ready;     // some load has its address computed
    logic           ldq_issue_en;       // a load is eligible to issue to dcache
    logic           ldq_resp;           // a load completes (dcache response) this cycle
    logic           stq_nonempty;
    logic           stq_head_unknown;   // oldest store's address not yet resolved
    logic   [31:0]  ld_resp_cnt;
    logic   [31:0]  ld_block_cycles;          // addr-ready load blocked by disambiguation
    logic   [31:0]  ld_block_unknown_cycles;  //   ... while oldest store addr is unknown
    logic           mem_viol_detect;          // speculative load aliased an older store (pulse)
    logic           mem_viol_flush;           // violated load reached head -> pipeline flush
    logic   [31:0]  mem_viol_detect_cnt;
    logic   [31:0]  mem_viol_flush_cnt;

    assign mem_viol_detect = top_tb.dut.backend_i.ldq_rob_itf.violation;
    assign mem_viol_flush  = top_tb.dut.backend_i.rob_i.viol_flush;

    always_comb begin
        ldq_addr_ready = 1'b0;
        for (int i = 0; i < LDQ_DEPTH; i++) begin
            if (top_tb.dut.backend_i.lsu_i.ldq_i.ldq_arr[i].valid &&
                top_tb.dut.backend_i.lsu_i.ldq_i.ldq_arr[i].addr_valid) begin
                ldq_addr_ready = 1'b1;
            end
        end
    end

    assign ldq_issue_en = top_tb.dut.backend_i.lsu_i.ldq_i.issue_en;
    assign ldq_resp     = top_tb.dut.backend_i.lsu_i.ld_dmem_itf_i.resp;
    assign stq_nonempty = (top_tb.dut.backend_i.lsu_i.stq_i.counter != '0);
    assign stq_head_unknown = stq_nonempty &&
        ~top_tb.dut.backend_i.lsu_i.stq_i.fifo[top_tb.dut.backend_i.lsu_i.stq_i.rd_ptr_actual].addr_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            ld_resp_cnt             <= '0;
            ld_block_cycles         <= '0;
            ld_block_unknown_cycles <= '0;
            mem_viol_detect_cnt     <= '0;
            mem_viol_flush_cnt      <= '0;
        end else begin
            if (ldq_resp) ld_resp_cnt <= ld_resp_cnt + 1;
            if (ldq_addr_ready && ~ldq_issue_en) begin
                ld_block_cycles <= ld_block_cycles + 1;
                if (stq_head_unknown) ld_block_unknown_cycles <= ld_block_unknown_cycles + 1;
            end
            if (mem_viol_detect) mem_viol_detect_cnt <= mem_viol_detect_cnt + 1;
            if (mem_viol_flush)  mem_viol_flush_cnt  <= mem_viol_flush_cnt + 1;
        end
    end

    logic   [63:0]              cycle_cnt;
    always_ff @(posedge clk) begin
        if (rst) cycle_cnt <= '0;
        else     cycle_cnt <= cycle_cnt + 1;
    end

    final begin
        $display("==================== PERF MONITOR ====================");
        $display("Cycles                 : %0d", cycle_cnt);
        $display("--- Branches ---");
        $display("Total branches         : %0d", br_cnt);
        $display("  mispredicts          : %0d (%.2f%%)", br_mispredict_cnt, br_mispredict_rate*100.0);
        $display("Conditional branches   : %0d", br_cond_cnt);
        $display("  mispredicts          : %0d (%.2f%%)", br_cond_mispredict_cnt, br_cond_mispredict_rate*100.0);
        $display("Unconditional (jal/jalr): %0d", br_uncond_cnt);
        $display("  mispredicts          : %0d (%.2f%%)", br_uncond_mispredict_cnt, br_uncond_mispredict_rate*100.0);
        $display("--- Dispatch stalls (cycles blocked by full RS) ---");
        $display("INT  RS full           : %0d", ds_int_rs_block);
        $display("INTM RS full           : %0d", ds_intm_rs_block);
        $display("BR   RS full           : %0d", ds_br_rs_block);
        $display("MEM  RS full           : %0d", ds_mem_rs_block);
        $display("--- LSU / load disambiguation ---");
        $display("Loads completed        : %0d", ld_resp_cnt);
        $display("Load disambig-block cyc: %0d", ld_block_cycles);
        $display("  (oldest store unknown): %0d", ld_block_unknown_cycles);
        $display("Spec-load violations    : %0d", mem_viol_detect_cnt);
        $display("Spec-load viol flushes  : %0d", mem_viol_flush_cnt);
        $display("--- Mul / Div ---");
        $display("Multiplies             : %0d", mul_cnt);
        $display("Divides                : %0d", div_cnt);
        $display("--- DCache / store buffer ---");
        $display("DCache misses          : %0d", dc_miss_cnt);
        $display("DCache miss-stall cyc  : %0d", dc_miss_stall_cyc);
        $display("Store-buf-full cyc     : %0d", stb_full_cyc);
        $display("=====================================================");
    end

endmodule
