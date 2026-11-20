// Blackbox stub for the Synopsys DesignWare sequential divider IP (DW_div_seq).
// The real DW_div_seq has no open-source liberty model, so for the Nangate45
// open-source flow it is treated as an IP macro black box (like the SRAMs).
// CAVEAT: total area/power reported by this flow EXCLUDES the divider's cells.
// The instantiation in fu_div.sv uses A_WIDTH=B_WIDTH=33, NUM_CYC_DIV=12.
(* blackbox *)
module DW_div_seq (clk, rst_n, hold, start, a, b, complete, divide_by_0, quotient, remainder);
  parameter a_width    = 33;
  parameter b_width    = 33;
  parameter tc_mode    = 1;
  parameter num_cyc    = 12;
  parameter rst_mode   = 1;
  parameter input_mode = 0;
  parameter output_mode= 0;
  parameter early_start= 0;
  input                      clk;
  input                      rst_n;
  input                      hold;
  input                      start;
  input  [a_width-1:0]       a;
  input  [b_width-1:0]       b;
  output                     complete;
  output                     divide_by_0;
  output [a_width-1:0]       quotient;
  output [b_width-1:0]       remainder;
endmodule
