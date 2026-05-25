module gshare
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,

    cb_bp_itf.bp                    from_cb,
    input   logic [31:0]            blk_pc,

    // Speculative history update, driven from the fetch stage.
    input   logic                   flush,          // backend misprediction recovery
    input   logic                   spec_update_en, // a fetch block is consumed this cycle
    input   logic [IF_WIDTH-1:0]    spec_br_valid,  // fetched slots that are branches (in order)
    input   logic [IF_WIDTH-1:0]    spec_br_taken,  // predicted direction the machine acted on

    output  logic [PHT_IDX-1:0]     ghr_snapshot,
    output  logic [IF_WIDTH-1:0]    predict_taken
);
    logic   [PHT_IDX-1:0]   ghr_spec;     // speculative history (used for prediction)
    logic   [PHT_IDX-1:0]   ghr_commit;   // architectural history (recovery point)
    logic   [1:0]           pht[PHT_DEPTH];

    // Architectural history advances with the resolved outcome at commit.
    // Note: backend_flush implies from_cb.update_en (the mispredicted branch is
    // the one committing), so ghr_commit_next already folds in that outcome and
    // is the correct value to resume fetch from.
    logic   [PHT_IDX-1:0]   ghr_commit_next;
    assign ghr_commit_next = from_cb.update_en
                           ? {ghr_commit[PHT_IDX-2:0], from_cb.branch_taken}
                           : ghr_commit;

    // Speculative history advances with predicted directions as the block is
    // consumed (in program order across the fetched slots).
    logic   [PHT_IDX-1:0]   ghr_spec_fetch;
    always_comb begin
        ghr_spec_fetch = ghr_spec;
        for (int i = 0; i < IF_WIDTH; i++) begin
            if (spec_br_valid[i]) begin
                ghr_spec_fetch = {ghr_spec_fetch[PHT_IDX-2:0], spec_br_taken[i]};
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            ghr_spec   <= '0;
            ghr_commit <= '0;
            for (int i = 0; i < PHT_DEPTH; i++) begin
                pht[i] <= 2'b01;
            end
        end else begin
            ghr_commit <= ghr_commit_next;

            if (flush) begin
                ghr_spec <= ghr_commit_next;        // resync to architectural history
            end else if (spec_update_en) begin
                ghr_spec <= ghr_spec_fetch;
            end

            if (from_cb.update_en) begin
                // Train the PHT at the SAME index this branch was predicted from
                // (from_cb.ghr is the speculative-history snapshot it carried).
                if (from_cb.branch_taken) begin
                    pht[from_cb.ghr ^ from_cb.pc[PHT_IDX+1:2]] <= (pht[from_cb.ghr ^ from_cb.pc[PHT_IDX+1:2]] == 2'b11) ? 2'b11 : pht[from_cb.ghr ^ from_cb.pc[PHT_IDX+1:2]] + 2'd1;
                end else begin
                    pht[from_cb.ghr ^ from_cb.pc[PHT_IDX+1:2]] <= (pht[from_cb.ghr ^ from_cb.pc[PHT_IDX+1:2]] == 2'b00) ? 2'b00 : pht[from_cb.ghr ^ from_cb.pc[PHT_IDX+1:2]] - 2'd1;
                end
            end
        end
    end

    assign ghr_snapshot = ghr_spec;

    logic   [IF_WIDTH-1:0]  [31:0]  pc_in;
    generate for (genvar i = 0; i < IF_WIDTH; i++) begin
        assign pc_in[i] = blk_pc + unsigned'(i) * 4;
        assign predict_taken[i] = pht[ghr_spec ^ pc_in[i][PHT_IDX+1:2]] >= 2'b10;
    end endgenerate

endmodule
