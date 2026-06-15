package ooo

import spinal.core._
import ooo.frontend.{FrontendTop, InstQueue}
import ooo.backend.BackendTop
import ooo.common.{CacheAdapter, BmemArbiter}
import ooo.execute.FuDiv

/** Top-level core -- the Phase-4 full integration. Emits module `cpu` with the
  * exact SV bmem boundary (clk, rst, bmem_*), plus a debug `rvfi_flat` output
  * (ID_WIDTH x rvfi_dbg_t) the SpinalHDL sim harness taps for the RVFI monitor.
  *
  * Wires FrontendTop + InstQueue + BackendTop + BmemArbiter + CacheAdapter and the
  * blackboxed fu_div into the complete out-of-order core. Each sub-component owns
  * its clock domain via its clk/rst io (active-high sync reset).
  */
class Cpu(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("cpu")
  val RVFIW = 413

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val bmem_addr   = out Bits (32 bits)
    val bmem_read   = out Bool()
    val bmem_write  = out Bool()
    val bmem_wdata  = out Bits (64 bits)
    val bmem_ready  = in  Bool()
    val bmem_raddr  = in  Bits (32 bits)
    val bmem_rdata  = in  Bits (64 bits)
    val bmem_rvalid = in  Bool()
    val rvfi_flat   = out Bits (cfg.idWidth * RVFIW bits)   // debug: ROB rvfi record
  }
  noIoPrefix()

  val frontend = new FrontendTop(cfg)
  val iq       = new InstQueue(cfg, depth = 8)
  val backend  = new BackendTop(cfg)
  val arb      = new BmemArbiter(cfg)
  val ca       = new CacheAdapter(cfg)
  val fudiv    = new FuDiv(cfg)

  val flush = backend.io.backend_flush
  for (c <- Seq(frontend.io.clk, iq.io.clk, backend.io.clk, arb.io.clk, ca.io.clk, fudiv.io.clk)) c := io.clk
  frontend.io.rst := io.rst; backend.io.rst := io.rst; arb.io.rst := io.rst; ca.io.rst := io.rst
  iq.io.rst := io.rst || flush
  fudiv.io.rst := io.rst || flush

  // ---- frontend control ----
  frontend.io.backend_flush := flush
  frontend.io.backend_redirect_pc := backend.io.backend_redirect_pc

  // ---- frontend -> inst_queue (frontend_fifo) ----
  iq.io.in_valid := frontend.io.to_fifo_valid
  frontend.io.to_fifo_ready := iq.io.in_ready
  iq.io.in_inst_flat := frontend.io.to_fifo_inst_flat
  iq.io.in_inst_raw_flat := frontend.io.to_fifo_inst_raw_flat
  iq.io.in_is_compressed := frontend.io.to_fifo_is_compressed
  iq.io.in_predict_taken := frontend.io.to_fifo_predict_taken
  iq.io.in_predict_target_flat := frontend.io.to_fifo_predict_target_flat
  iq.io.in_pc_flat := frontend.io.to_fifo_pc_flat
  iq.io.in_valid_slots := frontend.io.to_fifo_valid_slots
  iq.io.in_ghr := frontend.io.to_fifo_ghr

  // ---- inst_queue -> backend (fifo_backend) ----
  backend.io.from_fifo_valid := iq.io.out_valid
  iq.io.out_ready := backend.io.from_fifo_ready
  backend.io.ff_inst_flat := iq.io.out_inst_flat
  backend.io.ff_inst_raw_flat := iq.io.out_inst_raw_flat
  backend.io.ff_is_compressed := iq.io.out_is_compressed
  backend.io.ff_predict_taken := iq.io.out_predict_taken
  backend.io.ff_predict_target_flat := iq.io.out_predict_target_flat
  backend.io.ff_pc_flat := iq.io.out_pc_flat
  backend.io.ff_valid_slots := iq.io.out_valid_slots
  backend.io.ff_ghr_flat := iq.io.out_ghr_flat

  // ---- backend -> frontend (cb_bp) ----
  frontend.io.from_cb_update_en := backend.io.to_bp_update_en
  frontend.io.from_cb_pc := backend.io.to_bp_pc
  frontend.io.from_cb_fu_opcode := backend.io.to_bp_fu_opcode
  frontend.io.from_cb_branch_taken := backend.io.to_bp_branch_taken
  frontend.io.from_cb_target_address := backend.io.to_bp_target
  frontend.io.from_cb_ghr := backend.io.to_bp_ghr
  frontend.io.from_cb_is_call := backend.io.to_bp_is_call
  frontend.io.from_cb_is_ret := backend.io.to_bp_is_ret
  frontend.io.from_cb_is_compressed := backend.io.to_bp_is_compressed

  // ---- fu_div (externalised from backend) ----
  fudiv.io.prv_valid := backend.io.div_prv_valid
  backend.io.div_prv_ready := fudiv.io.prv_ready
  backend.io.div_nxt_valid := fudiv.io.nxt_valid
  fudiv.io.nxt_ready := backend.io.div_nxt_ready
  fudiv.io.iss_in := backend.io.div_iss_in
  backend.io.div_cdb_out := fudiv.io.cdb_out

  // ---- icache cacheline: frontend(master) <-> arb.icache(slave) ----
  arb.io.icache_addr := frontend.io.icache_addr; arb.io.icache_read := frontend.io.icache_read
  arb.io.icache_write := frontend.io.icache_write; arb.io.icache_wdata := frontend.io.icache_wdata
  frontend.io.icache_ready := arb.io.icache_ready; frontend.io.icache_rdata := arb.io.icache_rdata
  frontend.io.icache_raddr := arb.io.icache_raddr; frontend.io.icache_rvalid := arb.io.icache_rvalid

  // ---- dcache cacheline: backend(master dfp) <-> arb.dcache(slave) ----
  arb.io.dcache_addr := backend.io.dfp_addr; arb.io.dcache_read := backend.io.dfp_read
  arb.io.dcache_write := backend.io.dfp_write; arb.io.dcache_wdata := backend.io.dfp_wdata
  backend.io.dfp_ready := arb.io.dcache_ready; backend.io.dfp_rdata := arb.io.dcache_rdata
  backend.io.dfp_raddr := arb.io.dcache_raddr; backend.io.dfp_rvalid := arb.io.dcache_rvalid

  // ---- adapter cacheline: arb.adapter(master) <-> ca.ufp(slave) ----
  ca.io.ufp_addr := arb.io.adapter_addr; ca.io.ufp_read := arb.io.adapter_read
  ca.io.ufp_write := arb.io.adapter_write; ca.io.ufp_wdata := arb.io.adapter_wdata
  arb.io.adapter_ready := ca.io.ufp_ready; arb.io.adapter_rdata := ca.io.ufp_rdata
  arb.io.adapter_raddr := ca.io.ufp_raddr; arb.io.adapter_rvalid := ca.io.ufp_rvalid

  // ---- cache_adapter dfp -> bmem boundary ----
  io.bmem_addr := ca.io.dfp_addr; io.bmem_read := ca.io.dfp_read; io.bmem_write := ca.io.dfp_write; io.bmem_wdata := ca.io.dfp_wdata
  ca.io.dfp_ready := io.bmem_ready; ca.io.dfp_raddr := io.bmem_raddr; ca.io.dfp_rdata := io.bmem_rdata; ca.io.dfp_rvalid := io.bmem_rvalid

  // ---- rvfi debug ----
  io.rvfi_flat := backend.io.rvfi_itf_flat
}
