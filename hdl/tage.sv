module tage
import rv32i_types::*;
#(
    parameter TABLE_COUNT = 4,       
    parameter GHR_BITS = GHR_WIDTH
)
(
    input  logic           clk,
    input  logic           rst,

    // Interface from Fetch
    input  logic [31:0]    fetch_pc,
    input  logic [GHR_BITS-1:0] ghr_in,
    output logic           pred_taken_tage, 
    output tage_meta_t     tage_meta_out,

    input  logic           update_valid,
    input  logic [31:0]    update_pc,
    input  logic [GHR_BITS-1:0] update_ghr,
    input  logic           actual_taken,
    input  tage_meta_t     update_tage_meta,
    input  logic           is_branch_inst
);
    integer i, j;
    localparam TAG_BITS = 8;  // Reduced for area optimization
    localparam ENTRY_COUNT = 32;  // Reduced for area optimization (50% savings)
    localparam INDEX_WIDTH = $clog2(ENTRY_COUNT); 
    
    // Function to get history length for each table (geometrically increasing)
    function automatic integer get_history_length(input integer table_idx);
        case (table_idx)
            0: return 2;   // Very short - capture immediate local correlations
            1: return 8;   // Short-medium - local patterns with some history
            2: return 17;  // Medium - balanced local/global
            3: return 32;  // Maximum - full global history
            default: return 2;
        endcase
    endfunction 

    typedef struct packed {
        logic [2:0] ctr;     
        logic [TAG_BITS-1:0] tag; 
        logic [1:0] u;       
        logic valid;
    } tage_entry_t;

    tage_entry_t tage_tables[TABLE_COUNT-1:0][ENTRY_COUNT-1:0];

    logic [INDEX_WIDTH-1:0] indices[TABLE_COUNT-1:0];
    logic [TAG_BITS-1:0] tags[TABLE_COUNT-1:0];
    
    logic [3:0] best_match_idx;  
    logic best_match_found;
    
    logic [3:0] p_idx;
    logic p_valid;
    
    logic [INDEX_WIDTH-1:0] update_indices_comb[TABLE_COUNT-1:0];
    logic [TAG_BITS-1:0] update_tags_comb[TABLE_COUNT-1:0];
    
    // Base predictor (simple bimodal) for when no TAGE table matches
    logic [1:0] base_predictor[16];
    logic [3:0] base_index;
    logic base_pred;
    assign base_index = fetch_pc[5:2];
    assign base_pred = base_predictor[base_index][1];
    
    // Aging counter for usefulness decay
    logic [5:0] aging_counter;


    generate for (genvar k = 0; k < TABLE_COUNT; k++) begin : gen_tables
        
        localparam HISTORY_LEN = get_history_length(k);
        
        logic [INDEX_WIDTH-1:0] folded_history;
        logic [INDEX_WIDTH-1:0] folded_history_update;
        
        function automatic [INDEX_WIDTH-1:0] hash_fold (input [GHR_BITS-1:0] history, input integer history_len);
            reg [INDEX_WIDTH-1:0] result = '0;
            reg [GHR_BITS-1:0] temp_history = history;
            
            for (integer j = 0; j < history_len; j = j + INDEX_WIDTH) begin
                result = result ^ temp_history[INDEX_WIDTH-1:0];
                temp_history = temp_history >> INDEX_WIDTH;
            end
            return result;
        endfunction
        
        assign folded_history = hash_fold(ghr_in, HISTORY_LEN);
        
        if (k == 0) begin
            // Table 0: Focus on low PC bits for tight loops
            assign indices[k] = INDEX_WIDTH'(fetch_pc[INDEX_WIDTH+2:3] ^ folded_history);
            assign tags[k] = TAG_BITS'(fetch_pc[TAG_BITS+2:3] ^ ghr_in[TAG_BITS-1:0]);
        end else if (k == 1) begin
            // Table 1: Mix low and mid PC bits
            assign indices[k] = INDEX_WIDTH'(fetch_pc[7:4] ^ folded_history ^ fetch_pc[12:9]);
            assign tags[k] = TAG_BITS'(fetch_pc[11:4] ^ ghr_in[TAG_BITS-1:0] ^ fetch_pc[17:10]);
        end else if (k == 2) begin
            // Table 2: Mix mid and high PC bits
            assign indices[k] = INDEX_WIDTH'(fetch_pc[8:5] ^ folded_history ^ fetch_pc[15:12]);
            assign tags[k] = TAG_BITS'(fetch_pc[12:5] ^ ghr_in[TAG_BITS-1:0] ^ fetch_pc[19:12]);
        end else begin
            // Table 3: Mix all PC ranges
            assign indices[k] = INDEX_WIDTH'(fetch_pc[INDEX_WIDTH+2:3] ^ folded_history ^ fetch_pc[INDEX_WIDTH+10:11]);
            assign tags[k] = TAG_BITS'(fetch_pc[TAG_BITS+2:3] ^ ghr_in[TAG_BITS-1:0] ^ fetch_pc[TAG_BITS+10:11]);
        end
        
        assign folded_history_update = hash_fold(update_ghr, HISTORY_LEN);
        
        if (k == 0) begin
            assign update_indices_comb[k] = INDEX_WIDTH'(update_pc[INDEX_WIDTH+2:3] ^ folded_history_update);
            assign update_tags_comb[k] = TAG_BITS'(update_pc[TAG_BITS+2:3] ^ update_ghr[TAG_BITS-1:0]);
        end else if (k == 1) begin
            assign update_indices_comb[k] = INDEX_WIDTH'(update_pc[7:4] ^ folded_history_update ^ update_pc[12:9]);
            assign update_tags_comb[k] = TAG_BITS'(update_pc[11:4] ^ update_ghr[TAG_BITS-1:0] ^ update_pc[17:10]);
        end else if (k == 2) begin
            assign update_indices_comb[k] = INDEX_WIDTH'(update_pc[8:5] ^ folded_history_update ^ update_pc[15:12]);
            assign update_tags_comb[k] = TAG_BITS'(update_pc[12:5] ^ update_ghr[TAG_BITS-1:0] ^ update_pc[19:12]);
        end else begin
            assign update_indices_comb[k] = INDEX_WIDTH'(update_pc[INDEX_WIDTH+2:3] ^ folded_history_update ^ update_pc[INDEX_WIDTH+10:11]);
            assign update_tags_comb[k] = TAG_BITS'(update_pc[TAG_BITS+2:3] ^ update_ghr[TAG_BITS-1:0] ^ update_pc[TAG_BITS+10:11]);
        end
        
    end endgenerate
    
    always_comb begin
        best_match_idx = 4'd0;
        best_match_found = 1'b0;
        pred_taken_tage = 1'b0;
        
        // Search from longest history to shortest
        for (integer i = TABLE_COUNT-1; i >= 0; i--) begin
            if (tage_tables[i][indices[i]].valid && (tage_tables[i][indices[i]].tag == tags[i])) begin
                if (!best_match_found) begin
                    best_match_idx = 4'(unsigned'(i)); 
                    best_match_found = 1'b1;
                    pred_taken_tage = tage_tables[i][indices[i]].ctr[2];
                end
            end
        end
        
        // Fallback to base predictor if no TAGE table matches
        if (!best_match_found) begin
            pred_taken_tage = base_pred;
        end

        tage_meta_out.ghr_checkpoint      = ghr_in;
        tage_meta_out.pred_table_idx      = best_match_idx;
        tage_meta_out.pred_tag_match_idx  = best_match_found ? 2'd1 : 2'd0; 
        tage_meta_out.pred_valid          = best_match_found;
        
        p_idx = update_tage_meta.pred_table_idx;
        p_valid = update_tage_meta.pred_valid;
        
    end

    always_ff @(posedge clk) begin
        automatic logic predicted_direction;
        automatic logic mispredicted;
        automatic logic should_allocate;
        automatic logic [3:0] base_update_idx;
        
        if (rst) begin
            for (i = 0; i < TABLE_COUNT; i++) begin
                for (j = 0; j < ENTRY_COUNT; j++) begin
                    tage_tables[i][j] <= '0;
                end
            end
            for (i = 0; i < 16; i++) begin
                base_predictor[i] <= 2'b01;  // Weakly not-taken
            end
            aging_counter <= '0;
        end else begin
            // More aggressive aging: decrement usefulness every 64 updates (was 128)
            aging_counter <= aging_counter + 6'd1;
            if (aging_counter == 6'd63) begin
                for (i = 0; i < TABLE_COUNT; i++) begin
                    for (j = 0; j < ENTRY_COUNT; j++) begin
                        if (tage_tables[i][j].u > 2'd0)
                            tage_tables[i][j].u <= tage_tables[i][j].u - 2'd1;
                    end
                end
            end
            
            if (update_valid && is_branch_inst) begin
                predicted_direction = tage_tables[p_idx][update_indices_comb[p_idx]].ctr[2];
                mispredicted = p_valid && (actual_taken != predicted_direction);
                
                // Update base predictor
                base_update_idx = update_pc[5:2];
                if (actual_taken) begin
                    if (base_predictor[base_update_idx] < 2'd3)
                        base_predictor[base_update_idx] <= base_predictor[base_update_idx] + 2'd1;
                end else begin
                    if (base_predictor[base_update_idx] > 2'd0)
                        base_predictor[base_update_idx] <= base_predictor[base_update_idx] - 2'd1;
                end
                
                if (p_valid) begin
                    tage_entry_t predicting_entry;
                    predicting_entry = tage_tables[p_idx][update_indices_comb[p_idx]];

                    // Update counter with better saturation
                    if (actual_taken) begin
                        if (predicting_entry.ctr < 3'd7)
                            predicting_entry.ctr = predicting_entry.ctr + 3'd1;
                    end else begin
                        if (predicting_entry.ctr > 3'd0)
                            predicting_entry.ctr = predicting_entry.ctr - 3'd1;
                    end
                    
                    // Update usefulness: more aggressive updates
                    if (actual_taken == predicted_direction) begin
                        // Correct prediction - increase usefulness
                        if (predicting_entry.u < 2'd3)
                            predicting_entry.u = predicting_entry.u + 2'd1;
                    end else if (mispredicted) begin
                        // Misprediction - decrease usefulness more aggressively
                        if (predicting_entry.u > 2'd0)
                            predicting_entry.u = predicting_entry.u - 2'd1;
                    end

                    tage_tables[p_idx][update_indices_comb[p_idx]] <= predicting_entry;
                end
                
                // Smarter allocation: only on misprediction or when no prediction
                should_allocate = mispredicted || !p_valid;
                
                if (should_allocate) begin
                    // Allocate in tables with longer history than the provider
                    automatic logic allocated;
                    allocated = 1'b0;
                    for (i = TABLE_COUNT-1; i >= 0; i--) begin
                        if (!allocated && (!p_valid || i > integer'(p_idx))) begin
                            tage_entry_t entry;
                            entry = tage_tables[i][update_indices_comb[i]];
                            // Allocate if entry has low usefulness or is invalid
                            if (entry.u == 2'd0 || !entry.valid) begin
                                entry.valid = 1'b1;
                                entry.tag   = update_tags_comb[i];
                                entry.ctr   = actual_taken ? 3'd5 : 3'd2;  // Stronger initial bias (was 4/3)
                                entry.u     = 2'd0;  // Start with low usefulness
                                tage_tables[i][update_indices_comb[i]] <= entry;
                                allocated = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule