module decode
import rv32i_types::*;
(
    input if_id_stage_reg_t     decode_struct_in,  // Contains instruction, PC, order, and status flag
    output id_dis_stage_reg_t   decode_struct_out  // Fully decoded instruction with control signals
);

    logic [31:0] inst;
    logic [2:0] funct3;  // Function code for most operations
    logic [6:0] funct7;  // Additional function code for R-type instructions
    logic [6:0] opcode;  // Primary opcode
    logic [31:0] i_imm, s_imm, b_imm, u_imm, j_imm;  // Immediate values for each format
    logic [4:0] rs1_addr, rs2_addr, rd_addr;  // Register addresses

    // Extract fields from instruction
    assign inst = decode_struct_in.inst;
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];
    
    // Sign-extend immediates based on instruction format
    assign i_imm  = {{21{inst[31]}}, inst[30:20]};
    assign s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imm  = {inst[31:12], 12'h000};
    assign j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    
    assign rs1_addr = inst[19:15];
    assign rs2_addr = inst[24:20];
    assign rd_addr = inst[11:7];

    always_comb begin
        decode_struct_out = '0;

        // Pass through unchanged fields
        decode_struct_out.inst = decode_struct_in.inst;
        decode_struct_out.pc = decode_struct_in.pc;
        decode_struct_out.order = decode_struct_in.order;
        decode_struct_out.valid = decode_struct_in.valid;
        decode_struct_out.opcode = opcode;
        decode_struct_out.funct3 = funct3;
        decode_struct_out.funct7 = funct7;
        decode_struct_out.rd_addr = rd_addr;
        decode_struct_out.rs1_addr = rs1_addr;
        decode_struct_out.rs2_addr = rs2_addr;
        
        // Initialize operation types to defined values (reduces logic)
        decode_struct_out.aluop = alu_op_add;
        decode_struct_out.multop = mult_op_mul;
        decode_struct_out.brop = branch_f3_beq;
        decode_struct_out.memop = mem_op_none;
        decode_struct_out.prediction = decode_struct_in.prediction;
        decode_struct_out.tage_meta = decode_struct_in.tage_meta;
        
        unique case (opcode)
            op_b_lui: begin
                decode_struct_out.op_type = alu;
                decode_struct_out.imm = u_imm;
                decode_struct_out.regf_we = 1'b1;
                decode_struct_out.alu_m1_sel = no_out;
                decode_struct_out.alu_m2_sel = imm_out;
            end
            op_b_auipc: begin
                decode_struct_out.op_type = alu;
                decode_struct_out.imm = u_imm;
                decode_struct_out.regf_we = 1'b1;
                decode_struct_out.alu_m1_sel = pc_out;
                decode_struct_out.alu_m2_sel = imm_out;
            end
            op_b_jal: begin
                decode_struct_out.op_type = br;
                decode_struct_out.imm = j_imm;
                decode_struct_out.regf_we = 1'b1;
            end
            op_b_jalr: begin
                decode_struct_out.op_type = br;
                decode_struct_out.imm = i_imm;
                decode_struct_out.regf_we = 1'b1;
                decode_struct_out.use_rs1 = 1'b1;
            end
            op_b_br: begin
                decode_struct_out.op_type = br;
                decode_struct_out.imm = b_imm;
                decode_struct_out.rd_addr = '0;
                decode_struct_out.brop = branch_f3_t'(funct3);
                decode_struct_out.use_rs1 = 1'b1;
                decode_struct_out.use_rs2 = 1'b1;
            end
            op_b_load: begin
                decode_struct_out.op_type = mem;
                decode_struct_out.imm = i_imm;
                decode_struct_out.regf_we = 1'b1;
                decode_struct_out.use_rs1 = 1'b1;
                
                unique case (funct3)
                    load_f3_lb:  {decode_struct_out.memop, decode_struct_out.mem_rmask} = {mem_op_b,  4'b0001};
                    load_f3_lbu: {decode_struct_out.memop, decode_struct_out.mem_rmask} = {mem_op_bu, 4'b0001};
                    load_f3_lh:  {decode_struct_out.memop, decode_struct_out.mem_rmask} = {mem_op_h,  4'b0011};
                    load_f3_lhu: {decode_struct_out.memop, decode_struct_out.mem_rmask} = {mem_op_hu, 4'b0011};
                    load_f3_lw:  {decode_struct_out.memop, decode_struct_out.mem_rmask} = {mem_op_w,  4'b1111};
                    default:     decode_struct_out.memop = mem_op_none;
                endcase
            end
            op_b_store: begin
                decode_struct_out.op_type = mem;
                decode_struct_out.imm = s_imm;
                decode_struct_out.rd_addr = '0;
                decode_struct_out.use_rs1 = 1'b1;
                decode_struct_out.use_rs2 = 1'b1;

                unique case (funct3)
                    store_f3_sb: {decode_struct_out.memop, decode_struct_out.mem_wmask} = {mem_op_b, 4'b0001};
                    store_f3_sh: {decode_struct_out.memop, decode_struct_out.mem_wmask} = {mem_op_h, 4'b0011};
                    store_f3_sw: {decode_struct_out.memop, decode_struct_out.mem_wmask} = {mem_op_w, 4'b1111};
                    default:     decode_struct_out.memop = mem_op_none;
                endcase
            end
            op_b_imm: begin
                decode_struct_out.op_type = alu;
                decode_struct_out.imm = i_imm;
                decode_struct_out.regf_we = 1'b1;
                decode_struct_out.use_rs1 = 1'b1;
                decode_struct_out.alu_m1_sel = rs1_out;
                decode_struct_out.alu_m2_sel = imm_out;
                
                unique case (funct3)
                    arith_f3_slt:  decode_struct_out.aluop = alu_op_slt;
                    arith_f3_sltu: decode_struct_out.aluop = alu_op_sltu;
                    arith_f3_sr:   decode_struct_out.aluop = (funct7[5]) ? alu_op_sra : alu_op_srl;
                    default:       decode_struct_out.aluop = alu_ops'(funct3);
                endcase
            end
            op_b_reg: begin
                decode_struct_out.regf_we = 1'b1;
                decode_struct_out.use_rs1 = 1'b1;
                decode_struct_out.use_rs2 = 1'b1;
                decode_struct_out.alu_m1_sel = rs1_out;
                decode_struct_out.alu_m2_sel = rs2_out;

                if (funct7 == mult) begin
                    decode_struct_out.op_type = mul;
                    decode_struct_out.multop = mult_ops'(funct3);
                end else begin
                    decode_struct_out.op_type = alu;
                    unique case (funct3)
                        arith_f3_slt:  decode_struct_out.aluop = alu_op_slt;
                        arith_f3_sltu: decode_struct_out.aluop = alu_op_sltu;
                        arith_f3_sr:   decode_struct_out.aluop = (funct7[5]) ? alu_op_sra : alu_op_srl;
                        arith_f3_add:  decode_struct_out.aluop = (funct7[5]) ? alu_op_sub : alu_op_add;
                        default:       decode_struct_out.aluop = alu_ops'(funct3);
                    endcase
                end
            end
            default: ;
        endcase
    end

endmodule