// Yosys blackbox stubs for the right-sized cache fakeram45 macros referenced by the
// P&R wrappers. Port widths match the LEF/lib exactly. Kept as blackboxes (-lib) so
// yosys leaves them as macro instances in the netlist. The data macros keep the
// 256-wide / 7-bit-addr port template (only the depth/area differ); the D$ tag keeps
// the 32-wide / 5-bit-addr template.
(* blackbox *)
module fakeram45_64x256(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);  // I$ data
  input clk, ce_in, we_in;
  input  [6:0]   addr_in;
  input  [255:0] wd_in;
  input  [255:0] w_mask_in;
  output [255:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_16x256(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);  // D$ data
  input clk, ce_in, we_in;
  input  [6:0]   addr_in;
  input  [255:0] wd_in;
  input  [255:0] w_mask_in;
  output [255:0] rd_out;
endmodule

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
module fakeram45_64x124(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);  // TAGE bank
  input clk, ce_in, we_in;
  input  [5:0]   addr_in;
  input  [123:0] wd_in;
  input  [123:0] w_mask_in;
  output [123:0] rd_out;
endmodule
