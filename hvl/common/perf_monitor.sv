module perf_monitor
import uop_types::*;
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
        $display("=====================================================");
    end

endmodule
