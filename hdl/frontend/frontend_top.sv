module frontend_top
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               backend_flush,
    input   logic   [31:0]      backend_redirect_pc,

    frontend_fifo_itf.frontend  to_fifo,

    // I cache connected to arbiter
    cacheline_itf.master        icache_itf,

    cb_bp_itf.bp                from_cb
);

    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;
    localparam  unsigned    IF_WIDTH_IDX= $clog2(IF_WIDTH);

    logic                   if1_valid;
    logic                   if1_ready;

    // Stage IF0 = Access ICache

    logic   [31:0]                  pc_next;
    logic   [31:0]                  pc;             // start PC of the block fetched this cycle
    logic   [31:0]                  blk_pc;
    logic   [IF_WIDTH-1:0]  [31:0]  insts;          // raw block words from the I-cache

    logic                   prev_rst;

    logic   [IF_WIDTH-1:0]          predict_taken;
    logic   [IF_WIDTH-1:0]          predict_taken_gshare;
    logic   [IF_WIDTH-1:0]  [31:0]  predict_target;
    logic   [IF_WIDTH-1:0]          predict_taken_ubtb;
    logic   [IF_WIDTH-1:0]  [31:0]  predict_target_ubtb;

    logic   predict_taken_en;
    logic   [IF_WIDTH_IDX-1:0]  predict_taken_idx;

    always_ff @(posedge clk) begin
        prev_rst <= rst;
    end

    // ========================================================================
    // C-extension fetch realignment.
    //
    // The I-cache delivers an 8B-aligned block (IF_WIDTH words = 2*IF_WIDTH
    // parcels). RVC instructions are halfword aligned and variable length, so the
    // genuine instruction stream starts at pc (halfword granularity) and a 32-bit
    // instruction may straddle the 8B block boundary. fetch_align walks the
    // parcels from pc; a straddling op is detected as a "span" and its low parcel
    // is carried (carry_*) to be re-supplied next cycle prepended to the next
    // block. For pure RV32I (word aligned, 32-bit only) no op ever spans an
    // 8B block, so the carry path is never taken and behaviour is unchanged.
    // ========================================================================
    logic                   carry_valid;    // a straddling 32-bit op was carried
    logic   [15:0]          carry_lo;       // its low parcel
    logic   [31:0]          carry_pc;       // its PC

    // block parcels, in address order
    logic   [2*IF_WIDTH-1:0] [15:0]  blk_parcels;
    generate for (genvar w = 0; w < IF_WIDTH; w++) begin : blk_par
        assign blk_parcels[2*w]   = insts[w][15:0];
        assign blk_parcels[2*w+1] = insts[w][31:16];
    end endgenerate

    // halfword offset of pc within the block (0 .. 2*IF_WIDTH-1)
    logic   [IF_WIDTH_IDX:0]  po;
    assign po = pc[$clog2(IF_BLK_SIZE)-1:1];

    // parcel window + base PC + valid-parcel count fed to fetch_align
    logic   [31:0]                      fa_pc;
    logic   [2*IF_WIDTH-1:0]  [15:0]    fa_parcels;
    logic   [PARCEL_CNT_W-1:0]          fa_n_valid;

    always_comb begin
        fa_parcels = '0;
        if (carry_valid) begin
            // {carried low parcel, block parcels 0..2*IF_WIDTH-2}
            fa_pc         = carry_pc;
            fa_parcels[0] = carry_lo;
            for (int k = 1; k < 2*IF_WIDTH; k++) fa_parcels[k] = blk_parcels[k-1];
            fa_n_valid    = (PARCEL_CNT_W)'(2*IF_WIDTH);
        end else begin
            // block parcels from pc to end of block
            fa_pc      = pc;
            for (int k = 0; k < 2*IF_WIDTH; k++) begin
                if (unsigned'(po) + unsigned'(k) < 2*IF_WIDTH)
                    fa_parcels[k] = blk_parcels[unsigned'(po) + unsigned'(k)];
            end
            fa_n_valid = (PARCEL_CNT_W)'(2*IF_WIDTH - unsigned'(po));
        end
    end

    logic   [IF_WIDTH-1:0]  [31:0]  fa_inst;
    logic   [IF_WIDTH-1:0]  [31:0]  fa_inst_raw;
    logic   [IF_WIDTH-1:0]  [31:0]  fa_inst_pc;
    logic   [IF_WIDTH-1:0]          fa_inst_comp;
    logic   [IF_WIDTH-1:0]          fa_inst_valid;
    logic   [IF_WIDTH-1:0]  [31:0]  fa_seq_next;
    logic   [PARCEL_CNT_W-1:0]      fa_consumed;
    logic                           fa_span;
    logic   [15:0]                  fa_span_lo;
    logic   [31:0]                  fa_span_pc;
    logic   [31:0]                  fa_next_pc;

    fetch_align fetch_align_i(
        .pc             (fa_pc),
        .parcels        (fa_parcels),
        .n_valid        (fa_n_valid),
        .inst           (fa_inst),
        .inst_raw       (fa_inst_raw),
        .inst_pc        (fa_inst_pc),
        .inst_comp      (fa_inst_comp),
        .inst_valid     (fa_inst_valid),
        .seq_next       (fa_seq_next),
        .consumed       (fa_consumed),
        .span           (fa_span),
        .span_lo        (fa_span_lo),
        .span_pc        (fa_span_pc),
        .next_pc        (fa_next_pc)
    );

    // Gate predictions by whether the slot is actually a control transfer.
    // The predictors index/tag the PC dropping bit [1] (word granularity), so
    // under RVC a compressed branch and its halfword-adjacent neighbour alias to
    // the same uBTB/TAGE entry. A non-branch must therefore never inherit a
    // predicted target: it has no fu_br recovery, so a stray predict_taken would
    // mis-redirect the fetch and a stray predict_target would corrupt rvfi
    // pc_wdata. Forcing non-control slots to {not-taken, fall-through} is also a
    // no-op for pure RV32I (where non-branches never alias to a valid entry).
    logic   [IF_WIDTH-1:0]          is_ctrl;
    logic   [IF_WIDTH-1:0]          eff_predict_taken;
    logic   [IF_WIDTH-1:0]  [31:0]  eff_predict_target;
    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            is_ctrl[i] = (fa_inst[i][6:0] == 7'b1100011)   // branch
                      || (fa_inst[i][6:0] == 7'b1101111)   // jal
                      || (fa_inst[i][6:0] == 7'b1100111);  // jalr
            eff_predict_taken[i]  = is_ctrl[i] && predict_taken[i];
            eff_predict_target[i] = is_ctrl[i] ? predict_target[i] : fa_seq_next[i];
        end
    end

    // First valid slot that the predictor says is taken -> redirect there.
    always_comb begin
        predict_taken_en = '0;
        predict_taken_idx = '0;
        for (int i = 0; i < IF_WIDTH; i++) begin
            if (fa_inst_valid[i] && eff_predict_taken[i]) begin
                predict_taken_en  = 1'b1;
                predict_taken_idx = (IF_WIDTH_IDX)'(unsigned'(i));
                break;
            end
        end
    end

    // A span only matters when it is not pre-empted by an earlier taken branch.
    logic   span_carry;
    assign span_carry = fa_span && ~predict_taken_en;

    always_comb begin
        if (prev_rst) begin
            pc_next = 32'haaaaa000;
        end else if (backend_flush) begin
            pc_next = backend_redirect_pc;
        end else if (predict_taken_en) begin
            pc_next = eff_predict_target[predict_taken_idx];
        end else if (span_carry) begin
            // advance to the next block so the I-cache fetches the spanning op's
            // high parcel; carry_* re-supplies the low parcel next cycle.
            pc_next = (blk_pc + IF_BLK_SIZE);
        end else begin
            pc_next = fa_next_pc;
        end
    end

    logic                   fetch_fire;
    assign fetch_fire = to_fifo.valid && to_fifo.ready;

    always_ff @(posedge clk) begin
        if (rst || backend_flush) begin
            carry_valid <= 1'b0;
        end else if (fetch_fire) begin
            carry_valid <= span_carry;
            carry_lo    <= fa_span_lo;
            carry_pc    <= fa_span_pc;
        end
    end

    // Stage IF1 = Read ICache and send to FIFO

    if1_stage if1_stage_i(
        .clk                    (clk),
        .rst                    (rst),

        .flush                  (backend_flush),

        .prv_valid              ('1), // pc_next is always generating the next request
        .prv_ready              (),   // not used

        .nxt_valid              (if1_valid),
        .nxt_ready              (if1_ready),

        .pc_next                (pc_next),

        .pc                     (pc),
        .insts                  (insts),

        .icache_itf             (icache_itf)
    );

    logic   [GHR_LEN-1:0]   ghr_snapshot;

    // Branch predecode for speculative history update: which extracted slots are
    // control transfers (matching the events the control buffer feeds back at
    // commit). Uses the decompressed instruction words.
    logic   [IF_WIDTH-1:0]  spec_br_valid;

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            spec_br_valid[i] = to_fifo.packet.valid[i] &&
                ( (fa_inst[i][6:0] == 7'b1100011)     // conditional branch
                || (fa_inst[i][6:0] == 7'b1101111)    // jal
                || (fa_inst[i][6:0] == 7'b1100111) ); // jalr
        end
    end

    tage tage_i(
        .clk                    (clk),
        .rst                    (rst),
        .from_cb                (from_cb),
        .inst_pc                (fa_inst_pc),
        .flush                  (backend_flush),
        .spec_update_en         (fetch_fire),
        .spec_br_valid          (spec_br_valid),
        .spec_br_taken          (eff_predict_taken),
        .ghr_snapshot           (ghr_snapshot),
        .predict_taken          (predict_taken_gshare)
    );

    ubtb ubtb_i(
        .clk                    (clk),
        .rst                    (rst),
        .from_cb                (from_cb),
        .predict_taken_gshare   (predict_taken_gshare),
        .inst_pc                (fa_inst_pc),
        .seq_next               (fa_seq_next),
        .predict_target         (predict_target_ubtb),
	    .predict_taken		    (predict_taken_ubtb)
    );

    // Return Address Stack: overrides return targets on top of the uBTB.
    ras ras_i(
        .clk                    (clk),
        .rst                    (rst),
        .flush                  (backend_flush),
        .fetch_fire             (fetch_fire),
        .inst_pc                (fa_inst_pc),
        .seq_next               (fa_seq_next),
        .inst_valid             (fa_inst_valid),
        .insts                  (fa_inst),
        .predict_taken_in       (predict_taken_ubtb),
        .predict_target_in      (predict_target_ubtb),
        .predict_taken_out      (predict_taken),
        .predict_target_out     (predict_target),
        .from_cb                (from_cb)
    );

    assign if1_ready = to_fifo.ready;
    assign to_fifo.valid = if1_valid;
    assign blk_pc = pc & ~(unsigned'(IF_BLK_SIZE - 1));
    assign to_fifo.packet.ghr = ghr_snapshot;

    generate for (genvar i = 0; i < IF_WIDTH; i++) begin : pkt
        assign to_fifo.packet.inst[i]          = fa_inst[i];
        assign to_fifo.packet.inst_raw[i]      = fa_inst_raw[i];
        assign to_fifo.packet.is_compressed[i] = fa_inst_comp[i];
        assign to_fifo.packet.pc[i]            = fa_inst_pc[i];
        assign to_fifo.packet.predict_taken[i] = eff_predict_taken[i];
        assign to_fifo.packet.predict_target[i]= eff_predict_target[i];
    end endgenerate

    // Valid = an instruction was actually extracted here AND no earlier slot in
    // the bundle was a taken branch. (Runtime loop: keeps the slot-vs-index
    // comparison non-constant so the unsigned-compare lint stays quiet.)
    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            to_fifo.packet.valid[i] = fa_inst_valid[i] &&
                ~(predict_taken_en && (unsigned'(i) > unsigned'(predict_taken_idx)));
        end
    end

endmodule
