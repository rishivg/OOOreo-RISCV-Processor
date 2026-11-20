// FPGA bindings for the registered-address, delayed-write SRAM interface.
// A disabled chip select retains the captured command, including pending writes.
module ooo_fpga_openram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter NUM_WMASKS = 4,
    parameter RAM_DEPTH = 1 << ADDR_WIDTH,
    parameter BLOCK = 0
) (
    input clk0, csb0, web0,
    input [NUM_WMASKS-1:0] wmask0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0
);
    localparam MASK_WIDTH = DATA_WIDTH / NUM_WMASKS;
    reg pending_web;
    reg [NUM_WMASKS-1:0] pending_mask;
    reg [ADDR_WIDTH-1:0] pending_addr;
    reg [DATA_WIDTH-1:0] pending_data;

    always @(posedge clk0) begin
        if (!csb0) begin
            pending_web <= web0;
            pending_mask <= wmask0;
            pending_addr <= addr0;
            pending_data <= din0;
        end
    end

    generate if (BLOCK) begin : g_block
        (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
        reg [DATA_WIDTH-1:0] raw, forwarded;
        reg [NUM_WMASKS-1:0] forward_mask;
        wire [ADDR_WIDTH-1:0] read_addr = csb0 ? pending_addr : addr0;
        integer lane;

        // Explicit write forwarding preserves the SRAM model's write-first read,
        // including a pending write while the captured read address is held.
        always @(posedge clk0) begin
            raw <= mem[read_addr];
            forward_mask <= (!pending_web && pending_addr == read_addr) ? pending_mask : 0;
            if (!pending_web && pending_addr == read_addr)
                forwarded <= pending_data;
            for (lane = 0; lane < NUM_WMASKS; lane = lane + 1)
                if (!pending_web && pending_mask[lane])
                    mem[pending_addr][lane*MASK_WIDTH +: MASK_WIDTH] <=
                        pending_data[lane*MASK_WIDTH +: MASK_WIDTH];
        end

        genvar byte_lane;
        for (byte_lane = 0; byte_lane < NUM_WMASKS; byte_lane = byte_lane + 1) begin : g_output
            assign dout0[byte_lane*MASK_WIDTH +: MASK_WIDTH] = forward_mask[byte_lane]
                ? forwarded[byte_lane*MASK_WIDTH +: MASK_WIDTH]
                : raw[byte_lane*MASK_WIDTH +: MASK_WIDTH];
        end
    end else begin : g_distributed
        (* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
        integer lane;
        always @(posedge clk0)
            for (lane = 0; lane < NUM_WMASKS; lane = lane + 1)
                if (!pending_web && pending_mask[lane])
                    mem[pending_addr][lane*MASK_WIDTH +: MASK_WIDTH] <=
                        pending_data[lane*MASK_WIDTH +: MASK_WIDTH];
        assign dout0 = mem[pending_addr];
    end endgenerate
endmodule

module dcache_data_array #(
    parameter DATA_WIDTH = 256, ADDR_WIDTH = 4, NUM_WMASKS = 32,
    parameter RAM_DEPTH = 1 << ADDR_WIDTH
) (
    input clk0, csb0, web0,
    input [NUM_WMASKS-1:0] wmask0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0
);
    ooo_fpga_openram #(DATA_WIDTH, ADDR_WIDTH, NUM_WMASKS, RAM_DEPTH, 0) ram (.*);
endmodule

module dcache_data_bank #(
    parameter DATA_WIDTH = 32, ADDR_WIDTH = 4, NUM_WMASKS = 4,
    parameter RAM_DEPTH = 1 << ADDR_WIDTH
) (
    input clk0, csb0, web0,
    input [NUM_WMASKS-1:0] wmask0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0
);
    ooo_fpga_openram #(DATA_WIDTH, ADDR_WIDTH, NUM_WMASKS, RAM_DEPTH, 0) ram (.*);
endmodule

module icache_data_array #(
    parameter DATA_WIDTH = 256, ADDR_WIDTH = 6, NUM_WMASKS = 32,
    parameter RAM_DEPTH = 1 << ADDR_WIDTH
) (
    input clk0, csb0, web0,
    input [NUM_WMASKS-1:0] wmask0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0
);
    ooo_fpga_openram #(DATA_WIDTH, ADDR_WIDTH, NUM_WMASKS, RAM_DEPTH, 1) ram (.*);
endmodule

module icache_data_bank #(
    parameter DATA_WIDTH = 128, ADDR_WIDTH = 6, NUM_WMASKS = 16,
    parameter RAM_DEPTH = 1 << ADDR_WIDTH
) (
    input clk0, csb0, web0,
    input [NUM_WMASKS-1:0] wmask0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0
);
    ooo_fpga_openram #(DATA_WIDTH, ADDR_WIDTH, NUM_WMASKS, RAM_DEPTH, 1) ram (.*);
endmodule

module dcache_tag_array #(
    parameter DATA_WIDTH = 25, ADDR_WIDTH = 4,
    parameter RAM_DEPTH = 1 << ADDR_WIDTH
) (
    input clk0, csb0, web0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0
);
    ooo_fpga_openram #(DATA_WIDTH, ADDR_WIDTH, 1, RAM_DEPTH, 0) ram (.wmask0(1'b1), .*);
endmodule
