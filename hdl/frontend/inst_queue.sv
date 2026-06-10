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
    logic   [31:0]              c_raw [NC];
    logic                       c_comp[NC];
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
            c_raw [s] = head.inst_raw[s];
            c_comp[s] = head.is_compressed[s];
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
            c_raw [IF_WIDTH+s] = head1.inst_raw[s];
            c_comp[IF_WIDTH+s] = head1.is_compressed[s];
            c_pc  [IF_WIDTH+s] = head1.pc[s];
            c_ghr [IF_WIDTH+s] = head1.ghr;
            c_pt  [IF_WIDTH+s] = head1.predict_taken[s];
            c_ptgt[IF_WIDTH+s] = head1.predict_target[s];
            c_br  [IF_WIDTH+s] = is_branch(head1.inst[s]);
        end
    end

    // ---- compact the valid candidates into an ordered stream (up to ID_WIDTH) ----
    // The back-end consumes ID_WIDTH instrs/cycle, while a fetch packet is IF_WIDTH
    // wide (IF_WIDTH >= ID_WIDTH). We stream the first <=ID_WIDTH valid candidates
    // (head slots from rd_slot, then head+1 slots); a packet wider than ID_WIDTH is
    // drained over multiple cycles via rd_slot. OW == IF_WIDTH degenerates to the
    // original single-cycle-per-packet behaviour.
    localparam int OW = ID_WIDTH;
    logic   [31:0]              s_inst[OW];
    logic   [31:0]              s_raw [OW];
    logic                       s_comp[OW];
    logic   [31:0]              s_pc  [OW];
    logic   [GHR_LEN-1:0]       s_ghr [OW];
    logic                       s_pt  [OW];
    logic   [31:0]              s_ptgt[OW];
    logic                       s_br  [OW];
    logic   [$clog2(NC)-1:0]    s_src [OW];         // which candidate filled this stream slot
    logic   [$clog2(OW+1)-1:0]  n_avail;            // how many valid instrs available (0..OW)

    always_comb begin
        automatic int k = 0;
        for (int i = 0; i < OW; i++) begin
            s_inst[i] = 'x; s_raw[i] = 'x; s_comp[i] = 1'b0; s_pc[i] = 'x; s_ghr[i] = 'x; s_pt[i] = 1'b0;
            s_ptgt[i] = 'x; s_br[i] = 1'b0; s_src[i] = '0;
        end
        for (int j = 0; j < NC; j++) begin
            if (c_v[j] && (k < OW)) begin
                s_inst[k] = c_inst[j];
                s_raw [k] = c_raw[j];
                s_comp[k] = c_comp[j];
                s_pc  [k] = c_pc[j];
                s_ghr [k] = c_ghr[j];
                s_pt  [k] = c_pt[j];
                s_ptgt[k] = c_ptgt[j];
                s_br  [k] = c_br[j];
                s_src [k] = ($clog2(NC))'(j);
                k++;
            end
        end
        n_avail = ($clog2(OW+1))'(k);
    end

    // ---- build the output bundle: at most ONE branch per bundle ----
    // A branch no longer has to be the youngest in the bundle: a predicted-not-
    // taken branch can co-dispatch its sequential successor (predicted-taken
    // branches already had their successors invalidated at fetch, so [br,nonbr]
    // only forms on the predicted path). Recovery is slot-granular (rob.sv) so a
    // younger same-row instr is squashed on a mispredict. We still cap at one
    // branch per bundle -- the control buffer dequeues one branch per row.
    logic   [OW-1:0]            bundle_valid;
    logic   [$clog2(OW+1)-1:0]  bundle_count;
    always_comb begin
        automatic logic br_seen = 1'b0;
        bundle_valid = '0;
        for (int i = 0; i < OW; i++) begin
            if (unsigned'(i) < n_avail) begin
                if (i == 0) begin
                    bundle_valid[i] = 1'b1;
                end else if (bundle_valid[i-1] && !(s_br[i] && br_seen)) begin
                    bundle_valid[i] = 1'b1;           // include unless it'd be a 2nd branch
                end
                if (bundle_valid[i] && s_br[i]) br_seen = 1'b1;
            end
        end
        bundle_count = '0;
        for (int i = 0; i < OW; i++)
            if (bundle_valid[i]) bundle_count = ($clog2(OW+1))'(bundle_count + 1);
    end

    // ---- drive the output interface ----
    // A pure C-extension span-fetch cycle can enqueue a packet with no valid
    // instructions (its single 32-bit instruction straddled the block boundary
    // and was carried). Such an empty head packet must be skipped, not streamed,
    // or it would block the queue forever (deq_fire never fires on it).
    logic                   head_empty;
    assign head_empty = have_h && (head.valid == '0);

    assign out.valid = have_h && ~head_empty && (n_avail != '0);
    always_comb begin
        out.packet = '0;
        for (int i = 0; i < OW; i++) begin
            out.packet.valid[i]          = bundle_valid[i];
            out.packet.inst[i]           = s_inst[i];
            out.packet.inst_raw[i]       = s_raw[i];
            out.packet.is_compressed[i]  = s_comp[i];
            out.packet.pc[i]             = s_pc[i];
            out.packet.ghr[i]            = s_ghr[i];
            out.packet.predict_taken[i]  = s_pt[i];
            out.packet.predict_target[i] = s_ptgt[i];
        end
    end

    // ---- advance the read pointer / slot by bundle_count instructions ----
    // Generalized for IF_WIDTH > ID_WIDTH: a fetch packet has IF_WIDTH prefix-valid
    // slots, drained ID_WIDTH per cycle. last_src is the candidate index (0..NC-1)
    // of the last consumed instr; for head candidates the index equals the absolute
    // slot, for head+1 candidates the slot is index-IF_WIDTH. We move to the next
    // valid slot after it, crossing into head+1 (and on to the packet after) only
    // when the current head packet is fully drained.
    logic                   deq_fire;
    assign deq_fire = out.valid && out.ready;

    logic   [$clog2(NC)-1:0]    last_src;       // candidate index of the last consumed instr
    assign last_src = s_src[bundle_count - 1'b1];

    // Does the head packet still have a valid slot after the last consumed head
    // slot? (guarded index so we never read head.valid out of range.)
    logic                       head_more;
    logic   [ADDR_IDX-1:0]      head_nx_slot;
    always_comb begin
        head_more    = 1'b0;
        head_nx_slot = '0;
        if (unsigned'(last_src) + 1 < IF_WIDTH) begin
            head_nx_slot = (ADDR_IDX)'(unsigned'(last_src) + 1);
            head_more    = head.valid[head_nx_slot];
        end
    end

    // If the last consumed instr was in head+1, does head+1 have a valid slot after?
    logic                       h1_more;
    logic   [ADDR_IDX-1:0]      h1_cur_slot;    // slot of last consumed within head+1
    logic   [ADDR_IDX-1:0]      h1_nx_slot;
    always_comb begin
        h1_more     = 1'b0;
        h1_cur_slot = (ADDR_IDX)'(unsigned'(last_src) - IF_WIDTH);
        h1_nx_slot  = '0;
        if (unsigned'(h1_cur_slot) + 1 < IF_WIDTH) begin
            h1_nx_slot = (ADDR_IDX)'(unsigned'(h1_cur_slot) + 1);
            h1_more    = head1.valid[h1_nx_slot];
        end
    end

    logic   [ADDR_IDX:0]    nxt_rd_ptr;
    logic   [ADDR_IDX-1:0]  nxt_rd_slot;
    always_comb begin
        nxt_rd_ptr  = rd_ptr;
        nxt_rd_slot = rd_slot;
        if (head_empty) begin
            // discard the empty span-fetch packet
            nxt_rd_ptr  = (ADDR_IDX+1)'(rd_ptr + 1);
            nxt_rd_slot = '0;
        end else if (deq_fire) begin
            if (c_inh[last_src]) begin
                // last consumed instr was in the head packet
                if (head_more) begin
                    // head still has a valid slot after -> stay, advance slot
                    nxt_rd_ptr  = rd_ptr;
                    nxt_rd_slot = head_nx_slot;
                end else begin
                    // head exhausted -> next packet, slot 0
                    nxt_rd_ptr  = (ADDR_IDX+1)'(rd_ptr + 1);
                    nxt_rd_slot = '0;
                end
            end else begin
                // last consumed instr was in head+1: head fully consumed -> head+1
                // becomes the new head (rd_ptr+1)
                if (h1_more) begin
                    nxt_rd_ptr  = (ADDR_IDX+1)'(rd_ptr + 1);
                    nxt_rd_slot = h1_nx_slot;
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
