
module DW_mult_seq #(
    parameter a_width = 32,
    parameter b_width = 32,
    parameter tc_mode = 0,
    parameter num_cyc = 3,
    parameter rst_mode = 0,
    parameter input_mode = 1,
    parameter output_mode = 1,
    parameter early_start = 0
) (
    input logic clk,
    input logic rst_n,
    input logic hold,
    input logic start,
    input logic [a_width-1:0] a,
    input logic [b_width-1:0] b,
    output logic complete,
    output logic [a_width+b_width-1:0] product
);

    logic [a_width+b_width-1:0] product_pipe [num_cyc];
    logic complete_pipe [num_cyc];
    
    // Helper signals for signed arithmetic
    logic signed [a_width-1:0] a_signed;
    logic signed [b_width-1:0] b_signed;

    assign a_signed = a;
    assign b_signed = b;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < num_cyc; i++) begin
                product_pipe[i] <= '0;
                complete_pipe[i] <= '0;
            end
            complete <= 0;
            product <= '0;
        end else if (!hold) begin
            // Pipeline stage 0 calculation
            logic [a_width+b_width-1:0] prod_val;

            if (tc_mode) begin
               prod_val = $signed(a_signed) * $signed(b_signed);
            end else begin
               prod_val = a * b;
            end
            
            product_pipe[0] <= prod_val;
            complete_pipe[0] <= start;

            // Shift through pipeline
            for (int i = 1; i < num_cyc; i++) begin
                product_pipe[i] <= product_pipe[i-1];
                complete_pipe[i] <= complete_pipe[i-1];
            end
            
            // Output is from the last stage
            if (num_cyc > 0) begin
                complete <= complete_pipe[num_cyc-1];
                product <= product_pipe[num_cyc-1];
            end else begin
                // Passthrough for 0 cycles (unlikely for seq module but for robustness)
                complete <= start;
                product <= prod_val;
            end
        end
    end

endmodule

module DW_div_seq #(
    parameter a_width = 32,
    parameter b_width = 32,
    parameter tc_mode = 0,
    parameter num_cyc = 3,
    parameter rst_mode = 0,
    parameter input_mode = 1,
    parameter output_mode = 1,
    parameter early_start = 0
) (
    input logic clk,
    input logic rst_n,
    input logic hold,
    input logic start,
    input logic [a_width-1:0] a,
    input logic [b_width-1:0] b,
    output logic complete,
    output logic divide_by_0,
    output logic [a_width-1:0] quotient,
    output logic [b_width-1:0] remainder
);

    logic [a_width-1:0] quotient_pipe [num_cyc];
    logic [b_width-1:0] remainder_pipe [num_cyc];
    logic div_by_0_pipe [num_cyc];
    logic complete_pipe [num_cyc];

    logic signed [a_width-1:0] a_signed;
    logic signed [b_width-1:0] b_signed;

    assign a_signed = a;
    assign b_signed = b;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < num_cyc; i++) begin
                quotient_pipe[i] <= '0;
                remainder_pipe[i] <= '0;
                div_by_0_pipe[i] <= '0;
                complete_pipe[i] <= '0;
            end
            complete <= 0;
            quotient <= '0;
            remainder <= '0;
            divide_by_0 <= 0;
        end else if (!hold) begin
            // Calculation
            logic [a_width-1:0] q_val;
            logic [b_width-1:0] r_val;
            logic db0;

            db0 = (b == 0);
            
            if (tc_mode) begin
                if (db0) begin
                    q_val = '1; 
                    r_val = a;   
                end else if (a == {1'b1, {(a_width-1){1'b0}}} && b == { {(b_width){1'b1}} }) begin
                     // Overflow case for signed division (INT_MIN / -1)
                     q_val = {1'b1, {(a_width-1){1'b0}}};
                     r_val = '0;
                end else begin
                    q_val = a_signed / b_signed; 
                    r_val = a_signed % b_signed;
                end
            end else begin
                if (db0) begin
                    q_val = '1;
                    r_val = a;
                end else begin
                    q_val = a / b;
                    r_val = a % b;
                end
            end

            quotient_pipe[0] <= q_val;
            remainder_pipe[0] <= r_val;
            div_by_0_pipe[0] <= db0;
            complete_pipe[0] <= start;

             // Shift through pipeline
            for (int i = 1; i < num_cyc; i++) begin
                quotient_pipe[i] <= quotient_pipe[i-1];
                remainder_pipe[i] <= remainder_pipe[i-1];
                div_by_0_pipe[i] <= div_by_0_pipe[i-1];
                complete_pipe[i] <= complete_pipe[i-1];
            end
            
            if (num_cyc > 0) begin
                complete <= complete_pipe[num_cyc-1];
                quotient <= quotient_pipe[num_cyc-1];
                remainder <= remainder_pipe[num_cyc-1];
                divide_by_0 <= div_by_0_pipe[num_cyc-1];
            end else begin
                complete <= start;
                quotient <= q_val;
                remainder <= r_val;
                divide_by_0 <= db0;
            end
        end
    end

endmodule
