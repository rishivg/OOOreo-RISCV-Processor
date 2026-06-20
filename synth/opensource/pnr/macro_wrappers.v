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

// I-cache is 64 sets (I_SET_IDX=6) -> 6-bit addr; fakeram45_128x256 (128 deep)
// fits. ADDR_WIDTH param absorbs the icache's #(.ADDR_WIDTH(SET_IDX)) override.
module icache_data_array #(parameter ADDR_WIDTH = 6)
  (vdd, gnd, clk0, csb0, web0, addr0, wmask0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [31:0]  wmask0;
  input  [255:0] din0;
  output [255:0] dout0;
  wire [255:0] wmask_bit;
  genvar i;
  generate for (i = 0; i < 256; i = i + 1) begin : g_wmask
    assign wmask_bit[i] = wmask0[i/8];
  end endgenerate
  fakeram45_128x256 u_ram (              // 128 deep -> addr_in[6:0], zero-extend
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in(7'(addr0)), .wd_in(din0), .w_mask_in(wmask_bit), .rd_out(dout0));
endmodule

module dcache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [24:0] din0;
  output [24:0] dout0;
  wire [31:0] rd;
  assign dout0 = rd[24:0];
  fakeram45_32x32 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({1'b0, addr0}), .wd_in({7'b0, din0}), .w_mask_in(32'hFFFFFFFF), .rd_out(rd));
endmodule

// I-cache tag array is 64 sets -> 64-deep fakeram45_64x32 (was 32x32 at 16 sets).
module icache_tag_array #(parameter ADDR_WIDTH = 6)
  (vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [23:0] din0;
  output [23:0] dout0;
  wire [31:0] rd;
  assign dout0 = rd[23:0];
  fakeram45_64x32 u_ram (                // 64 deep -> addr_in[5:0]
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in(6'(addr0)), .wd_in({8'b0, din0}), .w_mask_in(32'hFFFFFFFF), .rd_out(rd));
endmodule
