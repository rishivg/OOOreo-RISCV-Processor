// 1R1W micro-BTB bank with synchronous reads and bit-masked writes.
// Reads hold when re is low; a read/write collision returns the pre-write row.
// Zero-initialized rows leave all prediction lanes invalid.
module ubtb_bank_array(clk, re, raddr, rdata, we, waddr, wdata, wmask);
  parameter DATA_WIDTH = 256;
  parameter ADDR_WIDTH = 4;
  parameter RAM_DEPTH = 1 << ADDR_WIDTH;

  input  clk;
  input  re;
  input  [ADDR_WIDTH-1:0] raddr;
  output [DATA_WIDTH-1:0] rdata;
  input  we;
  input  [ADDR_WIDTH-1:0] waddr;
  input  [DATA_WIDTH-1:0] wdata;
  input  [DATA_WIDTH-1:0] wmask;

  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  integer i;
  initial begin
    for (i = 0; i < RAM_DEPTH; i = i + 1) mem[i] = {DATA_WIDTH{1'b0}};
  end

  // synchronous masked write
  always @(posedge clk) begin
    if (we) mem[waddr] <= (mem[waddr] & ~wmask) | (wdata & wmask);
  end

  // synchronous read, re-gated (holds during a stall); registered output = fakeram45 timing
  reg [DATA_WIDTH-1:0] rdata_reg;
  initial rdata_reg = {DATA_WIDTH{1'b0}};
  always @(posedge clk) begin
    if (re) rdata_reg <= mem[raddr];
  end
  assign rdata = rdata_reg;
endmodule
