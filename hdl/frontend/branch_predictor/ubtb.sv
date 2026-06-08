module ubtb
import cpu_params::*;
import uop_types::*;
(
    input   logic                           clk,
    input   logic                           rst,

    cb_bp_itf.bp                            from_cb,

    input   logic [IF_WIDTH-1:0]            predict_taken_gshare,
    input   logic [IF_WIDTH-1:0]  [31:0]    inst_pc,    // per-instruction (realigned) PC
    input   logic [IF_WIDTH-1:0]  [31:0]    seq_next,   // per-instruction fall-through PC
    output  logic [IF_WIDTH-1:0]  [31:0]    predict_target,
    output  logic [IF_WIDTH-1:0]	        predict_taken
);
    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;
    
    typedef struct packed {
        logic                       valid;
        logic   [31:0]              target;
        logic   [UBTB_TAG_IDX-1:0]  tag;
    } ubtb_entry_t;

    typedef enum logic [2:0] {  
        INSERT          = 3'b001,
        UPDATE          = 3'b010,
        OVERWRITE       = 3'b100
    } ubtb_update_t;

    // uBTB tag with the RVC de-alias fold: pc[1] (halfword bit) XORed into the LSB
    // so a compressed branch and its neighbour in the same word get distinct tags.
    // For RV32I pc[1]==0 always -> identical to the old pc[..:2] tag (im unchanged).
    function automatic logic [UBTB_TAG_IDX-1:0] btag(input logic [31:0] pc);
        btag = {pc[UBTB_TAG_IDX+1:3], pc[2] ^ pc[1]};
    endfunction

    ubtb_entry_t            br_ubtb    [UBTB_DEPTH];
    ubtb_update_t           br_ubtb_update;
    logic [UBTB_IDX-1:0]    br_update_idx;
    logic [UBTB_IDX-1:0]    br_insert_idx;
    logic [UBTB_IDX-1:0]    br_ubtb_head;

    // Clock-gate the branch uBTB: written only on a committed taken conditional
    // branch (or reset), idle on the vast majority of cycles.
    logic br_ubtb_wr_en;
    logic br_ubtb_gclk;
    assign br_ubtb_wr_en = rst || (from_cb.update_en && from_cb.branch_taken && ~from_cb.fu_opcode[3]);
    clock_gate br_ubtb_cg (.clk(clk), .en(br_ubtb_wr_en), .gclk(br_ubtb_gclk));

    always_ff @(posedge br_ubtb_gclk) begin
        if (rst) begin
            br_ubtb_head <= '0;
            for (int i = 0; i < UBTB_DEPTH; i++) begin
                br_ubtb[i].valid    <= '0;
            end
        end else if (from_cb.update_en && from_cb.branch_taken && ~from_cb.fu_opcode[3]) begin
            unique case (br_ubtb_update)
                INSERT: begin
                    br_ubtb[br_insert_idx].valid    <= '1;
                    br_ubtb[br_insert_idx].tag      <= btag(from_cb.pc);
                    br_ubtb[br_insert_idx].target   <= from_cb.target_address;
                end
                UPDATE: begin
                    br_ubtb[br_update_idx].tag      <= btag(from_cb.pc);
                    br_ubtb[br_update_idx].target   <= from_cb.target_address;
                end
                OVERWRITE: begin
                    br_ubtb[br_ubtb_head].tag       <= btag(from_cb.pc);
                    br_ubtb[br_ubtb_head].target    <= from_cb.target_address;
                    br_ubtb_head <= br_ubtb_head + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    always_comb begin
        br_ubtb_update = OVERWRITE;
        br_update_idx = 'x;
        br_insert_idx = 'x;

        for (int unsigned i = 0; i < UBTB_DEPTH; i++) begin
            if (~from_cb.fu_opcode[3]) begin
                if (!br_ubtb[i].valid) begin
                    br_ubtb_update = INSERT;
                    br_insert_idx = (UBTB_IDX)'(i);
                end else if (br_ubtb[i].tag == btag(from_cb.pc)) begin
                    br_ubtb_update = UPDATE;
                    br_update_idx = (UBTB_IDX)'(i);
                end
            end
        end
    end

    ubtb_entry_t            j_ubtb     [UBTB_DEPTH];
    ubtb_update_t           j_ubtb_update;
    logic [UBTB_IDX-1:0]    j_update_idx;
    logic [UBTB_IDX-1:0]    j_insert_idx;
    logic [UBTB_IDX-1:0]    j_ubtb_head;

    // Clock-gate the jump uBTB: written only on a committed taken jump (or reset).
    logic j_ubtb_wr_en;
    logic j_ubtb_gclk;
    assign j_ubtb_wr_en = rst || (from_cb.update_en && from_cb.branch_taken && from_cb.fu_opcode[3]);
    clock_gate j_ubtb_cg (.clk(clk), .en(j_ubtb_wr_en), .gclk(j_ubtb_gclk));

    always_ff @(posedge j_ubtb_gclk) begin
        if (rst) begin
            j_ubtb_head  <= '0;
            for (int i = 0; i < UBTB_DEPTH; i++) begin
                j_ubtb[i].valid     <= '0;
            end
        end else if (from_cb.update_en && from_cb.branch_taken && from_cb.fu_opcode[3]) begin
            unique case (j_ubtb_update)
                INSERT: begin
                    j_ubtb[j_insert_idx].valid    <= '1;
                    j_ubtb[j_insert_idx].tag      <= btag(from_cb.pc);
                    j_ubtb[j_insert_idx].target   <= from_cb.target_address;
                end
                UPDATE: begin
                    j_ubtb[j_update_idx].tag      <= btag(from_cb.pc);
                    j_ubtb[j_update_idx].target   <= from_cb.target_address;
                end
                OVERWRITE: begin
                    j_ubtb[j_ubtb_head].tag       <= btag(from_cb.pc);
                    j_ubtb[j_ubtb_head].target    <= from_cb.target_address;
                    j_ubtb_head <= j_ubtb_head + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    always_comb begin
        j_ubtb_update = OVERWRITE;
        j_update_idx = 'x;
        j_insert_idx = 'x;

        for (int unsigned i = 0; i < UBTB_DEPTH; i++) begin
            if (from_cb.fu_opcode[3]) begin
                if (!j_ubtb[i].valid) begin
                    j_ubtb_update = INSERT;
                    j_insert_idx = (UBTB_IDX)'(i);
                end else if(j_ubtb[i].tag == btag(from_cb.pc)) begin
                    j_ubtb_update = UPDATE;
                    j_update_idx = (UBTB_IDX)'(i);
                end
            end
        end
    end

    logic   [IF_WIDTH-1:0]  [31:0]  pc_in;
    generate for (genvar w = 0; w < IF_WIDTH; w++) begin
        always_comb begin
	        predict_taken[w] = 1'b0;
            pc_in[w] = inst_pc[w];
            predict_target[w] = seq_next[w];
            for (int i = 0; i < UBTB_DEPTH; i++) begin
                if (predict_taken_gshare[w] && br_ubtb[i].valid && (br_ubtb[i].tag == btag(pc_in[w]))) begin
                    predict_target[w] = br_ubtb[i].target;
		            predict_taken[w]  = 1'b1;
                    break;
                end
                // prioritize jump over branch
                if (j_ubtb[i].valid && (j_ubtb[i].tag == btag(pc_in[w]))) begin
                    predict_target[w] = j_ubtb[i].target;
		            predict_taken[w] = 1'b1;
                    break;
                end
            end
        end
    end endgenerate

endmodule
