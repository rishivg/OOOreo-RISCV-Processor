// Module-swap shim (ROADMAP Phase 2 / interface layer). Drop-in replacement for
// hdl/backend/execute/int_rs/fu_alu.sv: same port list (including the `cdb_itf.fu`
// SystemVerilog interface), but the body just adapts the interface to the
// SpinalHDL-generated `fu_alu_spinal` (flattened CDB ports). SpinalHDL cannot emit
// an SV interface, so this thin shim carries it; all FU logic lives in fu_alu_spinal.v.
//
// Used only by sim/build_swap.sh (fu_alu case); hdl/ stays pristine.
module fu_alu
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,
    input   logic               int_rs_valid,
    output  logic               fu_alu_ready,
    input   fu_alu_reg_t        fu_alu_reg_in,
    output  bypass_network_t    bypass,
    cdb_itf.fu                  cdb
);

    fu_alu_spinal fu_alu_spinal_i (
        .clk                (clk),
        .rst                (rst),
        .int_rs_valid       (int_rs_valid),
        .fu_alu_ready       (fu_alu_ready),
        .fu_alu_reg_in      (fu_alu_reg_in),
        .bypass             (bypass),

        .cdb_rob_id         (cdb.rob_id),
        .cdb_rd_phy         (cdb.rd_phy),
        .cdb_rd_arch        (cdb.rd_arch),
        .cdb_rd_value       (cdb.rd_value),
        .cdb_rs1_value_dbg  (cdb.rs1_value_dbg),
        .cdb_rs2_value_dbg  (cdb.rs2_value_dbg),
        .cdb_valid          (cdb.valid)
    );

endmodule
