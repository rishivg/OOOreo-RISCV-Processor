module ras
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,

    input   logic                   flush,          // backend misprediction recovery
    input   logic                   fetch_fire,     // a fetch block is consumed this cycle
    input   logic   [31:0]          blk_pc,         // block-aligned fetch PC
    input   logic   [31:0]          pc,             // actual fetch PC (may start mid-block)
    input   logic   [IF_WIDTH-1:0]  [31:0]  insts,

    // Prediction coming in from the uBTB; the RAS overrides return targets.
    input   logic   [IF_WIDTH-1:0]          predict_taken_in,
    input   logic   [IF_WIDTH-1:0]  [31:0]  predict_target_in,
    output  logic   [IF_WIDTH-1:0]          predict_taken_out,
    output  logic   [IF_WIDTH-1:0]  [31:0]  predict_target_out,

    // Commit feedback (resolved, in-order) used to recover the stack.
    cb_bp_itf.bp                    from_cb
);
    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;

    // Two stacks mirroring the gshare spec/commit split: tos_spec drives
    // prediction and is corrupted freely by wrong-path fetch; ras_commit_mem /
    // tos_commit are touched only by committed calls/returns and never see the
    // wrong path, so resyncing spec<-commit on every flush undoes corruption.
    logic   [31:0]          ras_spec_mem   [RAS_DEPTH];
    logic   [31:0]          ras_commit_mem [RAS_DEPTH];
    logic   [RAS_IDX-1:0]   tos_spec;
    logic   [RAS_IDX-1:0]   tos_commit;

    // Which fetched slot is the first one actually fetched this block.
    logic   [IF_WIDTH-1:0]  start_slot;
    assign start_slot = (IF_WIDTH)'((pc & (IF_BLK_SIZE-1)) >> 2);

    // Per-slot predecode of RAS actions (RISC-V link registers are x1/x5).
    logic   [IF_WIDTH-1:0]  call_slot;
    logic   [IF_WIDTH-1:0]  ret_slot;
    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            logic [6:0] op; logic [4:0] rd; logic [4:0] rs1; logic link_rd; logic link_rs1;
            op       = insts[i][6:0];
            rd       = insts[i][11:7];
            rs1      = insts[i][19:15];
            link_rd  = (rd  == 5'd1) || (rd  == 5'd5);
            link_rs1 = (rs1 == 5'd1) || (rs1 == 5'd5);
            call_slot[i] = ((op == 7'b1101111) || (op == 7'b1100111)) && link_rd;       // jal/jalr writing link
            ret_slot[i]  = (op == 7'b1100111) && link_rs1 && ~link_rd;                   // jalr reading link only
        end
    end

    // Speculative stack update across the fetched slots, in program order.
    logic   [IF_WIDTH-1:0]          push_en;
    logic   [IF_WIDTH-1:0]  [RAS_IDX-1:0]   push_idx;
    logic   [IF_WIDTH-1:0]  [31:0]          push_val;
    logic   [RAS_IDX-1:0]           tos_next;

    always_comb begin
        automatic logic [RAS_IDX-1:0] t = tos_spec;
        automatic logic taken_seen = 1'b0;
        for (int i = 0; i < IF_WIDTH; i++) begin
            predict_taken_out[i]  = predict_taken_in[i];
            predict_target_out[i] = predict_target_in[i];
            push_en[i]  = 1'b0;
            push_idx[i] = '0;
            push_val[i] = '0;
            if ((start_slot <= (IF_WIDTH)'(i)) && ~taken_seen) begin
                if (ret_slot[i]) begin
                    predict_taken_out[i]  = 1'b1;
                    predict_target_out[i] = ras_spec_mem[t];        // predicted return target
                    t = (RAS_IDX)'(t - 1'b1);                       // pop
                end
                if (call_slot[i]) begin
                    t = (RAS_IDX)'(t + 1'b1);                       // push
                    push_en[i]  = 1'b1;
                    push_idx[i] = t;
                    push_val[i] = blk_pc + 32'(unsigned'(i)) * 32'd4 + 32'd4;
                end
                if (predict_taken_out[i]) taken_seen = 1'b1;
            end
        end
        tos_next = t;
    end

    // Committed stack: advanced only by resolved (in-order) calls/returns.
    logic   [RAS_IDX-1:0]   tos_commit_next;
    always_comb begin
        tos_commit_next = tos_commit;
        if (from_cb.update_en && from_cb.is_ret)  tos_commit_next = (RAS_IDX)'(tos_commit - 1'b1);
        if (from_cb.update_en && from_cb.is_call) tos_commit_next = (RAS_IDX)'(tos_commit + 1'b1);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            tos_spec   <= '0;
            tos_commit <= '0;
        end else begin
            // Commit stack updates (immune to the wrong path).
            tos_commit <= tos_commit_next;
            if (from_cb.update_en && from_cb.is_call) begin
                ras_commit_mem[tos_commit_next] <= from_cb.pc + 32'd4;
            end

            // Spec stack: resync from the committed stack on flush (folding in
            // this cycle's committed push), otherwise follow the fetch stream.
            if (flush) begin
                tos_spec <= tos_commit_next;
                for (int i = 0; i < RAS_DEPTH; i++) begin
                    ras_spec_mem[i] <= (from_cb.update_en && from_cb.is_call
                                        && ((RAS_IDX)'(i) == tos_commit_next))
                                       ? (from_cb.pc + 32'd4) : ras_commit_mem[i];
                end
            end else if (fetch_fire) begin
                tos_spec <= tos_next;
                for (int i = 0; i < IF_WIDTH; i++) begin
                    if (push_en[i]) ras_spec_mem[push_idx[i]] <= push_val[i];
                end
            end
        end
    end

endmodule
