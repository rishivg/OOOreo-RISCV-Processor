module tage
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,

    cb_bp_itf.bp                    from_cb,
    input   logic [31:0]            blk_pc,

    // Speculative history update, driven from the fetch stage (same protocol
    // the gshare predictor used).
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
    // identical scheme to the previous gshare, just GHR_LEN bits wide.
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

    function automatic logic [TAGE_IDX-1:0] idx_of(input logic [31:0] pc, input logic [GHR_LEN-1:0] h, input int unsigned L);
        idx_of = pc[TAGE_IDX+1:2] ^ fold_idx(h, L);
    endfunction

    function automatic logic [TAGE_TAG_BITS-1:0] tag_of(input logic [31:0] pc, input logic [GHR_LEN-1:0] h, input int unsigned L);
        tag_of = pc[TAGE_TAG_BITS+1:2] ^ fold_tag(h, L) ^ pc[2*TAGE_TAG_BITS+1:TAGE_TAG_BITS+2];
    endfunction

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

    always_comb begin
        for (int i = 0; i < IF_WIDTH; i++) begin
            pc_in[i] = blk_pc + 32'(unsigned'(i)) * 32'd4;
            base_pred[i] = bimodal[pc_in[i][PHT_IDX+1:2]] >= 2'b10;
            predict_taken[i] = base_pred[i];
            for (int t = 0; t < TAGE_NUM; t++) begin
                p_ent[i][t] = tt[t][idx_of(pc_in[i], ghr_spec, HISTLEN[t])];
                p_hit[i][t] = (p_ent[i][t].tag == tag_of(pc_in[i], ghr_spec, HISTLEN[t]));
            end
            // longest hitting component provides the prediction
            for (int t = 0; t < TAGE_NUM; t++) begin
                if (p_hit[i][t]) predict_taken[i] = (p_ent[i][t].ctr >= 0);
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
    logic                        final_pred;
    logic                        mispredict;

    logic [$clog2(TAGE_NUM+1)-1:0] alloc_start;
    logic                          alloc_valid;
    logic [$clog2(TAGE_NUM)-1:0]   alloc_table;

    always_comb begin
        u_taken     = from_cb.branch_taken;
        base_pred_c = bimodal[from_cb.pc[PHT_IDX+1:2]] >= 2'b10;

        for (int t = 0; t < TAGE_NUM; t++) begin
            u_idx[t] = idx_of(from_cb.pc, from_cb.ghr, HISTLEN[t]);
            u_ent[t] = tt[t][u_idx[t]];
            u_hit[t] = (u_ent[t].tag == tag_of(from_cb.pc, from_cb.ghr, HISTLEN[t]));
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
        final_pred  = u_prov_pred;
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
    //---------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            ghr_spec   <= '0;
            ghr_commit <= '0;
            for (int i = 0; i < PHT_DEPTH; i++) bimodal[i] <= 2'b01;
            for (int t = 0; t < TAGE_NUM; t++)
                for (int j = 0; j < TAGE_DEPTH; j++) tt[t][j] <= '0;
        end else begin
            ghr_commit <= ghr_commit_next;
            if (flush)                ghr_spec <= ghr_commit_next;
            else if (spec_update_en)  ghr_spec <= ghr_spec_fetch;

            if (from_cb.update_en) begin
                // base predictor learns only for branches with no tagged provider
                if (!u_provider_valid) begin
                    if (u_taken) bimodal[from_cb.pc[PHT_IDX+1:2]] <= (bimodal[from_cb.pc[PHT_IDX+1:2]] == 2'b11) ? 2'b11 : bimodal[from_cb.pc[PHT_IDX+1:2]] + 2'b01;
                    else         bimodal[from_cb.pc[PHT_IDX+1:2]] <= (bimodal[from_cb.pc[PHT_IDX+1:2]] == 2'b00) ? 2'b00 : bimodal[from_cb.pc[PHT_IDX+1:2]] - 2'b01;
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
                        tt[t][u_idx[t]].tag <= tag_of(from_cb.pc, from_cb.ghr, HISTLEN[t]);
                        tt[t][u_idx[t]].ctr <= u_taken ? 3'sb000 : 3'sb111;   // weakly toward outcome
                        tt[t][u_idx[t]].u   <= '0;
                    end else if (mispredict && !alloc_valid && (unsigned'(t) >= alloc_start)) begin
                        // no free entry: age the candidates so one frees up later
                        tt[t][u_idx[t]].u <= (u_ent[t].u == '0) ? u_ent[t].u : u_ent[t].u - 1'b1;
                    end
                end
            end
        end
    end

endmodule
