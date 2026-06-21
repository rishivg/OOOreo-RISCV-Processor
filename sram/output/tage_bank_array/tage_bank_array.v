// Behavioral model for a block-read TAGE table bank (1R1W).
// 64 rows x 112b (= 8 lanes x 14b). SYNCHRONOUS read: the address is sampled at cycle T
// (when re=1) and the registered row lands at T+1 -- a true fakeram45-style macro. The
// reader (tage_spinal) presents the address one cycle early off blk_pc_next so the
// prediction stays aligned with the fetched block. re also gates the capture so rdata
// HOLDS during a stall. Synchronous bit-masked write on an independent write port.
module tage_bank_array(clk, re, raddr, rdata, we, waddr, wdata, wmask);
  parameter DATA_WIDTH = 112;
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
