package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/memory/lsu_adapter.sv` -- the dispatch fan-out to the
  * mem_rs / load-queue / store-queue: a memory uop is accepted only when all three
  * consumers are ready, and each consumer's valid is gated by the other two. The
  * uop payload itself is a pure fan-out wired in the shim; this module is the
  * valid/ready handshake combinational logic. Combinational-only (no clk/reset).
  *
  * Named lsu_adapter_spinal; sim/swap_shims/lsu_adapter.sv carries the four
  * ds_rs_mono_itf ports and fans out uop directly.
  */
class LsuAdapter(cfg: CpuConfig = CpuConfig()) extends Component {
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
