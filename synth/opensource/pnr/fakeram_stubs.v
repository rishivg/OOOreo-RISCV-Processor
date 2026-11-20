// Blackboxes for active Nangate45 screening macro bindings.

(* blackbox *)
module fakeram45_16x32(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);   // D$ tag
  input clk, ce_in, we_in;
  input  [4:0]  addr_in;
  input  [31:0] wd_in;
  input  [31:0] w_mask_in;
  output [31:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_64x32(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);   // I$ tag
  input clk, ce_in, we_in;
  input  [5:0]  addr_in;
  input  [31:0] wd_in;
  input  [31:0] w_mask_in;
  output [31:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_1r1w_32x96(clk, ce_in, we_in, addr_in, waddr_in, wd_in, w_mask_in, rd_out);  // TAGE bank
  input clk, ce_in, we_in;
  input  [5:0]   addr_in, waddr_in;
  input  [123:0] wd_in;
  input  [123:0] w_mask_in;
  output [123:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_1r1w_64x32(clk, ce_in, we_in, addr_in, waddr_in, wd_in, w_mask_in, rd_out);  // BIM bank
  input clk, ce_in, we_in;
  input  [5:0]  addr_in, waddr_in;
  input  [31:0] wd_in;
  input  [31:0] w_mask_in;
  output [31:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_1r1w_16x240(clk, ce_in, we_in, addr_in, waddr_in, wd_in, w_mask_in, rd_out);  // uBTB bank
  input clk, ce_in, we_in;
  input  [6:0]   addr_in, waddr_in;
  input  [255:0] wd_in;
  input  [255:0] w_mask_in;
  output [255:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_64x128(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);  // I$ data block banks (128 of 256)
  input clk, ce_in, we_in;
  input  [6:0]   addr_in;
  input  [255:0] wd_in;
  input  [255:0] w_mask_in;
  output [255:0] rd_out;
endmodule
