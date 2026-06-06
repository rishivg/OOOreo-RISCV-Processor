// C-extension fetch realignment (combinational extraction core).
//
// Given 2*IF_WIDTH 16-bit parcels starting at pc (halfword granularity), walk
// them in program order extracting up to IF_WIDTH instructions: each parcel
// whose low two bits are 2'b11 begins a 32-bit instruction (this + next parcel),
// otherwise a 16-bit compressed one. Each extracted instruction is expanded to
// 32 bits by the decompressor and tagged with its own PC (pc + 2*parcel_index).
// next_pc is the PC immediately after the last extracted instruction (the
// sequential fetch target).
//
// This is the pure extraction logic; the surrounding fetch must supply the
// 2*IF_WIDTH parcels starting at pc (a 2-block / line-spanning read or a
// carried-parcel buffer) and align the predictor to the per-instruction PCs.
module fetch_align
import cpu_params::*;
(
    input   logic   [31:0]                      pc,
    input   logic   [2*IF_WIDTH-1:0]  [15:0]    parcels,    // at pc, pc+2, pc+4, ...
    output  logic   [IF_WIDTH-1:0]    [31:0]    inst,       // decompressed 32-bit
    output  logic   [IF_WIDTH-1:0]    [31:0]    inst_pc,    // per-instruction PC
    output  logic   [IF_WIDTH-1:0]             inst_comp,   // was compressed (16-bit)
    output  logic   [31:0]                      next_pc
);
    localparam int PIDX = $clog2(2*IF_WIDTH + 1);

    logic [PIDX-1:0]    start_idx [IF_WIDTH+1];   // parcel index where each slot starts
    logic               comp      [IF_WIDTH];
    logic [31:0]        raw       [IF_WIDTH];

    always_comb begin
        start_idx[0] = '0;
        for (int s = 0; s < IF_WIDTH; s++) begin
            automatic logic [15:0] p   = parcels[start_idx[s]];
            automatic logic [PIDX-1:0] hi = start_idx[s] + 1'b1;
            comp[s]        = (p[1:0] != 2'b11);
            raw[s]         = comp[s] ? {16'b0, p} : {parcels[hi], p};
            start_idx[s+1] = start_idx[s] + (comp[s] ? (PIDX)'(1) : (PIDX)'(2));
        end
    end

    genvar gi;
    generate for (gi = 0; gi < IF_WIDTH; gi++) begin : dec
        logic [31:0] expanded;
        logic        is_c;
        decompressor d_i (.inst_in(raw[gi]), .inst_out(expanded), .is_compressed(is_c));
        assign inst[gi]      = expanded;
        assign inst_comp[gi] = is_c;
        assign inst_pc[gi]   = pc + 32'(start_idx[gi]) * 32'd2;
    end endgenerate

    assign next_pc = pc + 32'(start_idx[IF_WIDTH]) * 32'd2;

endmodule
