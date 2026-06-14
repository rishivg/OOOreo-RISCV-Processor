// Module-swap shim for hdl/backend/branch/control_buffer.sv. Carries the four SV
// interfaces (ds_rs_mono_itf, br_cdb_itf.cb, cb_rob_itf.cb, cb_bp_itf.cb) and maps
// them onto control_buffer_spinal. Used only by sim/build_swap.sh.
module control_buffer
import cpu_params::*;
import uop_types::*;
(
    input   logic               clk,
    input   logic               rst,
    ds_rs_mono_itf.rs           from_ds,
    br_cdb_itf.cb               br_cdb_in,
    cb_rob_itf.cb               to_rob,
    cb_bp_itf.cb                to_bp,
    input   logic               branch_ready
);
    control_buffer_spinal control_buffer_spinal_i (
        .clk(clk), .rst(rst),
        .from_ds_valid(from_ds.valid),
        .from_ds_ready(from_ds.ready),
        .uop_rob_id(from_ds.uop.rob_id),
        .uop_pc(from_ds.uop.pc),
        .uop_fu_opcode(from_ds.uop.fu_opcode),
        .uop_ghr(from_ds.uop.ghr),
        .uop_is_compressed(from_ds.uop.is_compressed),
        .uop_inst(from_ds.uop.inst),
        .branch_ready(branch_ready),
        .br_cdb_valid(br_cdb_in.valid),
        .br_cdb_rob_id(br_cdb_in.rob_id),
        .br_cdb_miss_predict(br_cdb_in.miss_predict),
        .br_cdb_target(br_cdb_in.target_address),
        .br_cdb_branch_taken(br_cdb_in.branch_taken),
        .to_rob_rob_id(to_rob.rob_id),
        .to_rob_miss_predict(to_rob.miss_predict),
        .to_rob_target(to_rob.target_address),
        .to_rob_ready(to_rob.ready),
        .to_rob_dequeue(to_rob.dequeue),
        .to_bp_update_en(to_bp.update_en),
        .to_bp_pc(to_bp.pc),
        .to_bp_fu_opcode(to_bp.fu_opcode),
        .to_bp_branch_taken(to_bp.branch_taken),
        .to_bp_target(to_bp.target_address),
        .to_bp_ghr(to_bp.ghr),
        .to_bp_is_call(to_bp.is_call),
        .to_bp_is_ret(to_bp.is_ret),
        .to_bp_is_compressed(to_bp.is_compressed)
    );
endmodule
