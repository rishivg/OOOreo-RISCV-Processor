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
  fakeram45_16x256 u_ram (              // right-sized: D$ is 16 sets (was 128-deep macro)
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({3'b0, addr0}), .wd_in(din0), .w_mask_in(wmask_bit), .rd_out(dout0));
endmodule

// I-cache is 64 sets (I_SET_IDX=6) -> 6-bit addr; right-sized fakeram45_64x256
// (was the 128-deep macro). ADDR_WIDTH param absorbs the #(.ADDR_WIDTH(SET_IDX)).
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
  fakeram45_64x256 u_ram (              // 64-deep (right-sized) -> addr_in[6:0], zero-extend
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
  fakeram45_16x32 u_ram (              // right-sized: D$ tag is 16 sets (was 32-deep macro)
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

// Block-read TAGE table bank: 64 rows x 112b (8 lanes x 14b) -> fakeram45_64x124
// (1 macro/bank, 8 banks = 2 per table x NUM=4). The RTL bank is 1R1W (read=predict,
// write=commit); mapped here to a single-port macro with addr-mux (we ? waddr : raddr).
// AREA-measurement model: a real build needs a 1R1W macro (or sync-read + bank conflict
// handling) -- see Phase 3c notes. ce_in tied active (read every cycle).
module tage_bank_array(clk, re, raddr, rdata, we, waddr, wdata, wmask);
  input clk, re, we;
  input  [5:0]   raddr, waddr;
  input  [111:0] wdata, wmask;
  output [111:0] rdata;
  wire [123:0] rd;
  assign rdata = rd[111:0];
  fakeram45_64x124 u_ram (
    .clk(clk), .ce_in(1'b0), .we_in(~we),
    .addr_in(we ? waddr : raddr),
    .wd_in({12'b0, wdata}), .w_mask_in({12'b0, wmask}), .rd_out(rd));
endmodule
