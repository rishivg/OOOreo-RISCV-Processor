// P&R macro wrappers: adapt the core's cache-array blackbox ports to the
// Nangate45 fakeram45 physical macros so the netlist can be floorplanned/placed.
// Pure wiring (no logic) -> these add hierarchy only, not delay.
//   data array: 16x256 in the RTL -> fakeram45_128x256 (only 256-wide model;
//               oversized depth, which is fine: SRAM area is reported separately
//               and this only needs to give the cache pins a physical footprint).
//   tag  array: 16x24  in the RTL -> fakeram45_32x32.
// Port-name/polarity mapping is connectivity-only (timing is what we measure),
// so chip/write enables are wired straight through without inverters.

module dcache_data_array(vdd, gnd, clk0, csb0, web0, addr0, wmask0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]   addr0;
  input  [31:0]  wmask0;
  input  [255:0] din0;
  output [255:0] dout0;
  wire [255:0] wmask_bit;
  genvar i;
  generate for (i = 0; i < 256; i = i + 1) begin : g_wmask
    assign wmask_bit[i] = wmask0[i/8];   // expand byte mask -> per-bit mask
  end endgenerate
  fakeram45_128x256 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({3'b0, addr0}), .wd_in(din0), .w_mask_in(wmask_bit), .rd_out(dout0));
endmodule

module icache_data_array(vdd, gnd, clk0, csb0, web0, addr0, wmask0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]   addr0;
  input  [31:0]  wmask0;
  input  [255:0] din0;
  output [255:0] dout0;
  wire [255:0] wmask_bit;
  genvar i;
  generate for (i = 0; i < 256; i = i + 1) begin : g_wmask
    assign wmask_bit[i] = wmask0[i/8];
  end endgenerate
  fakeram45_128x256 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({3'b0, addr0}), .wd_in(din0), .w_mask_in(wmask_bit), .rd_out(dout0));
endmodule

module dcache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [23:0] din0;
  output [23:0] dout0;
  wire [31:0] rd;
  assign dout0 = rd[23:0];
  fakeram45_32x32 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({1'b0, addr0}), .wd_in({8'b0, din0}), .w_mask_in(32'hFFFFFFFF), .rd_out(rd));
endmodule

module icache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [23:0] din0;
  output [23:0] dout0;
  wire [31:0] rd;
  assign dout0 = rd[23:0];
  fakeram45_32x32 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({1'b0, addr0}), .wd_in({8'b0, din0}), .w_mask_in(32'hFFFFFFFF), .rd_out(rd));
endmodule
