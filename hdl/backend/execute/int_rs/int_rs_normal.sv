module int_rs_normal
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    ds_rs_itf.rs                from_ds,
    rs_prf_itf.rs               to_prf,
    cdb_itf.rs                  cdb[CDB_WIDTH],
    cdb_itf.fu                  fu_cdb_out
);
    ///////////////////////////
    // Reservation Stations  //
    ///////////////////////////

    logic   [INTRS_DEPTH-1:0]           rs_valid;
    logic   [INTRS_DEPTH-1:0]           rs_request;
    logic   [INTRS_DEPTH-1:0]           rs_grant;
    logic   [INTRS_DEPTH-1:0]           rs_push_en;
    int_rs_entry_t  [INTRS_DEPTH-1:0]   rs_entry;
    int_rs_entry_t  [INTRS_DEPTH-1:0]   rs_entry_in;
    int_rs_entry_t  [ID_WIDTH-1:0]      from_ds_entry;
    int_rs_entry_t                      issued_entry;

    always_comb begin
        for (int w = 0; w < ID_WIDTH; w++) begin
            from_ds_entry[w].rob_id     = from_ds.uop[w].rob_id;
            from_ds_entry[w].rs1_phy    = from_ds.uop[w].rs1_phy;
            from_ds_entry[w].rs1_valid  = from_ds.uop[w].rs1_valid;
            from_ds_entry[w].rs2_phy    = from_ds.uop[w].rs2_phy;
            from_ds_entry[w].rs2_valid  = from_ds.uop[w].rs2_valid;
            from_ds_entry[w].rd_phy     = from_ds.uop[w].rd_phy;
            from_ds_entry[w].rd_arch    = from_ds.uop[w].rd_arch;
            from_ds_entry[w].op1_sel    = from_ds.uop[w].op1_sel;
            from_ds_entry[w].op2_sel    = from_ds.uop[w].op2_sel;
            from_ds_entry[w].imm        = from_ds.uop[w].imm;
            from_ds_entry[w].fu_opcode  = from_ds.uop[w].fu_opcode;
        end
    end

    generate for (genvar i = 0; i < INTRS_DEPTH; i++) begin : rs_array
        rs_entry #(
            .RS_ENTRY_T (int_rs_entry_t)
        ) int_rs_entry_i (
            .clk        (clk),
            .rst        (rst),

            .valid      (rs_valid[i]),
            .request    (rs_request[i]),
            .grant      (rs_grant[i]),

            .push_en    (rs_push_en[i]),
            .entry_in   (rs_entry_in[i]),
            .entry_out  (),
            .entry      (rs_entry[i]),
            .clear      (1'b0),
            .wakeup_cdb (cdb),
            .fast_bypass(),
            .rs_bypass()
        );
    end endgenerate

    ////////////////////////////////////
    // Free List (O(N) -> O(1) Fix)   //
    ////////////////////////////////////

    // Parameter for Index Bits
    localparam INTRS_IDX_BITS = $clog2(INTRS_DEPTH);
    
    logic   [INTRS_IDX_BITS-1:0]    freelist    [INTRS_DEPTH];
    logic   [INTRS_IDX_BITS:0]      fl_head;
    logic   [INTRS_IDX_BITS:0]      fl_tail;
    logic   [INTRS_IDX_BITS:0]      fl_count;
    
    // Calculate number of allocated ops this cycle
    logic   [2:0]                   alloc_cnt; // optimized for ID_WIDTH <= 4
    logic                           free_cnt;

    assign free_cnt = |rs_grant;
    
    always_comb begin
        alloc_cnt = '0;
        if (from_ds.ready) begin
            for (int w = 0; w < ID_WIDTH; w++) begin
                if (from_ds.valid[w]) alloc_cnt++;
            end
        end
    end

    // Encoder for the single grant (since issue width is 1 here)
    logic   [INTRS_IDX_BITS-1:0]    granted_idx;
    always_comb begin
        granted_idx = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            if (rs_grant[i]) begin
                granted_idx = INTRS_IDX_BITS'(i);
                break;
            end
        end
    end

    // Free List Sequential Logic
    always_ff @(posedge clk) begin
        if (rst) begin
            fl_head <= '0;
            fl_tail <= '0; // Empty? No, full.
            // Initialization: Tail = 0, Head = 0.
            // Let's say Head points to next item to Pop.
            // Tail points to next slot to Push.
            // Full state: Tail == Head (and count says full)
            fl_count <= INTRS_DEPTH;
            for(int i=0; i<INTRS_DEPTH; i++) begin
                freelist[i] <= INTRS_IDX_BITS'(i);
            end
             // To indicate full, maybe tail wrapped?
             // Let's use count as truth.
             fl_tail <= (INTRS_IDX_BITS+1)'(INTRS_DEPTH); 
             // Logic: Write at Tail, Read at Head.
             // Reset: Write 0..N-1. Tail=N. Head=0.
        end else begin
            // Update Count
            fl_count <= fl_count - (INTRS_IDX_BITS+1)'(alloc_cnt) + (INTRS_IDX_BITS+1)'(free_cnt);

            // Update Head (Alloc)
            fl_head <= fl_head + (INTRS_IDX_BITS+1)'(alloc_cnt);

            // Update Tail (Free) & Write
            if (free_cnt) begin
                freelist[fl_tail[INTRS_IDX_BITS-1:0]] <= granted_idx;
                fl_tail <= fl_tail + 1;
            end
        end
    end

    // Push Logic - Mapped from Free List
    logic   [INTRS_DEPTH-1:0]   [ID_WIDTH-1:0]  entry_push_en_arr;

    always_comb begin
        logic [1:0]                offset;
        logic [INTRS_IDX_BITS:0]   ptr;
        logic [INTRS_IDX_BITS-1:0] target_rs_idx;

        for (int i = 0; i < INTRS_DEPTH; i++) begin
            entry_push_en_arr[i] = '0;
        end
        
        // Map dispatch packet 'w' to the RS entry from freelist
        if (from_ds.ready) begin
            for (int w = 0; w < ID_WIDTH; w++) begin
                // If this op is valid, give it the next token
                if (from_ds.valid[w]) begin
                    // We need to find *which* token is for *which* w.
                    // If w=0 is valid, it gets head+0.
                    // If w=1 is valid, it gets head+1 (if w=0 was valid) or head+0 (if w=0 was invalid).
                    // Calculation of offset:
                    offset = '0;
                    for (int k = 0; k < w; k++) begin
                        if (from_ds.valid[k]) offset++;
                    end
                    
                    // Assign
                    ptr = fl_head + (INTRS_IDX_BITS+1)'(offset);
                    target_rs_idx = freelist[ptr[INTRS_IDX_BITS-1:0]]; // Modulo addressing
                    
                    entry_push_en_arr[target_rs_idx][w] = 1'b1;
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            rs_push_en[i] = |entry_push_en_arr[i];
        end
    end

    generate for (genvar i = 0; i < INTRS_DEPTH; i++) begin : push_muxes
        one_hot_mux #(
            .T          (int_rs_entry_t),
            .NUM_INPUTS (ID_WIDTH)
        ) push_mux (
            .data_in    (from_ds_entry),
            .select     (entry_push_en_arr[i]),
            .data_out   (rs_entry_in[i])
        );
    end endgenerate

    // Issue Logic
    // loop from top and issue the first entry requesting for issue
    always_comb begin
        rs_grant = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            if (rs_request[i]) begin
                rs_grant[i] = 1'b1;
                break;
            end
        end
    end

    // One-hot mux to select the issued entry
    one_hot_mux #(
        .T          (int_rs_entry_t),
        .NUM_INPUTS (INTRS_DEPTH)
    ) ohm (
        .data_in    (rs_entry),
        .select     (rs_grant),
        .data_out   (issued_entry)
    );

    // ready logic
    assign from_ds.ready = (fl_count >= (INTRS_IDX_BITS+1)'(ID_WIDTH));

    // communicate with prf
    assign to_prf.rs1_phy = issued_entry.rs1_phy;
    assign to_prf.rs2_phy = issued_entry.rs2_phy;

    //////////////////////
    // INT_RS to FU_ALU //
    //////////////////////
    logic           int_rs_valid;
    logic           fu_alu_ready;
    fu_alu_reg_t    fu_alu_reg_in;

    // handshake with fu_alu_reg:
    assign int_rs_valid = |rs_grant;

    // send data to fu_alu_reg
    always_comb begin 
        fu_alu_reg_in.rob_id       = issued_entry.rob_id;
        fu_alu_reg_in.rd_phy       = issued_entry.rd_phy;
        fu_alu_reg_in.rd_arch      = issued_entry.rd_arch;
        fu_alu_reg_in.op1_sel      = issued_entry.op1_sel;
        fu_alu_reg_in.op2_sel      = issued_entry.op2_sel;
        fu_alu_reg_in.fu_opcode    = issued_entry.fu_opcode;
        fu_alu_reg_in.imm          = issued_entry.imm;

        fu_alu_reg_in.rs1_value    = to_prf.rs1_value;
        fu_alu_reg_in.rs2_value    = to_prf.rs2_value;
    end

    
    // Functional Units
    fu_alu fu_alu_i(
        .clk                    (clk),
        .rst                    (rst),
        .int_rs_valid           (int_rs_valid),
        .fu_alu_ready           (fu_alu_ready),
        .fu_alu_reg_in          (fu_alu_reg_in),
        .bypass                 (),
        .cdb                    (fu_cdb_out)
    );

endmodule
