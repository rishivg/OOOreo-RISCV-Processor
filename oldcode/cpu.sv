module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);

    logic bmem_flag;

    logic   [31:0]  pc, pc_next, pc_next_prev;
    logic   [31:0]  order;
    logic           stall;
    logic           alu_stall_unit_dis, mult_stall_unit_dis, br_stall_unit_dis, mem_stall_unit_dis;

    rat_arf_entry_t rat_arf_table [32];
    logic           rs1_rdy, rs2_rdy;
    logic mem_stall;

    logic mul_alu_available, int_alu_available, br_alu_available, mem_available;

    localparam NUM_FUNC_UNIT = 4;
    
    if_id_stage_reg_t  decode_struct_in;
    id_dis_stage_reg_t decode_struct_out;
    id_dis_stage_reg_t dispatch_struct_in;
    reservation_station_t dispatch_struct_out [NUM_FUNC_UNIT];
    reservation_station_t next_execute [NUM_FUNC_UNIT];

    to_writeback_t   execute_output [NUM_FUNC_UNIT];
    to_writeback_t   next_writeback [NUM_FUNC_UNIT]; 

    logic [4:0] current_rd_rob_idx;

    logic   [31:0]  ufp_addr;
    logic   [3:0]   ufp_rmask;
    logic   [31:0]  ufp_rdata;
    logic   [255:0] ufp_rcache_line;
    logic           ufp_resp;

    logic   [31:0]  dfp_addr;
    logic           dfp_read;
    logic           dfp_write;
    logic   [255:0] dfp_rdata;
    logic   [255:0] dfp_wdata;
    logic           dfp_resp;

    logic prediction_followed;

    logic   [31:0]  dfp_addr_inst;
    logic           dfp_read_inst;
    logic   [255:0] dfp_rdata_inst;
    logic           dfp_resp_inst;

    logic   [31:0]  dmem_addr;
    logic   [3:0]   dmem_rmask;
    logic   [3:0]   dmem_wmask;
    logic   [31:0]  dmem_rdata;
    logic   [31:0]  dmem_wdata;
    logic           dmem_resp;
    
    logic   [31:0]  ufp_addr_mem;
    logic   [3:0]   ufp_rmask_mem;
    logic   [3:0]   ufp_wmask_mem;
    logic   [31:0]  ufp_rdata_mem;
    logic   [255:0] ufp_rcache_line_mem;
    logic   [31:0]  ufp_wdata_mem;
    logic           ufp_resp_mem;

    logic   [31:0]  dfp_addr_mem;
    logic           dfp_read_mem;
    logic           dfp_write_mem;
    logic   [255:0] dfp_rdata_mem;
    logic   [255:0] dfp_wdata_mem;
    logic           dfp_resp_mem;

    logic rsv_stall;

    cache_adapter cache_line_adapter (
        .clk        (clk),
        .rst        (rst),
        .bmem_ready (bmem_ready),
        .bmem_raddr (bmem_raddr),
        .bmem_rdata (bmem_rdata),
        .bmem_rvalid(bmem_rvalid),
        .dfp_wdata  (dfp_wdata),
        .dfp_write  (dfp_write),
        .dfp_rdata  (dfp_rdata),
        .dfp_resp   (dfp_resp),
        .bmem_wdata (bmem_wdata),
        .bmem_write (bmem_write),
        .bmem_read  (bmem_read),
        .bmem_addr  (bmem_addr),
        .bmem_flag(bmem_flag)
    );

    prefetcher instruction_cache (
        .clk        (clk),
        .rst        (rst),
        
        .ufp_addr   (ufp_addr),
        .ufp_rmask  (ufp_rmask),
        .ufp_rdata  (ufp_rdata),
        .ufp_rcache_line (ufp_rcache_line),
        .ufp_resp   (ufp_resp),

        .dfp_addr   (dfp_addr_inst),
        .dfp_read   (dfp_read_inst),
        .dfp_rdata  (dfp_rdata_inst),
        .dfp_resp   (dfp_resp_inst)
    );

    dcache data_cache (
        .clk        (clk),
        .rst        (rst),
        
        .ufp_addr   (ufp_addr_mem),
        .ufp_rmask  (ufp_rmask_mem),
        .ufp_wmask  (ufp_wmask_mem),
        .ufp_rdata  (ufp_rdata_mem),
        .ufp_rcache_line (ufp_rcache_line_mem),
        .ufp_wdata  (ufp_wdata_mem),
        .ufp_resp   (ufp_resp_mem),

        .dfp_addr   (dfp_addr_mem),
        .dfp_read   (dfp_read_mem),
        .dfp_write  (dfp_write_mem),
        .dfp_rdata  (dfp_rdata_mem),
        .dfp_wdata  (dfp_wdata_mem),
        .dfp_resp   (dfp_resp_mem)
    );
    cdb cdbus;

    localparam WIDTH = 129;  // 1 (valid) + 31 (tage_meta) + 1 (pred) + 32 (order) + 32 (pc) + 32 (inst)
    localparam DEPTH = 8;

    logic full_o, empty_o;
    logic enqueue_i, dequeue_i;
    logic [WIDTH-1:0] data_i, data_o;
    logic [31:0] curr_instr_addr, last_instr_addr;
    logic [255:0] curr_instr_data, last_instr_data;

    logic [255:0] curr_dmem_data, last_dmem_data;

    queue #(
        .WIDTH      (WIDTH),
        .DEPTH      (DEPTH)
    ) instruction_queue (
        .clk        (clk),
        .rst        (rst),
        .flush      (cdbus.flush),
        .enqueue_wdata (data_i),
        .enqueue    (enqueue_i),
        .full       (full_o),
        .dequeue_rdata (data_o),
        .dequeue    (dequeue_i),
        .empty      (empty_o)
    );

    logic instr_enable;

    always_ff @(posedge clk) begin
        if (rst) begin
            last_instr_data <= '0;
            last_instr_addr <= '0;
        end
        else begin
            if (instr_enable) begin
                last_instr_data <= curr_instr_data;
                last_instr_addr <= curr_instr_addr;
            end
        end
    end

    logic dmem_enable;


    logic inst_mem_stall;

    always_ff @(posedge clk) begin
        if (rst) begin
            inst_mem_stall <= 1'b0;
        end else if (dfp_resp_inst) begin
            inst_mem_stall <= 1'b0;
        end else if (dfp_read_inst && (!mem_stall)) begin
            inst_mem_stall <= 1'b1;
        end 
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            last_dmem_data <= '0;
        end
        else begin
            if (dmem_enable) begin
                last_dmem_data <= curr_dmem_data;
            end
        end
    end

    logic [4:0] rs1_rob_idx, rs2_rob_idx;

    logic       rob_full_o;
    rob_forward_t rob_table_o [32];

    // Early decode for combinational prediction
    if_id_stage_reg_t  decode_struct_in_early;
    id_dis_stage_reg_t decode_struct_out_early;

    decode decode_stage (
        .decode_struct_in   (decode_struct_in),
        .decode_struct_out  (decode_struct_out)
    );

    decode decode_stage_early (
        .decode_struct_in   (decode_struct_in_early),
        .decode_struct_out  (decode_struct_out_early)
    );

    always_comb begin
        rs1_rdy = rat_arf_table[dispatch_struct_in.rs1_addr].ready;
        rs2_rdy = rat_arf_table[dispatch_struct_in.rs2_addr].ready;
        rs1_rob_idx = rat_arf_table[dispatch_struct_in.rs1_addr].rob_idx;
        rs2_rob_idx = rat_arf_table[dispatch_struct_in.rs2_addr].rob_idx;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < 32; i++) begin
                rat_arf_table[i] <= '0;
                rat_arf_table[i].ready <= '1;
            end
        end else if(cdbus.flush) begin
            for (integer i = 0; i < 32; i++) begin
                rat_arf_table[i].ready <= '1;
            end
            if (cdbus.regf_we && (cdbus.commit_rd_addr != 5'd0)) begin
                rat_arf_table[cdbus.commit_rd_addr].data <= cdbus.commit_data;
            end
        end else begin
            if (cdbus.regf_we && (cdbus.commit_rd_addr != 5'd0)) begin
                rat_arf_table[cdbus.commit_rd_addr].data <= cdbus.commit_data;

                if (rat_arf_table[cdbus.commit_rd_addr].rob_idx == cdbus.commit_rob_idx)
                    rat_arf_table[cdbus.commit_rd_addr].ready <= 1'b1;
            end

            if (dispatch_struct_in.valid && (dispatch_struct_in.rd_addr != 5'd0)) begin
                rat_arf_table[dispatch_struct_in.rd_addr].ready <= 1'b0;
                rat_arf_table[dispatch_struct_in.rd_addr].rob_idx <= current_rd_rob_idx;
            end
        end
    end

    rob_entry_t head_entry;

    rob rob_inst (
        .clk(clk),
        .rst(rst),
        .disp_entry(decode_struct_out),
        .head_entry(head_entry),
        .rob_out(rob_table_o),
        .enqueue(decode_struct_out.valid),
        .dequeue(cdbus.regf_we),
        .cdbus(cdbus),
        .tail_addr(current_rd_rob_idx),
        .full(rob_full_o)
    );
    
    logic   rsv_rs1_ready, rsv_rs2_ready;
    assign rsv_rs1_ready = rs1_rdy || (!dispatch_struct_in.use_rs1);
    assign rsv_rs2_ready = rs2_rdy || (!dispatch_struct_in.use_rs2);

    rename_dispatch rsv (
        .clk(clk),
        .rst(rst),
        .dispatch_struct_in(dispatch_struct_in),
        .current_rd_rob_idx(current_rd_rob_idx),
        .rs1_data_in(rat_arf_table[dispatch_struct_in.rs1_addr].data),
        .rs1_ready(rsv_rs1_ready),

        .rs2_data_in(rat_arf_table[dispatch_struct_in.rs2_addr].data),
        .rs2_ready(rsv_rs2_ready),
        .rob_table(rob_table_o),

        .cdbus(cdbus),
        .dmem_resp(dmem_resp),

        .rs1_rob_idx(rs1_rob_idx), 
        .rs2_rob_idx(rs2_rob_idx),
        .integer_alu_available(int_alu_available),
        .mul_alu_available(mul_alu_available),
        .br_alu_available(br_alu_available),
        .mem_available(mem_available),
        .next_execute_alu(dispatch_struct_out[0]),
        .next_execute_mult_div(dispatch_struct_out[1]),
        .next_execute_branch(dispatch_struct_out[2]),
        .next_execute_mem(dispatch_struct_out[3])
    );
    
    alu_ex alu_inst (
        .next_execute(next_execute[0]),
        .execute_output(execute_output[0])
    );

    mdu_ex mul_inst (
        .clk(clk),
        .rst(rst),
        .next_execute(next_execute[1]),
        .execute_output(execute_output[1])
    );

    bru_ex br_inst (
        .next_execute(next_execute[2]),
        .execute_output(execute_output[2])
    );
    
    lsu_ex mem_inst (
        .clk(clk),
        .rst(rst),
        .mem_stall(mem_stall),
        .dmem_addr(dmem_addr),
        .dmem_rmask(dmem_rmask),
        .dmem_wmask(dmem_wmask),
        .dmem_rdata(dmem_rdata),
        .dmem_wdata(dmem_wdata),
        .dmem_resp(dmem_resp),
        .rob_entry_o(head_entry),
        .next_execute(next_execute[3]),
        .execute_output(execute_output[3]),
        .cdbus(cdbus)
    );

    // TAGE predictor signals
    logic [GHR_WIDTH-1:0] ghr;
    logic prediction_tage;
    tage_meta_t tage_meta;
    logic is_branch_commit;
    
    assign is_branch_commit = head_entry.valid && head_entry.status == done && head_entry.op_type == br;
    
    // TAGE predictor instantiation
    tage tage_inst (
        .clk(clk),
        .rst(rst),
        // Prediction interface - predict based on the instruction being fetched
        .fetch_pc(decode_struct_out_early.pc),
        .ghr_in(ghr),
        .pred_taken_tage(prediction_tage),
        .tage_meta_out(tage_meta),
        // Update interface
        .update_valid(is_branch_commit),
        .update_pc(head_entry.pc),
        .update_ghr(head_entry.tage_meta.ghr_checkpoint),  
        .actual_taken(head_entry.br_en),
        .update_tage_meta(head_entry.tage_meta),  // Use stored metadata from ROB
        .is_branch_inst(is_branch_commit)
    );
    
    // Prediction signals
    logic prediction;
    
    // Global History Register management - speculative updates with recovery
    logic is_branch_or_jal_predicted;
    assign is_branch_or_jal_predicted = decode_struct_out.valid && 
                                        (decode_struct_out.opcode == op_b_br || decode_struct_out.opcode == op_b_jal) &&
                                        prediction_followed;
    
    logic branch_mispredicted;
    assign branch_mispredicted = is_branch_commit && (head_entry.br_en != head_entry.prediction);
    
    always_ff @(posedge clk) begin
        if (rst) begin
            ghr <= '0;
        end else if (cdbus.flush && branch_mispredicted) begin
            // Restore GHR on misprediction: use checkpointed GHR and add actual outcome
            ghr <= {head_entry.tage_meta.ghr_checkpoint[GHR_WIDTH-2:0], head_entry.br_en};
        end else if (is_branch_or_jal_predicted) begin
            // Speculative update: shift in predicted outcome
            ghr <= {ghr[GHR_WIDTH-2:0], prediction};
        end
    end

    // Use TAGE predictions directly
    assign prediction = prediction_tage;
    
    always_comb begin
        dfp_resp_inst = '0;
        dfp_rdata_inst = '0;

        dfp_addr = dfp_addr_inst;
        dfp_read = dfp_read_inst;
        dfp_write = 1'b0;
        dfp_wdata = '0;
        dfp_rdata_inst = dfp_rdata;
        dfp_resp_inst = dfp_resp && inst_mem_stall;

        dfp_rdata_mem = '0;
        dfp_resp_mem = 1'b0;

        if (mem_stall) begin
            dfp_addr = dfp_addr_mem;
            dfp_read = dfp_read_mem ;
            dfp_write = dfp_write_mem;
            dfp_wdata = dfp_wdata_mem;

            dfp_rdata_mem = dfp_rdata;
            dfp_resp_mem = dfp_resp && (!inst_mem_stall);
            dfp_resp_inst = dfp_resp && inst_mem_stall;
        end
    end

    logic flush_stalling;
    logic [31:0] m_order;

    always_ff @(posedge clk) begin : fetch
        if (rst) begin
            pc          <= 32'haaaaa000;
            order       <= '0;
            ufp_rmask   <= '0;
            data_i      <= '0;
            bmem_read   <= 1'b0;
            bmem_addr      <= 32'h0;
            enqueue_i <= 1'b0;    
            bmem_flag <= 1'b0;   
            flush_stalling <= '0;
        end else begin
            if (enqueue_i)  enqueue_i <= 1'b0;
            if (bmem_read)  bmem_read <= 1'b0;

            if (cdbus.flush) begin 
                pc <= pc_next; 
                bmem_read <= 1'b0;
                if (dfp_resp) begin 
                    bmem_read <= 1'b0;
                    bmem_flag <= 1'b0;
                 end
                if (ufp_rmask > '0)
                    flush_stalling <= '1;
                else begin
                    order <= m_order;
                    if (pc_next[31:5] != last_instr_addr[31:5]) begin
                        ufp_rmask <= '1; 
                        ufp_addr <= pc_next;                         
                    end
               end            
            end else if (dfp_read_mem && (head_entry.rd_rob_idx == next_execute[3].rd_rob_idx)) begin
                if (bmem_flag == 1'd0) begin
                    bmem_addr  <= dfp_addr;
                    bmem_read <= 1'd1;
                    bmem_flag <= 1'd1;
                end else begin
                    bmem_read <= 1'd0;
                end

                if (dfp_resp) begin 
                    bmem_flag <= 1'd0;
                end        
            end 
            else if (ufp_resp && (flush_stalling == '1)) begin
                flush_stalling <= '0;
                data_i <= {1'b1, tage_meta, prediction && prediction_followed, m_order, pc_next, last_instr_data[32*pc[4:2] +: 32]};
                order <= m_order;
                ufp_addr <= pc;
                ufp_rmask <= '1;   
            end
            else begin
                if (ufp_resp) begin
                    data_i <= {1'b1, tage_meta, prediction && prediction_followed, order, pc, ufp_rdata};
                    if (!full_o) begin
                        ufp_rmask <= '0;
                        enqueue_i <= 1'b1;
                        pc <= pc_next;
                        order <= order + 'd1;
                    end
                end else if (pc[31:5] == last_instr_addr[31:5] && ~&ufp_rmask) begin
                    ufp_rmask <= '0;
                    data_i <= {1'b1, tage_meta, prediction && prediction_followed, order, pc, last_instr_data[32*pc[4:2] +: 32]};
                    if (!full_o && !stall) begin
                        enqueue_i <= 1'b1;
                        pc <= pc_next;
                        order <= order + 'd1;
                    end
                end else if (ufp_rmask == 4'd0) begin
                    ufp_addr <= pc;
                    ufp_rmask <= '1;                   
                end 
                if (dfp_write && !bmem_flag) begin
                    bmem_addr <= dfp_addr;
                end 
                if (dfp_resp) begin 
                        bmem_read <= 1'b0;
                        bmem_flag <= 1'b0;
                end else if (dfp_read) begin
                    if (bmem_flag == 1'b0) begin
                        bmem_addr  <= dfp_addr;
                        bmem_read <= 1'b1;
                        bmem_flag <= 1'b1;
                    end else begin
                        bmem_read <= 1'b0;
                    end
                end

            end
        end
    end

    logic [WIDTH-1:0] data_i_comb;
    logic data_i_comb_valid;
    
    always_comb begin
        data_i_comb = '0;
        data_i_comb_valid = 1'b0;

        if (dfp_read_mem && (head_entry.rd_rob_idx == next_execute[3].rd_rob_idx)) begin
            data_i_comb = data_i;
            data_i_comb_valid = 1'b0;  // Not a new fetch
        end else if (ufp_resp && (flush_stalling == '1)) begin
            data_i_comb = {1'b1, 31'b0, 1'b0, m_order, pc_next_prev, last_instr_data[32*pc[4:2] +: 32]};
            data_i_comb_valid = 1'b1;
        end else begin
            if (ufp_resp) begin
                data_i_comb = {1'b1, 31'b0, 1'b0, order, pc, ufp_rdata};
                data_i_comb_valid = 1'b1;
            end else if (pc[31:5] == last_instr_addr[31:5] && ~&ufp_rmask) begin
                data_i_comb = {1'b1, 31'b0, 1'b0, order, pc, last_instr_data[32*pc[4:2] +: 32]};
                data_i_comb_valid = 1'b1;
            end else if (ufp_rmask == 4'd0) begin
                data_i_comb = data_i;
                data_i_comb_valid = 1'b0;  // Not a new fetch
            end
        end
    end

    always_comb begin : data_cache_ufp
        ufp_addr_mem = dmem_addr;
        ufp_rmask_mem = dmem_rmask;
        ufp_wmask_mem = dmem_wmask;
        ufp_wdata_mem = dmem_wdata;
        dmem_rdata = ufp_rdata_mem;
        dmem_resp = ufp_resp_mem;
    end

    always_comb begin : prep_decode_in
        dequeue_i = (!empty_o && !rst && !stall) || (full_o && (!rsv_stall)); 
        decode_struct_in = '0;

        if (!empty_o) begin
            decode_struct_in.inst = data_o[31:0];
            decode_struct_in.pc = data_o[63:32];
            decode_struct_in.order = data_o[95:64];      
            decode_struct_in.prediction = data_o[96];
            decode_struct_in.tage_meta = data_o[127:97];
        end

        decode_struct_in.valid = dequeue_i;

        // Early decode for same-cycle prediction - valid when we have a new instruction
        decode_struct_in_early = '0;
        decode_struct_in_early.inst = data_i_comb[31:0];
        decode_struct_in_early.pc = data_i_comb[63:32];
        decode_struct_in_early.order = data_i_comb[95:64];
        decode_struct_in_early.valid = data_i_comb_valid && !stall && !rst;

    end

    always_comb begin : update_line_buffer
        instr_enable = 1'b0;
        dmem_enable = 1'b0;
        curr_instr_addr = '0;
        curr_instr_data = '0;
        curr_dmem_data = '0;

        if (ufp_resp) begin
            curr_instr_addr = pc;
            curr_instr_data = ufp_rcache_line;
            instr_enable = 1'b1;      
        end
        if (cdbus.flush) begin
            if (pc[31:5] != last_instr_addr[31:5]) begin
                curr_instr_addr = pc;
                curr_instr_data = '0;
            end
            instr_enable = 1'b1;            
        end else if (ufp_resp_mem && mem_stall && |dmem_wmask) begin
            curr_dmem_data = last_dmem_data;
            curr_dmem_data[32*dmem_addr[4:2] +: 32] = ufp_wdata_mem;
            dmem_enable = 1'b1;            
        end else if (ufp_resp_mem && mem_stall) begin
            curr_dmem_data = ufp_rcache_line_mem;
            dmem_enable = 1'b1;            
        end
    end

    always_ff @(posedge clk) begin : update_dispatch_str
        if (rst || cdbus.flush) begin
            dispatch_struct_in <= '0;
            next_execute <= '{NUM_FUNC_UNIT{'0}};
        end
        else begin
            if (!rsv_stall)
                dispatch_struct_in <= decode_struct_out;
            
            next_execute[0] <= dispatch_struct_out[0];
            next_execute[1] <= dispatch_struct_out[1];
            next_execute[2] <= dispatch_struct_out[2];
            if (!mem_stall)
                next_execute[3] <= dispatch_struct_out[3];
        end
    end

    always_comb begin
        next_writeback = execute_output;
    end

    to_writeback_t   next_writeback_prev [NUM_FUNC_UNIT];
    always_ff @(posedge clk) begin
        if (rst) begin
            next_writeback_prev <= '{NUM_FUNC_UNIT{'0}};
        end else begin
            next_writeback_prev <= next_writeback;
        end
    end

    always_comb begin : update_rs_we_cdbus
        cdbus = '0;
        pc_next = pc + 32'd4;
        prediction_followed = '0;
        
        // Check if we should follow the prediction for branches/jumps (using early decode)
        if (decode_struct_out_early.opcode == op_b_jal || decode_struct_out_early.opcode == op_b_br) begin
            if (prediction) begin
                prediction_followed = '1;
                pc_next = decode_struct_out_early.imm + decode_struct_out_early.pc;
                // Prevent infinite loop if prediction points to same PC
                if (pc == pc_next) begin
                    pc_next = pc + 32'd4;
                    prediction_followed = '0;
                end
            end
        end

        cdbus.alu_data = next_writeback[0].rd_data;
        cdbus.alu_rd_addr = next_writeback[0].rd_addr;
        cdbus.alu_rob_idx = next_writeback[0].rd_rob_idx;
        cdbus.alu_valid = next_writeback[0].valid;

        cdbus.mul_data = next_writeback[1].rd_data;
        cdbus.mul_rd_addr = next_writeback[1].rd_addr;
        cdbus.mul_rob_idx = next_writeback[1].rd_rob_idx;
        cdbus.mul_valid = next_writeback[1].valid;

        cdbus.br_data = next_writeback[2].rd_data;
        cdbus.br_rd_addr = next_writeback[2].rd_addr;
        cdbus.br_rob_idx = next_writeback[2].rd_rob_idx;
        cdbus.br_valid = next_writeback[2].valid;
        cdbus.br_en = next_writeback[2].br_en;
        cdbus.pc_new = next_writeback[2].pc_new;
        cdbus.prediction = next_writeback[2].prediction;

        cdbus.mem_data = next_writeback[3].rd_data;
        cdbus.mem_rd_addr = next_writeback[3].rd_addr;
        cdbus.mem_rob_idx = next_writeback[3].rd_rob_idx;
        cdbus.mem_valid = next_writeback[3].valid && (next_writeback[3] != next_writeback_prev[3]);
        cdbus.mem_addr = next_writeback[3].mem_addr;
        cdbus.mem_rmask = next_writeback[3].mem_rmask;
        cdbus.mem_wmask = next_writeback[3].mem_wmask;
        cdbus.mem_rdata = next_writeback[3].mem_rdata;
        cdbus.mem_wdata = next_writeback[3].mem_wdata;

        if (head_entry.valid && head_entry.status == done) begin
            cdbus.commit_data = head_entry.rd_data;
            cdbus.commit_rd_addr = head_entry.rd_addr;
            cdbus.commit_rob_idx = head_entry.rd_rob_idx;
            cdbus.regf_we = 1'b1;
            cdbus.rs1_addr = head_entry.rs1_addr;
            cdbus.rs2_addr = head_entry.rs2_addr;
            cdbus.pc = head_entry.pc;
            cdbus.inst = head_entry.inst;
            if (head_entry.br_en != head_entry.prediction) begin
                if (head_entry.br_en == 0) begin
                    pc_next = head_entry.pc + 32'd4;
                    cdbus.flush = '1;
                end else begin
                    pc_next = head_entry.pc_new;
                    cdbus.flush = '1;
                end
            end
        end
    end



    always_ff @(posedge clk) begin
        if (rst) begin
            pc_next_prev <= '0;
        end
        else begin
            pc_next_prev <= pc_next;
        end
    end

    always_comb begin : update_stall
        stall = 1'b0;
        rsv_stall = 1'b0;

        alu_stall_unit_dis  = !int_alu_available && (dispatch_struct_in.op_type == alu);
        mult_stall_unit_dis = !mul_alu_available && (dispatch_struct_in.op_type == mul);
        br_stall_unit_dis   = !br_alu_available  && (dispatch_struct_in.op_type == br );
        mem_stall_unit_dis  = !mem_available     && (dispatch_struct_in.op_type == mem);

        // General stalls (queue full or ROB full)
        if (full_o || rob_full_o) stall = 1'b1;
        
        // RS-specific stalls: only stall decode/dispatch if the specific RS needed is full
        if (dispatch_struct_in.valid && (alu_stall_unit_dis || mult_stall_unit_dis || br_stall_unit_dis || mem_stall_unit_dis))  begin
            stall = 1'b1;    
            rsv_stall = 1'b1;
        end 
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            m_order <= '0;
        end
        else if (cdbus.regf_we)
            m_order <= m_order + 1;
    end

    logic           monitor_valid;
    logic   [63:0]  monitor_order;
    logic   [31:0]  monitor_inst;
    logic   [4:0]   monitor_rs1_addr;
    logic   [4:0]   monitor_rs2_addr;
    logic   [31:0]  monitor_rs1_rdata;
    logic   [31:0]  monitor_rs2_rdata;
    logic   [4:0]   monitor_rd_addr;
    logic   [31:0]  monitor_rd_wdata;
    logic   [31:0]  monitor_pc_rdata;
    logic   [31:0]  monitor_pc_wdata;
    logic   [31:0]  monitor_mem_addr;
    logic   [3:0]   monitor_mem_rmask;
    logic   [3:0]   monitor_mem_wmask;
    logic   [31:0]  monitor_mem_rdata;
    logic   [31:0]  monitor_mem_wdata;

    assign monitor_valid     = cdbus.regf_we;
    assign monitor_order     = m_order; 
    assign monitor_inst      = cdbus.inst;
    assign monitor_rs1_addr  = cdbus.rs1_addr;
    assign monitor_rs2_addr  = cdbus.rs2_addr;
    assign monitor_rs1_rdata = rat_arf_table[cdbus.rs1_addr].data;
    assign monitor_rs2_rdata = rat_arf_table[cdbus.rs2_addr].data;
    assign monitor_rd_addr   = cdbus.commit_rd_addr;
    assign monitor_rd_wdata  = cdbus.commit_data;
    assign monitor_pc_rdata  = cdbus.pc;

    always_comb begin
        if (head_entry.valid && head_entry.status == done && head_entry.br_en) 
            monitor_pc_wdata = head_entry.pc_new;
        else 
            monitor_pc_wdata  = cdbus.pc + 4;
    end

    assign monitor_mem_addr  = head_entry.mem_addr;
    assign monitor_mem_rmask = head_entry.mem_rmask;
    assign monitor_mem_wmask = head_entry.mem_wmask;
    assign monitor_mem_rdata = head_entry.mem_rdata;
    assign monitor_mem_wdata = head_entry.mem_wdata;

endmodule : cpu