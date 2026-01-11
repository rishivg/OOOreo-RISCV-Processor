module alu_ex 
import rv32i_types::*;
(
    input  reservation_station_t next_execute,  // Instruction ready for execution
    output to_writeback_t   execute_output  // Result to writeback
);

    logic [31:0] aluout;  // ALU result
    logic [31:0] a, b;  // ALU operands

    always_comb begin
        // Operand selection
        unique case (next_execute.alu_m1_sel)
            rs1_out: a = next_execute.rs1_data;
            pc_out:  a = next_execute.pc;
            default: a = '0;
        endcase

        unique case (next_execute.alu_m2_sel)
            rs2_out:  b = next_execute.rs2_data;
            imm_out:  b = next_execute.imm_sext;
            four_out: b = 32'd4;
            default:  b = '0;
        endcase

        // ALU operations
        unique case (next_execute.aluop)
            alu_op_add:  aluout = a + b;
            alu_op_sub:  aluout = a - b;
            alu_op_sll:  aluout = a << b[4:0];
            alu_op_srl:  aluout = a >> b[4:0];
            alu_op_sra:  aluout = unsigned'($signed(a) >>> b[4:0]);
            alu_op_xor:  aluout = a ^ b;
            alu_op_or:   aluout = a | b;
            alu_op_and:  aluout = a & b;
            alu_op_slt:  aluout = {31'd0, $signed(a) < $signed(b)};
            alu_op_sltu: aluout = {31'd0, a < b};
            default:     aluout = '0;
        endcase

        // Output assignment
        execute_output = '0;
        if (next_execute.valid) begin
            execute_output.valid = 1'b1;
            execute_output.rd_addr = next_execute.rd_addr;
            execute_output.rd_rob_idx = next_execute.rd_rob_idx;
            execute_output.rd_data = aluout;
        end
    end
endmodule