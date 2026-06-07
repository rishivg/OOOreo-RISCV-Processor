// Execute interfaces: common data bus (CDB), RS<->PRF operand read/bypass,
// branch-result CDB. Split out of backend_itf.sv.

interface cdb_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic   [PRF_IDX-1:0]   rd_phy;
    logic   [ARF_IDX-1:0]   rd_arch;
    logic   [31:0]          rd_value;
    logic   [31:0]          rs1_value_dbg;
    logic   [31:0]          rs2_value_dbg;
    logic                   valid;

    modport fu (
        output              rob_id,
        output              rd_phy,
        output              rd_arch,
        output              rd_value,
        output              rs1_value_dbg,
        output              rs2_value_dbg,
        output              valid
    );

    modport rs (
        input               rd_phy,
        input               valid
    );

    modport prf (
        input               rd_phy,
        input               rd_value,
        input               valid
    );

    modport rob (
        input               rob_id,
        input               rd_value,
        input               rs1_value_dbg,
        input               rs2_value_dbg,
        input               valid
    );

    modport rat (
        input               rd_phy,
        input               rd_arch,
        input               valid
    );

endinterface

interface br_cdb_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic                   miss_predict;
    logic   [31:0]          target_address;
    logic                   valid;
    logic                   branch_taken;

    modport fu (
        output              rob_id,
        output              miss_predict,
        output              target_address,
        output              valid,
        output              branch_taken
    );

    modport cb (
        input              rob_id,
        input              miss_predict,
        input              target_address,
        input              valid,
        input              branch_taken
    );

endinterface

interface rs_prf_itf();
import cpu_params::*;
import int_rs_types::*;

    logic   [PRF_IDX-1:0]   rs1_phy;
    logic   [PRF_IDX-1:0]   rs2_phy;
    logic   [31:0]          rs1_value;
    logic   [31:0]          rs2_value;
    bypass_t                rs_bypass;

    modport rs (
        output              rs1_phy,
        output              rs2_phy,
        input               rs1_value,
        input               rs2_value,
        output              rs_bypass
    );

    modport prf (
        input               rs1_phy,
        input               rs2_phy,
        output              rs1_value,
        output              rs2_value,
        input               rs_bypass
    );

endinterface
