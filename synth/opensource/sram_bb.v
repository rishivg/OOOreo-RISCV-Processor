// Empty blackbox stubs for the 6 SRAM macros so OpenSTA can link the netlist.
// No timing arcs => paths through the cache arrays are not analyzed (their
// access timing comes from the macro .lib in a real flow). Reg-to-reg core
// logic paths ARE analyzed, which is what this baseline targets.

module dcache_data_array(vdd, gnd, clk0, csb0, web0, addr0, wmask0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]   addr0;
  input  [31:0]  wmask0;
  input  [255:0] din0;
  output [255:0] dout0;
endmodule

module icache_data_array(vdd, gnd, clk0, csb0, web0, addr0, wmask0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]   addr0;
  input  [31:0]  wmask0;
  input  [255:0] din0;
  output [255:0] dout0;
endmodule

module mp_cache_data_array(vdd, gnd, clk0, csb0, web0, addr0, wmask0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]   addr0;
  input  [31:0]  wmask0;
  input  [255:0] din0;
  output [255:0] dout0;
endmodule

module dcache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [24:0] din0;
  output [24:0] dout0;
endmodule

module icache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [23:0] din0;
  output [23:0] dout0;
endmodule

module mp_cache_tag_array(vdd, gnd, clk0, csb0, web0, addr0, din0, dout0);
  inout vdd; inout gnd;
  input clk0, csb0, web0;
  input  [3:0]  addr0;
  input  [22:0] din0;
  output [22:0] dout0;
endmodule

module DW_div_seq(clk, rst_n, hold, start, a, b, complete, divide_by_0, quotient, remainder);
  parameter a_width = 33, b_width = 33, tc_mode = 1, num_cyc = 12,
            rst_mode = 1, input_mode = 0, output_mode = 0, early_start = 0;
  input  clk, rst_n, hold, start;
  input  [32:0] a;
  input  [32:0] b;
  output complete, divide_by_0;
  output [32:0] quotient;
  output [32:0] remainder;
endmodule
