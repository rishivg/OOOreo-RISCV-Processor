// Fetch Target Buffer: predicts a fetch block's EXIT branch from the block-start
// PC alone -- the prerequisite for a run-ahead decoupled front-end. Given an
// aligned 8B block address, it returns whether the block has a learned exit
// branch, that branch's halfword offset within the block, its target, and whether
// it is conditional (so the BPU asks TAGE for direction) or a return (so the BPU
// takes the RAS target). The fall-through (block + IF_BLK_SIZE) is computed by the
// BPU and needs no storage.
//
// Direct-mapped, trained at commit from the control buffer (one write per resolved
// branch), clock-gated like the uBTB. Standalone for now (not yet wired); the BPU
// in frontend_top will combine this with TAGE direction + RAS at integration.
module ftb
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    cb_bp_itf.bp                from_cb,        // commit-side training

    // lookup: the aligned block-start PC the BPU wants to predict
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

    ftb_entry_t                     ftb [FTB_DEPTH];

    // ---- lookup (combinational read on the block address) ----
    logic   [FTB_IDX-1:0]           rd_idx;
    logic   [FTB_TAG_BITS-1:0]      rd_tag;
    assign rd_idx = block_pc[FTB_IDX+2:3];                       // drop the 3 block-offset bits
    assign rd_tag = block_pc[FTB_TAG_BITS+FTB_IDX+2:FTB_IDX+3];

    ftb_entry_t                     rd_entry;
    assign rd_entry    = ftb[rd_idx];
    assign ftb_hit     = rd_entry.valid && (rd_entry.tag == rd_tag);
    assign ftb_br_off  = rd_entry.br_off;
    assign ftb_is_cond = rd_entry.is_cond;
    assign ftb_is_ret  = rd_entry.is_ret;
    assign ftb_target  = rd_entry.target;

    // ---- training at commit ----
    logic   [31:0]                  tr_block_pc;
    logic   [FTB_IDX-1:0]           wr_idx;
    logic   [FTB_TAG_BITS-1:0]      wr_tag;
    assign tr_block_pc = from_cb.pc & ~(32'(IF_WIDTH*4 - 1));    // align the branch PC to its block
    assign wr_idx = tr_block_pc[FTB_IDX+2:3];
    assign wr_tag = tr_block_pc[FTB_TAG_BITS+FTB_IDX+2:FTB_IDX+3];

    // Written only on a committed branch (or reset) -> clock-gate it (uBTB pattern).
    logic ftb_wr_en;
    logic ftb_gclk;
    assign ftb_wr_en = rst || from_cb.update_en;
    clock_gate ftb_cg (.clk(clk), .en(ftb_wr_en), .gclk(ftb_gclk));

    always_ff @(posedge ftb_gclk) begin
        if (rst) begin
            for (int i = 0; i < FTB_DEPTH; i++) ftb[i].valid <= 1'b0;
        end else if (from_cb.update_en) begin
            ftb[wr_idx].valid   <= 1'b1;
            ftb[wr_idx].tag     <= wr_tag;
            ftb[wr_idx].br_off  <= from_cb.pc[2:1];             // halfword offset in the 8B block
            ftb[wr_idx].is_cond <= ~from_cb.fu_opcode[3];        // [3]=0 -> conditional branch (uBTB convention)
            ftb[wr_idx].is_ret  <= from_cb.is_ret;
            ftb[wr_idx].target  <= from_cb.target_address;
        end
    end

endmodule : ftb
