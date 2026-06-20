// Behavioral model for a block-read TAGE table bank (1R1W).
// 64 rows x 112b (= 8 lanes x 14b). COMBINATIONAL read (same-cycle, to preserve the
// flop-version IPC == Phase 3a -- this is the area-measurement build; the sync-read
// 1-cycle-latency retiming is a deliberate follow-up). Synchronous bit-masked write on
// an independent write port (no read/write conflict in sim).
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

  // combinational read (IPC parity with the flop tables)
  assign rdata = mem[raddr];
endmodule
