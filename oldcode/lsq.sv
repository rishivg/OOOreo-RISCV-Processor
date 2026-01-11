module split_lsq
import rv32i_types::*;
# (
    parameter DEPTH = 4,
    parameter ROB_IDX_WIDTH = 5
)(
    input  logic        clk,
    input  logic        rst,
    input  reservation_station_t new_lsq_entry,

    input  cdb          cdbus,
    input               dmem_resp,

    output logic lsq_available,
    output reservation_station_t next_execute
);
    localparam PTR_WIDTH = $clog2(DEPTH);
    
    reservation_station_t empty_lsq_entry;
    reservation_station_t ld_queue[DEPTH], st_queue[DEPTH];

    logic [PTR_WIDTH-1:0] ld_head, st_head;
    logic [PTR_WIDTH-1:0] ld_tail, st_tail;
    logic [PTR_WIDTH-1:0] ld_next_head;
    logic [PTR_WIDTH:0]   ld_count, st_count;
    logic ld_full, st_full;
    
    // Optimized CDB validity checks (computed once)
    logic alu_has_data, mul_has_data, br_has_data, mem_has_data, commit_has_data;
    assign alu_has_data = cdbus.alu_valid;
    assign mul_has_data = cdbus.mul_valid;
    assign br_has_data = cdbus.br_valid;
    assign mem_has_data = cdbus.mem_valid && !(&cdbus.mem_wmask);
    assign commit_has_data = cdbus.regf_we;
    
    // Precomputed operand ready status
    logic ld_operands_ready[DEPTH];
    logic st_operands_ready[DEPTH];
    always_comb begin
        for (integer unsigned i = 0; i < DEPTH; i++) begin
            ld_operands_ready[i] = ld_queue[i].valid && ld_queue[i].rs1_ready && ld_queue[i].rs2_ready;
            st_operands_ready[i] = st_queue[i].valid && st_queue[i].rs1_ready && st_queue[i].rs2_ready;
        end
    end

    assign empty_lsq_entry = '0;

    always_ff @(posedge clk) begin
        if (rst || cdbus.flush) begin
            ld_queue <= '{DEPTH{empty_lsq_entry}};
            ld_head <= '0;
            ld_tail <= '0;
            ld_full <= 1'b0;
            
            st_queue <= '{DEPTH{empty_lsq_entry}};
            st_head <= '0;
            st_tail <= '0;
            st_full <= 1'b0;
        end
        else begin
            // Enqueue new entry
            if (new_lsq_entry.valid && lsq_available) begin
                if (new_lsq_entry.regf_we) begin
                    ld_queue[ld_tail] <= new_lsq_entry;
                    ld_tail <= ld_tail + PTR_WIDTH'(1);
                    if (ld_tail == ld_head - PTR_WIDTH'(1))
                        ld_full <= 1'b1;
                end else begin
                    st_queue[st_tail] <= new_lsq_entry;
                    st_tail <= st_tail + PTR_WIDTH'(1);
                    if (st_tail == st_head - PTR_WIDTH'(1))
                        st_full <= 1'b1;
                end  
            end

            // Combined CDB update for both load and store queues
            for (integer unsigned i = 0; i < DEPTH; i++) begin
                // Update load queue operands - optimized comparisons
                if (!ld_queue[i].rs1_ready && (ld_queue[i].rs1_addr != '0)) begin
                    if (alu_has_data && (ld_queue[i].rs1_rob_idx == cdbus.alu_rob_idx)) begin
                        ld_queue[i].rs1_data <= cdbus.alu_data; 
                        ld_queue[i].rs1_ready <= 1'b1;                         
                    end else if (mul_has_data && (ld_queue[i].rs1_rob_idx == cdbus.mul_rob_idx)) begin 
                        ld_queue[i].rs1_data <= cdbus.mul_data; 
                        ld_queue[i].rs1_ready <= 1'b1;                         
                    end else if (br_has_data && (ld_queue[i].rs1_rob_idx == cdbus.br_rob_idx)) begin
                        ld_queue[i].rs1_data <= cdbus.br_data; 
                        ld_queue[i].rs1_ready <= 1'b1;                         
                    end else if (mem_has_data && (ld_queue[i].rs1_rob_idx == cdbus.mem_rob_idx)) begin
                        ld_queue[i].rs1_data <= cdbus.mem_data; 
                        ld_queue[i].rs1_ready <= 1'b1;                         
                    end else if (commit_has_data && (ld_queue[i].rs1_rob_idx == cdbus.commit_rob_idx)) begin
                        ld_queue[i].rs1_data <= cdbus.commit_data; 
                        ld_queue[i].rs1_ready <= 1'b1;                         
                    end
                end

                if (!ld_queue[i].rs2_ready && (ld_queue[i].rs2_addr != '0)) begin
                    if (alu_has_data && (ld_queue[i].rs2_rob_idx == cdbus.alu_rob_idx)) begin
                        ld_queue[i].rs2_data <= cdbus.alu_data; 
                        ld_queue[i].rs2_ready <= 1'b1;                         
                    end else if (mul_has_data && (ld_queue[i].rs2_rob_idx == cdbus.mul_rob_idx)) begin 
                        ld_queue[i].rs2_data <= cdbus.mul_data; 
                        ld_queue[i].rs2_ready <= 1'b1;                         
                    end else if (br_has_data && (ld_queue[i].rs2_rob_idx == cdbus.br_rob_idx)) begin
                        ld_queue[i].rs2_data <= cdbus.br_data; 
                        ld_queue[i].rs2_ready <= 1'b1;                         
                    end else if (mem_has_data && (ld_queue[i].rs2_rob_idx == cdbus.mem_rob_idx)) begin
                        ld_queue[i].rs2_data <= cdbus.mem_data; 
                        ld_queue[i].rs2_ready <= 1'b1;                         
                    end else if (commit_has_data && (ld_queue[i].rs2_rob_idx == cdbus.commit_rob_idx)) begin
                        ld_queue[i].rs2_data <= cdbus.commit_data; 
                        ld_queue[i].rs2_ready <= 1'b1;                         
                    end
                end

                // Update store queue operands - optimized
                if (!st_queue[i].rs1_ready && (st_queue[i].rs1_addr != '0)) begin 
                    if (alu_has_data && (st_queue[i].rs1_rob_idx == cdbus.alu_rob_idx)) begin
                        st_queue[i].rs1_data <= cdbus.alu_data; 
                        st_queue[i].rs1_ready <= 1'b1;                         
                    end else if (mul_has_data && (st_queue[i].rs1_rob_idx == cdbus.mul_rob_idx)) begin
                        st_queue[i].rs1_data <= cdbus.mul_data; 
                        st_queue[i].rs1_ready <= 1'b1;                         
                    end else if (br_has_data && (st_queue[i].rs1_rob_idx == cdbus.br_rob_idx)) begin
                        st_queue[i].rs1_data <= cdbus.br_data; 
                        st_queue[i].rs1_ready <= 1'b1;                         
                    end else if (mem_has_data && (st_queue[i].rs1_rob_idx == cdbus.mem_rob_idx)) begin
                        st_queue[i].rs1_data <= cdbus.mem_data; 
                        st_queue[i].rs1_ready <= 1'b1;                         
                    end else if (commit_has_data && (st_queue[i].rs1_rob_idx == cdbus.commit_rob_idx)) begin
                        st_queue[i].rs1_data <= cdbus.commit_data; 
                        st_queue[i].rs1_ready <= 1'b1;                         
                    end
                end 
                
                if (!st_queue[i].rs2_ready && (st_queue[i].rs2_addr != '0)) begin
                    if (alu_has_data && (st_queue[i].rs2_rob_idx == cdbus.alu_rob_idx)) begin
                        st_queue[i].rs2_data <= cdbus.alu_data; 
                        st_queue[i].rs2_ready <= 1'b1;                         
                    end else if (mul_has_data && (st_queue[i].rs2_rob_idx == cdbus.mul_rob_idx)) begin 
                        st_queue[i].rs2_data <= cdbus.mul_data; 
                        st_queue[i].rs2_ready <= 1'b1;                         
                    end else if (br_has_data && (st_queue[i].rs2_rob_idx == cdbus.br_rob_idx)) begin
                        st_queue[i].rs2_data <= cdbus.br_data; 
                        st_queue[i].rs2_ready <= 1'b1;                         
                    end else if (mem_has_data && (st_queue[i].rs2_rob_idx == cdbus.mem_rob_idx)) begin
                        st_queue[i].rs2_data <= cdbus.mem_data;
                        st_queue[i].rs2_ready <= 1'b1;                         
                    end else if (commit_has_data && (st_queue[i].rs2_rob_idx == cdbus.commit_rob_idx)) begin
                        st_queue[i].rs2_data <= cdbus.commit_data; 
                        st_queue[i].rs2_ready <= 1'b1;                         
                    end
                end                // Mark load queue entry as complete when memory completes                 
                if (ld_queue[i].valid && ld_queue[i].rs1_ready && ld_queue[i].rs2_ready && cdbus.mem_valid && (cdbus.mem_rob_idx == ld_queue[i].rd_rob_idx) && (|ld_queue[i].mem_rmask)) begin
                    ld_queue[i].status <= COMPLETE;
                    ld_queue[i].valid <= 1'b0;

                    if (PTR_WIDTH'(i)==ld_head) begin
                        ld_head <= ld_next_head;
                        ld_full <= 1'b0;
                    end else if (PTR_WIDTH'(i)==ld_tail) begin
                        ld_tail <= ld_tail - PTR_WIDTH'(1);
                        ld_full <= 1'b0;
                    end
                end
            end

            // Mark store queue entry as wait_store/complete
            if (st_queue[st_head].status == WAIT_STORE && dmem_resp) begin
                st_queue[st_head].status <= COMPLETE;
                st_head <= st_head + PTR_WIDTH'(1);
                st_full <= 1'b0;
            end else if (st_queue[st_head].valid && cdbus.regf_we && (cdbus.commit_rob_idx == st_queue[st_head].rd_rob_idx) && (|st_queue[st_head].mem_wmask)) begin
                st_queue[st_head].status <= WAIT_STORE;
                st_queue[st_head].valid <= 1'b0;
            end
            
            // Advance load queue head past invalid entries (cleanup after stale completions)
            if (!ld_queue[ld_head].valid && (ld_count > '0)) begin
                ld_head <= ld_head + PTR_WIDTH'(1);
                ld_full <= 1'b0;
            end
            
            // Advance store queue head past invalid entries
            if (!st_queue[st_head].valid && st_queue[st_head].status != WAIT_STORE && (st_count > '0)) begin
                st_head <= st_head + PTR_WIDTH'(1);
                st_full <= 1'b0;
            end
        end
    end 


    logic [PTR_WIDTH-1:0] queue_idx; 
    always_comb begin : update_count
        ld_count = {1'b0, ld_tail - ld_head};     
        if (ld_tail < ld_head || ld_full)
            ld_count = {{1'b1, ld_tail} - {1'b0, ld_head}};   

        st_count = {1'b0, st_tail - st_head};     
        if (st_tail < st_head || st_full)
            st_count = {{1'b1, st_tail} - {1'b0, st_head}};   
        
        ld_next_head = ld_head + PTR_WIDTH'(1); 

        next_execute = '0;
        
        if (!cdbus.flush) begin
            // Speculative OoO Load Execution: Loads can bypass stores to different addresses
            // Priority: 1) Stores at head (in-order) 2) Loads that can bypass 3) Age-ordered loads
            
            if (st_count == '0) begin
                // No stores pending - any load can execute
                for (integer unsigned i = 0; i < DEPTH; i++) begin
                    if ((PTR_WIDTH+1)'(i) == ld_count)
                        break;

                    queue_idx = ld_head + PTR_WIDTH'(i);
                    if (ld_operands_ready[queue_idx]) begin
                        next_execute = ld_queue[queue_idx];
                        break;
                    end
                end
            end else if (ld_count == '0) begin
                // No loads - execute store at head
                if (st_operands_ready[st_head]) begin
                    next_execute = st_queue[st_head];
                end
            end else begin
                // Both queues have entries - enable speculative load bypass
                logic st_head_ready;
                logic ld_found;
                logic [PTR_WIDTH-1:0] ld_idx;
                logic [31:0] ld_addr;
                logic can_bypass;
                logic [PTR_WIDTH-1:0] st_idx;
                logic [31:0] st_addr;
                logic [3:0] ld_byte_mask, st_byte_mask;
                logic [31:0] forwarded_store_data;
                logic can_forward;
                
                st_head_ready = st_operands_ready[st_head];
                ld_found = 1'b0;
                ld_idx = 'x;
                can_bypass = 1'b0;
                can_forward = 1'b0;
                forwarded_store_data = '0;
                
                // Find oldest ready load and check if it can bypass pending stores
                for (integer unsigned i = 0; i < DEPTH; i++) begin
                    if ((PTR_WIDTH+1)'(i) == ld_count)
                        break;
                    
                    queue_idx = ld_head + PTR_WIDTH'(i);
                    if (ld_operands_ready[queue_idx]) begin
                        ld_found = 1'b1;
                        ld_idx = queue_idx;
                        ld_addr = ld_queue[queue_idx].rs1_data + ld_queue[queue_idx].imm_sext;
                        
                        // Check for address conflicts with recent older pending stores
                        // Optimize: Only check last 8 stores instead of entire queue for better timing
                        // This handles typical store-load forwarding patterns while reducing critical path
                        can_bypass = 1'b1;
                        
                        for (integer unsigned j = 0; j < 8; j++) begin  // Optimized window: last 8 stores
                            if ((PTR_WIDTH+1)'(j) >= st_count || j >= 8)
                                break;
                            
                            st_idx = st_head + PTR_WIDTH'(j);
                            
                            // Only check stores that are older than this load (order comparison)
                            if (st_queue[st_idx].valid && st_queue[st_idx].order < ld_queue[queue_idx].order) begin
                                // If store address is NOT ready, must wait - cannot bypass
                                if (!st_queue[st_idx].rs1_ready) begin
                                    can_bypass = 1'b0;
                                    break;
                                end
                                // Store address ready - check for memory conflict
                                st_addr = st_queue[st_idx].rs1_data + st_queue[st_idx].imm_sext;
                                
                                // Byte-level address matching for misaligned store forwarding
                                ld_byte_mask = ld_queue[queue_idx].mem_rmask << ld_addr[1:0];
                                st_byte_mask = st_queue[st_idx].mem_wmask << st_addr[1:0];
                                
                                // Check if addresses overlap (same word)
                                if (ld_addr[31:2] == st_addr[31:2]) begin
                                    // Check if store data is ready (rs2_ready)
                                    if (st_queue[st_idx].rs2_ready) begin
                                        // Check if store fully covers load (all load bytes are written by store)
                                        if ((ld_byte_mask & st_byte_mask) == ld_byte_mask) begin
                                            // Uncommitted store forwarding: forward data directly from pending store
                                            forwarded_store_data = st_queue[st_idx].rs2_data << (8 * st_addr[1:0]);
                                            can_forward = 1'b1;
                                            can_bypass = 1'b1;  // Can proceed without memory
                                        end else begin
                                            // Partial overlap - must wait for store to complete
                                            can_bypass = 1'b0;
                                        end
                                        break;  // Found matching store, stop searching
                                    end else begin
                                        // Store data not ready - must wait
                                        can_bypass = 1'b0;
                                        break;
                                    end
                                end
                            end
                        end
                        break;
                    end
                end
                
                // Selection logic with bypass capability
                if (st_head_ready) begin
                    if (ld_found && can_bypass && st_queue[st_head].order > ld_queue[ld_idx].order) begin
                        // Load is older and can safely bypass - execute it
                        next_execute = ld_queue[ld_idx];
                        // Apply uncommitted store forwarding if applicable
                        if (can_forward) begin
                            next_execute.rs2_data = forwarded_store_data;
                            next_execute.status = WAIT_STORE;
                        end
                    end else begin
                        // Execute store at head (maintains order for conflicting ops)
                        next_execute = st_queue[st_head];
                    end
                end else if (ld_found && can_bypass) begin
                    // Store not ready but load can bypass
                    next_execute = ld_queue[ld_idx];
                    // Apply uncommitted store forwarding if applicable
                    if (can_forward) begin
                        next_execute.rs2_data = forwarded_store_data;
                        next_execute.status = WAIT_STORE;
                    end
                end
            end
        end
    end

    always_comb begin
        lsq_available = !ld_full && !st_full;
    end
    
endmodule