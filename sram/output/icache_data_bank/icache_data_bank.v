// OpenRAM SRAM model
// I$ data BLOCK BANK (power lever): one 16B fetch block of a way's line per
// bank (2 banks/way); reads chip-enable only the addressed block's bank.
// Same registered-control / sync-read contract as icache_data_array.
// Words: 64
// Word size: 128
// Write size: 8

module icache_data_bank(
`ifdef USE_POWER_PINS
    vdd,
    gnd,
`endif
// Port 0: RW
    clk0,csb0,web0,wmask0,addr0,din0,dout0
  );

  parameter NUM_WMASKS = 16 ;
  parameter DATA_WIDTH = 128 ;
  parameter ADDR_WIDTH = 6 ;
  parameter RAM_DEPTH = 1 << ADDR_WIDTH;

`ifdef USE_POWER_PINS
    inout vdd;
    inout gnd;
`endif
  input  clk0; // clock
  input   csb0; // active low chip select
  input  web0; // active low write control
  input [ADDR_WIDTH-1:0]  addr0;
  input [NUM_WMASKS-1:0]   wmask0; // write mask
  input [DATA_WIDTH-1:0]  din0;
  output [DATA_WIDTH-1:0] dout0;

  reg [DATA_WIDTH-1:0]    mem [0:RAM_DEPTH-1];

  reg  web0_reg;
  reg [NUM_WMASKS-1:0]   wmask0_reg;
  reg [ADDR_WIDTH-1:0]  addr0_reg;
  reg [DATA_WIDTH-1:0]  din0_reg;
  reg [DATA_WIDTH-1:0]  dout0;

  always @(posedge clk0)
  begin
    if( !csb0 ) begin
      web0_reg <= web0;
      wmask0_reg <= wmask0;
      addr0_reg <= addr0;
      din0_reg <= din0;
    end
  end

  genvar gi;
  generate for (gi = 0; gi < NUM_WMASKS; gi = gi + 1) begin : g_wr
    always @ (posedge clk0)
      if ( !web0_reg && wmask0_reg[gi] )
        mem[addr0_reg][8*gi +: 8] <= din0_reg[8*gi +: 8];
  end endgenerate

  always @ (*)
  begin : MEM_READ0
    dout0 = mem[addr0_reg];
  end

endmodule
