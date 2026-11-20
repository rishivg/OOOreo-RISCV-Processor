package ooo

import spinal.core._
import ooo.frontend.{FrontendTop, InstQueue}
import ooo.backend.BackendTop
import ooo.common.{CacheAdapter, BmemArbiter}
import ooo.execute.FuDiv

/** Core integration: frontend, instruction queue, backend, memory bus, and optional MCU interfaces. */
class Cpu(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("cpu")
  val RVFIW = cfg.rvfiDbgW

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
    val scan_enable = if (cfg.lowPower) in Bool() else null
    val sleeping = if (cfg.lowPower) out Bool() else null
    val mmio = if (cfg.mmio) ooo.memory.MmioMaster() else null
    val rvfi_flat   = out Bits (cfg.idWidth * RVFIW bits)   // debug: ROB rvfi record
    val irq_ext     = if (cfg.zicsr) in Bool() else null      // Zicsr: platform interrupt (mip.MEIP)
  }
  noIoPrefix()

  val frontend = new FrontendTop(cfg)
  val iq       = new InstQueue(cfg, depth = cfg.instQueueDepth)
  val backend  = new BackendTop(cfg)
  val arb      = new BmemArbiter(cfg)
  val ca       = new CacheAdapter(cfg)
  val fudiv    = new FuDiv(cfg)

  val flush = backend.io.backend_flush
  def localFlush(): Bool = if (cfg.distributedFlush) {
    val replica=new ooo.common.FlushReplica
    replica.io.causes:=backend.io.flush_causes
    replica.io.flush
  } else flush
  val halt = Bool()
  val coreClock = Bool()
  if (cfg.lowPower) {
    val power = new ooo.common.SleepController
    val gate = new ooo.common.SafeClockGate(cfg.implementation.clockGate == "bufgctrl")
    power.io.clk := io.clk; power.io.rst := io.rst
    power.io.sleep_request := backend.io.sleep_request
    power.io.wake := backend.io.wfi_wake
    power.io.quiescent := backend.io.memory_idle && ca.io.idle &&
      !frontend.io.icache_read && !frontend.io.icache_write && !frontend.io.dbg_icache_unresponsive && !io.bmem_rvalid
    gate.io.clk := io.clk; gate.io.rst := io.rst
    gate.io.enable := power.io.clock_enable; gate.io.scan_enable := io.scan_enable
    coreClock := gate.io.gated_clk; io.sleeping := gate.io.closed
    // Same physical source clock; gating only removes complete cycles.
    val rootDomain = ClockDomain(io.clk,io.rst,config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC))
    val gatedDomain = ClockDomain(coreClock,io.rst,config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC))
    gatedDomain.setSynchronousWith(rootDomain)
    halt := power.io.halt || backend.io.sleep_request
    backend.io.aon_clk := io.clk
  } else { coreClock := io.clk; halt := False }
  val maintenanceHalt = Bool()
  if (!cfg.zicsr) maintenanceHalt := False
  if (cfg.zicsr) {
    val domain = ClockDomain(coreClock,io.rst,config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC))
    new ClockingArea(domain) {
      val state = RegInit(U(0,2 bits))
      maintenanceHalt := backend.io.fence_i_request || state =/= 0
      backend.io.cache_flush_request := state === 1
      frontend.io.invalidate := state === 2
      backend.io.fence_i_done := state === 3
      when(state === 0 && backend.io.fence_i_request) { state := 1 }
      when(state === 1 && backend.io.cache_flush_done && ca.io.idle &&
        !frontend.io.icache_read && !frontend.io.dbg_icache_unresponsive && !io.bmem_rvalid) { state := 2 }
      when(state === 2) { state := 3 }
      when(state === 3 && !backend.io.fence_i_request) { state := 0 }
    }
  }
  if (cfg.lowPower || cfg.zicsr) frontend.io.halt_fetch := halt || maintenanceHalt
  if (cfg.mmio) io.mmio <> backend.io.mmio
  for (c <- Seq(frontend.io.clk, iq.io.clk, backend.io.clk, arb.io.clk, ca.io.clk, fudiv.io.clk)) c := coreClock
  frontend.io.rst := io.rst; backend.io.rst := io.rst; arb.io.rst := io.rst; ca.io.rst := io.rst
  iq.io.rst := io.rst || localFlush()
  fudiv.io.rst := io.rst || localFlush()

  def connectFrontendControl(): Unit = {
    frontend.io.backend_flush := localFlush()
    frontend.io.backend_redirect_pc := backend.io.backend_redirect_pc
  }

  def connectFetchQueue(): Unit = {
    iq.io.in_valid := frontend.io.to_fifo_valid && !halt
    frontend.io.to_fifo_ready := iq.io.in_ready
    iq.io.in_inst_flat := frontend.io.to_fifo_inst_flat
    if (cfg.frontendPayloadSpeculation) iq.io.in_pre_flat := frontend.io.to_fifo_pre_flat
    iq.io.in_inst_raw_flat := frontend.io.to_fifo_inst_raw_flat
    iq.io.in_is_compressed := frontend.io.to_fifo_is_compressed
    iq.io.in_predict_taken := frontend.io.to_fifo_predict_taken
    iq.io.in_predict_target_flat := frontend.io.to_fifo_predict_target_flat
    iq.io.in_pc_flat := frontend.io.to_fifo_pc_flat
    iq.io.in_valid_slots := frontend.io.to_fifo_valid_slots
    iq.io.in_kp_flat := frontend.io.to_fifo_kp_flat
    iq.io.in_prov_flat := frontend.io.to_fifo_prov_flat
  }

  def connectBackendQueue(): Unit = {
    backend.io.from_fifo_valid := iq.io.out_valid && !halt
    iq.io.out_ready := backend.io.from_fifo_ready && !halt
    backend.io.ff_inst_flat := iq.io.out_inst_flat
    if (cfg.iqParallelDecode) backend.io.ff_decoded_flat := iq.io.out_decoded_flat
    backend.io.ff_inst_raw_flat := iq.io.out_inst_raw_flat
    backend.io.ff_is_compressed := iq.io.out_is_compressed
    backend.io.ff_predict_taken := iq.io.out_predict_taken
    backend.io.ff_predict_target_flat := iq.io.out_predict_target_flat
    backend.io.ff_pc_flat := iq.io.out_pc_flat
    backend.io.ff_valid_slots := iq.io.out_valid_slots
    backend.io.ff_kp_flat := iq.io.out_kp_flat
    backend.io.ff_prov_flat := iq.io.out_prov_flat
    backend.io.ff_pre_rs_type_flat := iq.io.out_pre_rs_type_flat
    backend.io.ff_pre_is_store  := iq.io.out_pre_is_store
    backend.io.ff_pre_is_atomic := iq.io.out_pre_is_atomic
    backend.io.ff_pre_has_rd    := iq.io.out_pre_has_rd
  }

  def connectBranchFeedback(): Unit = {
    frontend.io.from_cb_update_en := backend.io.to_bp_update_en
    frontend.io.from_cb_pc := backend.io.to_bp_pc
    frontend.io.from_cb_fu_opcode := backend.io.to_bp_fu_opcode
    frontend.io.from_cb_branch_taken := backend.io.to_bp_branch_taken
    frontend.io.from_cb_target_address := backend.io.to_bp_target
    frontend.io.from_cb_kp := backend.io.to_bp_kp
    frontend.io.from_cb_is_call := backend.io.to_bp_is_call
    frontend.io.from_cb_is_ret := backend.io.to_bp_is_ret
    frontend.io.from_cb_is_compressed := backend.io.to_bp_is_compressed
    frontend.io.from_cb_prov := backend.io.to_bp_prov
  }

  def connectDivider(): Unit = {
    fudiv.io.prv_valid := backend.io.div_prv_valid
    backend.io.div_prv_ready := fudiv.io.prv_ready
    backend.io.div_nxt_valid := fudiv.io.nxt_valid
    fudiv.io.nxt_ready := backend.io.div_nxt_ready
    fudiv.io.iss_in := backend.io.div_iss_in
    backend.io.div_cdb_out := fudiv.io.cdb_out
  }

  def connectMemoryFabric(): Unit = {
    arb.io.icache_addr := frontend.io.icache_addr; arb.io.icache_read := frontend.io.icache_read
    arb.io.icache_write := frontend.io.icache_write; arb.io.icache_wdata := frontend.io.icache_wdata
    frontend.io.icache_ready := arb.io.icache_ready; frontend.io.icache_rdata := arb.io.icache_rdata
    frontend.io.icache_raddr := arb.io.icache_raddr; frontend.io.icache_rvalid := arb.io.icache_rvalid

    arb.io.dcache_addr := backend.io.dfp_addr; arb.io.dcache_read := backend.io.dfp_read
    arb.io.dcache_write := backend.io.dfp_write; arb.io.dcache_wdata := backend.io.dfp_wdata
    if (cfg.bmemEarlyAddress) {
      arb.io.dcache_read_addr := backend.io.dfp_read_addr
      arb.io.dcache_write_addr := backend.io.dfp_write_addr
    }
    backend.io.dfp_ready := arb.io.dcache_ready; backend.io.dfp_rdata := arb.io.dcache_rdata
    backend.io.dfp_raddr := arb.io.dcache_raddr; backend.io.dfp_rvalid := arb.io.dcache_rvalid

    ca.io.ufp_addr := arb.io.adapter_addr; ca.io.ufp_read := arb.io.adapter_read
    ca.io.ufp_write := arb.io.adapter_write; ca.io.ufp_wdata := arb.io.adapter_wdata
    if (cfg.bmemBeatSpeculation) {
      backend.io.dfp_write_beat := ca.io.write_beat
      arb.io.write_beat := ca.io.write_beat
      arb.io.dcache_wdata_beat := backend.io.dfp_wdata_beat
      ca.io.ufp_wdata_beat := arb.io.adapter_wdata_beat
    }
    arb.io.adapter_ready := ca.io.ufp_ready; arb.io.adapter_rdata := ca.io.ufp_rdata
    arb.io.adapter_raddr := ca.io.ufp_raddr; arb.io.adapter_rvalid := ca.io.ufp_rvalid

    io.bmem_addr := ca.io.dfp_addr; io.bmem_read := ca.io.dfp_read; io.bmem_write := ca.io.dfp_write; io.bmem_wdata := ca.io.dfp_wdata
    ca.io.dfp_ready := io.bmem_ready; ca.io.dfp_raddr := io.bmem_raddr; ca.io.dfp_rdata := io.bmem_rdata; ca.io.dfp_rvalid := io.bmem_rvalid
  }

  if (cfg.zicsr) {
    if (cfg.lowPower) {
      val aon = ClockDomain(io.clk,io.rst,config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC))
      new ClockingArea(aon) {
        val irqMeta = RegNext(io.irq_ext) init(False)
        val irqSync = RegNext(irqMeta) init(False)
        irqMeta.addTag(crossClockDomain)
        irqSync.addTag(crossClockDomain)
        irqMeta.addAttribute("ASYNC_REG", "TRUE")
        irqSync.addAttribute("ASYNC_REG", "TRUE")
        backend.io.irq_ext := irqSync
      }
    } else backend.io.irq_ext := io.irq_ext
  }
  connectFrontendControl()
  connectFetchQueue()
  connectBackendQueue()
  connectBranchFeedback()
  connectDivider()
  connectMemoryFabric()

  // rvfi debug
  io.rvfi_flat := (if (cfg.rvfi) backend.io.rvfi_itf_flat else B(0, cfg.idWidth * RVFIW bits))
}
