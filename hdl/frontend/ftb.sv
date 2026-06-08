// Fetch Target Buffer: predicts a fetch block's EXIT branch from the block-START
// pc alone -- the prerequisite for a run-ahead decoupled front-end. Given an
// aligned 8B block address it returns whether the block has a learned exit branch,
// that branch's halfword offset within the block, its target, and whether it is
// conditional (so the BPU asks TAGE for direction) or a return (so the BPU takes
// the RAS target). The fall-through (block + IF_BLK_SIZE) is computed by the BPU.
//
// FULLY ASSOCIATIVE (FTB_DEPTH entries, wide block-pc tag, INSERT/UPDATE/OVERWRITE
// round-robin) -- the same scheme the uBTB uses, so distinct blocks do not collide
// on a shared index (the direct-mapped first version mispredicted ~18.5% of targets
// from index conflicts). Trained at commit on TAKEN branches (the redirect points),
// clock-gated like the uBTB. Standalone for now; the BPU combines this with TAGE
// direction + RAS at integration.
module ftb
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    cb_bp_itf.bp                from_cb,        // commit-side training

    // lookup: the aligned block-start pc the BPU wants to predict
    input   logic   [31:0]      block_pc,
    output  logic               ftb_hit,        // block has a learned exit branch
    output  logic   [1:0]       ftb_br_off,     // exit branch halfword offset in block (pc[2:1])
    output  logic               ftb_is_cond,    // conditional (needs TAGE direction)
    output  logic               ftb_is_ret,     // return (use RAS target instead of ftb_target)
    output  logic   [31:0]      ftb_target      // exit branch target (cond-taken / jal / jalr)
);

    typedef struct packed {
        logic                       valid;
        logic   [FTB_TAG_BITS-1:0]  tag;
        logic   [1:0]               br_off;
        logic                       is_cond;
        logic                       is_ret;
        logic   [31:0]              target;
    } ftb_entry_t;

    typedef enum logic [2:0] {
        INSERT      = 3'b001,
        UPDATE      = 3'b010,
        OVERWRITE   = 3'b100
    } ftb_update_t;

    ftb_entry_t                     ftb [FTB_DEPTH];
    logic   [FTB_IDX-1:0]           ftb_head;       // round-robin eviction pointer

    // block-pc tag: the block address (pc with the 3 block-offset bits zeroed)
    function automatic logic [FTB_TAG_BITS-1:0] blk_tag(input logic [31:0] p);
        blk_tag = p[FTB_TAG_BITS+2:3];
    endfunction

    // ---- lookup: associative search for a block-tag match ----
    logic   [FTB_TAG_BITS-1:0]      rd_tag;
    assign rd_tag = blk_tag(block_pc);
    always_comb begin
        ftb_hit     = 1'b0;
        ftb_br_off  = '0;
        ftb_is_cond = 1'b0;
        ftb_is_ret  = 1'b0;
        ftb_target  = '0;
        for (int i = 0; i < FTB_DEPTH; i++) begin
            if (ftb[i].valid && (ftb[i].tag == rd_tag)) begin
                ftb_hit     = 1'b1;
                ftb_br_off  = ftb[i].br_off;
                ftb_is_cond = ftb[i].is_cond;
                ftb_is_ret  = ftb[i].is_ret;
                ftb_target  = ftb[i].target;
            end
        end
    end

    // ---- training at commit (taken branches = the block exit points) ----
    logic   [FTB_TAG_BITS-1:0]      wr_tag;
    assign wr_tag = blk_tag(from_cb.pc);

    ftb_update_t                    ftb_op;
    logic   [FTB_IDX-1:0]           ins_idx;        // first invalid slot
    logic   [FTB_IDX-1:0]           upd_idx;        // matching-tag slot
    always_comb begin
        ftb_op  = OVERWRITE;
        ins_idx = 'x;
        upd_idx = 'x;
        for (int unsigned i = 0; i < FTB_DEPTH; i++) begin
            if (!ftb[i].valid) begin
                ftb_op  = INSERT;
                ins_idx = (FTB_IDX)'(i);
            end else if (ftb[i].tag == wr_tag) begin
                ftb_op  = UPDATE;
                upd_idx = (FTB_IDX)'(i);
            end
        end
    end

    // Written only on a committed taken branch (or reset) -> clock-gate it.
    logic ftb_wr_en;
    logic ftb_gclk;
    assign ftb_wr_en = rst || (from_cb.update_en && from_cb.branch_taken);
    clock_gate ftb_cg (.clk(clk), .en(ftb_wr_en), .gclk(ftb_gclk));

    always_ff @(posedge ftb_gclk) begin
        if (rst) begin
            ftb_head <= '0;
            for (int i = 0; i < FTB_DEPTH; i++) ftb[i].valid <= 1'b0;
        end else if (from_cb.update_en && from_cb.branch_taken) begin
            unique case (ftb_op)
                INSERT: begin
                    ftb[ins_idx].valid   <= 1'b1;
                    ftb[ins_idx].tag     <= wr_tag;
                    ftb[ins_idx].br_off  <= from_cb.pc[2:1];
                    ftb[ins_idx].is_cond <= ~from_cb.fu_opcode[3];
                    ftb[ins_idx].is_ret  <= from_cb.is_ret;
                    ftb[ins_idx].target  <= from_cb.target_address;
                end
                UPDATE: begin
                    ftb[upd_idx].br_off  <= from_cb.pc[2:1];
                    ftb[upd_idx].is_cond <= ~from_cb.fu_opcode[3];
                    ftb[upd_idx].is_ret  <= from_cb.is_ret;
                    ftb[upd_idx].target  <= from_cb.target_address;
                end
                OVERWRITE: begin
                    ftb[ftb_head].tag     <= wr_tag;
                    ftb[ftb_head].br_off  <= from_cb.pc[2:1];
                    ftb[ftb_head].is_cond <= ~from_cb.fu_opcode[3];
                    ftb[ftb_head].is_ret  <= from_cb.is_ret;
                    ftb[ftb_head].target  <= from_cb.target_address;
                    ftb_head <= ftb_head + 1'b1;
                end
                default: ;
            endcase
        end
    end

endmodule : ftb
