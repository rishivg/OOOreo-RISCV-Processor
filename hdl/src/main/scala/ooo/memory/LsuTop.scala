package ooo.memory

import spinal.core._
import ooo.CpuConfig
import ooo.execute.{MemRs, BypassT}

/** SpinalHDL port of `hdl/memory/lsu_top.sv` -- the load/store unit cluster.
  *
  * Instantiates the validated SpinalHDL leaves (LsuAdapter, MemRs, LoadQueue,
  * StoreQueue, StoreBuf, DmemArbiter, Dcache) and wires the internal LSU interfaces
  * flat. The dispatch uop is fanned out (mem_rs entry built in the shim; ldq/stq
  * take the relevant uop fields). FIRST SpinalHDL subsystem composing previously
  * swap-validated subsystems.
  *
  * Named lsu_top_spinal; sim/swap_shims/lsu_top.sv carries the external SV
  * interfaces, builds mem_rs_entry + uop fields, and recreates the perf_monitor-
  * tapped sub-instance scopes (stb_i / stq_i / ldq_i / dcache_i.dcache_ctrl_i).
  */
class LsuTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("lsu_top_spinal")
  val CDBW = cfg.cdbWidth      // [CDB_WIDTH]
  val NFB  = cfg.numFastBypass // 2
  val PIDX = cfg.prfIdx        // 6
  val RIDX = cfg.robIdx        // 6
  val AIDX = cfg.arfIdx        // 5
  val LDQ  = cfg.ldqDepth      // 8
  val STQ  = cfg.stqDepth      // 8
  val MEMEW = 56               // mem_rs_entry_t
  val BNW  = 1 + PIDX + 32     // bypass_network_t = 39
  val BPW  = BypassT.width(cfg) // bypass_t width

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    // dispatch (from_ds) -- uop pre-extracted in the shim
    val from_ds_valid       = in  Bool()
    val from_ds_ready       = out Bool()
    val mem_rs_entry_flat   = in  Bits (MEMEW bits)
    val uop_rob_id          = in  Bits (RIDX bits)
    val uop_fu_opcode       = in  Bits (4 bits)
    val uop_rd_arch         = in  Bits (AIDX bits)
    val uop_rd_phy          = in  Bits (PIDX bits)
    val uop_is_atomic       = in  Bool()              // RV32A (aExt)
    val uop_amo_op          = in  Bits (4 bits)       // RV32A (aExt)
    // RV32A: ROB head handshake -> AtomicUnit
    val atomic_go           = in  Bool()
    val atomic_go_rob_id    = in  Bits (RIDX bits)
    // to_prf (mem_rs single read port)
    val to_prf_rs1_phy   = out Bits (PIDX bits)
    val to_prf_rs2_phy   = out Bits (PIDX bits)
    val to_prf_rs_bypass = out Bits (BPW bits)
    val to_prf_rs1_value = in  Bits (32 bits)
    val to_prf_rs2_value = in  Bits (32 bits)
    // cdb_itf.rs[CDB_WIDTH] (mem_rs wakeup)
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits)
    val cdb_valid       = in Bits (CDBW bits)
    // alu_bypass[NUM_FAST_BYPASS]
    val alu_bypass_flat = in Bits (NFB * BNW bits)
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
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rdata  = in  Bits (256 bits)
    val dfp_rvalid = in  Bool()
    // perf_monitor taps (surfaced into named sub-scopes by the shim)
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

  // ---- sub-modules ----
  val adapter = new LsuAdapter(cfg)
  val memRs   = new MemRs(cfg)
  val ldq     = new LoadQueue(cfg)
  val stq     = new StoreQueue(cfg)
  val stb     = new StoreBuf(cfg)
  val arb     = new DmemArbiter(cfg)
  val dc      = new Dcache(cfg)
  val atomicU = if (cfg.aExt) new AtomicUnit(cfg) else null

  // clocks / resets
  for (m <- Seq(memRs.io.clk, ldq.io.clk, stq.io.clk, stb.io.clk, arb.io.clk, dc.io.clk)) m := io.clk
  memRs.io.rst := io.rst || flush          // mem_rs reset folds in flush (per SV lsu_top)
  ldq.io.rst := io.rst; ldq.io.backend_flush := flush
  stq.io.rst := io.rst; stq.io.backend_flush := flush
  stb.io.rst := io.rst
  arb.io.rst := io.rst; arb.io.backend_flush := flush
  dc.io.rst  := io.rst

  // ---- dispatch fan-out (lsu_adapter handshake) ----
  adapter.io.from_ds_valid   := io.from_ds_valid
  io.from_ds_ready           := adapter.io.from_ds_ready
  adapter.io.to_mem_rs_ready := memRs.io.from_ds_ready
  adapter.io.to_ldq_ready    := ldq.io.from_ds_ready
  adapter.io.to_stq_ready    := stq.io.from_ds_ready

  // ---- mem_rs ----
  memRs.io.from_ds_valid      := adapter.io.to_mem_rs_valid
  memRs.io.from_ds_entry_flat := io.mem_rs_entry_flat
  memRs.io.to_prf_rs1_phy   <> io.to_prf_rs1_phy
  memRs.io.to_prf_rs2_phy   <> io.to_prf_rs2_phy
  memRs.io.to_prf_rs_bypass <> io.to_prf_rs_bypass
  memRs.io.to_prf_rs1_value := io.to_prf_rs1_value
  memRs.io.to_prf_rs2_value := io.to_prf_rs2_value
  memRs.io.cdb_rd_phy_flat  := io.cdb_rd_phy_flat
  memRs.io.cdb_valid        := io.cdb_valid
  memRs.io.alu_bypass_flat  := io.alu_bypass_flat

  // ---- agu_lsq (mem_rs -> ldq + stq) ----
  ldq.io.from_agu_valid := memRs.io.to_lsq_valid
  ldq.io.from_agu_data  := memRs.io.to_lsq_data
  stq.io.from_agu_valid := memRs.io.to_lsq_valid
  stq.io.from_agu_data  := memRs.io.to_lsq_data

  // RV32A: atomics still allocate in mem_rs (operand read + AGU) but must NOT create
  // LDQ/STQ entries -- the AtomicUnit owns their memory effect.
  val atomicSkip = if (cfg.aExt) io.uop_is_atomic else False

  // ---- load_queue dispatch + outputs ----
  ldq.io.from_ds_valid        := adapter.io.to_ldq_valid && !atomicSkip
  ldq.io.from_ds_uop_rob_id   := io.uop_rob_id
  ldq.io.from_ds_uop_fu_opcode := io.uop_fu_opcode
  ldq.io.from_ds_uop_rd_arch  := io.uop_rd_arch
  ldq.io.from_ds_uop_rd_phy   := io.uop_rd_phy
  // RV32A: AtomicUnit result takes priority on the LSU CDB lane (atomics execute at
  // the ROB head; a younger load's CDB does not fire that cycle on the serial path).
  val aCdbV = if (cfg.aExt) atomicU.io.cdb_valid else False
  io.fu_cdb_rob_id        := Mux(aCdbV, if (cfg.aExt) atomicU.io.cdb_rob_id   else ldq.io.cdb_rob_id,   ldq.io.cdb_rob_id)
  io.fu_cdb_rd_phy        := Mux(aCdbV, if (cfg.aExt) atomicU.io.cdb_rd_phy   else ldq.io.cdb_rd_phy,   ldq.io.cdb_rd_phy)
  io.fu_cdb_rd_arch       := Mux(aCdbV, if (cfg.aExt) atomicU.io.cdb_rd_arch  else ldq.io.cdb_rd_arch,  ldq.io.cdb_rd_arch)
  io.fu_cdb_rd_value      := Mux(aCdbV, if (cfg.aExt) atomicU.io.cdb_rd_value else ldq.io.cdb_rd_value, ldq.io.cdb_rd_value)
  io.fu_cdb_rs1_value_dbg := Mux(aCdbV, if (cfg.aExt) atomicU.io.cdb_rs1_dbg  else ldq.io.cdb_rs1_value_dbg, ldq.io.cdb_rs1_value_dbg)
  io.fu_cdb_rs2_value_dbg := Mux(aCdbV, if (cfg.aExt) atomicU.io.cdb_rs2_dbg  else ldq.io.cdb_rs2_value_dbg, ldq.io.cdb_rs2_value_dbg)
  io.fu_cdb_valid         := aCdbV || ldq.io.cdb_valid
  io.ld_rob_rob_id           := ldq.io.to_rob_rob_id
  io.ld_rob_addr_dbg         := ldq.io.to_rob_addr_dbg
  io.ld_rob_rmask_dbg        := ldq.io.to_rob_rmask_dbg
  io.ld_rob_rdata_dbg        := ldq.io.to_rob_rdata_dbg
  io.ld_rob_valid            := ldq.io.to_rob_valid
  io.ld_rob_violation        := ldq.io.to_rob_violation
  io.ld_rob_violation_rob_id := ldq.io.to_rob_violation_rob_id

  // ---- store_queue dispatch + outputs ----
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

  // ---- ldq <-> stq disambiguation/forward (ldq_stq) ----
  stq.io.ldq_tracker_flat := ldq.io.ldq_tracker_flat
  stq.io.ldq_addr_flat    := ldq.io.ldq_addr_flat
  stq.io.ldq_rmask_flat   := ldq.io.ldq_rmask_flat
  ldq.io.stq_tail            := stq.io.stq_tail
  ldq.io.stq_deq             := stq.io.stq_deq
  ldq.io.stq_has_conf        := stq.io.has_conflicting_store
  ldq.io.stq_known_conflict  := stq.io.known_conflict
  ldq.io.stq_unknown_older   := stq.io.unknown_older
  ldq.io.stq_forward_en      := stq.io.forward_en
  ldq.io.stq_forward_wdata_flat := stq.io.forward_wdata_flat

  // ---- stq -> stb (stq_stb) ----
  stb.io.from_stq_valid := stq.io.to_stb_valid
  stq.io.to_stb_ready   := stb.io.from_stq_ready
  stb.io.from_stq_addr  := stq.io.to_stb_addr
  stb.io.from_stq_wmask := stq.io.to_stb_wmask
  stb.io.from_stq_wdata := stq.io.to_stb_wdata

  // ---- ldq <-> stb (ldq_stb) ----
  stb.io.ldq_addr_flat  := ldq.io.stb_ldq_addr_flat
  stb.io.ldq_rmask_flat := ldq.io.stb_ldq_rmask_flat
  ldq.io.stb_has_conf   := stb.io.has_conflicting_store

  // ---- ld/st dmem -> arbiter -> dcache ----
  arb.io.load_valid := ldq.io.dmem_valid
  ldq.io.dmem_ready := arb.io.load_ready
  arb.io.load_addr  := ldq.io.dmem_addr
  arb.io.load_rmask := ldq.io.dmem_rmask
  ldq.io.dmem_resp  := arb.io.load_resp
  ldq.io.dmem_rdata := arb.io.load_rdata
  arb.io.store_valid := stb.io.dmem_valid
  stb.io.dmem_ready  := arb.io.store_ready
  arb.io.store_addr  := stb.io.dmem_addr
  arb.io.store_wmask := stb.io.dmem_wmask
  arb.io.store_wdata := stb.io.dmem_wdata

  // ---- RV32A AtomicUnit <-> arbiter atomic port (highest priority) ----
  if (cfg.aExt) {
    atomicU.io.clk := io.clk; atomicU.io.rst := io.rst; atomicU.io.backend_flush := flush
    atomicU.io.disp_valid   := adapter.io.to_mem_rs_valid && memRs.io.from_ds_ready && io.uop_is_atomic
    atomicU.io.disp_rob_id  := io.uop_rob_id
    atomicU.io.disp_amo_op  := io.uop_amo_op
    atomicU.io.disp_rd_phy  := io.uop_rd_phy
    atomicU.io.disp_rd_arch := io.uop_rd_arch
    atomicU.io.agu_valid := memRs.io.to_lsq_valid
    atomicU.io.agu_data  := memRs.io.to_lsq_data
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
  dc.io.ufp_rmask := arb.io.cache_rmask
  dc.io.ufp_wmask := arb.io.cache_wmask
  dc.io.ufp_wdata := arb.io.cache_wdata
  arb.io.cache_rdata := dc.io.ufp_rdata
  arb.io.cache_resp  := dc.io.ufp_resp

  // ---- dcache dfp -> external ----
  io.dfp_addr  := dc.io.dfp_addr
  io.dfp_read  := dc.io.dfp_read
  io.dfp_write := dc.io.dfp_write
  io.dfp_wdata := dc.io.dfp_wdata
  dc.io.dfp_ready  := io.dfp_ready
  dc.io.dfp_raddr  := io.dfp_raddr
  dc.io.dfp_rdata  := io.dfp_rdata
  dc.io.dfp_rvalid := io.dfp_rvalid

  // ---- perf taps ----
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
