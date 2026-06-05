module fu_mul
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // Prev stage handshake
    input   logic               prv_valid,
    output  logic               prv_ready,

    // Next stage handshake
    output  logic               nxt_valid,
    input   logic               nxt_ready,

    input   intm_rs_reg_t       iss_in,

    output  fu_cdb_reg_t        cdb_out
);

    //---------------------------------------------------------------------------------
    // Declare IP port signals:
    //---------------------------------------------------------------------------------

    localparam                  DATA_WIDTH = 32;
    localparam                  A_WIDTH = DATA_WIDTH+1; // msb for sign extension
    localparam                  B_WIDTH = DATA_WIDTH+1; // msb for sign extension

    logic                       mul_start;
    logic [A_WIDTH-1:0]         a; // Multiplier / Dividend
    logic [B_WIDTH-1:0]         b; // Multiplicand / Divisor

    logic [A_WIDTH+B_WIDTH-1:0] product;

    logic                       complete;
    logic [DATA_WIDTH-1:0]      outcome;
    intm_rs_reg_t               intm_rs_reg;
    logic [DATA_WIDTH:0]        au, bu, as, bs; // msb for sign extension

    //---------------------------------------------------------------------------------
    // Wrap up as Pipelined Register: From Prev
    //---------------------------------------------------------------------------------

    logic                       reg_valid;
    logic                       prv_reg_valid;
    logic                       reg_start;
    logic                       mul_ready;
    logic                       prv_mul_ready;

    // Pipeline reg to interface with the previous stage
    skid_buffer #(
        .DATA_T (intm_rs_reg_t)
    ) cdb_reg (
        .clk        (clk),
        .rst        (rst),
        .prv_valid  (prv_valid),
        .prv_ready  (prv_ready),
        .nxt_valid  (reg_valid),
        .nxt_ready  (mul_ready),
        .prv_data   (iss_in),
        .nxt_data   (intm_rs_reg)
    );

    // start signal generation
    always_ff @( posedge clk ) begin
        prv_reg_valid <= reg_valid;
    end

    always_ff @( posedge clk ) begin
        prv_mul_ready <= mul_ready;
    end

    //---------------------------------------------------------------------------------
    // IP Control:
    //---------------------------------------------------------------------------------

    assign  mul_start = reg_valid && (~prv_reg_valid) || reg_valid && prv_mul_ready;
    assign  mul_ready = nxt_valid && nxt_ready;

    // mult: multiplier and multiplicand are interchanged
    assign  au = {1'b0, intm_rs_reg.rs1_value};
    assign  bu = {1'b0, intm_rs_reg.rs2_value}; 
    assign  as = {intm_rs_reg.rs1_value[DATA_WIDTH-1], intm_rs_reg.rs1_value};
    assign  bs = {intm_rs_reg.rs2_value[DATA_WIDTH-1], intm_rs_reg.rs2_value};

    always_comb begin
        a = '0;
        b = '0;
        outcome = 'x;
        unique case (intm_rs_reg.fu_opcode)
            MD_MUL: begin
                a = as;
                b = bs;
                outcome = product[DATA_WIDTH-1:0];
            end
            MD_MULH: begin      // signed x signed
                a = as;
                b = bs;
                outcome = product[2*DATA_WIDTH-1:DATA_WIDTH];
            end
            MD_MULHSU: begin    // signed x unsigned
                a = as;
                b = bu;
                outcome = product[2*DATA_WIDTH-1:DATA_WIDTH];
            end
            MD_MULHU: begin     // unsigned x unsigned
                a = au;
                b = bu;
                outcome = product[2*DATA_WIDTH-1:DATA_WIDTH];
            end
            default: ;
        endcase
    end

    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------

    // Parallel pipelined multiplier (replaces the 3-cycle sequential DesignWare
    // unit). A single signed 33x33 product is computed combinationally and
    // pushed through MUL_LATENCY register stages, so latency is a direct design
    // knob and throughput is one per cycle. Maps to FPGA DSP blocks; a/b are
    // sign-extended so one signed multiply covers MUL/MULH/MULHSU/MULHU.
    localparam  int unsigned    MUL_LATENCY = 2;

    logic signed [A_WIDTH-1:0]          a_s, b_s;
    logic signed [A_WIDTH+B_WIDTH-1:0]  product_s;  // 66-bit context -> full signed product
    logic [A_WIDTH+B_WIDTH-1:0]  product_comb;
    logic [A_WIDTH+B_WIDTH-1:0]  product_pipe [MUL_LATENCY];
    logic                        valid_pipe   [MUL_LATENCY];

    assign a_s          = signed'(a);
    assign b_s          = signed'(b);
    assign product_s    = a_s * b_s;
    assign product_comb = product_s;

    // Output backpressure: the CDB arbiter gives div priority (cdb_mul_ready =
    // ~fu_div_valid in intm_rs), so a completed multiply can be held off when a
    // divide broadcasts the same cycle. The datapath pipeline must FREEZE while
    // its tail result is blocked -- otherwise it shifts the completed result out
    // the next cycle and the result (and the instruction's CDB broadcast) is lost
    // forever, hanging the ROB head. Only exercised by mul/div CDB contention.
    logic output_stall;
    assign output_stall = nxt_valid && ~nxt_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < MUL_LATENCY; i++) valid_pipe[i] <= 1'b0;
        end else if (~output_stall) begin
            product_pipe[0] <= product_comb;
            valid_pipe[0]   <= mul_start;
            for (int i = 1; i < MUL_LATENCY; i++) begin
                product_pipe[i] <= product_pipe[i-1];
                valid_pipe[i]   <= valid_pipe[i-1];
            end
        end
    end

    assign product  = product_pipe[MUL_LATENCY-1];
    assign complete = valid_pipe[MUL_LATENCY-1];

    assign nxt_valid                = reg_valid && complete && ~mul_start;
    assign cdb_out.rob_id           = intm_rs_reg.rob_id;
    assign cdb_out.rd_arch          = intm_rs_reg.rd_arch;
    assign cdb_out.rd_phy           = intm_rs_reg.rd_phy;
    assign cdb_out.rd_value         = outcome;
    assign cdb_out.rs1_value_dbg    = intm_rs_reg.rs1_value;
    assign cdb_out.rs2_value_dbg    = intm_rs_reg.rs2_value;

endmodule
