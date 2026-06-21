// Behavioral model for a block-read bimodal (base PHT) bank (1R1W).
// 64 rows x 16b (= 8 lanes x 2b). SYNCHRONOUS read: address sampled at T (re=1), registered
// row out at T+1 -- a true fakeram45-style macro (reader presents the address one cycle
// early off blk_pc_next). re gates the capture so rdata HOLDS during a stall.
// Synchronous bit-masked write on an independent write port. Memory inits to 2'b01 per
// lane (16'h5555) to match the original bimodal RegInit(01) warm-up.
module bim_bank_array(clk, re, raddr, rdata, we, waddr, wdata, wmask);
  parameter DATA_WIDTH = 16;
  parameter ADDR_WIDTH = 6;
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
    for (i = 0; i < RAM_DEPTH; i = i + 1) mem[i] = 16'h5555;  // 8 lanes x 2'b01
  end

  // synchronous masked write
  always @(posedge clk) begin
    if (we) mem[waddr] <= (mem[waddr] & ~wmask) | (wdata & wmask);
  end

  // synchronous read, re-gated (holds during a stall); init 5555 = warm-up parity
  reg [DATA_WIDTH-1:0] rdata_reg;
  initial rdata_reg = 16'h5555;
  always @(posedge clk) begin
    if (re) rdata_reg <= mem[raddr];
  end
  assign rdata = rdata_reg;
endmodule
