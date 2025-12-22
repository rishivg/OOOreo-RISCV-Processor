module queue 
import rv32i_types::*;
#(
    parameter WIDTH = 32,  // Data width
    parameter DEPTH = 8    // Queue depth (ENTRIES in old_hdl)
)(
    input  logic clk,
    input  logic rst,
    input  logic flush,  // Flush signal to clear queue
    
    // Enqueue interface (write side)
    input  logic [WIDTH-1:0] enqueue_wdata,  // Data to enqueue
    input  logic enqueue,  // Enqueue enable
    output logic full,  // Queue is full
    
    // Dequeue interface (read side)
    output logic [WIDTH-1:0] dequeue_rdata,  // Data to dequeue
    input  logic dequeue,  // Dequeue enable
    output logic empty  // Queue is empty
);

    // Use one additional pointer width to distinguish full from empty
    localparam IND = $clog2(DEPTH);
    
    logic [WIDTH-1:0] entries [DEPTH-1:0];  // Queue storage
    logic [IND:0] head_ptr;  // Head pointer with MSB for full detection
    logic [IND:0] tail_ptr;  // Tail pointer with MSB for full detection
    
    // Full when pointers match in lower parts but differ in MSB
    assign full = ((head_ptr[IND-1:0] == tail_ptr[IND-1:0]) && (head_ptr[IND] != tail_ptr[IND]));
    // Empty when pointers match exactly
    assign empty = (head_ptr == tail_ptr);
    // Combinational output from queue head
    assign dequeue_rdata = entries[head_ptr[IND-1:0]];

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            head_ptr <= '0;
            tail_ptr <= '0;
        end
        else begin
            // Allow simultaneous enqueue and dequeue for maximum throughput
            // Enqueue: write data and advance tail pointer
            if (enqueue && !full) begin
                entries[tail_ptr[IND-1:0]] <= enqueue_wdata;
                tail_ptr <= tail_ptr + 1'b1;
            end
            
            // Dequeue: advance head pointer (can happen simultaneously with enqueue)
            if (dequeue && !empty) begin
                head_ptr <= head_ptr + 1'b1;
            end
        end
    end

endmodule : queue
