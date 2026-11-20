// Pin bindings for placeholder Nangate45 screening macros.

module dcache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [24:0] din0;
  output [24:0] dout0;
  wire [31:0] rd;
  assign dout0 = rd[24:0];
  fakeram45_16x32 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({1'b0, addr0}), .wd_in({7'b0, din0}), .w_mask_in(32'hFFFFFFFF), .rd_out(rd));
endmodule

// I-cache tags use a 64-row screening macro.
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

// TAGE: independent read/write ports; fixed 32 x 96 screening geometry.
module tage_bank_array #(parameter DATA_WIDTH=96, parameter ADDR_WIDTH=5)
                       (clk, re, raddr, rdata, we, waddr, wdata, wmask);  // params accept the BlackBox override; body is fixed-width
  input clk, re, we;
  input  [4:0]  raddr, waddr;
  input  [95:0] wdata, wmask;
  output [95:0] rdata;
  wire [123:0] rd;
  assign rdata = rd[95:0];
  fakeram45_1r1w_32x96 u_ram (
    .clk(clk), .ce_in(~(re | we)), .we_in(~we),
    .addr_in({1'b0, raddr}), .waddr_in({1'b0, waddr}),
    .wd_in({28'b0, wdata}), .w_mask_in({28'b0, wmask}), .rd_out(rd));
endmodule

// Bimodal predictor: 64 x 16 logical bits in a 1R1W 64 x 32 fixture.
module bim_bank_array #(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=6)
                      (clk, re, raddr, rdata, we, waddr, wdata, wmask);  // params accept the BlackBox override; body is fixed-width
  input clk, re, we;
  input  [5:0]  raddr, waddr;
  input  [15:0] wdata, wmask;
  output [15:0] rdata;
  wire [31:0] rd;
  assign rdata = rd[15:0];
  fakeram45_1r1w_64x32 u_ram (
    .clk(clk), .ce_in(~(re | we)), .we_in(~we),
    .addr_in(raddr), .waddr_in(waddr),
    .wd_in({16'b0, wdata}), .w_mask_in({16'b0, wmask}), .rd_out(rd));
endmodule

// uBTB: 16 x 240 logical bits with independent read/write addresses.
module ubtb_bank_array #(parameter DATA_WIDTH=240, parameter ADDR_WIDTH=4)
                       (clk, re, raddr, rdata, we, waddr, wdata, wmask);  // params accept the BlackBox override
  input clk, re, we;
  input  [3:0]   raddr, waddr;
  input  [239:0] wdata, wmask;          // {valid,tag9,adj2,lo18} x 8 lanes = 240b
  output [239:0] rdata;
  wire [255:0] rd;
  assign rdata = rd[239:0];
  fakeram45_1r1w_16x240 u_ram (
    .clk(clk), .ce_in(~(re | we)), .we_in(~we),
    .addr_in({3'b0, raddr}), .waddr_in({3'b0, waddr}),
    .wd_in({16'b0, wdata}), .w_mask_in({16'b0, wmask}), .rd_out(rd));
endmodule

// I-cache: fills write both 128-bit banks; reads enable the addressed bank.
module icache_data_bank #(parameter ADDR_WIDTH = 6)
  (vdd, gnd, clk0, csb0, web0, wmask0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [15:0]  wmask0;
  input  [127:0] din0;
  output [127:0] dout0;
  wire [255:0] rd;
  assign dout0 = rd[127:0];
  wire [127:0] wmask_bit;
  genvar i;
  generate for (i = 0; i < 128; i = i + 1) begin : g_wmask
    assign wmask_bit[i] = wmask0[i/8];
  end endgenerate
  fakeram45_64x128 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in(7'(addr0)), .wd_in({128'b0, din0}), .w_mask_in({128'b0, wmask_bit}), .rd_out(rd));
endmodule

// Predecode follows the corresponding I-cache data bank address and chip select.
module icache_pd_bank #(parameter ADDR_WIDTH = 6, parameter DATA_WIDTH = 32)
  (vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [DATA_WIDTH-1:0] din0;
  output [DATA_WIDTH-1:0] dout0;
  wire [31:0] rd;
  assign dout0 = rd[DATA_WIDTH-1:0];
  fakeram45_64x32 u_ram (
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in(6'(addr0)), .wd_in(32'(din0)), .w_mask_in({32{1'b1}}), .rd_out(rd));
endmodule

// D-cache: one 32-bit word per bank; byte enables expand to per-bit masks.
module dcache_data_bank #(parameter ADDR_WIDTH = 4)
  (vdd, gnd, clk0, csb0, web0, wmask0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [3:0]  wmask0;
  input  [31:0] din0;
  output [31:0] dout0;
  wire [31:0] wmask_bit;
  genvar i;
  generate for (i = 0; i < 32; i = i + 1) begin : g_wmask
    assign wmask_bit[i] = wmask0[i/8];
  end endgenerate
  fakeram45_16x32 u_ram (              // 16 deep (macro addr is 5b, zero-extended)
    .clk(clk0), .ce_in(csb0), .we_in(web0),
    .addr_in({1'b0, addr0}), .wd_in(din0), .w_mask_in(wmask_bit), .rd_out(dout0));
endmodule
