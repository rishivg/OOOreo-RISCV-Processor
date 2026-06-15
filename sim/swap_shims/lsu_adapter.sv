// Module-swap shim for hdl/memory/lsu_adapter.sv. Carries the four ds_rs_mono_itf
// ports; fans out the uop payload directly and routes the valid/ready handshake
// through lsu_adapter_spinal. Used only by sim/build_swap.sh; hdl/ stays pristine.
module lsu_adapter
import cpu_params::*;
import uop_types::*;
import lsu_types::*;
(
    ds_rs_mono_itf.rs           from_ds,
    ds_rs_mono_itf.ds           to_mem_rs,
    ds_rs_mono_itf.ds           to_ldq,
    ds_rs_mono_itf.ds           to_stq
);
    // uop payload fan-out
    assign to_mem_rs.uop = from_ds.uop;
    assign to_ldq.uop    = from_ds.uop;
    assign to_stq.uop    = from_ds.uop;

    lsu_adapter_spinal lsu_adapter_spinal_i (
        .from_ds_valid   (from_ds.valid),
        .from_ds_ready   (from_ds.ready),
        .to_mem_rs_ready (to_mem_rs.ready),
        .to_mem_rs_valid (to_mem_rs.valid),
        .to_ldq_ready    (to_ldq.ready),
        .to_ldq_valid    (to_ldq.valid),
        .to_stq_ready    (to_stq.ready),
        .to_stq_valid    (to_stq.valid)
    );
endmodule
