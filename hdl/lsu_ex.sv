module lsu_ex
import rv32i_types::*;
(
    input  logic            clk,
    input  logic            rst,
    input  cdb              cdbus,

    output logic            mem_stall,
    output logic   [31:0]   dmem_addr,
    output logic   [3:0]    dmem_rmask,
    output logic   [3:0]    dmem_wmask,
    input  logic   [31:0]   dmem_rdata,
    output logic   [31:0]   dmem_wdata,
    input  logic            dmem_resp,

    input rob_entry_t rob_entry_o,

    input  reservation_station_t next_execute,
    output to_writeback_t   execute_output
);
    logic [31:0] next_addr;
    assign next_addr = next_execute.rs1_data + next_execute.imm_sext;

    logic is_load, is_store, curr_store;
    assign is_load = (rv32i_opcode'(next_execute.inst[6:0]) == op_b_load);
    assign is_store = (rv32i_opcode'(next_execute.inst[6:0]) == op_b_store);

    logic   [31:0]   addr;
    logic   [3:0]    rmask;
    logic   [3:0]    wmask;

    logic   [31:0]  prev_pc;
    logic           new_inst;
    logic           mem_stall_local;

    always_ff @(posedge clk) begin
        if (rst)
            prev_pc <= '0;
        else if (!mem_stall_local)
            prev_pc <= next_execute.pc;
    end
    logic [4:0]  prev_rd_rob_idx;

    assign new_inst = (prev_pc != next_execute.pc || prev_rd_rob_idx != next_execute.rd_rob_idx) && next_execute.valid;
    assign mem_stall = mem_stall_local | new_inst;

    always_comb begin 
        curr_store = rob_entry_o.valid && (rob_entry_o.status == done) && (|rob_entry_o.mem_wmask);
        addr = {next_addr[31:2], 2'd0};
        rmask = next_execute.mem_rmask << next_addr[1:0];
        wmask = next_execute.mem_wmask << next_addr[1:0];
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            mem_stall_local <= 1'b0;
            dmem_rmask <= '0;
            dmem_wmask <= '0;
            prev_rd_rob_idx <= '0;
        end else begin
            prev_rd_rob_idx <= next_execute.rd_rob_idx;
            
            if (dmem_resp) begin
                mem_stall_local <= 1'b0;
                dmem_rmask <= '0;
                dmem_wmask <= '0;
            end else if (!mem_stall_local && !cdbus.flush) begin
                if (curr_store) begin
                    dmem_addr <= rob_entry_o.mem_addr;
                    dmem_rmask <= '0;
                    dmem_wmask <= rob_entry_o.mem_wmask;
                    dmem_wdata <= rob_entry_o.mem_wdata;
                    mem_stall_local <= 1'b1;
                end else if (is_load && next_execute.valid && new_inst) begin
                    dmem_addr <= {next_addr[31:2], 2'd0};
                    dmem_rmask <= next_execute.mem_rmask << next_addr[1:0];
                    dmem_wmask <= '0;
                    mem_stall_local <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        logic [31:0] raw_data;
        logic [1:0]  byte_offset;
        
        execute_output = '0;
        execute_output.rd_addr = next_execute.rd_addr;
        execute_output.rd_rob_idx = next_execute.rd_rob_idx;
        
        byte_offset = next_addr[1:0];
        
        // Determine raw data source
        if (is_load && next_execute.status == WAIT_STORE) begin
            raw_data = next_execute.rs2_data;
        end else begin
            raw_data = dmem_rdata;
        end

        if ((is_load && next_execute.status == WAIT_STORE) || (is_load && dmem_resp)) begin
            execute_output.valid = 1'b1;
            execute_output.mem_addr = (is_load && dmem_resp) ? dmem_addr : {next_addr[31:2], 2'd0};
            execute_output.mem_rmask = rmask;
            execute_output.mem_rdata = (is_load && dmem_resp) ? dmem_rdata : '0;

            unique case (next_execute.memop)
                mem_op_b    : execute_output.rd_data = {{24{raw_data[8*byte_offset + 7]}}, raw_data[8*byte_offset +: 8]};
                mem_op_bu   : execute_output.rd_data = {24'd0, raw_data[8*byte_offset +: 8]};
                mem_op_h    : execute_output.rd_data = {{16{raw_data[8*byte_offset + 15]}}, raw_data[8*byte_offset +: 16]};
                mem_op_hu   : execute_output.rd_data = {16'd0, raw_data[8*byte_offset +: 16]};
                mem_op_w    : execute_output.rd_data = raw_data >> (8*byte_offset);
                default     : execute_output.rd_data = '0;
            endcase
        end else if (is_store) begin
            execute_output.valid = 1'b1;
            execute_output.mem_addr = addr;
            execute_output.mem_wmask = wmask;
            execute_output.mem_wdata = next_execute.rs2_data << (8 * byte_offset);
        end
    end
endmodule
