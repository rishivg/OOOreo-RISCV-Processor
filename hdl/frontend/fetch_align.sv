// C-extension fetch realignment (combinational extraction core).
//
// Given up to 2*IF_WIDTH 16-bit parcels starting at pc (halfword granularity),
// walk them in program order extracting up to IF_WIDTH instructions: each parcel
// whose low two bits are 2'b11 begins a 32-bit instruction (this + next parcel),
// otherwise a 16-bit compressed one. Each extracted instruction is expanded to
// 32 bits by the decompressor and tagged with its own PC (pc + 2*parcel_index).
//
// n_valid tells how many of the parcels are present (the rest belong to the next
// fetch block and are not yet available). A slot is extractable (inst_valid) only
// when all parcels it needs are within n_valid AND every earlier slot was valid
// (in-order). If a 32-bit instruction's low parcel is available but its high
// parcel is past n_valid, that is a block-boundary "span": the surrounding fetch
// must carry span_lo (its low parcel, at span_pc) and re-supply it next cycle
// prepended to the next block. consumed = parcels eaten by the valid slots;
// next_pc = pc + 2*consumed (the sequential fetch target after this bundle).
module fetch_align
import cpu_params::*;
(
    input   logic   [31:0]                      pc,
    input   logic   [2*IF_WIDTH-1:0]  [15:0]    parcels,    // at pc, pc+2, pc+4, ...
    input   logic   [PARCEL_CNT_W-1:0]          n_valid,    // # of valid parcels (0..2*IF_WIDTH)
    output  logic   [IF_WIDTH-1:0]    [31:0]    inst,       // decompressed 32-bit
    output  logic   [IF_WIDTH-1:0]    [31:0]    inst_raw,   // original encoding (RVC: {16'b0,parcel}) for RVFI
    output  logic   [IF_WIDTH-1:0]    [31:0]    inst_pc,    // per-instruction PC
    output  logic   [IF_WIDTH-1:0]             inst_comp,   // was compressed (16-bit)
    output  logic   [IF_WIDTH-1:0]             inst_valid,  // slot fully extractable
    output  logic   [IF_WIDTH-1:0]    [31:0]    seq_next,   // per-slot fall-through PC (pc+stride)
    output  logic   [PARCEL_CNT_W-1:0]          consumed,   // parcels eaten by valid slots
    output  logic                               span,       // trailing 32-bit op missing its high parcel
    output  logic   [15:0]                      span_lo,    // low parcel of the spanning op
    output  logic   [31:0]                      span_pc,    // PC of the spanning op
    output  logic   [31:0]                      next_pc     // sequential PC after this bundle
);
    localparam int PMAX = 2*IF_WIDTH;               // total parcel positions
    localparam int PIDX = $clog2(PMAX + 1);

    logic [PIDX-1:0]    start_idx [IF_WIDTH+1];      // parcel index where each slot starts
    logic [15:0]        lo_parcel [IF_WIDTH];
    logic [31:0]        raw       [IF_WIDTH];

    always_comb begin
        automatic logic still_valid = 1'b1;
        start_idx[0] = '0;
        for (int s = 0; s < IF_WIDTH; s++) begin
            automatic logic [PIDX-1:0] idx = start_idx[s];
            automatic logic [PIDX-1:0] hi  = (PIDX)'(idx + 1'b1);
            automatic logic [15:0]     p   = parcels[idx];
            automatic logic            comp_s;
            automatic logic            lo_ok;
            automatic logic            hi_ok;
            automatic logic            this_valid;

            comp_s        = (p[1:0] != 2'b11);
            lo_ok         = (unsigned'(idx) < unsigned'(n_valid));
            hi_ok         = (unsigned'(hi)  < unsigned'(n_valid));
            this_valid    = still_valid && lo_ok && (comp_s || hi_ok);

            lo_parcel[s]  = p;
            inst_comp[s]  = comp_s;
            inst_valid[s] = this_valid;
            raw[s]        = comp_s ? {16'b0, p} : {parcels[hi], p};
            inst_pc[s]    = pc + 32'(idx) * 32'd2;
            seq_next[s]   = inst_pc[s] + (comp_s ? 32'd2 : 32'd4);

            if (this_valid) begin
                start_idx[s+1] = (PIDX)'(idx + (comp_s ? (PIDX)'(1) : (PIDX)'(2)));
            end else begin
                start_idx[s+1] = idx;
                still_valid    = 1'b0;
            end
        end
    end

    assign consumed = (PARCEL_CNT_W)'(start_idx[IF_WIDTH]);
    assign next_pc  = pc + 32'(consumed) * 32'd2;

    // Span: the bundle was cut short and the next parcel begins a 32-bit op whose
    // high half lies past the valid parcels (in the next block). Carry it.
    logic [PIDX-1:0] b_idx;
    logic [15:0]     boundary_parcel;
    assign b_idx = (unsigned'(consumed) < unsigned'(PMAX)) ? consumed[PIDX-1:0] : '0;
    assign boundary_parcel = parcels[b_idx];
    assign span    = (~inst_valid[IF_WIDTH-1])
                  && (unsigned'(consumed) < unsigned'(n_valid))
                  && (boundary_parcel[1:0] == 2'b11)
                  && (unsigned'(consumed + (PARCEL_CNT_W)'(1)) >= unsigned'(n_valid));
    assign span_lo = boundary_parcel;
    assign span_pc = pc + 32'(consumed) * 32'd2;

    genvar gi;
    generate for (gi = 0; gi < IF_WIDTH; gi++) begin : dec
        logic [31:0] expanded;
        logic        is_c;
        decompressor d_i (.inst_in(raw[gi]), .inst_out(expanded), .is_compressed(is_c));
        assign inst[gi]     = expanded;
        assign inst_raw[gi] = raw[gi];   // original (un-decompressed) encoding for RVFI
    end endgenerate

endmodule
