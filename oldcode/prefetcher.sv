module prefetcher (
    input   logic           clk,
    input   logic           rst,
    
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    output  logic   [31:0]  ufp_rdata,
    output  logic   [255:0] ufp_rcache_line,
    output  logic           ufp_resp,
    
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    input   logic   [255:0] dfp_rdata,
    input   logic           dfp_resp
);
    logic ufp_resp_internal;
    logic[31:0] ufp_addr_internal;
    logic[3:0]  ufp_rmask_internal;
    
    // Stride prefetcher signals
    logic        pf_valid;
    logic [31:0] pf_addr;
    logic        pf_grant;

    // State machine for demand/prefetch
    typedef enum logic [1:0] {
        DEMAND,     // Serving CPU demand requests
        PREFETCH    // Issuing prefetch requests
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= DEMAND;
        end else begin
            state <= next_state;
        end
    end
    
    // State transition logic
    always_comb begin
        next_state = state;
        
        case (state)
            DEMAND: begin
                // Issue prefetch immediately after demand completes if prediction available
                if (ufp_resp_internal && pf_valid) begin
                    next_state = PREFETCH;
                end
            end
            
            PREFETCH: begin
                // Return to DEMAND as soon as prefetch completes
                if (ufp_resp_internal) begin
                    next_state = DEMAND;
                end
            end
        endcase
    end
    
    // Address/control multiplexing
    always_comb begin
        // Default assignments to prevent latches
        ufp_addr_internal = ufp_addr;
        ufp_rmask_internal = ufp_rmask;
        ufp_resp = ufp_resp_internal;
        pf_grant = 1'b0;
        
        case (state)
            DEMAND: begin
                // Demand uses defaults set above
            end
            
            PREFETCH: begin
                ufp_addr_internal = pf_addr;
                ufp_rmask_internal = 4'b1111;
                ufp_resp = 1'b0;  // Don't signal CPU during prefetch
                pf_grant = 1'b1;
            end
            
            default: begin
                // Default case uses initial assignments
            end
        endcase
    end
    
    // Stride prefetcher instantiation
    stride_prefetcher #(
        .LINE_SHIFT(5),
        .PREFETCH_DISTANCE(2)   // Reduced from 4
    ) stride_pf (
        .clk(clk),
        .rst(rst),
        .access_valid(ufp_resp_internal),
        .access_addr(ufp_addr),
        .pf_valid(pf_valid),
        .pf_addr(pf_addr),
        .pf_grant(pf_grant)
    );

    icache instruction_cache (
        .clk        (clk),
        .rst        (rst),
        
        .ufp_addr   (ufp_addr_internal),
        .ufp_rmask  (ufp_rmask_internal),
        .ufp_rdata  (ufp_rdata),
        .ufp_rcache_line (ufp_rcache_line),
        .ufp_resp   (ufp_resp_internal),

        .dfp_addr   (dfp_addr),
        .dfp_read   (dfp_read),
        .dfp_rdata  (dfp_rdata),
        .dfp_resp   (dfp_resp)
    );
endmodule

// Stride prefetcher module
module stride_prefetcher #(
    parameter integer LINE_SHIFT       = 5,
    parameter integer PREFETCH_DISTANCE = 1  // How many strides ahead to prefetch
)(
    input  logic        clk,
    input  logic        rst,

    input  logic        access_valid,
    input  logic [31:0] access_addr,

    output logic        pf_valid,
    output logic [31:0] pf_addr,
    input  logic        pf_grant
);

    localparam BLOCK_ADDR_WIDTH = 32 - LINE_SHIFT;

    logic signed [BLOCK_ADDR_WIDTH-1:0] last_block_addr;
    logic signed [BLOCK_ADDR_WIDTH-1:0] last_stride;
    logic                               conf;  
    logic                               have_last;

    logic [BLOCK_ADDR_WIDTH-1:0] pending_pf_block;
    logic                        pending_pf;

    logic signed [BLOCK_ADDR_WIDTH-1:0] access_block_addr;
    assign access_block_addr = $signed(BLOCK_ADDR_WIDTH'(access_addr[31:LINE_SHIFT]));
    
    logic signed [BLOCK_ADDR_WIDTH-1:0] stride_now;
    assign stride_now = access_block_addr - last_block_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            last_block_addr  <= '0;
            last_stride      <= '0;
            conf             <= 1'b0;
            have_last        <= 1'b0;
            pending_pf       <= 1'b0;
            pending_pf_block <= '0;
        end else begin
            // Clear pending prefetch when granted
            if (pf_valid && pf_grant) begin
                pending_pf <= 1'b0;
            end

            if (access_valid) begin
                last_block_addr <= access_block_addr;

                if (!have_last) begin
                    // Start predicting immediately - assume first stride is valid
                    have_last   <= 1'b1;
                    last_stride <= stride_now;
                    conf        <= 1'b1;  // Optimistically assume stride is valid
                    
                    // Issue first prefetch immediately
                    if (stride_now != 0 && !pending_pf) begin
                        pending_pf       <= 1'b1;
                        pending_pf_block <= BLOCK_ADDR_WIDTH'(unsigned'(access_block_addr + (stride_now * PREFETCH_DISTANCE)));
                    end
                end else begin
                    // Simple confidence: set if stride matches, clear if different
                    conf <= (stride_now == last_stride) && (stride_now != 0);
                    
                    // Update stride on mismatch or zero
                    if (stride_now != last_stride || stride_now == 0) begin
                        last_stride <= stride_now;
                    end
                    
                    // Issue prefetch if confident and no pending prefetch
                    if (conf && last_stride != 0 && !pending_pf) begin
                        pending_pf       <= 1'b1;
                        pending_pf_block <= BLOCK_ADDR_WIDTH'(unsigned'(access_block_addr + (last_stride * PREFETCH_DISTANCE)));
                    end
                end
            end
        end
    end

    always_comb begin
        pf_valid = pending_pf;
        pf_addr  = {pending_pf_block, {LINE_SHIFT{1'b0}}};
    end

endmodule