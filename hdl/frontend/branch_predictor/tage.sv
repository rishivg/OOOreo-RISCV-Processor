module tage
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,

    cb_bp_itf.bp                    from_cb,
    input   logic [IF_WIDTH-1:0] [31:0] inst_pc,    // per-instruction (realigned) PC

    // Speculative history update, driven from the fetch stage.
    input   logic                   flush,          // backend misprediction recovery
    input   logic                   spec_update_en, // a fetch block is consumed this cycle
    input   logic [IF_WIDTH-1:0]    spec_br_valid,  // fetched slots that are branches (in order)
    input   logic [IF_WIDTH-1:0]    spec_br_taken,  // predicted direction the machine acted on

    output  logic [GHR_LEN-1:0]     ghr_snapshot,
    output  logic [IF_WIDTH-1:0]    predict_taken
);
    // Geometric history lengths for the tagged components (shortest..longest).
    localparam int unsigned HISTLEN [TAGE_NUM] = '{7, 15, 31, 63};

    typedef struct packed {
        logic [TAGE_TAG_BITS-1:0]           tag;
        logic signed [TAGE_CTR_BITS-1:0]    ctr;    // >=0 => predict taken
        logic [TAGE_U_BITS-1:0]             u;      // usefulness
    } tage_entry_t;

    //---------------------------------------------------------------------------
    // Global history (speculative for prediction, committed for recovery) —
    // speculative history drives prediction; committed history is the recovery point.
    //---------------------------------------------------------------------------
    logic [GHR_LEN-1:0]     ghr_spec;
    logic [GHR_LEN-1:0]     ghr_commit;

    logic [GHR_LEN-1:0]     ghr_commit_next;
    assign ghr_commit_next = from_cb.update_en
                           ? {ghr_commit[GHR_LEN-2:0], from_cb.branch_taken}
                           : ghr_commit;

    logic [GHR_LEN-1:0]     ghr_spec_fetch;
    always_comb begin
        ghr_spec_fetch = ghr_spec;
        for (int i = 0; i < IF_WIDTH; i++) begin
            if (spec_br_valid[i]) begin
                ghr_spec_fetch = {ghr_spec_fetch[GHR_LEN-2:0], spec_br_taken[i]};
            end
        end
    end

    assign ghr_snapshot = ghr_spec;

    //---------------------------------------------------------------------------
    // Index / tag hashing
    //---------------------------------------------------------------------------
    function automatic logic [TAGE_IDX-1:0] fold_idx(input logic [GHR_LEN-1:0] h, input int unsigned L);
        fold_idx = '0;
        for (int unsigned i = 0; i < L; i++)
            fold_idx[i % TAGE_IDX] = fold_idx[i % TAGE_IDX] ^ h[i];
    endfunction

    function automatic logic [TAGE_TAG_BITS-1:0] fold_tag(input logic [GHR_LEN-1:0] h, input int unsigned L);
        fold_tag = '0;
        for (int unsigned i = 0; i < L; i++)
            fold_tag[i % TAGE_TAG_BITS] = fold_tag[i % TAGE_TAG_BITS] ^ h[i];
    endfunction

    // Combine the PC with a pre-computed history fold. The fold (an XOR tree
    // over the global history) depends only on (history, length), not the PC or
    // fetch slot, so it is computed once per component below and shared.
    // pc[1] (the RVC halfword bit) is XORed into the index/tag LSB so a compressed
    // branch and its halfword neighbour in the same word no longer alias to one
    // entry. For RV32I pc[1]==0 always -> the fold is a no-op (im stays identical).
    function automatic logic [TAGE_IDX-1:0] idx_comb(input logic [31:0] pc, input logic [TAGE_IDX-1:0] fidx);
        idx_comb = {pc[TAGE_IDX+1:3], pc[2] ^ pc[1]} ^ fidx;
    endfunction

    function automatic logic [TAGE_TAG_BITS-1:0] tag_comb(input logic [31:0] pc, input logic [TAGE_TAG_BITS-1:0] ftag);
        tag_comb = {pc[TAGE_TAG_BITS+1:3], pc[2] ^ pc[1]} ^ ftag ^ pc[2*TAGE_TAG_BITS+1:TAGE_TAG_BITS+2];
    endfunction

    // Bimodal base index, with the same RVC de-alias fold.
    function automatic logic [PHT_IDX-1:0] bidx(input logic [31:0] pc);
        bidx = {pc[PHT_IDX+1:3], pc[2] ^ pc[1]};
    endfunction

    // Commit-side bimodal index, precomputed into a signal: a function call in the
    // index of a non-blocking-assigned array element trips Verilator V3Delayed.
    logic [PHT_IDX-1:0] bim_widx;
    assign bim_widx = bidx(from_cb.pc);

    // Per-component history folds, computed once each: from the speculative
    // history for prediction (shared by both fetch slots) and from the carried
    // snapshot for training at commit (shared by the hit check and allocation).
    logic [TAGE_IDX-1:0]        fidx_s [TAGE_NUM];   // speculative (prediction)
    logic [TAGE_TAG_BITS-1:0]   ftag_s [TAGE_NUM];
    logic [TAGE_IDX-1:0]        fidx_c [TAGE_NUM];   // committed snapshot (training)
    logic [TAGE_TAG_BITS-1:0]   ftag_c [TAGE_NUM];
    always_comb begin
        for (int t = 0; t < TAGE_NUM; t++) begin
            fidx_s[t] = fold_idx(ghr_spec,    HISTLEN[t]);
            ftag_s[t] = fold_tag(ghr_spec,    HISTLEN[t]);
            fidx_c[t] = fold_idx(from_cb.ghr, HISTLEN[t]);
            ftag_c[t] = fold_tag(from_cb.ghr, HISTLEN[t]);
        end
    end

    //---------------------------------------------------------------------------
    // Storage
    //---------------------------------------------------------------------------
    logic [1:0]     bimodal [PHT_DEPTH];                 // base predictor (PC-indexed 2-bit)
    tage_entry_t    tt      [TAGE_NUM][TAGE_DEPTH];      // tagged components

    //---------------------------------------------------------------------------
    // Prediction (one independent lookup per fetch slot, using ghr_spec)
    //---------------------------------------------------------------------------
    logic [31:0]                    pc_in       [IF_WIDTH];
    tage_entry_t                    p_ent       [IF_WIDTH][TAGE_NUM];
    logic                           p_hit       [IF_WIDTH][TAGE_NUM];
    logic                           base_pred   [IF_WIDTH];

    // Policy counter: when a provider entry is freshly allocated (weak ctr,
    // u==0) its prediction is unreliable, so fall back to the alternate
    // prediction while this counter's MSB is set (use_alt_on_newly_allocated).
    logic [3:0]                     use_alt_on_na;

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            automatic logic prov_v;
            automatic int   prov_t;
            automatic logic alt_p;
            pc_in[i] = inst_pc[i];
            base_pred[i] = bimodal[bidx(pc_in[i])] >= 2'b10;
            for (int t = 0; t < TAGE_NUM; t++) begin
                p_ent[i][t] = tt[t][idx_comb(pc_in[i], fidx_s[t])];
                p_hit[i][t] = (p_ent[i][t].tag == tag_comb(pc_in[i], ftag_s[t]));
            end
            // longest hit provides; next-longest (else base) is the alternate
            prov_v = 1'b0;
            prov_t = 0;
            alt_p  = base_pred[i];
            for (int t = 0; t < TAGE_NUM; t++) begin
                if (p_hit[i][t]) begin
                    alt_p  = prov_v ? (p_ent[i][prov_t].ctr >= 0) : base_pred[i];
                    prov_v = 1'b1;
                    prov_t = t;
                end
            end
            if (prov_v && (p_ent[i][prov_t].u == '0)
                && ((p_ent[i][prov_t].ctr == 0) || (p_ent[i][prov_t].ctr == -1))
                && use_alt_on_na[3]) begin
                predict_taken[i] = alt_p;                          // weak provider: trust the alternate
            end else if (prov_v) begin
                predict_taken[i] = (p_ent[i][prov_t].ctr >= 0);
            end else begin
                predict_taken[i] = base_pred[i];
            end
        end
    end

    //---------------------------------------------------------------------------
    // Training at commit: re-derive the prediction indices from the carried
    // history snapshot (from_cb.ghr) and current table state.
    //---------------------------------------------------------------------------
    logic [TAGE_IDX-1:0]        u_idx   [TAGE_NUM];
    tage_entry_t                u_ent   [TAGE_NUM];
    logic                       u_hit   [TAGE_NUM];
    logic                       u_taken;
    logic                       base_pred_c;

    logic [$clog2(TAGE_NUM)-1:0] u_provider;
    logic                        u_provider_valid;
    logic                        u_prov_pred;
    logic                        u_alt_pred;
    logic                        u_prov_weak;    // provider entry is freshly allocated (weak ctr, u==0)
    logic                        final_pred;
    logic                        mispredict;

    logic [$clog2(TAGE_NUM+1)-1:0] alloc_start;
    logic                          alloc_valid;
    logic [$clog2(TAGE_NUM)-1:0]   alloc_table;

    always_comb begin
        u_taken     = from_cb.branch_taken;
        base_pred_c = bimodal[bim_widx] >= 2'b10;

        for (int t = 0; t < TAGE_NUM; t++) begin
            u_idx[t] = idx_comb(from_cb.pc, fidx_c[t]);
            u_ent[t] = tt[t][u_idx[t]];
            u_hit[t] = (u_ent[t].tag == tag_comb(from_cb.pc, ftag_c[t]));
        end

        // provider = longest hit; alt = next-longest hit (else base)
        u_provider       = '0;
        u_provider_valid = 1'b0;
        u_prov_pred      = base_pred_c;
        u_alt_pred       = base_pred_c;
        for (int t = 0; t < TAGE_NUM; t++) begin
            if (u_hit[t]) begin
                u_alt_pred       = u_provider_valid ? (u_ent[u_provider].ctr >= 0) : base_pred_c;
                u_provider       = ($clog2(TAGE_NUM))'(t);
                u_provider_valid = 1'b1;
            end
        end
        u_prov_pred = u_provider_valid ? (u_ent[u_provider].ctr >= 0) : base_pred_c;
        u_prov_weak = u_provider_valid && (u_ent[u_provider].u == '0)
                      && ((u_ent[u_provider].ctr == 0) || (u_ent[u_provider].ctr == -1));
        // effective prediction the front-end acted on (alt for weak providers)
        final_pred  = (u_prov_weak && use_alt_on_na[3]) ? u_alt_pred : u_prov_pred;
        mispredict  = (final_pred != u_taken);

        // allocation search: first component longer than the provider with u==0
        alloc_start = u_provider_valid ? ($clog2(TAGE_NUM+1))'(u_provider + 1) : '0;
        alloc_valid = 1'b0;
        alloc_table = '0;
        for (int t = 0; t < TAGE_NUM; t++) begin
            if (!alloc_valid && (unsigned'(t) >= alloc_start) && (u_ent[t].u == '0)) begin
                alloc_valid = 1'b1;
                alloc_table = ($clog2(TAGE_NUM))'(t);
            end
        end
    end

    // signed counter / usefulness saturating helpers
    function automatic logic signed [TAGE_CTR_BITS-1:0] ctr_upd(input logic signed [TAGE_CTR_BITS-1:0] c, input logic taken);
        if (taken) ctr_upd = (c == (2**(TAGE_CTR_BITS-1)-1)) ? c : c + 1;
        else       ctr_upd = (c == -(2**(TAGE_CTR_BITS-1))) ? c : c - 1;
    endfunction

    //---------------------------------------------------------------------------
    // State update
    //
    // Split into two clock domains so the large tagged-table / bimodal arrays
    // can be clock-gated: they are written only at commit (from_cb.update_en) or
    // during reset, a minority of cycles, whereas the small global-history state
    // (ghr_spec/ghr_commit/use_alt_on_na) updates every cycle and stays ungated.
    //---------------------------------------------------------------------------

    // Ungated: per-cycle global-history + policy-counter state.
    always_ff @(posedge clk) begin
        if (rst) begin
            ghr_spec   <= '0;
            ghr_commit <= '0;
            use_alt_on_na <= 4'd8;
        end else begin
            ghr_commit <= ghr_commit_next;
            if (flush)                ghr_spec <= ghr_commit_next;
            else if (spec_update_en)  ghr_spec <= ghr_spec_fetch;

            if (from_cb.update_en) begin
                // tune use_alt_on_na when a freshly-allocated provider disagreed
                // with its alternate: reward whichever was right
                if (u_prov_weak && (u_prov_pred != u_alt_pred)) begin
                    if (u_alt_pred == u_taken) use_alt_on_na <= (use_alt_on_na == 4'hF) ? use_alt_on_na : use_alt_on_na + 4'd1;
                    else                       use_alt_on_na <= (use_alt_on_na == 4'h0) ? use_alt_on_na : use_alt_on_na - 4'd1;
                end
            end
        end
    end

    // Gated: the bimodal + tagged tables only ever change on a reset init or a
    // commit train (from_cb.update_en). en is exactly that union -> a superset.
    logic tage_wr_en;
    logic tage_gclk;
    assign tage_wr_en = rst || from_cb.update_en;
    clock_gate tage_cg (.clk(clk), .en(tage_wr_en), .gclk(tage_gclk));

    always_ff @(posedge tage_gclk) begin
        if (rst) begin
            for (int i = 0; i < PHT_DEPTH; i++) bimodal[i] <= 2'b01;
            for (int t = 0; t < TAGE_NUM; t++)
                for (int j = 0; j < TAGE_DEPTH; j++) tt[t][j] <= '0;
        end else begin
            // from_cb.update_en is guaranteed asserted here (gate enable).
            // base predictor learns only for branches with no tagged provider
            if (!u_provider_valid) begin
                if (u_taken) bimodal[bim_widx] <= (bimodal[bim_widx] == 2'b11) ? 2'b11 : bimodal[bim_widx] + 2'b01;
                else         bimodal[bim_widx] <= (bimodal[bim_widx] == 2'b00) ? 2'b00 : bimodal[bim_widx] - 2'b01;
            end

            // per-table writes (each table written at most once per commit)
            for (int t = 0; t < TAGE_NUM; t++) begin
                if (u_provider_valid && (($clog2(TAGE_NUM))'(t) == u_provider)) begin
                    // strengthen/weaken provider; bump usefulness if it beat the alt
                    tt[t][u_idx[t]].ctr <= ctr_upd(u_ent[t].ctr, u_taken);
                    if (u_prov_pred != u_alt_pred) begin
                        if (u_prov_pred == u_taken)
                            tt[t][u_idx[t]].u <= (u_ent[t].u == '1) ? u_ent[t].u : u_ent[t].u + 1'b1;
                        else
                            tt[t][u_idx[t]].u <= (u_ent[t].u == '0) ? u_ent[t].u : u_ent[t].u - 1'b1;
                    end
                end else if (mispredict && alloc_valid && (($clog2(TAGE_NUM))'(t) == alloc_table)) begin
                    // allocate a new entry in a longer component
                    tt[t][u_idx[t]].tag <= tag_comb(from_cb.pc, ftag_c[t]);
                    tt[t][u_idx[t]].ctr <= u_taken ? 3'sb000 : 3'sb111;   // weakly toward outcome
                    tt[t][u_idx[t]].u   <= '0;
                end else if (mispredict && !alloc_valid && (unsigned'(t) >= alloc_start)) begin
                    // no free entry: age the candidates so one frees up later
                    tt[t][u_idx[t]].u <= (u_ent[t].u == '0) ? u_ent[t].u : u_ent[t].u - 1'b1;
                end
            end
        end
    end

endmodule
