// Yosys blackbox stubs for the Nangate45 fakeram45 macros referenced by the
// P&R wrappers. Port widths match the platform LEF/lib exactly. Kept as
// blackboxes (-lib) so yosys leaves them as macro instances in the netlist.
(* blackbox *)
module fakeram45_128x256(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);
  input clk, ce_in, we_in;
  input  [6:0]   addr_in;
  input  [255:0] wd_in;
  input  [255:0] w_mask_in;
  output [255:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_32x32(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);
  input clk, ce_in, we_in;
  input  [4:0]  addr_in;
  input  [31:0] wd_in;
  input  [31:0] w_mask_in;
  output [31:0] rd_out;
endmodule

(* blackbox *)
module fakeram45_64x32(clk, ce_in, we_in, addr_in, wd_in, w_mask_in, rd_out);
  input clk, ce_in, we_in;
  input  [5:0]  addr_in;
  input  [31:0] wd_in;
  input  [31:0] w_mask_in;
  output [31:0] rd_out;
endmodule
