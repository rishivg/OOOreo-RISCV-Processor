module prf
import cpu_params::*;
import prf_types::*;
import int_rs_types::*;
(
    input   logic               clk,

    rs_prf_itf.prf              from_rs[CDB_WIDTH],
    cdb_itf.prf                 cdb[CDB_WIDTH],
    input bypass_network_t      alu_bypass[NUM_FAST_BYPASS]
);
    // physical register file
    logic [31:0]    prf_data            [PRF_DEPTH-1:1];

    // local copy of cdb interface and rs_prf_interface
    cdb_prf_t       cdb_local           [CDB_WIDTH];
    rs_prf_itf_t    from_rs_local_in    [CDB_WIDTH];
    rs_prf_itf_t    from_rs_local_out   [CDB_WIDTH];

    generate 
        for (genvar i = 0; i < CDB_WIDTH; i++) begin 
            assign cdb_local[i].valid       = cdb[i].valid;
            assign cdb_local[i].rd_phy      = cdb[i].rd_phy;
            assign cdb_local[i].rd_value    = cdb[i].rd_value;

            assign from_rs_local_in[i].rs1_phy = from_rs[i].rs1_phy;
            assign from_rs_local_in[i].rs2_phy = from_rs[i].rs2_phy;
            assign from_rs_local_in[i].rs1_value = 'x; // silence Spyglass
            assign from_rs_local_in[i].rs2_value = 'x; // silence Spyglass
            assign from_rs_local_in[i].rs_bypass = from_rs[i].rs_bypass;
            assign from_rs[i].rs1_value     = from_rs_local_out[i].rs1_value;
            assign from_rs[i].rs2_value     = from_rs_local_out[i].rs2_value;
        end
    endgenerate

    // Clock-gate the register-file array: written only when a CDB lane carries a
    // result for a non-zero physical register. en = OR of every write port's
    // enable (exact superset). The latch-based clock_gate stays transparent even
    // though these CDB valids are combinational on the load-to-use pass-through.
    logic prf_wr_en;
    logic prf_gclk;
    always_comb begin
        prf_wr_en = 1'b0;
        for (int i = 0; i < CDB_WIDTH; i++)
            if (cdb_local[i].valid && (cdb_local[i].rd_phy != '0))
                prf_wr_en = 1'b1;
    end
    clock_gate prf_cg (.clk(clk), .en(prf_wr_en), .gclk(prf_gclk));

    always_ff @(posedge prf_gclk) begin
        for (int i = 0; i < CDB_WIDTH; i++) begin
            if (cdb_local[i].valid && (cdb_local[i].rd_phy != '0)) begin
                prf_data[cdb_local[i].rd_phy] <= cdb_local[i].rd_value;
            end
        end
    end

    always_comb begin
        for (int i = 0; i < CDB_WIDTH; i++) begin
            // Unfortunatly, we cannot generate a case statement based on CDB_WIDTH
            unique case (from_rs_local_in[i].rs_bypass.rs1_bypass_en)
                6'b000000: begin
                    from_rs_local_out[i].rs1_value = (from_rs_local_in[i].rs1_phy == '0) ? '0 : prf_data[from_rs_local_in[i].rs1_phy];
                end
                6'b000001: begin
                    from_rs_local_out[i].rs1_value = cdb_local[0].rd_value;
                end
                6'b000010: begin
                    from_rs_local_out[i].rs1_value = cdb_local[1].rd_value;
                end
                6'b000100: begin
                    from_rs_local_out[i].rs1_value = cdb_local[2].rd_value;
                end
                6'b001000: begin
                    from_rs_local_out[i].rs1_value = cdb_local[3].rd_value;
                end
                6'b010000: begin
                    from_rs_local_out[i].rs1_value = cdb_local[4].rd_value;
                end
                6'b100000: begin
                    from_rs_local_out[i].rs1_value = alu_bypass[from_rs_local_in[i].rs_bypass.rs1_bypass_sel].rd_value;
                end
                default: begin
                    from_rs_local_out[i].rs1_value = 'x;
                end
            endcase
        end
    end

    always_comb begin
        for (int i = 0; i < CDB_WIDTH; i++) begin
            // Unfortunatly, we cannot generate a case statement based on CDB_WIDTH
            unique case (from_rs_local_in[i].rs_bypass.rs2_bypass_en)
                6'b000000: begin
                    from_rs_local_out[i].rs2_value = (from_rs_local_in[i].rs2_phy == '0) ? '0 : prf_data[from_rs_local_in[i].rs2_phy];
                end
                6'b000001: begin
                    from_rs_local_out[i].rs2_value = cdb_local[0].rd_value;
                end
                6'b000010: begin
                    from_rs_local_out[i].rs2_value = cdb_local[1].rd_value;
                end
                6'b000100: begin
                    from_rs_local_out[i].rs2_value = cdb_local[2].rd_value;
                end
                6'b001000: begin
                    from_rs_local_out[i].rs2_value = cdb_local[3].rd_value;
                end
                6'b010000: begin
                    from_rs_local_out[i].rs2_value = cdb_local[4].rd_value;
                end
                6'b100000: begin
                    from_rs_local_out[i].rs2_value = alu_bypass[from_rs_local_in[i].rs_bypass.rs2_bypass_sel].rd_value;
                end
                default: begin
                    from_rs_local_out[i].rs2_value = 'x;
                end
            endcase
        end
    end


endmodule
