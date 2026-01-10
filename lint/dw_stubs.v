
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
    // Stub
    always_comb begin
        complete = start;
        product = '0; 
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
    // Stub
    always_comb begin
        complete = start;
        divide_by_0 = '0;
        quotient = '0;
        remainder = '0;
    end
endmodule
