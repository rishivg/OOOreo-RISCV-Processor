module mdu_ex 
import rv32i_types::*;
(
    input  logic            clk,
    input  logic            rst,
    input  reservation_station_t next_execute,
    output to_writeback_t   execute_output
);

    logic start [2];  // 0: multiplier (unified), 1: divider
    logic done  [2];

    logic [65:0] product_mul;  // Unified multiplier output (max width for all operations)

    logic [31:0] quotient;
    logic [31:0] remainder;
    logic        div_by_0;

    logic div_overflow;
    logic is_mul_op, is_div_op;
    
    logic new_inst;
    mult_ops mult_op_running;
    logic        last_valid;
    logic        module_idx;  // 0: mul, 1: div
    logic [4:0]  prev_rd_rob_idx;
    
    // Pipeline stage to break critical path from CDB to MDU
    logic [31:0] rs1_staged, rs2_staged;
    mult_ops mult_op_staged;
    logic valid_staged;
    logic [4:0] rd_addr_staged, rd_rob_idx_staged;
    
    // Capture operands when starting - register early to break timing path
    logic [31:0] rs1_captured, rs2_captured;
    
    // Multiplier operands and mode control - registered to reduce timing
    logic [32:0] mul_a, mul_b;
    
    assign div_overflow = (rs1_captured == 32'h80000000) && (rs2_captured == 32'hFFFFFFFF);
    assign new_inst = valid_staged && ((!last_valid) || (prev_rd_rob_idx != rd_rob_idx_staged));
    
    assign is_mul_op = (mult_op_staged == mult_op_mul) || (mult_op_staged == mult_op_mulh) ||
                       (mult_op_staged == mult_op_mulhu) || (mult_op_staged == mult_op_mulhsu);
    assign is_div_op = (mult_op_staged == mult_op_div) || (mult_op_staged == mult_op_rem) ||
                       (mult_op_staged == mult_op_divu) || (mult_op_staged == mult_op_remu);

    // Configure unified multiplier operands based on operation
    // This is now registered to reduce timing pressure
    always_comb begin
        case (mult_op_running)
            mult_op_mul, mult_op_mulh: begin
                // Signed multiply
                mul_a = {rs1_captured[31], rs1_captured};
                mul_b = {rs2_captured[31], rs2_captured};
            end
            mult_op_mulhu: begin
                // Unsigned multiply
                mul_a = {1'b0, rs1_captured};
                mul_b = {1'b0, rs2_captured};
            end
            mult_op_mulhsu: begin
                // Signed x Unsigned
                mul_a = {rs1_captured[31], rs1_captured};
                mul_b = {1'b0, rs2_captured};
            end
            default: begin
                mul_a = {1'b0, rs1_captured};
                mul_b = {1'b0, rs2_captured};
            end
        endcase
    end

    // Unified multiply unit - handles all multiplication operations
    DW_mult_seq #(
        .a_width(33), 
        .b_width(33),
        .tc_mode(1),  // Set to 1 to support signed mode
        .num_cyc(4),
        .early_start(1)
    ) multiply_unified (
        .clk(clk),
        .rst_n(~rst),
        .hold(1'b0),
        .start(start[0]),
        .a(mul_a),
        .b(mul_b),
        .complete(done[0]),
        .product(product_mul)
    );
    
    // Shared divide unit - handles both signed and unsigned
    DW_div_seq #(
        .a_width(32), 
        .b_width(32),
        .tc_mode(1),
        .num_cyc(4),
        .early_start(1)
    ) divide_shared (
        .clk(clk),
        .rst_n(~rst),
        .hold(1'b0),
        .start(start[1]),
        .a(rs1_captured),
        .b(rs2_captured),
        .complete(done[1]),
        .divide_by_0(div_by_0),
        .quotient(quotient),
        .remainder(remainder)
    );

    always_comb begin : module_select
        // 0: unified multiplier, 1: divider
        module_idx = is_div_op ? 1'b1 : 1'b0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            execute_output <= '0;
            mult_op_running <= mult_ops'(0);
            last_valid <= 1'b0;
            prev_rd_rob_idx <= '0;
            start <= '{default: 1'b0};
            rs1_captured <= '0;
            rs2_captured <= '0;
            // Pipeline stage reset
            rs1_staged <= '0;
            rs2_staged <= '0;
            mult_op_staged <= mult_ops'(0);
            valid_staged <= 1'b0;
            rd_addr_staged <= '0;
            rd_rob_idx_staged <= '0;
        end else begin
            // Stage 1: Capture operands from reservation station (breaks CDB→MDU path)
            rs1_staged <= next_execute.rs1_data;
            rs2_staged <= next_execute.rs2_data;
            mult_op_staged <= next_execute.multop;
            valid_staged <= next_execute.valid;
            rd_addr_staged <= next_execute.rd_addr;
            rd_rob_idx_staged <= next_execute.rd_rob_idx;
            last_valid <= valid_staged;
            
            // Stage 2: Start operation with staged operands
            if (valid_staged) begin
                if (new_inst) begin
                    execute_output.valid <= 1'b0;
                    execute_output.rd_addr <= rd_addr_staged;
                    execute_output.rd_rob_idx <= rd_rob_idx_staged;
                    execute_output.rd_data <= '0; 

                    mult_op_running <= mult_op_staged;
                    start[module_idx] <= 1'b1;
                    prev_rd_rob_idx <= rd_rob_idx_staged;

                    // Capture operands from staged registers
                    rs1_captured <= rs1_staged;
                    rs2_captured <= rs2_staged;
                end
                else if (start[module_idx]) begin
                    start[module_idx] <= 1'b0;
                end
                else if (done[module_idx]) begin
                    unique case (mult_op_running)
                        mult_op_mul:    execute_output.rd_data <= product_mul[31:0]; 
                        mult_op_mulh:   execute_output.rd_data <= product_mul[63:32]; 
                        mult_op_mulhu:  execute_output.rd_data <= product_mul[63:32]; 
                        mult_op_mulhsu: execute_output.rd_data <= product_mul[63:32]; 

                        mult_op_div, mult_op_divu: begin
                            if (div_by_0)
                                execute_output.rd_data <= 32'hFFFFFFFF;
                            else if (div_overflow && (mult_op_running == mult_op_div))
                                execute_output.rd_data <= 32'h80000000;
                            else 
                                execute_output.rd_data <= quotient;
                        end
                        
                        mult_op_rem, mult_op_remu: begin 
                            if (div_by_0)
                                execute_output.rd_data <= rs1_captured;
                            else if (div_overflow && (mult_op_running == mult_op_rem))
                                execute_output.rd_data <= 32'h0;
                            else 
                                execute_output.rd_data <= remainder; 
                        end
                    endcase
                    execute_output.valid <= 1'b1; 
                end
            end else begin
                execute_output.valid <= 1'b0;
            end
        end 
    end

endmodule