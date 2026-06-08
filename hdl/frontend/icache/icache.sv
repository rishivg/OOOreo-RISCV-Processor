module icache
import icache_types::*, cpu_params::*; #(
            parameter       IF_WIDTH    = 2,
            parameter       OFFSET_IDX  = I_OFFSET_IDX,
            parameter       SET_IDX     = I_SET_IDX,
            parameter       TAG_IDX     = I_TAG_IDX,
            parameter       NUM_WAYS    = I_NUM_WAYS
)
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]                  ufp_addr,
    input   logic                           ufp_read,
    output  logic   [IF_WIDTH-1:0]  [31:0]  ufp_rdata,
    output  logic                           ufp_resp,
    input   logic                           kill, // kill all pending misses

    // memory side signals, dfp -> downward facing port
    cacheline_itf.master    dfp
);
            localparam      PLRU_BITS   = NUM_WAYS - 1;
            localparam      WAY_BITS    = $clog2(NUM_WAYS);

    logic                   data_csb0[NUM_WAYS];
    logic                   tag_csb0[NUM_WAYS];
    logic                   plru_csb0;
    logic                   plru_csb1;

    logic                   data_web0[NUM_WAYS];
    logic                   tag_web0[NUM_WAYS];
    logic                   plru_web1;

    logic   [31:0]          data_wmask0;
    logic   [255:0]         data_din0;
    // Tag-array word is {epoch, tag}. Line-validity rode in a separate valid_array
    // (flops + a 64:1 read mux) which synthesis could not fold into the SRAM macro
    // -> it was THE I-cache Fmax wall. Validity now lives in the tag SRAM's MSB as
    // a GENERATION (epoch) bit: a line is valid iff line_epoch == global_epoch.
    // Reset just flips global_epoch (one flop), invalidating every line at once --
    // no multi-cycle sweep and no fetch hold-off (which had desynced fetch vs the
    // free-running front-end PC/predictor and thrashed the cache).
    logic   [TAG_IDX:0]     tag_din0;
    logic                   global_epoch;

    logic   [255:0]         data_dout0[NUM_WAYS];
    logic   [TAG_IDX:0]     tag_dout0[NUM_WAYS];
    logic                   valid_dout0[NUM_WAYS];
    logic   [PLRU_BITS-1:0] plru_dout0;
    logic   [PLRU_BITS-1:0] plru_din1;

    logic   [OFFSET_IDX-1:0] ufp_offset;
    logic   [SET_IDX-1:0]   ufp_set;
    logic   [TAG_IDX-1:0]   ufp_tag;

    icache_stage_reg_t       stage_reg;

    logic                   hit;
    logic   [WAY_BITS-1:0]  hit_way;
    logic   [WAY_BITS-1:0]  replace_way;

    logic                   stall;
    logic                   allocate_done;

    // Global generation counter: flip on reset to invalidate all lines at once.
    always_ff @(posedge clk) begin
        if (rst) global_epoch <= ~global_epoch;
    end

    assign ufp_offset = ufp_addr[OFFSET_IDX-1:0];
    assign ufp_set = ufp_addr[SET_IDX+OFFSET_IDX-1:OFFSET_IDX];
    assign ufp_tag = ufp_addr[TAG_IDX+SET_IDX+OFFSET_IDX-1:SET_IDX+OFFSET_IDX];

    generate for (genvar i = 0; i < NUM_WAYS; i++) begin : arrays
        // Per-way copy of the SRAM address. One net feeding all 8 macros (4 ways x
        // data+tag) was the high-fanout source behind the worst-path repeater tree;
        // splitting it into a driver per way (each feeding just its data+tag, which
        // sit adjacent after clustering) shrinks the fanout 4x. The keep attribute
        // stops CSE from merging the copies. Logically == sram_operating_set, the
        // addressed line is bit-identical.
        (* keep *) logic [SET_IDX-1:0] set_w;
        assign set_w = (~stall || kill) ? ufp_set : stage_reg.set_i;
        icache_data_array #(
            .ADDR_WIDTH (SET_IDX)
        ) data_array (
            .clk0       (clk),
            .csb0       (data_csb0[i]),
            .web0       (data_web0[i]),
            .wmask0     (data_wmask0),
            .addr0      (set_w),
            .din0       (data_din0),
            .dout0      (data_dout0[i])
        );
        icache_tag_array #(
            .ADDR_WIDTH (SET_IDX)
        ) tag_array (
            .clk0       (clk),
            .csb0       (tag_csb0[i]),
            .web0       (tag_web0[i]),
            .addr0      (set_w),
            .din0       (tag_din0),
            .dout0      (tag_dout0[i])
        );
        // A line is valid iff its stored epoch matches the current generation.
        assign valid_dout0[i] = (tag_dout0[i][TAG_IDX] == global_epoch);
    end endgenerate

    lru_array #(
        .S_INDEX (SET_IDX),
        .WIDTH   (PLRU_BITS)
    ) lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (plru_csb0),
        .addr0      (ufp_set),
        .din0       ('x),
        .dout0      (plru_dout0),
        .csb1       (plru_csb1),
        .web1       (plru_web1),
        .addr1      (stage_reg.set_i),
        .din1       (plru_din1)
    );


    // ========================================================================
    // FETCH stage
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            stage_reg.read <= '0;
        end else if (~stall || kill) begin
            stage_reg.read <= ufp_read;
            stage_reg.offset <= ufp_offset;
            stage_reg.set_i <= ufp_set;
            stage_reg.tag <= ufp_tag;
        end
    end

    // Chip-Select signals
    always_comb begin
        for (int i = 0; i < NUM_WAYS; i++) begin
            data_csb0[i] = 1'b1;
            tag_csb0[i] = 1'b1;
        end

        if (~stall || kill) begin
            for (int i = 0; i < NUM_WAYS; i++) begin
                data_csb0[i] = 1'b0;
                tag_csb0[i] = 1'b0;
            end
        end

        if (allocate_done) begin
            data_csb0[replace_way] = 1'b0;
            tag_csb0[replace_way] = 1'b0;
        end
    end

    assign plru_csb0 = stall;
    assign plru_csb1 = ~ufp_resp;

    // Write-Enable signals
    always_comb begin
        for (int i = 0; i < NUM_WAYS; i++) begin
            data_web0[i] = 1'b1;
            tag_web0[i] = 1'b1;
        end

        if (allocate_done) begin
            data_web0[replace_way] = 1'b0;
            tag_web0[replace_way] = 1'b0;
        end
    end

    assign plru_web1 = plru_csb1;

    // SRAM wmask and din
    always_comb begin
        if (allocate_done) begin
            data_wmask0 = '1;
            data_din0 = dfp.rdata;
        end else begin
            // Leave don't care for EDA optimization
            data_wmask0 = 'x;
            data_din0 = 'x;
        end
    end

    // Refill stamps the line with the current generation so it reads back valid.
    assign tag_din0 = {global_epoch, stage_reg.tag};

    // ========================================================================
    // PROCESS stage
    // ========================================================================

    assign dfp.wdata = 'x;

    generate for (genvar i = 0; i < IF_WIDTH; i++) begin : ufp_rdata_assign
        assign ufp_rdata[i] = data_dout0[hit_way][(8 * stage_reg.offset + unsigned'(32 * i)) +: 32];
    end endgenerate

    assign ufp_resp = stage_reg.read && ~stall;

    icache_ctrl #(
        .TAG_IDX    (TAG_IDX),
        .NUM_WAYS   (NUM_WAYS),
        .WAY_BITS   (WAY_BITS),
        .OFFSET_IDX (OFFSET_IDX),
        .SET_IDX    (SET_IDX)
    ) icache_ctrl_i (
        .clk            (clk),
        .rst            (rst),

        .kill           (kill),
        .read           (stage_reg.read),
        .tag            (stage_reg.tag),
        .set            (stage_reg.set_i),
        .tag_arr_out    (tag_dout0),
        .valid_arr_out  (valid_dout0),

        .stall          (stall),
        .allocate_done  (allocate_done),
        .hit_way        (hit_way),

        .dfp_addr       (dfp.addr),
        .dfp_read       (dfp.read),
        .dfp_write      (dfp.write),
        .dfp_ready      (dfp.ready),
        .dfp_raddr      (dfp.raddr),
        .dfp_rvalid     (dfp.rvalid)
    );

    plru_update #(
        .NUM_WAYS    (NUM_WAYS),
        .PLRU_BITS   (PLRU_BITS),
        .WAY_BITS    (WAY_BITS)
    ) plru_update_i (
        .current_plru   (plru_dout0),
        .next_plru      (plru_din1),
        .hit_way        (hit_way),
        .replace_way    (replace_way)
    );


endmodule
