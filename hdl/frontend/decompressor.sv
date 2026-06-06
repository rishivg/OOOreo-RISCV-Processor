// RV32C -> RV32I decompressor (combinational).
//
// Expands a 16-bit compressed instruction (low half of inst_in) into its 32-bit
// base-ISA equivalent. A full 32-bit instruction (inst_in[1:0]==2'b11) passes
// through unchanged. The integer subset of RV32C is covered (RV32IMC has no
// compressed M instructions); FP-compressed and RV64-only forms decode to a
// canonical illegal instruction (all-zero) so they are caught downstream.
//
// This is the decode half of the C extension; it is fed by the fetch
// realignment stage which walks 16-bit parcels and supplies one (possibly
// compressed) instruction per slot. PC stride (+2 / +4) is driven by
// is_compressed so the per-slot PC carried through the compacting queue is
// correct.
module decompressor (
    input   logic   [31:0]  inst_in,
    output  logic   [31:0]  inst_out,
    output  logic           is_compressed
);
    localparam logic [31:0] ILLEGAL = 32'h0000_0000;

    // 3-bit popular register field c.rs'/c.rd' -> x8..x15
    function automatic logic [4:0] creg(input logic [2:0] r);
        creg = {2'b01, r};
    endfunction

    logic [1:0]  quad;
    logic [2:0]  funct3;
    assign quad   = inst_in[1:0];
    assign funct3 = inst_in[15:13];
    assign is_compressed = (quad != 2'b11);

    // common compressed register fields
    logic [4:0] rd_h, rs1_h, rs2_h;   // high-form (bits 11:7 / 6:2)
    logic [4:0] rd_p, rs1_p, rs2_p;   // popular-form (x8..x15)
    assign rd_h  = inst_in[11:7];
    assign rs1_h = inst_in[11:7];
    assign rs2_h = inst_in[6:2];
    assign rd_p  = creg(inst_in[4:2]);
    assign rs1_p = creg(inst_in[9:7]);
    assign rs2_p = creg(inst_in[4:2]);

    // helpers to assemble base-ISA encodings
    function automatic logic [31:0] enc_r(input logic [6:0] f7, input logic [4:0] rs2,
                                          input logic [4:0] rs1, input logic [2:0] f3,
                                          input logic [4:0] rd, input logic [6:0] op);
        enc_r = {f7, rs2, rs1, f3, rd, op};
    endfunction
    function automatic logic [31:0] enc_i(input logic [11:0] imm, input logic [4:0] rs1,
                                          input logic [2:0] f3, input logic [4:0] rd,
                                          input logic [6:0] op);
        enc_i = {imm, rs1, f3, rd, op};
    endfunction
    function automatic logic [31:0] enc_s(input logic [11:0] imm, input logic [4:0] rs2,
                                          input logic [4:0] rs1, input logic [2:0] f3,
                                          input logic [6:0] op);
        enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], op};
    endfunction
    function automatic logic [31:0] enc_b(input logic [12:0] imm, input logic [4:0] rs2,
                                          input logic [4:0] rs1, input logic [2:0] f3,
                                          input logic [6:0] op);
        enc_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], op};
    endfunction
    function automatic logic [31:0] enc_u(input logic [31:12] imm, input logic [4:0] rd,
                                          input logic [6:0] op);
        enc_u = {imm, rd, op};
    endfunction
    function automatic logic [31:0] enc_j(input logic [20:0] imm, input logic [4:0] rd,
                                          input logic [6:0] op);
        enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, op};
    endfunction

    // assorted compressed immediates (sign-extended where the spec says so)
    logic [11:0] imm_ci;        // c.addi/c.li/c.andi/c.slli/c.srli/c.srai (6-bit signed)
    logic [11:0] imm_lw;        // c.lw/c.sw scaled word offset (unsigned)
    logic [11:0] imm_addi4spn;  // c.addi4spn nzuimm
    logic [11:0] imm_addi16sp;  // c.addi16sp (10-bit signed, x16)
    logic [31:12] imm_lui;      // c.lui
    logic [11:0] imm_lwsp, imm_swsp;
    logic [12:0] imm_cb;        // c.beqz/c.bnez branch offset
    logic [20:0] imm_cj;        // c.j/c.jal jump offset

    assign imm_ci       = {{7{inst_in[12]}}, inst_in[6:2]};
    assign imm_lw       = {5'b0, inst_in[5], inst_in[12:10], inst_in[6], 2'b00};
    assign imm_addi4spn = {2'b0, inst_in[10:7], inst_in[12:11], inst_in[5], inst_in[6], 2'b00};
    assign imm_addi16sp = {{3{inst_in[12]}}, inst_in[4:3], inst_in[5], inst_in[2], inst_in[6], 4'b0000};
    assign imm_lui      = {{15{inst_in[12]}}, inst_in[6:2]};
    assign imm_lwsp     = {4'b0, inst_in[3:2], inst_in[12], inst_in[6:4], 2'b00};
    assign imm_swsp     = {4'b0, inst_in[8:7], inst_in[12:9], 2'b00};
    assign imm_cb       = {{5{inst_in[12]}}, inst_in[6:5], inst_in[2], inst_in[11:10], inst_in[4:3], 1'b0};
    assign imm_cj       = {{10{inst_in[12]}}, inst_in[8], inst_in[10:9], inst_in[6],
                           inst_in[7], inst_in[2], inst_in[11], inst_in[5:3], 1'b0};

    always_comb begin
        inst_out = ILLEGAL;
        if (quad == 2'b11) begin
            inst_out = inst_in;                                   // already 32-bit
        end else begin
            unique case (quad)
            //--------------------------------------------------------------- C0
            2'b00: begin
                unique case (funct3)
                    3'b000: inst_out = (inst_in[12:2] == '0) ? ILLEGAL    // reserved
                                     : enc_i(imm_addi4spn, 5'd2, 3'b000, rd_p, 7'b0010011);  // c.addi4spn -> addi rd',x2,nz
                    3'b010: inst_out = enc_i(imm_lw, rs1_p, 3'b010, rd_p, 7'b0000011);        // c.lw  -> lw rd',off(rs1')
                    3'b110: inst_out = enc_s(imm_lw, rs2_p, rs1_p, 3'b010, 7'b0100011);       // c.sw  -> sw rs2',off(rs1')
                    default: inst_out = ILLEGAL;                                              // FP / reserved
                endcase
            end
            //--------------------------------------------------------------- C1
            2'b01: begin
                unique case (funct3)
                    3'b000: inst_out = enc_i(imm_ci, rd_h, 3'b000, rd_h, 7'b0010011);         // c.addi / c.nop
                    3'b001: inst_out = enc_j(imm_cj, 5'd1, 7'b1101111);                       // c.jal -> jal x1,off
                    3'b010: inst_out = enc_i(imm_ci, 5'd0, 3'b000, rd_h, 7'b0010011);         // c.li  -> addi rd,x0,imm
                    3'b011: begin
                        if (rd_h == 5'd2)
                            inst_out = enc_i(imm_addi16sp, 5'd2, 3'b000, 5'd2, 7'b0010011);   // c.addi16sp
                        else
                            inst_out = enc_u(imm_lui, rd_h, 7'b0110111);                      // c.lui rd,imm
                    end
                    3'b100: begin
                        unique case (inst_in[11:10])
                            2'b00: inst_out = enc_i({6'b0, inst_in[12], inst_in[6:2]}, rs1_p, 3'b101, rs1_p, 7'b0010011); // c.srli
                            2'b01: inst_out = enc_i({6'b010000, inst_in[6:2]} | {6'b0, inst_in[12], 5'b0}, rs1_p, 3'b101, rs1_p, 7'b0010011); // c.srai
                            2'b10: inst_out = enc_i(imm_ci, rs1_p, 3'b111, rs1_p, 7'b0010011); // c.andi
                            2'b11: begin
                                unique case ({inst_in[12], inst_in[6:5]})
                                    3'b000: inst_out = enc_r(7'b0100000, rs2_p, rs1_p, 3'b000, rs1_p, 7'b0110011); // c.sub
                                    3'b001: inst_out = enc_r(7'b0000000, rs2_p, rs1_p, 3'b100, rs1_p, 7'b0110011); // c.xor
                                    3'b010: inst_out = enc_r(7'b0000000, rs2_p, rs1_p, 3'b110, rs1_p, 7'b0110011); // c.or
                                    3'b011: inst_out = enc_r(7'b0000000, rs2_p, rs1_p, 3'b111, rs1_p, 7'b0110011); // c.and
                                    default: inst_out = ILLEGAL;                              // c.subw/addw = RV64
                                endcase
                            end
                        endcase
                    end
                    3'b101: inst_out = enc_j(imm_cj, 5'd0, 7'b1101111);                       // c.j -> jal x0,off
                    3'b110: inst_out = enc_b(imm_cb, 5'd0, rs1_p, 3'b000, 7'b1100011);        // c.beqz -> beq rs1',x0
                    3'b111: inst_out = enc_b(imm_cb, 5'd0, rs1_p, 3'b001, 7'b1100011);        // c.bnez -> bne rs1',x0
                    default: inst_out = ILLEGAL;
                endcase
            end
            //--------------------------------------------------------------- C2
            2'b10: begin
                unique case (funct3)
                    3'b000: inst_out = enc_i({6'b0, inst_in[12], inst_in[6:2]}, rd_h, 3'b001, rd_h, 7'b0010011); // c.slli
                    3'b010: inst_out = (rd_h == '0) ? ILLEGAL                                 // c.lwsp rd!=0
                                     : enc_i(imm_lwsp, 5'd2, 3'b010, rd_h, 7'b0000011);        // c.lwsp -> lw rd,off(x2)
                    3'b100: begin
                        if (inst_in[12] == 1'b0) begin
                            if (rs2_h == '0)
                                inst_out = enc_i(12'b0, rs1_h, 3'b000, 5'd0, 7'b1100111);     // c.jr -> jalr x0,0(rs1)
                            else
                                inst_out = enc_r(7'b0, rs2_h, 5'd0, 3'b000, rd_h, 7'b0110011); // c.mv -> add rd,x0,rs2
                        end else begin
                            if (rs1_h == '0 && rs2_h == '0)
                                inst_out = 32'h00100073;                                       // c.ebreak
                            else if (rs2_h == '0)
                                inst_out = enc_i(12'b0, rs1_h, 3'b000, 5'd1, 7'b1100111);     // c.jalr -> jalr x1,0(rs1)
                            else
                                inst_out = enc_r(7'b0, rs2_h, rd_h, 3'b000, rd_h, 7'b0110011); // c.add -> add rd,rd,rs2
                        end
                    end
                    3'b110: inst_out = enc_s(imm_swsp, rs2_h, 5'd2, 3'b010, 7'b0100011);       // c.swsp -> sw rs2,off(x2)
                    default: inst_out = ILLEGAL;                                               // FP forms
                endcase
            end
            default: inst_out = ILLEGAL;
            endcase
        end
    end

endmodule
