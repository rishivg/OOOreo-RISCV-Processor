package ooo.memory

import spinal.core._

/** Dispatch memory operations to load, store, and serial execution paths. */
class LsuAdapter extends Component {
  setDefinitionName("lsu_adapter_spinal")
  val io = new Bundle {
    val from_ds_valid   = in  Bool()
    val from_ds_ready   = out Bool()
    val to_mem_rs_ready = in  Bool()
    val to_mem_rs_valid = out Bool()
    val to_ldq_ready    = in  Bool()
    val to_ldq_valid    = out Bool()
    val to_stq_ready    = in  Bool()
    val to_stq_valid    = out Bool()
  }
  noIoPrefix()

  io.from_ds_ready   := io.to_mem_rs_ready && io.to_ldq_ready && io.to_stq_ready
  io.to_mem_rs_valid := io.from_ds_valid && io.to_ldq_ready && io.to_stq_ready
  io.to_stq_valid    := io.from_ds_valid && io.to_mem_rs_ready && io.to_ldq_ready
  io.to_ldq_valid    := io.from_ds_valid && io.to_mem_rs_ready && io.to_stq_ready
}
