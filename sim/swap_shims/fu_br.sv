// Module-swap shim (ROADMAP Phase 2 / interface layer). Drop-in for
// hdl/backend/branch/br_rs/fu_br.sv: same ports (incl. the cdb_itf.fu + br_cdb_itf.fu
// SV interfaces), body adapts them to the SpinalHDL `fu_br_spinal` (flattened ports).
// Used only by sim/build_swap.sh (fu_br case); hdl/ stays pristine.
module fu_br
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               br_rs_valid,
    output  logic               fu_br_ready,
    input   fu_br_reg_t         fu_br_reg_in,
    cdb_itf.fu                  cdb,
    br_cdb_itf.fu               br_cdb
);

    // surfaced for hvl/common/perf_monitor.sv hierarchical taps (fu_br_i.<name>)
    logic           fu_br_valid;
    logic           miss_predict;
    fu_br_reg_t     fu_br_reg_out;

    fu_br_spinal fu_br_spinal_i (
        .clk                    (clk),
        .rst                    (rst),
        .br_rs_valid            (br_rs_valid),
        .fu_br_ready            (fu_br_ready),
        .fu_br_reg_in           (fu_br_reg_in),

        .cdb_rob_id             (cdb.rob_id),
        .cdb_rd_phy             (cdb.rd_phy),
        .cdb_rd_arch            (cdb.rd_arch),
        .cdb_rd_value           (cdb.rd_value),
        .cdb_rs1_value_dbg      (cdb.rs1_value_dbg),
        .cdb_rs2_value_dbg      (cdb.rs2_value_dbg),
        .cdb_valid              (cdb.valid),

        .br_cdb_rob_id          (br_cdb.rob_id),
        .br_cdb_miss_predict    (br_cdb.miss_predict),
        .br_cdb_target_address  (br_cdb.target_address),
        .br_cdb_valid           (br_cdb.valid),
        .br_cdb_branch_taken    (br_cdb.branch_taken),

        .dbg_fu_br_valid        (fu_br_valid),
        .dbg_miss_predict       (miss_predict),
        .dbg_reg_out            (fu_br_reg_out)
    );

endmodule
