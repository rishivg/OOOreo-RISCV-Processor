package ooo.memory

import spinal.core._
import ooo.CpuConfig
import ooo.execute.{MemRs, BypassT}
import ooo.csr.CsrUnit

/** Load/store queues, cache arbitration, serial operations, and optional MMIO. */
class LsuTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("lsu_top_spinal")
  val CDBW = cfg.cdbWidth      // [CDB_WIDTH]
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val RIDX = cfg.robIdx
  val AIDX = cfg.arfIdx
  val LDQ  = cfg.ldqDepth
  val STQ  = cfg.stqDepth
  val MEMEW = ooo.execute.MemRsEntry.width(cfg) // mem_rs_entry_t
  val BNW  = cfg.bypassNetW     // bypass_network_t
  val BPW  = BypassT.width(cfg) // bypass_t width

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    // Dispatch payload
    val from_ds_valid       = in  Bool()
    val from_ds_ready       = out Bool()
    val mem_rs_entry_flat   = in  Bits (MEMEW bits)
    val uop_rob_id          = in  Bits (RIDX bits)
    val uop_fu_opcode       = in  Bits (4 bits)
    val uop_rd_arch         = in  Bits (AIDX bits)
    val uop_rd_phy          = in  Bits (PIDX bits)
    val uop_is_atomic       = in  Bool()              // RV32A (aExt)
    val uop_amo_op          = in  Bits (4 bits)       // RV32A (aExt)
    // RV32A: ROB head handshake -> AtomicUnit (and, with Zicsr, the CsrUnit: the two
    // CAMs decide who owns the rob_id)
    val atomic_go           = in  Bool()
    val atomic_go_rob_id    = in  Bits (RIDX bits)
    // Zicsr (ports exist only when cfg.zicsr)
    val aon_clk = if (cfg.lowPower) in Bool() else null
    val memory_idle = if (cfg.zicsr || cfg.lowPower || cfg.mmio) out Bool() else null
    val csr_wfi_held = if (cfg.lowPower) out Bool() else null
    val mmio = if (cfg.mmio) MmioMaster() else null
    val device_go = if (cfg.mmio) in Bool() else null
    val device_go_id = if (cfg.mmio) in Bits(RIDX bits) else null
    val device_mark = if (cfg.mmio) out Bool() else null
    val device_mark_id = if (cfg.mmio) out Bits(RIDX bits) else null
    val uop_is_csr   = if (cfg.zicsr) in Bool() else null
    val uop_csr_ctrl = if (cfg.zicsr) in Bits (20 bits) else null
    val csr_acc_en    = if (cfg.zicsr) out Bool() else null          // CsrUnit <-> Csr file (in BackendTop)
    val csr_acc_addr  = if (cfg.zicsr) out Bits (12 bits) else null
    val csr_acc_wdata = if (cfg.zicsr) out Bits (32 bits) else null
    val csr_acc_write = if (cfg.zicsr) out Bool() else null
    val csr_acc_op    = if (cfg.zicsr) out Bits (3 bits) else null
    val csr_acc_rdata = if (cfg.zicsr) in  Bits (32 bits) else null
    val csr_acc_illegal = if (cfg.zicsr) in Bool() else null
    val csr_mret_en   = if (cfg.zicsr) out Bool() else null
    val csr_mret_held = if (cfg.zicsr) out Bool() else null
    val fence_i_request = if (cfg.zicsr) out Bool() else null
    val fence_i_done = if (cfg.zicsr) in Bool() else null
    val cache_flush_request = if (cfg.zicsr) in Bool() else null
    val cache_flush_done = if (cfg.zicsr) out Bool() else null
    // exceptions -> ROB: (a) AGU-detected misaligned load/store, (c) illegal CSR
    val exc_a_valid  = if (cfg.zicsr) out Bool() else null
    val exc_a_rob_id = if (cfg.zicsr) out Bits (RIDX bits) else null
    val exc_a_cause  = if (cfg.zicsr) out Bits (4 bits) else null
    val exc_a_tval   = if (cfg.zicsr) out Bits (32 bits) else null
    val exc_c_valid  = if (cfg.zicsr) out Bool() else null
    val exc_c_rob_id = if (cfg.zicsr) out Bits (RIDX bits) else null
    // CLINT -> Csr file
    val irq_timer = if (cfg.zicsr) out Bool() else null
    val irq_soft  = if (cfg.zicsr) out Bool() else null
    val mtime     = if (cfg.zicsr) out UInt (64 bits) else null
    val go_older  = if (cfg.zicsr) in UInt (log2Up(cfg.idWidth + 1) bits) else null
    val csr_acc_instret_adj = if (cfg.zicsr) out UInt (log2Up(cfg.idWidth + 1) bits) else null
    // to_prf (mem_rs single read port)
    val to_prf_rs2_phy   = out Bits (PIDX bits)
    val to_prf_rs_bypass = out Bits (BPW bits)
    val to_prf_rs2_value = in  Bits (32 bits)
    // rs1 PRE-READ group (replaces the primary+alt rs1 ports; see MemRs/Prf)
    val to_prf_pre_rs1_select_flat = if (cfg.memPrfPredecode) out Bits(cfg.memrsDepth * (cfg.prfDepth - 1) bits) else null
    val to_prf_pre_rs1_phy_flat    = out Bits (cfg.memrsDepth * PIDX bits)
    val to_prf_pre_rs1_bypass_flat = out Bits (cfg.memrsDepth * BPW bits)
    val to_prf_pre_rs1_value_flat  = in  Bits (cfg.memrsDepth * 32 bits)
    val cdb_lsu_value = in Bits (32 bits)
    val base_cdb_values = if (cfg.memCdbSpeculation) in Bits(160 bits) else null
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits)
    val cdb_valid       = in Bits (CDBW bits)
    // shared branch|intm lane wakeup pre-resolve (see MemRs/RsEntry wkPreResolve)
    val wk_intm_phy_br  = in Bits (PIDX bits)
    val wk_intm_phy_div = in Bits (PIDX bits)
    val wk_intm_phy_mul = in Bits (PIDX bits)
    val wk_intm_sel_br  = in Bool()
    val wk_intm_sel_div = in Bool()
    // exported LSU-lane (atomic|load) pre-resolve taps for the int-side RS's
    val wk_lsu_phy_c_o = if (cfg.lsuWakeupPredecode && cfg.zicsr) out Bits(PIDX bits) else null
    val wk_lsu_sel_c_o = if (cfg.lsuWakeupPredecode && cfg.zicsr) out Bool() else null
    val wk_lsu_phy_a_o  = out Bits (PIDX bits)
    val wk_lsu_phy_l_o  = out Bits (PIDX bits)
    val wk_lsu_sel_a_o  = out Bool()
    val wk_lsu_sel_atomic_o = cfg.intCsrSpeculation generate (out Bool())
    val lsu_valid_without_csr_o = cfg.intCsrSpeculation generate (out Bool())
    // alu_bypass[NUM_FAST_BYPASS]
    val alu_bypass_flat = in Bits (NFB * BNW bits)
    val alu_address_flat = if (cfg.aluAguFusion) in Bits(NFB * ooo.memory.AluAddressSource.width bits) else null
    // fu_cdb_out (load result CDB)
    val fu_cdb_rob_id        = out Bits (RIDX bits)
    val fu_cdb_rd_phy        = out Bits (PIDX bits)
    val fu_cdb_rd_arch       = out Bits (AIDX bits)
    val fu_cdb_rd_value      = out Bits (32 bits)
    val fu_cdb_rs1_value_dbg = out Bits (32 bits)
    val fu_cdb_rs2_value_dbg = out Bits (32 bits)
    val fu_cdb_valid         = out Bool()
    // ld_to_rob
    val ld_rob_rob_id           = out Bits (RIDX bits)
    val ld_rob_addr_dbg         = out Bits (32 bits)
    val ld_rob_rmask_dbg        = out Bits (4 bits)
    val ld_rob_rdata_dbg        = out Bits (32 bits)
    val ld_rob_valid            = out Bool()
    val ld_rob_violation        = out Bool()
    val ld_rob_violation_rob_id = out Bits (RIDX bits)
    // st_to_rob
    val st_rob_rob_id        = out Bits (RIDX bits)
    val st_rob_addr_dbg      = out Bits (32 bits)
    val st_rob_wmask_dbg     = out Bits (4 bits)
    val st_rob_wdata_dbg     = out Bits (32 bits)
    val st_rob_rs1_value_dbg = out Bits (32 bits)
    val st_rob_rs2_value_dbg = out Bits (32 bits)
    val st_rob_valid         = out Bool()
    val st_rob_ready         = in  Bool()
    // dcache dfp (cacheline master)
    val dfp_addr   = out Bits (32 bits)
    val dfp_read   = out Bool()
    val dfp_write  = out Bool()
    val dfp_wdata  = out Bits (256 bits)
    val dfp_write_beat = if (cfg.bmemBeatSpeculation) in Bits(2 bits) else null
    val dfp_wdata_beat = if (cfg.bmemBeatSpeculation) out Bits(64 bits) else null
    val dfp_read_addr = if (cfg.bmemEarlyAddress) out Bits(32 bits) else null
    val dfp_write_addr = if (cfg.bmemEarlyAddress) out Bits(32 bits) else null
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rdata  = in  Bits (256 bits)
    val dfp_rvalid = in  Bool()
    // LSU state observations
    val dbg_stb_full        = out Bool()
    val dbg_stq_want_dequeue = out Bool()
    val dbg_stq_counter      = out Bits (cfg.stqIdx + 1 bits)
    val dbg_stq_rd_ptr_actual = out Bits (cfg.stqIdx bits)
    val dbg_stq_addr_valid_flat = out Bits (STQ bits)
    val dbg_ldq_valid_flat      = out Bits (LDQ bits)
    val dbg_ldq_addr_valid_flat = out Bits (LDQ bits)
    val dbg_ldq_issued_flat     = out Bits (LDQ bits)
    val dbg_ldq_issue_en        = out Bool()
    val dbg_dc_stall = out Bool()
    val dbg_dc_hit   = out Bool()
    val dbg_dc_rmask = out Bits (4 bits)
    val dbg_dc_wmask = out Bits (4 bits)
    val dbg_ld_dmem_resp = out Bool()   // perf taps lsu_i.ld_dmem_itf_i.resp
  }
  noIoPrefix()

  val flush = io.backend_flush

  // sub-modules
  val adapter = new LsuAdapter
  val memRs   = new MemRs(cfg)
  val ldq     = new LoadQueue(cfg)
  val stq     = new StoreQueue(cfg)
  val stb     = new StoreBuf(cfg)
  if (cfg.lsuCarryFreeStoreMatch) {
    memRs.io.stb_match_targets:=stb.io.agu_match_targets
    stb.io.load_agu_matches:=memRs.io.to_lsq_stb_matches
  }
  val arb     = new DmemArbiter(cfg)
  val dc      = new Dcache(cfg)
  val atomicU = if (cfg.aExt) new AtomicUnit(cfg) else null
  val csrU    = if (cfg.zicsr) new CsrUnit(cfg) else null
  val clint   = if (cfg.zicsr) new Clint(cfg, predecodedWrites=true, predecodedReads=true, retimedRead=cfg.clintRetimedRead, clientClockedRead=cfg.clintCoreRead) else null
  val peripheral = if (cfg.mmio) new MmioBridge(cfg) else null
  val memoryQuiet = if (cfg.zicsr || cfg.lowPower || cfg.mmio) !stb.io.dmem_valid && arb.io.idle && dc.io.idle &&
    (if (cfg.mmio) !peripheral.io.busy else True) else True
  if (cfg.zicsr || cfg.lowPower || cfg.mmio) {
    io.memory_idle := memoryQuiet
    csrU.io.memory_idle := memoryQuiet
    ldq.io.block_regular := csrU.io.drain_request || (if (cfg.mmio) io.device_go || peripheral.io.busy else False)
  }
  if (cfg.lowPower) io.csr_wfi_held := csrU.io.wfi_held
  if (cfg.zicsr) {
    io.fence_i_request := csrU.io.fence_i_request; csrU.io.fence_i_done := io.fence_i_done
    dc.io.flush_request := io.cache_flush_request; io.cache_flush_done := dc.io.flush_done
  }
  if (cfg.mmio) {
    val permission = io.device_go && !stb.io.dmem_valid && arb.io.idle && !peripheral.io.busy
    ldq.io.device_go := permission; ldq.io.device_go_id := io.device_go_id
    io.device_mark := memRs.io.to_lsq_valid && memRs.io.to_lsq_ordered
    io.device_mark_id := AguLsq.robId(memRs.io.to_lsq_data,cfg)
    peripheral.io.clk := io.clk; peripheral.io.rst := io.rst; peripheral.io.flush := flush
    io.mmio <> peripheral.io.bus
  }

  // clocks / resets
  for (m <- Seq(memRs.io.clk, ldq.io.clk, stq.io.clk, stb.io.clk, arb.io.clk, dc.io.clk)) m := io.clk
  memRs.io.rst := io.rst || flush          // mem_rs reset folds in flush (per SV lsu_top)
  ldq.io.rst := io.rst; ldq.io.backend_flush := flush
  stq.io.rst := io.rst; stq.io.backend_flush := flush
  stb.io.rst := io.rst
  arb.io.rst := io.rst; arb.io.backend_flush := flush
  dc.io.rst  := io.rst

  // dispatch fan-out (lsu_adapter handshake)
  // Backpressure an incoming ATOMIC while the AtomicUnit capture CAM is full
  // (CAMN in-flight; atomics execute serially at the ROB head anyway). Constant
  // False on non-atomic uops and when aExt is off -- bit-identical there.
  val atomicCamStall =
    if (cfg.aExt && cfg.zicsr) (io.uop_is_atomic && !atomicU.io.disp_ready) || (io.uop_is_csr && !csrU.io.disp_ready)
    else if (cfg.aExt) io.uop_is_atomic && !atomicU.io.disp_ready
    else if (cfg.zicsr) io.uop_is_csr && !csrU.io.disp_ready
    else False
  adapter.io.from_ds_valid   := io.from_ds_valid && !atomicCamStall
  io.from_ds_ready           := adapter.io.from_ds_ready && !atomicCamStall
  adapter.io.to_mem_rs_ready := memRs.io.from_ds_ready
  adapter.io.to_ldq_ready    := ldq.io.from_ds_ready
  adapter.io.to_stq_ready    := stq.io.from_ds_ready

  // mem_rs
  memRs.io.from_ds_valid      := adapter.io.to_mem_rs_valid
  memRs.io.from_ds_entry_flat := io.mem_rs_entry_flat
  memRs.io.to_prf_rs2_phy   <> io.to_prf_rs2_phy
  memRs.io.to_prf_rs_bypass <> io.to_prf_rs_bypass
  memRs.io.to_prf_rs2_value := io.to_prf_rs2_value
  if (cfg.memPrfPredecode) memRs.io.to_prf_pre_rs1_select_flat <> io.to_prf_pre_rs1_select_flat
  memRs.io.to_prf_pre_rs1_phy_flat    <> io.to_prf_pre_rs1_phy_flat
  memRs.io.to_prf_pre_rs1_bypass_flat <> io.to_prf_pre_rs1_bypass_flat
  memRs.io.to_prf_pre_rs1_value_flat  := io.to_prf_pre_rs1_value_flat
  memRs.io.cdb_lsu_value              := io.cdb_lsu_value
  memRs.io.cdb_rd_phy_flat  := io.cdb_rd_phy_flat
  memRs.io.cdb_valid        := io.cdb_valid
  if (cfg.memCdbSpeculation) memRs.io.base_cdb_values := io.base_cdb_values
  memRs.io.wk_intm_phy_br   := io.wk_intm_phy_br
  memRs.io.wk_intm_phy_div  := io.wk_intm_phy_div
  memRs.io.wk_intm_phy_mul  := io.wk_intm_phy_mul
  memRs.io.wk_intm_sel_br   := io.wk_intm_sel_br
  memRs.io.wk_intm_sel_div  := io.wk_intm_sel_div
  memRs.io.alu_bypass_flat  := io.alu_bypass_flat
  if (cfg.aluAguFusion) memRs.io.alu_address_flat := io.alu_address_flat

  // agu_lsq (mem_rs -> ldq + stq)
  ldq.io.from_agu_valid := memRs.io.to_lsq_valid
  ldq.io.from_agu_data  := memRs.io.to_lsq_data
  ldq.io.agu_hi0 := memRs.io.to_lsq_hi0
  ldq.io.agu_hi1 := memRs.io.to_lsq_hi1
  ldq.io.agu_c16 := memRs.io.to_lsq_c16
  if (cfg.mmio) ldq.io.agu_ordered := memRs.io.to_lsq_ordered
  stq.io.from_agu_valid := memRs.io.to_lsq_valid
  stq.io.from_agu_data  := memRs.io.to_lsq_data
  if (cfg.storePairPrecompute && cfg.storePairSplitTag) {
    stq.io.agu_hi0 := memRs.io.to_lsq_hi0; stq.io.agu_hi1 := memRs.io.to_lsq_hi1
    stq.io.agu_c16 := memRs.io.to_lsq_c16
  }

  // RV32A: atomics still allocate in mem_rs (operand read + AGU) but must NOT create
  // LDQ/STQ entries -- the AtomicUnit owns their memory effect.
  val atomicSkip =
    if (cfg.aExt && cfg.zicsr) io.uop_is_atomic || io.uop_is_csr
    else if (cfg.aExt) io.uop_is_atomic
    else if (cfg.zicsr) io.uop_is_csr
    else False

  // load_queue dispatch + outputs
  ldq.io.from_ds_valid        := adapter.io.to_ldq_valid && !atomicSkip
  ldq.io.from_ds_uop_rob_id   := io.uop_rob_id
  ldq.io.from_ds_uop_fu_opcode := io.uop_fu_opcode
  ldq.io.from_ds_uop_rd_arch  := io.uop_rd_arch
  ldq.io.from_ds_uop_rd_phy   := io.uop_rd_phy
  // RV32A: AtomicUnit result takes priority on the LSU CDB lane (atomics execute at
  // the ROB head; a younger load's CDB does not fire that cycle on the serial path).
  val aCdbV0 = if (cfg.aExt) atomicU.io.cdb_valid else (if (cfg.zicsr) null else False)
  // Zicsr: the CsrUnit result shares the serial slot above the AtomicUnit. The two are
  // mutually exclusive by construction (one serial op at the head), so the "atomic"
  // source of the lane mux becomes Mux(csr, csr, atomic) and the select ORs.
  val cCdbV = if (cfg.zicsr) csrU.io.cdb_valid else null
  val aCdbV = if (cfg.zicsr && cfg.aExt) aCdbV0 || cCdbV else if (cfg.zicsr) cCdbV else aCdbV0
  def serialSrc(csrV: => Bits, atomV: => Bits, loadV: Bits): Bits =
    if (cfg.zicsr && cfg.aExt) Mux(cCdbV, csrV, atomV)
    else if (cfg.zicsr) csrV
    else if (cfg.aExt) atomV
    else loadV
  // wakeup pre-resolve taps (RsEntry wkPreResolve, via memRs): the two register-
  // output sources behind fu_cdb_rd_phy's atomic-vs-load mux + its select. With
  // aExt off the mux collapses; feed the load phy twice (constant-folds).
  if (cfg.lsuWakeupPredecode && cfg.zicsr) {
    memRs.io.wk_lsu_phy_c := csrU.io.cdb_rd_phy
    memRs.io.wk_lsu_sel_c := cCdbV
    io.wk_lsu_phy_c_o := csrU.io.cdb_rd_phy
    io.wk_lsu_sel_c_o := cCdbV
  }
  memRs.io.wk_lsu_phy_a := (if (cfg.lsuWakeupPredecode && cfg.zicsr)
    (if (cfg.aExt) atomicU.io.cdb_rd_phy else ldq.io.cdb_rd_phy)
    else serialSrc(csrU.io.cdb_rd_phy, atomicU.io.cdb_rd_phy, ldq.io.cdb_rd_phy))
  memRs.io.wk_lsu_phy_l := ldq.io.cdb_rd_phy
  memRs.io.wk_lsu_sel_a := aCdbV
  io.wk_lsu_phy_a_o := memRs.io.wk_lsu_phy_a
  io.wk_lsu_phy_l_o := memRs.io.wk_lsu_phy_l
  io.wk_lsu_sel_a_o := aCdbV
  if (cfg.intCsrSpeculation) {
    val atomicValid = if (cfg.aExt) aCdbV0 else False
    io.wk_lsu_sel_atomic_o := atomicValid
    io.lsu_valid_without_csr_o := atomicValid || ldq.io.cdb_valid
  }
  io.fu_cdb_rob_id        := Mux(aCdbV, serialSrc(csrU.io.cdb_rob_id,   atomicU.io.cdb_rob_id,   ldq.io.cdb_rob_id),   ldq.io.cdb_rob_id)
  io.fu_cdb_rd_phy        := Mux(aCdbV, serialSrc(csrU.io.cdb_rd_phy,   atomicU.io.cdb_rd_phy,   ldq.io.cdb_rd_phy),   ldq.io.cdb_rd_phy)
  io.fu_cdb_rd_arch       := Mux(aCdbV, serialSrc(csrU.io.cdb_rd_arch,  atomicU.io.cdb_rd_arch,  ldq.io.cdb_rd_arch),  ldq.io.cdb_rd_arch)
  io.fu_cdb_rd_value      := Mux(aCdbV, serialSrc(csrU.io.cdb_rd_value, atomicU.io.cdb_rd_value, ldq.io.cdb_rd_value), ldq.io.cdb_rd_value)
  if (cfg.lsuWaySpeculation) {
    if (cfg.lsuForwardSpeculation) {
      val cacheSelect = dc.io.ufp_selected_way & B(cfg.lsuCacheCandidates bits,
        default -> (!aCdbV && !ldq.io.cdb_forward_enable))
      val forwardSelect = ldq.io.cdb_forward_select & B(cfg.lsuForwardCandidates bits,default -> !aCdbV)
      val serialBase = cfg.lsuCacheCandidates + cfg.lsuForwardCandidates
      for (w <- 0 until serialBase)
        memRs.io.cdb_lsu_way_value_flat(w * 32,32 bits) := ldq.io.cdb_way_value_flat(w * 32,32 bits)
      if (cfg.lsuSerialCandidates == 2) {
        memRs.io.cdb_lsu_way_select := cCdbV.asBits ## (aCdbV && !cCdbV).asBits ## forwardSelect ## cacheSelect
        memRs.io.cdb_lsu_way_value_flat(serialBase * 32,32 bits) := atomicU.io.cdb_rd_value
        memRs.io.cdb_lsu_way_value_flat((serialBase + 1) * 32,32 bits) := csrU.io.cdb_rd_value
      } else {
        memRs.io.cdb_lsu_way_select := aCdbV.asBits ## forwardSelect ## cacheSelect
        memRs.io.cdb_lsu_way_value_flat(serialBase * 32,32 bits) :=
          serialSrc(csrU.io.cdb_rd_value,atomicU.io.cdb_rd_value,B(0,32 bits))
      }
    } else {
      memRs.io.cdb_lsu_way_select := dc.io.ufp_selected_way
      for (w <- 0 until cfg.lsuBypassCandidates) {
        val loadValue = ldq.io.cdb_way_value_flat(w * 32,32 bits)
        memRs.io.cdb_lsu_way_value_flat(w * 32,32 bits) :=
          Mux(aCdbV,serialSrc(csrU.io.cdb_rd_value,atomicU.io.cdb_rd_value,loadValue),loadValue)
      }
    }
  }
  io.fu_cdb_rs1_value_dbg := Mux(aCdbV, serialSrc(csrU.io.cdb_rs1_dbg,  atomicU.io.cdb_rs1_dbg,  ldq.io.cdb_rs1_value_dbg), ldq.io.cdb_rs1_value_dbg)
  io.fu_cdb_rs2_value_dbg := Mux(aCdbV, serialSrc(B(0, 32 bits),        atomicU.io.cdb_rs2_dbg,  ldq.io.cdb_rs2_value_dbg), ldq.io.cdb_rs2_value_dbg)
  io.fu_cdb_valid         := aCdbV || ldq.io.cdb_valid
  io.ld_rob_rob_id           := ldq.io.to_rob_rob_id
  io.ld_rob_addr_dbg         := ldq.io.to_rob_addr_dbg
  io.ld_rob_rmask_dbg        := ldq.io.to_rob_rmask_dbg
  io.ld_rob_rdata_dbg        := ldq.io.to_rob_rdata_dbg
  io.ld_rob_valid            := ldq.io.to_rob_valid
  io.ld_rob_violation        := ldq.io.to_rob_violation
  io.ld_rob_violation_rob_id := ldq.io.to_rob_violation_rob_id

  // store_queue dispatch + outputs
  stq.io.from_ds_valid        := adapter.io.to_stq_valid && !atomicSkip
  stq.io.from_ds_uop_rob_id   := io.uop_rob_id
  stq.io.from_ds_uop_fu_opcode := io.uop_fu_opcode
  io.st_rob_rob_id        := stq.io.to_rob_rob_id
  io.st_rob_addr_dbg      := stq.io.to_rob_addr_dbg
  io.st_rob_wmask_dbg     := stq.io.to_rob_wmask_dbg
  io.st_rob_wdata_dbg     := stq.io.to_rob_wdata_dbg
  io.st_rob_rs1_value_dbg := stq.io.to_rob_rs1_value_dbg
  io.st_rob_rs2_value_dbg := stq.io.to_rob_rs2_value_dbg
  io.st_rob_valid         := stq.io.to_rob_valid
  stq.io.to_rob_ready     := io.st_rob_ready

  // ldq <-> stq disambiguation/forward (ldq_stq)
  stq.io.ldq_tracker_flat := ldq.io.ldq_tracker_flat
  if (cfg.storeAgePrecompute) stq.io.ldq_tracker_next_flat := ldq.io.ldq_tracker_next_flat
  if (cfg.storePairPrecompute) stq.io.ldq_addr_write := ldq.io.ldq_addr_write
  stq.io.ldq_addr_flat    := ldq.io.ldq_addr_flat
  stq.io.ldq_rmask_flat   := ldq.io.ldq_rmask_flat
  ldq.io.stq_tail            := stq.io.stq_tail
  ldq.io.stq_deq             := stq.io.stq_deq
  ldq.io.stq_has_conf        := stq.io.has_conflicting_store
  ldq.io.stq_known_conflict  := stq.io.known_conflict
  ldq.io.stq_unknown_older   := stq.io.unknown_older
  ldq.io.stq_forward_en      := stq.io.forward_en
  ldq.io.stq_forward_wdata_flat := stq.io.forward_wdata_flat
  if (cfg.lsuStoreForwardLanes) {
    ldq.io.stq_store_data_flat := stq.io.forward_store_data_flat
    ldq.io.stq_store_select_flat := stq.io.forward_store_select_flat
  }

  if (cfg.lsuBufferForwardLanes) {
    ldq.io.stb_store_data_flat := stb.io.forward_store_data_flat
    ldq.io.stb_store_select_flat := stb.io.forward_store_select_flat
  }


  // stq -> stb (stq_stb)
  val externalStore = if (cfg.mmio) DeviceRegion.external(stq.io.to_stb_addr,cfg) else False
  val externalLoad = if (cfg.mmio) ldq.io.dmem_external else False
  stb.io.from_stq_valid := stq.io.to_stb_valid && !externalStore
  stq.io.to_stb_ready := (if (cfg.mmio) Mux(externalStore,
    peripheral.io.done && peripheral.io.is_write && !peripheral.io.error,stb.io.from_stq_ready) else stb.io.from_stq_ready)
  if (cfg.mmio) {
    val loadOffer = ldq.io.dmem_valid && externalLoad
    val storeOffer = stq.io.to_stb_valid && externalStore && io.device_go &&
      (stq.io.to_rob_rob_id === io.device_go_id) && !stb.io.dmem_valid && arb.io.idle && !peripheral.io.busy
    peripheral.io.start := (loadOffer || storeOffer) && !flush
    peripheral.io.addr := Mux(loadOffer,ldq.io.dmem_original_addr,stq.io.device_addr)
    peripheral.io.wdata := stq.io.to_stb_wdata
    peripheral.io.rmask := Mux(loadOffer,ldq.io.dmem_rmask,B(0,4 bits))
    peripheral.io.wmask := Mux(loadOffer,B(0,4 bits),stq.io.to_stb_wmask)
    peripheral.io.rob_id := Mux(loadOffer,ldq.io.dmem_rob_id,stq.io.to_rob_rob_id)
  }
  stb.io.from_stq_addr  := stq.io.to_stb_addr
  stb.io.from_stq_wmask := stq.io.to_stb_wmask
  stb.io.from_stq_wdata := stq.io.to_stb_wdata

  // ldq <-> stb (ldq_stb)
  stb.io.ldq_addr_flat  := ldq.io.stb_ldq_addr_flat
  stb.io.ldq_rmask_flat := ldq.io.stb_ldq_rmask_flat
  if (cfg.storeBufferPrecompute) {
    stb.io.ldq_addr_write := ldq.io.ldq_addr_write
    stb.io.load_agu_addr := AguLsq.addr(ldq.io.from_agu_data)
    stb.io.load_agu_mask := AguLsq.mask(ldq.io.from_agu_data)
    if (cfg.storePairSplitTag) {
      stb.io.agu_hi0 := memRs.io.to_lsq_hi0; stb.io.agu_hi1 := memRs.io.to_lsq_hi1
      stb.io.agu_c16 := memRs.io.to_lsq_c16
    }
  }
  ldq.io.stb_has_conf   := stb.io.has_conflicting_store
  ldq.io.stb_forward_en := stb.io.forward_en
  ldq.io.stb_forward_wdata_flat := stb.io.forward_wdata_flat

  // ld/st dmem -> arbiter -> dcache
  arb.io.load_valid := (if (cfg.mmio) ldq.io.dmem_cache_valid else ldq.io.dmem_valid)
  arb.io.load_valid_early := ldq.io.dmem_valid_early && (if (cfg.dcacheReadAllBanks) True else !externalLoad)
  ldq.io.dmem_ready := (if (cfg.mmio) Mux(externalLoad,peripheral.io.accepted,arb.io.load_ready) else arb.io.load_ready)
  arb.io.load_addr  := ldq.io.dmem_addr
  arb.io.load_hi0   := ldq.io.dmem_hi0
  arb.io.load_hi1   := ldq.io.dmem_hi1
  arb.io.load_c16   := ldq.io.dmem_c16
  if (cfg.zicsr) {
    ldq.io.agu_clint := memRs.io.to_lsq_clint
    ldq.io.agu_clint_read_sel := memRs.io.to_lsq_clint_read_sel
    arb.io.load_clint := ldq.io.dmem_clint
    arb.io.load_clint_read_sel := ldq.io.dmem_clint_read_sel
  }
  arb.io.load_rmask := ldq.io.dmem_rmask
  arb.io.load_word_oh := ldq.io.dmem_word_oh
  ldq.io.dmem_resp  := arb.io.load_resp || (if (cfg.mmio) peripheral.io.done && !peripheral.io.is_write && !peripheral.io.error else False)
  ldq.io.dmem_rdata := (if (cfg.mmio) Mux(peripheral.io.done,peripheral.io.result,arb.io.load_rdata) else arb.io.load_rdata)
  if (cfg.lsuWaySpeculation) {
    for (w <- 0 until cfg.lsuCacheCandidates) {
      val cached = dc.io.ufp_way_rdata_flat(w * 32,32 bits)
      val internal = if (cfg.zicsr) Mux(clint.io.resp,clint.io.rdata,cached) else cached
      ldq.io.dmem_way_rdata_flat(w * 32,32 bits) :=
        (if (cfg.mmio) Mux(peripheral.io.done,peripheral.io.result,internal) else internal)
    }
  }
  arb.io.store_valid := stb.io.dmem_valid
  stb.io.dmem_ready  := arb.io.store_ready
  arb.io.store_addr  := stb.io.dmem_addr
  arb.io.store_wmask := stb.io.dmem_wmask
  arb.io.store_wdata := stb.io.dmem_wdata

  // RV32A AtomicUnit <-> arbiter atomic port (highest priority)
  if (cfg.aExt) {
    atomicU.io.clk := io.clk; atomicU.io.rst := io.rst; atomicU.io.backend_flush := flush
    atomicU.io.disp_valid   := adapter.io.to_mem_rs_valid && memRs.io.from_ds_ready && io.uop_is_atomic
    atomicU.io.disp_rob_id  := io.uop_rob_id
    atomicU.io.disp_amo_op  := io.uop_amo_op
    atomicU.io.disp_rd_phy  := io.uop_rd_phy
    atomicU.io.disp_rd_arch := io.uop_rd_arch
    atomicU.io.agu_valid := memRs.io.to_lsq_valid
    atomicU.io.agu_data  := memRs.io.to_lsq_data
    atomicU.io.agu_hi0   := memRs.io.to_lsq_hi0
    atomicU.io.agu_hi1   := memRs.io.to_lsq_hi1
    atomicU.io.agu_c16   := memRs.io.to_lsq_c16
    atomicU.io.st_commit_valid := stq.io.to_stb_valid && stb.io.from_stq_ready
    atomicU.io.st_commit_addr  := stq.io.to_stb_addr
    atomicU.io.go        := io.atomic_go
    atomicU.io.go_rob_id := io.atomic_go_rob_id
    atomicU.io.stb_empty := !stb.io.dmem_valid    // stb idle => all older stores in cache
    arb.io.atomic_valid := atomicU.io.cache_valid
    arb.io.atomic_addr  := atomicU.io.cache_addr
    arb.io.atomic_rmask := atomicU.io.cache_rmask
    arb.io.atomic_wmask := atomicU.io.cache_wmask
    arb.io.atomic_wdata := atomicU.io.cache_wdata
    atomicU.io.cache_ready := arb.io.atomic_ready
    atomicU.io.cache_resp  := arb.io.atomic_resp
    atomicU.io.cache_rdata := arb.io.atomic_rdata
  } else {
    arb.io.atomic_valid := False
    arb.io.atomic_addr  := B(0, 32 bits)
    arb.io.atomic_rmask := B(0, 4 bits)
    arb.io.atomic_wmask := B(0, 4 bits)
    arb.io.atomic_wdata := B(0, 32 bits)
  }

  dc.io.ufp_addr  := arb.io.cache_addr
  dc.io.ufp_hi0   := arb.io.cache_hi0
  dc.io.ufp_hi1   := arb.io.cache_hi1
  dc.io.ufp_c16   := arb.io.cache_c16
  dc.io.ufp_req_early := arb.io.cache_req_fire   // enable-only superset: a CLINT cycle is a harmless spurious array read
  dc.io.ufp_word_oh   := arb.io.cache_word_oh
  dc.io.ufp_wdata := arb.io.cache_wdata
  if (cfg.zicsr) {
    // Decode uncached CLINT requests per source before arbitration.
    dc.io.ufp_rmask := arb.io.cache_mem_rmask
    dc.io.ufp_wmask := arb.io.cache_mem_wmask
    clint.io.clk := (if (cfg.lowPower) io.aon_clk else io.clk); clint.io.rst := io.rst
    clint.io.req_valid := arb.io.clint_req_fire
    clint.io.req_addr  := arb.io.cache_addr(15 downto 0)
    clint.io.req_rmask := arb.io.cache_rmask
    if (cfg.clintEarlyWrite) {
      // The granted write selector gates updates; payload selection needs only priority.
      clint.io.req_wmask := Mux(arb.io.atomic_valid,arb.io.atomic_wmask,arb.io.store_wmask)
      clint.io.req_wdata := Mux(arb.io.atomic_valid,arb.io.atomic_wdata,arb.io.store_wdata)
    } else {
      clint.io.req_wmask := arb.io.cache_wmask
      clint.io.req_wdata := arb.io.cache_wdata
    }
    if (cfg.clintCoreRead) clint.io.read_clk := io.clk
    clint.io.read_sel := arb.io.clint_read_sel
    clint.io.read_fire := arb.io.clint_read_fire
    clint.io.request_fire := arb.io.clint_req_fire
    // Decode registered write addresses before the late arbitration controls.
    val storeReady = if (cfg.clintLateWriteGrant) arb.io.load_ready else arb.io.store_ready
    val storeWrite = arb.io.store_valid && storeReady && arb.io.store_wmask.orR
    if (cfg.clintLateWriteGrant) clint.io.write_block := arb.io.load_valid && !arb.io.atomic_valid
    val storeSelect = Clint.writeSelect(arb.io.store_addr, cfg)
    val atomicWrite = arb.io.atomic_valid && arb.io.atomic_ready && arb.io.atomic_wmask.orR
    val atomicSelect = Clint.writeSelect(arb.io.atomic_addr, cfg)
    clint.io.write_sel := (storeSelect & B(Clint.offsets.size bits, default -> storeWrite)) |
      (atomicSelect & B(Clint.offsets.size bits, default -> atomicWrite))
    arb.io.cache_rdata := Mux(clint.io.resp, clint.io.rdata, dc.io.ufp_rdata)
    arb.io.cache_resp  := dc.io.ufp_resp || clint.io.resp
    io.irq_timer := clint.io.irq_timer
    io.irq_soft  := clint.io.irq_soft
    io.mtime     := clint.io.mtime
  } else {
    dc.io.ufp_rmask := arb.io.cache_rmask
    dc.io.ufp_wmask := arb.io.cache_wmask
    arb.io.cache_rdata := dc.io.ufp_rdata
    arb.io.cache_resp  := dc.io.ufp_resp
  }

  // Zicsr: CsrUnit (sibling of the AtomicUnit) + exception reporting
  if (cfg.zicsr) {
    csrU.io.clk := io.clk; csrU.io.rst := io.rst; csrU.io.backend_flush := flush
    csrU.io.disp_valid   := adapter.io.to_mem_rs_valid && memRs.io.from_ds_ready && io.uop_is_csr
    csrU.io.disp_rob_id  := io.uop_rob_id
    csrU.io.disp_ctrl    := io.uop_csr_ctrl
    csrU.io.disp_rd_phy  := io.uop_rd_phy
    csrU.io.disp_rd_arch := io.uop_rd_arch
    csrU.io.agu_valid := memRs.io.to_lsq_valid
    csrU.io.agu_data  := memRs.io.to_lsq_data
    csrU.io.go        := io.atomic_go
    csrU.io.go_rob_id := io.atomic_go_rob_id
    csrU.io.go_older  := io.go_older
    io.csr_acc_instret_adj := csrU.io.acc_instret_adj
    io.csr_acc_en    := csrU.io.acc_en
    io.csr_acc_addr  := csrU.io.acc_addr
    io.csr_acc_wdata := csrU.io.acc_wdata
    io.csr_acc_write := csrU.io.acc_write
    io.csr_acc_op    := csrU.io.acc_op
    csrU.io.acc_rdata   := io.csr_acc_rdata
    csrU.io.acc_illegal := io.csr_acc_illegal
    io.csr_mret_en   := csrU.io.mret_en
    io.csr_mret_held := csrU.io.mret_held
    io.exc_c_valid  := csrU.io.exc_valid
    io.exc_c_rob_id := csrU.io.exc_rob_id
    // misaligned load/store, detected at AGU issue (cause 4 load / 6 store; an atomic
    // reports 4 -- it is MEM_LW-shaped here -- where the spec says 6 for AMO/SC)
    io.exc_a_valid  := memRs.io.to_lsq_valid && memRs.io.to_lsq_misaligned
    io.exc_a_rob_id := AguLsq.robId(memRs.io.to_lsq_data, cfg)
    io.exc_a_cause  := Mux(memRs.io.to_lsq_is_store, B(6, 4 bits), B(4, 4 bits))
    io.exc_a_tval   := AguLsq.addr(memRs.io.to_lsq_data)
    if (cfg.mmio) {
      when(peripheral.io.done && peripheral.io.error) {
        io.exc_a_valid := True; io.exc_a_rob_id := peripheral.io.done_rob_id
        io.exc_a_cause := Mux(peripheral.io.is_write,B(7,4 bits),B(5,4 bits))
        io.exc_a_tval := peripheral.io.done_addr
      }
      if (cfg.aExt) when(atomicU.io.device_fault) {
        io.exc_a_valid := True; io.exc_a_rob_id := atomicU.io.device_fault_id
        io.exc_a_cause := atomicU.io.device_fault_cause; io.exc_a_tval := atomicU.io.device_fault_addr
      }
    }
  }

  // dcache dfp -> external
  io.dfp_addr  := dc.io.dfp_addr
  io.dfp_read  := dc.io.dfp_read
  io.dfp_write := dc.io.dfp_write
  io.dfp_wdata := dc.io.dfp_wdata
  if (cfg.bmemEarlyAddress) {
    io.dfp_read_addr := dc.io.dfp_read_addr
    io.dfp_write_addr := dc.io.dfp_write_addr
  }
  if (cfg.bmemBeatSpeculation) {
    dc.io.dfp_write_beat := io.dfp_write_beat
    io.dfp_wdata_beat := dc.io.dfp_wdata_beat
  }
  dc.io.dfp_ready  := io.dfp_ready
  dc.io.dfp_raddr  := io.dfp_raddr
  dc.io.dfp_rdata  := io.dfp_rdata
  dc.io.dfp_rvalid := io.dfp_rvalid

  // perf taps
  io.dbg_stb_full          := stb.io.dbg_full
  io.dbg_stq_want_dequeue  := stq.io.dbg_want_dequeue
  io.dbg_stq_counter       := stq.io.dbg_counter
  io.dbg_stq_rd_ptr_actual := stq.io.dbg_rd_ptr_actual
  io.dbg_stq_addr_valid_flat := stq.io.dbg_addr_valid_flat
  io.dbg_ldq_valid_flat      := ldq.io.dbg_valid_flat
  io.dbg_ldq_addr_valid_flat := ldq.io.dbg_addr_valid_flat
  io.dbg_ldq_issued_flat     := ldq.io.dbg_issued_flat
  io.dbg_ldq_issue_en        := ldq.io.dbg_issue_en
  io.dbg_dc_stall := dc.io.dbg_stall
  io.dbg_dc_hit   := dc.io.dbg_hit
  io.dbg_dc_rmask := dc.io.dbg_rmask
  io.dbg_dc_wmask := dc.io.dbg_wmask
  io.dbg_ld_dmem_resp := arb.io.load_resp
}
