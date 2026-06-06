module inst_queue
import fetch_types::*, cpu_params::*; #(
            parameter               DEPTH     = 16
)
(
    input   logic               clk,
    input   logic               rst,

    frontend_fifo_itf.fifo      in,

    fifo_backend_itf.fifo       out
);

    localparam                  ADDR_IDX = $clog2(DEPTH);

    fetch_packet_t              fifo[DEPTH];

    logic                       enq_en;
    logic                       full;
    fetch_packet_t              enq_data;

    assign enq_en = in.valid;
    assign in.ready = ~full;
    assign enq_data = in.packet;

    logic   [ADDR_IDX:0]    wr_ptr;
    logic   [ADDR_IDX-1:0]  wr_ptr_actual;
    logic                   wr_ptr_flag;
    logic   [ADDR_IDX:0]    rd_ptr;
    logic   [ADDR_IDX-1:0]  rd_ptr_actual;
    logic                   rd_ptr_flag;
    logic   [ADDR_IDX-1:0]  rd_slot;        // next slot of the head packet to read

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    logic   [ADDR_IDX:0]    n_entries;
    assign n_entries = (ADDR_IDX+1)'(wr_ptr - rd_ptr);
    assign full  = (n_entries == (ADDR_IDX+1)'(DEPTH));

    logic                   empty;      // no packets buffered (tapped by perf_monitor)
    assign empty = (n_entries == '0);
    logic                   have_h;     // at least 1 packet buffered (head)
    logic                   have_h1;    // at least 2 packets buffered (head+1)
    assign have_h  = (n_entries >= (ADDR_IDX+1)'(1));
    assign have_h1 = (n_entries >= (ADDR_IDX+1)'(2));

    logic   [ADDR_IDX-1:0]  rd_ptr_p1_actual;
    assign rd_ptr_p1_actual = (ADDR_IDX)'(rd_ptr_actual + 1'b1);

    fetch_packet_t          head;
    fetch_packet_t          head1;
    assign head  = fifo[rd_ptr_actual];
    assign head1 = fifo[rd_ptr_p1_actual];

    // ---- branch predecode (opcode-only; matches the front-end's spec_br_valid) ----
    function automatic logic is_branch(input logic [31:0] inst);
        is_branch = (inst[6:0] == 7'b1100011)   // conditional branch
                 || (inst[6:0] == 7'b1101111)   // jal
                 || (inst[6:0] == 7'b1100111);  // jalr
    endfunction

    // ---- candidate stream: head slots (from rd_slot) then head+1 slots, in order ----
    // For IF_WIDTH==2 there are 4 candidate (packet,slot) positions. Each carries
    // its own pc (packet.pc + slot*4) and ghr (the source packet's snapshot).
    localparam int NC = 2*IF_WIDTH;     // 4 candidates
    logic                       c_v   [NC];
    logic   [31:0]              c_inst[NC];
    logic   [31:0]              c_pc  [NC];
    logic   [GHR_LEN-1:0]       c_ghr [NC];
    logic                       c_pt  [NC];
    logic   [31:0]              c_ptgt[NC];
    logic                       c_br  [NC];
    logic   [ADDR_IDX-1:0]      c_slot[NC];     // slot index within its packet
    logic                       c_inh [NC];     // candidate is in the head packet (else head+1)

    always_comb begin
        for (int s = 0; s < IF_WIDTH; s++) begin
            // head candidates (indices 0..IF_WIDTH-1)
            c_inh [s] = 1'b1;
            c_slot[s] = (ADDR_IDX)'(s);
            c_v   [s] = have_h && (unsigned'(s) >= rd_slot) && head.valid[s];
            c_inst[s] = head.inst[s];
            c_pc  [s] = head.pc[s];
            c_ghr [s] = head.ghr;
            c_pt  [s] = head.predict_taken[s];
            c_ptgt[s] = head.predict_target[s];
            c_br  [s] = is_branch(head.inst[s]);
            // head+1 candidates (indices IF_WIDTH..2*IF_WIDTH-1)
            c_inh [IF_WIDTH+s] = 1'b0;
            c_slot[IF_WIDTH+s] = (ADDR_IDX)'(s);
            c_v   [IF_WIDTH+s] = have_h1 && head1.valid[s];
            c_inst[IF_WIDTH+s] = head1.inst[s];
            c_pc  [IF_WIDTH+s] = head1.pc[s];
            c_ghr [IF_WIDTH+s] = head1.ghr;
            c_pt  [IF_WIDTH+s] = head1.predict_taken[s];
            c_ptgt[IF_WIDTH+s] = head1.predict_target[s];
            c_br  [IF_WIDTH+s] = is_branch(head1.inst[s]);
        end
    end

    // ---- compact the valid candidates into an ordered stream ----
    logic   [31:0]              s_inst[IF_WIDTH];
    logic   [31:0]              s_pc  [IF_WIDTH];
    logic   [GHR_LEN-1:0]       s_ghr [IF_WIDTH];
    logic                       s_pt  [IF_WIDTH];
    logic   [31:0]              s_ptgt[IF_WIDTH];
    logic                       s_br  [IF_WIDTH];
    logic   [$clog2(NC)-1:0]    s_src [IF_WIDTH];   // which candidate filled this stream slot
    logic   [IF_WIDTH:0]        n_avail;            // how many valid instrs available (0..IF_WIDTH)

    always_comb begin
        automatic int k = 0;
        for (int i = 0; i < IF_WIDTH; i++) begin
            s_inst[i] = 'x; s_pc[i] = 'x; s_ghr[i] = 'x; s_pt[i] = 1'b0;
            s_ptgt[i] = 'x; s_br[i] = 1'b0; s_src[i] = '0;
        end
        for (int j = 0; j < NC; j++) begin
            if (c_v[j] && (k < IF_WIDTH)) begin
                s_inst[k] = c_inst[j];
                s_pc  [k] = c_pc[j];
                s_ghr [k] = c_ghr[j];
                s_pt  [k] = c_pt[j];
                s_ptgt[k] = c_ptgt[j];
                s_br  [k] = c_br[j];
                s_src [k] = ($clog2(NC))'(j);
                k++;
            end
        end
        n_avail = (IF_WIDTH+1)'(k);
    end

    // ---- build the output bundle: stop after a branch so it is the youngest ----
    logic   [IF_WIDTH-1:0]      bundle_valid;
    logic   [$clog2(IF_WIDTH+1)-1:0] bundle_count;
    always_comb begin
        bundle_valid = '0;
        for (int i = 0; i < IF_WIDTH; i++) begin
            // slot i is valid if available AND no earlier slot in the bundle was a branch
            if (unsigned'(i) < n_avail) begin
                if (i == 0)                 bundle_valid[i] = 1'b1;
                else if (!s_br[i-1] && bundle_valid[i-1]) bundle_valid[i] = 1'b1;
            end
        end
        bundle_count = '0;
        for (int i = 0; i < IF_WIDTH; i++)
            if (bundle_valid[i]) bundle_count = ($clog2(IF_WIDTH+1))'(bundle_count + 1);
    end

    // ---- drive the output interface ----
    assign out.valid = have_h && (n_avail != '0);
    always_comb begin
        out.packet = '0;
        for (int i = 0; i < IF_WIDTH; i++) begin
            out.packet.valid[i]          = bundle_valid[i];
            out.packet.inst[i]           = s_inst[i];
            out.packet.pc[i]             = s_pc[i];
            out.packet.ghr[i]            = s_ghr[i];
            out.packet.predict_taken[i]  = s_pt[i];
            out.packet.predict_target[i] = s_ptgt[i];
        end
    end

    // ---- advance the read pointer / slot by bundle_count instructions ----
    logic                   deq_fire;
    assign deq_fire = out.valid && out.ready;

    logic   [$clog2(NC)-1:0]    last_src;       // candidate index of the last consumed instr
    assign last_src = s_src[bundle_count - 1'b1];

    logic   [ADDR_IDX:0]    nxt_rd_ptr;
    logic   [ADDR_IDX-1:0]  nxt_rd_slot;
    always_comb begin
        nxt_rd_ptr  = rd_ptr;
        nxt_rd_slot = rd_slot;
        if (deq_fire) begin
            if (c_inh[last_src]) begin
                // last consumed instr was in the head packet
                if (head.valid[1] && (c_slot[last_src] == '0)) begin
                    // consumed head slot0, head slot1 still valid -> stay, advance slot
                    nxt_rd_ptr  = rd_ptr;
                    nxt_rd_slot = (ADDR_IDX)'(1);
                end else begin
                    // head exhausted (consumed its last valid slot) -> next packet
                    nxt_rd_ptr  = (ADDR_IDX+1)'(rd_ptr + 1);
                    nxt_rd_slot = '0;
                end
            end else begin
                // last consumed instr was in head+1: head fully consumed too
                if (head1.valid[1] && (c_slot[last_src] == '0)) begin
                    // consumed head+1 slot0, its slot1 still valid -> head becomes head+1
                    nxt_rd_ptr  = (ADDR_IDX+1)'(rd_ptr + 1);
                    nxt_rd_slot = (ADDR_IDX)'(1);
                end else begin
                    nxt_rd_ptr  = (ADDR_IDX+1)'(rd_ptr + 2);
                    nxt_rd_slot = '0;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr  <= '0;
            rd_ptr  <= '0;
            rd_slot <= '0;
        end else begin
            if (enq_en && ~full) begin
                fifo[wr_ptr_actual] <= enq_data;
                wr_ptr <= (ADDR_IDX+1)'(wr_ptr + 1);
            end
            rd_ptr  <= nxt_rd_ptr;
            rd_slot <= nxt_rd_slot;
        end
    end

    //////////////////////////
    // Performance Counters //
    //////////////////////////

    logic   [ADDR_IDX-1:0]      perf_n_elem;
    always_ff @(posedge clk) begin
        if (rst) perf_n_elem <= '0;
        else     perf_n_elem <= (ADDR_IDX)'(n_entries);
    end

endmodule
