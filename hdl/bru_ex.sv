module bru_ex 
    import rv32i_types::*;
    (
        input  reservation_station_t next_execute,  // Instruction ready for execution
        output to_writeback_t   execute_output  // Result to writeback
    );
    logic [31:0] rd_new, pc_new;  // Operands and results
    logic br_en;  // Branch taken signal 

    always_comb begin
        // Initialize all outputs to prevent latch inference
        br_en = '0;
        rd_new = '0;
        pc_new = '0;
        
        unique case(next_execute.opcode)
            op_b_jal: begin  // Jump and link
                br_en = 1'b1;  // Unconditional jump
                rd_new = next_execute.pc + 4;  // Return address
                pc_new = next_execute.pc + next_execute.imm_sext;
            end
            op_b_jalr: begin  // Jump and link register
                br_en = 1'b1;  // Unconditional jump
                rd_new = next_execute.pc + 4;  // Return address
                pc_new = (next_execute.rs1_data + next_execute.imm_sext) & 32'hFFFFFFFE;
            end
            op_b_br: begin  // Conditional branch
                // Evaluate branch condition
                unique case (next_execute.brop)
                    branch_f3_beq : br_en = (next_execute.rs1_data == next_execute.rs2_data);  // Equal
                    branch_f3_bne : br_en = (next_execute.rs1_data != next_execute.rs2_data);  // Not equal
                    branch_f3_blt : br_en = ($signed(next_execute.rs1_data) <  $signed(next_execute.rs2_data));  // Less than signed
                    branch_f3_bge : br_en = ($signed(next_execute.rs1_data) >= $signed(next_execute.rs2_data));  // Greater/equal signed
                    branch_f3_bltu: br_en = (next_execute.rs1_data <  next_execute.rs2_data);  // Less than unsigned
                    branch_f3_bgeu: br_en = (next_execute.rs1_data >= next_execute.rs2_data);  // Greater/equal unsigned
                    default       : br_en = '0;
                endcase
                if (br_en) begin
                    pc_new = next_execute.pc + next_execute.imm_sext;
                end
            end
            default: begin
                // All signals already initialized
            end
        endcase
    end

    always_comb begin 
        execute_output = '0;
        
        if (next_execute.valid) begin
            execute_output.valid = 1'b1;
            execute_output.prediction = next_execute.prediction;
            execute_output.rd_addr = next_execute.rd_addr;
            execute_output.rd_rob_idx = next_execute.rd_rob_idx;
            execute_output.rd_data = rd_new;
            execute_output.br_en = br_en;
            execute_output.pc_new = pc_new;
        end 
    end

endmodule