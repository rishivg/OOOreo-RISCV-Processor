module rsv_station
import rv32i_types::*;
#(
    parameter DEPTH = 4, 
    parameter ROB_IDX_WIDTH = 5 
)
(
    input  logic                        clk,
    input  logic                        rst,
    input  reservation_station_t        new_rs_entry,

    input  cdb                          cdbus,

    output logic                        rs_available,
    output reservation_station_t        next_execute
);
    localparam PTR_WIDTH = $clog2(DEPTH);
    
    reservation_station_t stations[DEPTH];
    logic   [PTR_WIDTH-1:0] head, tail, next_head_idx;
    logic   [PTR_WIDTH:0]   count;
    logic                   overflow_alert;
    logic                   is_completing[DEPTH];
    
    // Parallel CDB match signals for each station
    logic rs1_match_alu[DEPTH], rs1_match_mul[DEPTH], rs1_match_br[DEPTH], rs1_match_mem[DEPTH], rs1_match_commit[DEPTH];
    logic rs2_match_alu[DEPTH], rs2_match_mul[DEPTH], rs2_match_br[DEPTH], rs2_match_mem[DEPTH], rs2_match_commit[DEPTH];
    
    // Optimized: Check validity once per CDB source
    logic alu_has_data, mul_has_data, br_has_data, mem_has_data, commit_has_data;
    assign alu_has_data = cdbus.alu_valid;
    assign mul_has_data = cdbus.mul_valid;
    assign br_has_data = cdbus.br_valid;
    assign mem_has_data = cdbus.mem_valid && !(&cdbus.mem_wmask);
    assign commit_has_data = cdbus.regf_we;
    
    // Precomputed operand ready status
    logic operands_ready[DEPTH];
    always_comb begin
        for (integer unsigned i = 0; i < DEPTH; i++) begin
            operands_ready[i] = stations[i].valid && stations[i].rs1_ready && stations[i].rs2_ready;
            // Compute is_completing combinationally to avoid blocking assignment in sequential block
            is_completing[i] = (cdbus.alu_rob_idx == stations[i].rd_rob_idx && alu_has_data) ||
                               (cdbus.mul_rob_idx == stations[i].rd_rob_idx && mul_has_data) ||
                               (cdbus.br_rob_idx == stations[i].rd_rob_idx && br_has_data);
            
            // Parallel CDB match computation - optimized with early validity check
            rs1_match_alu[i] = alu_has_data && (stations[i].rs1_rob_idx == cdbus.alu_rob_idx);
            rs1_match_mul[i] = mul_has_data && (stations[i].rs1_rob_idx == cdbus.mul_rob_idx);
            rs1_match_br[i] = br_has_data && (stations[i].rs1_rob_idx == cdbus.br_rob_idx);
            rs1_match_mem[i] = mem_has_data && (stations[i].rs1_rob_idx == cdbus.mem_rob_idx);
            rs1_match_commit[i] = commit_has_data && (stations[i].rs1_rob_idx == cdbus.commit_rob_idx);
            
            rs2_match_alu[i] = alu_has_data && (stations[i].rs2_rob_idx == cdbus.alu_rob_idx);
            rs2_match_mul[i] = mul_has_data && (stations[i].rs2_rob_idx == cdbus.mul_rob_idx);
            rs2_match_br[i] = br_has_data && (stations[i].rs2_rob_idx == cdbus.br_rob_idx);
            rs2_match_mem[i] = mem_has_data && (stations[i].rs2_rob_idx == cdbus.mem_rob_idx);
            rs2_match_commit[i] = commit_has_data && (stations[i].rs2_rob_idx == cdbus.commit_rob_idx);
        end
    end

    always_ff @(posedge clk) begin
        if (rst || cdbus.flush) begin
            stations <= '{DEPTH{'0}};
        end else begin
            // Dispatch new entry to tail
            if (new_rs_entry.valid && rs_available) begin
                stations[tail] <= new_rs_entry;
            end

            // CDB forwarding to all stations
            for (integer unsigned i = 0; i < DEPTH; i++) begin
                if (stations[i].valid) begin
                    // Update rs1 operand from CDB
                    if (!stations[i].rs1_ready && (stations[i].rs1_addr != '0)) begin
                        if (rs1_match_alu[i]) begin
                            stations[i].rs1_data <= cdbus.alu_data;
                            stations[i].rs1_ready <= 1'b1;
                        end else if (rs1_match_mul[i]) begin
                            stations[i].rs1_data <= cdbus.mul_data;
                            stations[i].rs1_ready <= 1'b1;
                        end else if (rs1_match_br[i]) begin
                            stations[i].rs1_data <= cdbus.br_data;
                            stations[i].rs1_ready <= 1'b1;
                        end else if (rs1_match_mem[i]) begin
                            stations[i].rs1_data <= cdbus.mem_data;
                            stations[i].rs1_ready <= 1'b1;
                        end else if (rs1_match_commit[i]) begin
                            stations[i].rs1_data <= cdbus.commit_data;
                            stations[i].rs1_ready <= 1'b1;
                        end
                    end
                    
                    // Update rs2 operand from CDB
                    if (!stations[i].rs2_ready && (stations[i].rs2_addr != '0)) begin
                        if (rs2_match_alu[i]) begin
                            stations[i].rs2_data <= cdbus.alu_data;
                            stations[i].rs2_ready <= 1'b1;
                        end else if (rs2_match_mul[i]) begin
                            stations[i].rs2_data <= cdbus.mul_data;
                            stations[i].rs2_ready <= 1'b1;
                        end else if (rs2_match_br[i]) begin
                            stations[i].rs2_data <= cdbus.br_data;
                            stations[i].rs2_ready <= 1'b1;
                        end else if (rs2_match_mem[i]) begin
                            stations[i].rs2_data <= cdbus.mem_data;
                            stations[i].rs2_ready <= 1'b1;
                        end else if (rs2_match_commit[i]) begin
                            stations[i].rs2_data <= cdbus.commit_data;
                            stations[i].rs2_ready <= 1'b1;
                        end
                    end

                    // Mark completed instructions
                    if (operands_ready[i] && is_completing[i]) begin
                        stations[i].status <= COMPLETE;
                        stations[i].valid <= 1'b0;
                    end
                end
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst || cdbus.flush) begin
            head <= '0;
            tail <= '0;
            overflow_alert <= 1'b0;
        end
        else begin
            if (new_rs_entry.valid && rs_available) begin
                tail <= tail + PTR_WIDTH'(1);
                if (tail == head-PTR_WIDTH'(1))
                    overflow_alert <= 1'b1;
            end
            
            for (integer unsigned i = 0; i < DEPTH; i++) begin
                if (operands_ready[i] && is_completing[i]) begin
                    if (PTR_WIDTH'(i) == head) begin
                        head <= next_head_idx;
                        overflow_alert <= 1'b0;
                    end
                end
            end
            
            // Advance head if current entry is invalid
            if (!stations[head].valid && count > '0) begin
                head <= head + PTR_WIDTH'(1);
                overflow_alert <= 1'b0;
            end
        end
    end

    logic   [PTR_WIDTH-1:0] idx; 
    always_comb begin : update_count
        count = {1'b0, tail - head};     
        if (tail < head || overflow_alert)
            count = {{1'b1, tail} - {1'b0, head}};   

        next_execute = '0;
        next_head_idx = head + PTR_WIDTH'(1);
        
        // Find next head candidate
        for (integer unsigned i = 1; i < DEPTH; i++) begin
                idx = PTR_WIDTH'(head + i);  // Full-width addition, then truncate

                if ((PTR_WIDTH+1)'(unsigned'(i)) == count) begin
                    next_head_idx = idx;
                    break;
                end

                if (stations[idx].valid) begin
                    next_head_idx = idx;
                    break;
                end
            end
            
            // Age-ordered selection: find oldest ready instruction from head
            for (integer unsigned i = 0; i < DEPTH; i++) begin
                if ((PTR_WIDTH+1)'(i) == count)
                    break;
                    
                idx = PTR_WIDTH'(head + i);  // Full-width addition, then truncate
                // Use precomputed operands_ready for faster selection
                if (operands_ready[idx] && !(is_completing[idx])) begin
                    next_execute = stations[idx];
                    break;
                end
            end
    end

    assign rs_available = (count < (PTR_WIDTH+1)'(unsigned'(DEPTH)));
endmodule