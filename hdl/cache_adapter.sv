module cache_adapter (
    input   logic           clk,
    input   logic           rst,

    input   logic           bmem_ready,
    input   logic [31:0]    bmem_raddr,
    input   logic [63:0]    bmem_rdata,
    input   logic           bmem_rvalid,
    input   logic [255:0]   dfp_wdata,
    input   logic           dfp_write,
    input   logic [31:0]    bmem_addr,

    output  logic [255:0]   dfp_rdata,
    output  logic           dfp_resp,
    output  logic [63:0]    bmem_wdata,
    output  logic           bmem_write,
    input   logic           bmem_read,
    input   logic           bmem_flag
);
    logic [255:0] accumulator;
    logic [1:0] word_count;
    logic [2:0] write_count;
    logic [31:0] past_bmem_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            accumulator <= 256'd0;
            word_count  <= 2'd0;
            write_count <= 3'd0;
            dfp_rdata   <= 256'd0;
            dfp_resp    <= 1'b0;
            past_bmem_addr <= '0;
        end else begin
            past_bmem_addr <= bmem_addr;
            dfp_resp <= 1'b0;

            if (bmem_rvalid && bmem_ready) begin
                if (word_count == 2'd0 && ((bmem_raddr == bmem_addr) || (bmem_raddr == past_bmem_addr))) begin
                    accumulator[63:0] <= bmem_rdata;
                    word_count <= 2'd1;
                end else if (word_count == 2'd1) begin
                    accumulator[127:64] <= bmem_rdata;
                    word_count <= 2'd2;
                end else if (word_count == 2'd2) begin
                    accumulator[191:128] <= bmem_rdata;
                    word_count <= 2'd3;
                end else if (word_count == 2'd3) begin
                    dfp_rdata <= {bmem_rdata, accumulator[191:0]};
                    dfp_resp <= 1'b1;
                    word_count <= 2'd0;
                end
            end

            if (dfp_write && bmem_ready && !bmem_flag) begin
                if (write_count == 3'd3) begin
                    dfp_resp <= 1'b1;
                end
                if (bmem_write || (dfp_write && !bmem_read && !bmem_flag)) begin
                    write_count <= (write_count == 3'd4) ? 3'd0 : (write_count + 3'd1);
                end
            end else begin
                write_count <= 3'd0;
            end
        end
    end

    always_comb begin
        bmem_wdata = 64'h0;
        bmem_write = 1'b0;

        if (dfp_write && !bmem_read && !bmem_flag) begin
            bmem_write = (write_count != 3'd4);
            case (write_count)
                3'd0: bmem_wdata = dfp_wdata[63:0];
                3'd1: bmem_wdata = dfp_wdata[127:64];
                3'd2: bmem_wdata = dfp_wdata[191:128];
                3'd3: bmem_wdata = dfp_wdata[255:192];
                default: bmem_wdata = 64'h0;
            endcase
        end
    end
endmodule