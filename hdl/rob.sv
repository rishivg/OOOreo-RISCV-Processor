module rob 
import rv32i_types::*;
(
    input logic clk,
    input logic rst,
    input id_dis_stage_reg_t disp_entry,  // Instruction being dispatched
    output  rob_entry_t head_entry,  // Head entry for commit

    input   logic       enqueue,  // Dispatch valid signal
    input   logic       dequeue,  // Commit signal from ROB head
    input   cdb         cdbus,  // Common data bus with execution results

    output  logic [4:0] tail_addr,  // Current tail index for new instructions
    output  logic       full,  // ROB is full
    output  logic       commit_valid,  // Head entry ready for commit (combinational)
    output  rob_forward_t rob_out [32]  // Narrow forwarding info (reduced from full entries)
);
    localparam integer unsigned DEPTH = 32;

    rob_entry_t rob [DEPTH];  // Reorder buffer storage (matches old_hdl naming)

    rob_entry_t rob_entry_i;  // New entry to insert

    logic [4:0]  head_ptr, tail_ptr;  // Head and tail pointers (matches old_hdl naming)
    logic [5:0] rob_count;  // Number of entries in ROB (6 bits sufficient for max 32)
    logic        empty_o;  // ROB is empty
    
    // Pre-computed CDB validity signals for timing optimization
    logic alu_has_data, mul_has_data, br_has_data, mem_has_data;
    assign alu_has_data = cdbus.alu_valid;
    assign mul_has_data = cdbus.mul_valid;
    assign br_has_data = cdbus.br_valid;
    assign mem_has_data = cdbus.mem_valid;
    
    assign empty_o = (rob_count == 6'd0);
    assign full = (rob_count == 6'd32);
    
    always_comb begin
        head_entry = rob[head_ptr];
        head_entry.rd_rob_idx = head_ptr; // Optimization: Use pointer directly
    end

    assign commit_valid = !empty_o && (rob[head_ptr].status == done);  // Early commit signal
    
    logic insert, remove;

    assign insert = (enqueue && (!full || dequeue));  // Can insert if not full or simultaneously committing
    assign remove = dequeue && !empty_o;  // Can remove if not empty

    always_comb begin
        rob_entry_i = '0;
        if (disp_entry.valid) begin
            // Initialize new ROB entry from dispatch
            rob_entry_i.valid = 1'b1;
            rob_entry_i.pc = disp_entry.pc;
            rob_entry_i.inst = disp_entry.inst;
            rob_entry_i.status = rob_wait;  // Waiting for execution
            rob_entry_i.op_type = disp_entry.op_type;
            rob_entry_i.rd_addr = disp_entry.rd_addr;
            rob_entry_i.rd_rob_idx = tail_ptr;  // Assign ROB index
            rob_entry_i.rs1_addr = disp_entry.rs1_addr;
            rob_entry_i.rs2_addr = disp_entry.rs2_addr;
            rob_entry_i.regf_we = disp_entry.regf_we;
            rob_entry_i.tage_meta = disp_entry.tage_meta;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer unsigned i = 0; i < DEPTH; i++) begin
                rob[i].valid <= 1'b0;
            end
            head_ptr <= '0;
            tail_ptr <= '0;
            tail_addr <= '0;
            rob_count <= 6'd0;
        end
        else if (cdbus.flush) begin  // Branch misprediction - flush pipeline
            for (integer unsigned i = 0; i < DEPTH; i++) begin
                rob[i].valid <= 1'b0;
            end
            head_ptr <= unsigned'(head_ptr + 5'd1);
            tail_ptr <= unsigned'(head_ptr + 5'd1);
            tail_addr <= tail_ptr;
            rob_count <= 6'd0;
        end
        else begin
            // CDB writeback and status updates - optimized
            if (alu_has_data && rob[cdbus.alu_rob_idx].valid) begin
                rob[cdbus.alu_rob_idx].status <= done;
                rob[cdbus.alu_rob_idx].rd_data <= cdbus.alu_data;
                rob[cdbus.alu_rob_idx].rd_valid <= 1'b1;
            end
            if (br_has_data && rob[cdbus.br_rob_idx].valid) begin
                rob[cdbus.br_rob_idx].status <= done;
                rob[cdbus.br_rob_idx].rd_data <= cdbus.br_data;
                rob[cdbus.br_rob_idx].rd_valid <= 1'b1;
                rob[cdbus.br_rob_idx].br_en <= cdbus.br_en;
                rob[cdbus.br_rob_idx].pc_new <= cdbus.pc_new;
                rob[cdbus.br_rob_idx].prediction <= cdbus.prediction;
            end
            if (mul_has_data && rob[cdbus.mul_rob_idx].valid) begin
                rob[cdbus.mul_rob_idx].status <= done;
                rob[cdbus.mul_rob_idx].rd_data <= cdbus.mul_data;
                rob[cdbus.mul_rob_idx].rd_valid <= 1'b1;
            end
            if (mem_has_data && rob[cdbus.mem_rob_idx].valid) begin
                rob[cdbus.mem_rob_idx].status <= done;
                rob[cdbus.mem_rob_idx].rd_data <= cdbus.mem_data;
                rob[cdbus.mem_rob_idx].rd_valid <= 1'b1;
                rob[cdbus.mem_rob_idx].mem_addr <= cdbus.mem_addr;
                rob[cdbus.mem_rob_idx].mem_rmask <= cdbus.mem_rmask;
                rob[cdbus.mem_rob_idx].mem_wmask <= cdbus.mem_wmask;
                rob[cdbus.mem_rob_idx].mem_rdata <= cdbus.mem_rdata;
                rob[cdbus.mem_rob_idx].mem_wdata <= cdbus.mem_wdata;
            end
            
            if (remove) begin
                rob[head_ptr].valid <= '0;
                head_ptr <= head_ptr + 5'd1;
            end
            
            if (rob[head_ptr].status == done) begin
                rob[head_ptr].status <= empty;
            end
            
            if (insert) begin
                rob[tail_ptr] <= rob_entry_i;
                tail_addr <= tail_ptr;
                tail_ptr <= tail_ptr + 5'd1;
            end

            case ({insert, remove})
                2'b10: rob_count <= rob_count + 1'b1; 
                2'b01: rob_count <= rob_count - 1'b1; 
                default: rob_count <= rob_count;      
            endcase
        end
   end

    // Extract only forwarding-relevant fields from ROB entries
    always_comb begin
        for (integer unsigned i = 0; i < DEPTH; i++) begin
            rob_out[i].valid = rob[i].valid;
            rob_out[i].rd_addr = rob[i].rd_addr;
            rob_out[i].rd_data = rob[i].rd_data;
            rob_out[i].rob_idx = 5'(i); // Optimization: Use index directly
            rob_out[i].rd_valid = rob[i].rd_valid;
        end
    end

endmodule