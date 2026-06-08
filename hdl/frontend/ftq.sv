// Fetch Target Queue: the decoupling buffer between the branch-prediction unit
// (BPU, the producer) and the instruction-fetch unit (IFU, the consumer) of a
// decoupled front-end. The BPU enqueues one fetch-block descriptor per cycle as
// fast as it can predict; the IFU dequeues the head to drive the I-cache. Because
// the IFU reads its fetch address from the FTQ head rather than from a mux gated
// by the I-cache's own stall, the predictor can run ahead while the I-cache
// stalls on a miss, and fetch-address generation leaves the I-cache critical path.
//
// Standalone FIFO for now (not yet wired); see frontend_top integration.
module ftq
import cpu_params::*, fetch_types::*;
#(
            parameter   DEPTH = 8
)
(
    input   logic               clk,
    input   logic               rst,
    input   logic               flush,      // backend redirect: discard all queued targets

    // producer side (BPU)
    input   logic               enq_valid,
    output  logic               enq_ready,  // ~full
    input   ftq_entry_t         enq_entry,

    // consumer side (IFU)
    output  logic               deq_valid,  // ~empty
    input   logic               deq_ready,
    output  ftq_entry_t         deq_entry,  // head: the fetch target to fetch now

    output  logic               empty,
    output  logic               full
);

    localparam  unsigned    ADDR_IDX = $clog2(DEPTH);

    ftq_entry_t                 mem [DEPTH];

    // pointers carry an extra wrap bit so full vs empty is unambiguous
    logic   [ADDR_IDX:0]        wr_ptr;
    logic   [ADDR_IDX:0]        rd_ptr;
    logic   [ADDR_IDX-1:0]      wr_ptr_actual;
    logic   [ADDR_IDX-1:0]      rd_ptr_actual;
    logic                       wr_ptr_flag;
    logic                       rd_ptr_flag;

    assign {wr_ptr_flag, wr_ptr_actual} = wr_ptr;
    assign {rd_ptr_flag, rd_ptr_actual} = rd_ptr;

    assign empty = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag == rd_ptr_flag);
    assign full  = (wr_ptr_actual == rd_ptr_actual) && (wr_ptr_flag != rd_ptr_flag);

    assign enq_ready = ~full;
    assign deq_valid = ~empty;
    assign deq_entry = mem[rd_ptr_actual];

    logic   enq_fire;
    logic   deq_fire;
    assign enq_fire = enq_valid && enq_ready;
    assign deq_fire = deq_valid && deq_ready;

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (enq_fire) begin
                mem[wr_ptr_actual] <= enq_entry;
                wr_ptr <= (ADDR_IDX+1)'(wr_ptr + 1'b1);
            end
            if (deq_fire) begin
                rd_ptr <= (ADDR_IDX+1)'(rd_ptr + 1'b1);
            end
        end
    end

endmodule : ftq
