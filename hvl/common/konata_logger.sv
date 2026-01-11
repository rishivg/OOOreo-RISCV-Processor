module konata_logger
import cpu_params::*;
(
    input   logic   clk,
    input   logic   rst
);

    integer f;
    longint unsigned cycle_cnt;
    longint unsigned instr_cnt;
    logic           enabled;

    // Buffered writer queue to minimize blocking in the producer path
    string q[$];

    // Shadow RO to map ROB index to global instruction ID
    // rob_id is flattened index (ID_WIDTH * ROB_DEPTH)
    longint unsigned shadow_id [ROB_DEPTH][ID_WIDTH];

    initial begin
        // Only enabled if +KANATA is passed
        if ($test$plusargs("KANATA")) begin
            enabled = 1'b1;
            // Open JSONL writer
            f = $fopen("konata.jsonl", "w");
            // Emit a small metadata record
            string meta = $sformatf("{\"meta\":{\"kanata_version\":4,\"start_time\":%0d}}", $time);
            $fwrite(f, "%s\n", meta);

            // Spawn writer thread that drains the queue and writes to disk.
            // Runs concurrently and only waits on the clock when queue empty.
            fork
                begin : konata_writer
                    forever begin
                        if (q.size() > 0) begin
                            string s = q.pop_front();
                            $fwrite(f, "%s\n", s);
                        end else begin
                            @(posedge clk);
                        end
                    end
                end
            join_none
        end else begin
            enabled = 1'b0;
        end
    end

    final begin
        if (enabled) begin
            // Drain remaining queue entries synchronously and close file
            while (q.size() > 0) begin
                string s = q.pop_front();
                $fwrite(f, "%s\n", s);
            end
            $fclose(f);
        end
    end

    // Signal Accessors
    logic [ROB_PTR_IDX-1:0] rob_tail_ptr;
    logic [ROB_PTR_IDX-1:0] rob_head_ptr;
    logic                   rob_flush;
    logic                   rob_valid_in;
    logic                   rob_ready_in;

    // We lift these signals out of the tasks to help Verilator scope resolution
    assign rob_tail_ptr = top_tb.dut.backend_i.rob_i.tail_ptr;
    assign rob_head_ptr = top_tb.dut.backend_i.rob_i.head_ptr;
    assign rob_flush    = top_tb.dut.backend_i.rob_i.backend_flush;
    assign rob_valid_in = top_tb.dut.backend_i.id_rob_itf_i.valid;
    assign rob_ready_in = top_tb.dut.backend_i.id_rob_itf_i.ready;

    // CDB Monitoring signals
    logic                   cdb_valid [CDB_WIDTH];
    logic [ROB_IDX-1:0]     cdb_rob_id [CDB_WIDTH];

    generate for(genvar c=0; c<CDB_WIDTH; c++) begin
        assign cdb_valid[c] = top_tb.dut.backend_i.rob_i.cdb_rob[c].valid;
        assign cdb_rob_id[c] = top_tb.dut.backend_i.rob_i.cdb_rob[c].rob_id;
    end endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_cnt <= 0;
            instr_cnt <= 0;
        end else if (enabled) begin
            cycle_cnt <= cycle_cnt + 1;
            // Emit a lightweight cycle heartbeat event into the queue
            q.push_back($sformatf("{\"event\":\"cycle\",\"cycle\":%0d}", cycle_cnt));
            
            // Monitor Dispatch
                if (rob_valid_in && rob_ready_in) begin
                    int dispatch_count = 0;
                    for (int i = 0; i < ID_WIDTH; i++) begin
                        if (top_tb.dut.backend_i.uops_valid[i]) begin
                            longint id = instr_cnt + dispatch_count;
                            int rob_idx_flat = int'(rob_tail_ptr) * ID_WIDTH + i;
                            int row = rob_idx_flat / ID_WIDTH;
                            int col = rob_idx_flat % ID_WIDTH;

                            shadow_id[row][col] <= id;

                            // Push structured dispatch event
                            q.push_back($sformatf("{\"event\":\"dispatch\",\"cycle\":%0d,\"instr_id\":%0d,\"rob_row\":%0d,\"rob_col\":%0d,\"dispatch_index\":%0d}", cycle_cnt, id, row, col, i));

                            // Emit lifecycle markers for compatibility (optional)
                            q.push_back($sformatf("{\"event\":\"lifecycle\",\"phase\":\"issue\",\"cycle\":%0d,\"instr_id\":%0d}", cycle_cnt, id));
                            q.push_back($sformatf("{\"event\":\"lifecycle\",\"phase\":\"stage0\",\"cycle\":%0d,\"instr_id\":%0d}", (cycle_cnt > 2) ? cycle_cnt - 2 : 0, id));
                            q.push_back($sformatf("{\"event\":\"lifecycle\",\"phase\":\"stage1\",\"cycle\":%0d,\"instr_id\":%0d}", (cycle_cnt > 1) ? cycle_cnt - 1 : 0, id));
                            q.push_back($sformatf("{\"event\":\"lifecycle\",\"phase\":\"exec\",\"cycle\":%0d,\"instr_id\":%0d}", cycle_cnt, id));

                            dispatch_count++;
                        end
                    end
                    instr_cnt <= instr_cnt + dispatch_count;
                end

            // Monitor Execute
            for (int i = 0; i < CDB_WIDTH; i++) begin
                if (cdb_valid[i]) begin
                    int rob_idx_flat = cdb_rob_id[i];
                    int row = rob_idx_flat / ID_WIDTH;
                    int col = rob_idx_flat % ID_WIDTH;
                    longint id = shadow_id[row][col];

                    // Execution/commit on CDB — push structured event
                    q.push_back($sformatf("{\"event\":\"execute\",\"cycle\":%0d,\"instr_id\":%0d,\"cdb\":%0d,\"rob_row\":%0d,\"rob_col\":%0d}", cycle_cnt, id, i, row, col));
                end
            end

            // Monitor Commit
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (top_tb.dut.backend_i.rob_i.commit_instr[i]) begin
                    int head_ptr = rob_head_ptr;
                    int row = head_ptr;
                    int col = i;
                    longint id = shadow_id[row][col];

                    q.push_back($sformatf("{\"event\":\"commit\",\"cycle\":%0d,\"instr_id\":%0d,\"rob_row\":%0d,\"rob_col\":%0d}", cycle_cnt, id, row, col));
                end
            end

            // Monitor Flush
            if (rob_flush) begin
                q.push_back($sformatf("{\"event\":\"flush\",\"cycle\":%0d}", cycle_cnt));
            end
        end
    end

endmodule
