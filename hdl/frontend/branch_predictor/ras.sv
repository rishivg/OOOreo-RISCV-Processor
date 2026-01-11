module ras
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,
    
    // Speculative Update (from UBTB/Frontend)
    input   logic               valid, // prediction_valid (ubtb hit)
    input   logic   [IF_WIDTH-1:0] is_call,
    input   logic   [IF_WIDTH-1:0] is_ret,
    input   logic   [IF_WIDTH-1:0] [31:0] pc, // Address of the call instruction
                                             // RAS should push pc + 4
    output  logic   [31:0]      predict_target
);
    localparam RAS_DEPTH = 16;
    localparam RAS_IDX_BITS = $clog2(RAS_DEPTH);

    logic   [31:0]  stack [RAS_DEPTH];
    logic   [RAS_IDX_BITS-1:0] sp; // Stack Pointer

    // Simple LIFO
    // On Reset, SP = 0.
    // Push: stack[sp] = val; sp++
    // Pop: sp--; out = stack[sp]
    
    // We only support 1 Call or 1 Ret per cycle (or prioritise the first one).
    // Given IF_WIDTH (Fetch Width), we might have multiple.
    // For simplicity, handle only the *first* control flow instruction in the bundle.
    
    logic                       do_push;
    logic                       do_pop;
    logic   [31:0]              push_data;

    always_comb begin
        do_push = 1'b0;
        do_pop = 1'b0;
        push_data = '0;
        
        for (int i = 0; i < IF_WIDTH; i++) begin
            if (is_call[i]) begin
                do_push = 1'b1;
                push_data = pc[i] + 32'd4;
                break;
            end
            if (is_ret[i]) begin
                do_pop = 1'b1;
                break;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sp <= '0;
        end else if (valid) begin
            if (do_push) begin
                stack[sp] <= push_data;
                sp <= sp + 1'b1;
            end else if (do_pop) begin
                sp <= sp - 1'b1;
            end
        end
    end

    // Combinational Read (Speculative)
    // If we pop, we read stack[sp-1].
    // Note: If we push/pop in the same cycle, the logic above is sequential.
    // The prediction must be available Combinationally.
    // So logic out = stack[sp-1];
    
    assign predict_target = (sp == 0) ? 32'h0 : stack[sp-1'b1];
    
endmodule
