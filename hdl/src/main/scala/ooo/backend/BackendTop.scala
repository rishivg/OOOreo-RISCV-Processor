package ooo.backend

import spinal.core._
import ooo.CpuConfig
import ooo.rename.{Rat, FreeList, Rob, Rrf}
import ooo.execute.{IntRs, IntmRs, BranchTop, Prf, RsEntryLayout}
import ooo.memory.LsuTop
import ooo.csr.Csr

/** Backend integration: decode, rename, issue, execution, and retirement. */
class BackendTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("backend_top_spinal")
  val IDW = cfg.idWidth; val CDBW = cfg.cdbWidth
  val PIDX = cfg.prfIdx; val AIDX = cfg.arfIdx; val RIDX = cfg.robIdx
  val PROV = cfg.bpProvW
  val RVFIW = cfg.rvfiDbgW
  val REGW = cfg.intmRsRegW; val CDBR = cfg.fuCdbRegW
  val FBRW = cfg.fuBrRegW
  val PPI = cfg.robPtrIdx + 1  // rob head/tail ptr width (6)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = out Bool(); val backend_redirect_pc = out Bits (32 bits)
    val flush_causes = if (cfg.distributedFlush) out Bits(6 bits) else null
    val from_fifo_valid = in Bool(); val from_fifo_ready = out Bool()
    val ff_decoded_flat = if (cfg.iqParallelDecode) in Bits(IDW * ooo.backend.decode.DecoderPayload.width(cfg) bits) else null
    val ff_inst_flat = in Bits (IDW * 32 bits); val ff_inst_raw_flat = in Bits (IDW * 32 bits)
    val ff_is_compressed = in Bits (IDW bits); val ff_predict_taken = in Bits (IDW bits)
    val ff_predict_target_flat = in Bits (IDW * 32 bits); val ff_pc_flat = in Bits (IDW * 32 bits)
    val ff_valid_slots = in Bits (IDW bits); val ff_kp_flat = in Bits (IDW * log2Up(cfg.ifWidth) bits)
    val ff_prov_flat = in Bits (IDW * PROV bits)
    // IQ enqueue-time pre-decode (see InstQueue.preDecode / IdStage)
    val ff_pre_rs_type_flat = in Bits (IDW * 2 bits)
    val ff_pre_is_store     = in Bits (IDW bits)
    val ff_pre_is_atomic    = in Bits (IDW bits)
    val ff_pre_has_rd       = in Bits (IDW bits)
    // dcache dfp
    val dfp_addr = out Bits (32 bits); val dfp_read = out Bool(); val dfp_write = out Bool()
    val dfp_wdata = out Bits (256 bits); val dfp_ready = in Bool(); val dfp_raddr = in Bits (32 bits)
    val dfp_write_beat = if (cfg.bmemBeatSpeculation) in Bits(2 bits) else null
    val dfp_wdata_beat = if (cfg.bmemBeatSpeculation) out Bits(64 bits) else null
    val dfp_read_addr = if (cfg.bmemEarlyAddress) out Bits(32 bits) else null
    val dfp_write_addr = if (cfg.bmemEarlyAddress) out Bits(32 bits) else null
    val dfp_rdata = in Bits (256 bits); val dfp_rvalid = in Bool()
    val to_bp_update_en = out Bool(); val to_bp_pc = out Bits (32 bits); val to_bp_fu_opcode = out Bits (4 bits)
    val to_bp_branch_taken = out Bool(); val to_bp_target = out Bits (32 bits); val to_bp_kp = out Bits (log2Up(cfg.ifWidth) bits)
    val to_bp_is_call = out Bool(); val to_bp_is_ret = out Bool(); val to_bp_is_compressed = out Bool()
    val to_bp_prov = out Bits (PROV bits)
    // externalised fu_div
    val div_prv_valid = out Bool(); val div_prv_ready = in Bool()
    val div_nxt_valid = in Bool(); val div_nxt_ready = out Bool()
    val div_iss_in = out Bits (REGW bits); val div_cdb_out = in Bits (CDBR bits)
    // perf dbg
    val dbg_fu_br_valid = out Bool(); val dbg_miss_predict = out Bool(); val dbg_reg_out = out Bits (FBRW bits)
    val dbg_id_rob_valid = out Bool(); val dbg_id_rob_ready = out Bool(); val dbg_id_rob_inst_valid = out Bits (IDW bits)
    val dbg_mul_start = out Bool(); val dbg_ldq_violation = out Bool()
    val dbg_stb_full = out Bool(); val dbg_stq_want_dequeue = out Bool()
    val dbg_stq_counter = out Bits (cfg.stqIdx + 1 bits); val dbg_stq_rd_ptr_actual = out Bits (cfg.stqIdx bits)
    val dbg_stq_addr_valid_flat = out Bits (cfg.stqDepth bits)
    val dbg_ldq_valid_flat = out Bits (cfg.ldqDepth bits); val dbg_ldq_addr_valid_flat = out Bits (cfg.ldqDepth bits)
    val dbg_ldq_issued_flat = out Bits (cfg.ldqDepth bits); val dbg_ldq_issue_en = out Bool()
    val dbg_dc_stall = out Bool(); val dbg_dc_hit = out Bool(); val dbg_dc_rmask = out Bits (4 bits); val dbg_dc_wmask = out Bits (4 bits)
    val dbg_ld_dmem_resp = out Bool()
    val dbg_viol_flush = out Bool(); val dbg_pop = out Bool(); val dbg_empty = out Bool(); val dbg_branch_flush = out Bool()
    val dbg_commit_instr = out Bits (IDW bits); val dbg_head_ptr_reg = out Bits (PPI bits); val dbg_tail_ptr_reg = out Bits (PPI bits)
    val rvfi_itf_flat = out Bits (IDW * RVFIW bits)
    // Zicsr: external (platform) interrupt line -> mip.MEIP
    val aon_clk = if (cfg.lowPower) in Bool() else null
    val sleep_request = if (cfg.lowPower) out Bool() else null
    val wfi_wake = if (cfg.lowPower) out Bool() else null
    val memory_idle = if (cfg.lowPower) out Bool() else null
    val mmio = if (cfg.mmio) ooo.memory.MmioMaster() else null
    val irq_ext = if (cfg.zicsr) in Bool() else null
    val fence_i_request = if (cfg.zicsr) out Bool() else null
    val fence_i_done = if (cfg.zicsr) in Bool() else null
    val cache_flush_request = if (cfg.zicsr) in Bool() else null
    val cache_flush_done = if (cfg.zicsr) out Bool() else null
  }
  noIoPrefix()

  // uop bundle (all fields Bits for clean ## packing)
  case class Uop() extends Bundle {
    val valid = Bits(1 bits); val pc = Bits(32 bits); val inst = Bits(32 bits); val is_compressed = Bits(1 bits)
    val rs_type = Bits(2 bits); val fu_type = Bits(2 bits); val fu_opcode = Bits(4 bits)
    val op1_sel = Bits(1 bits); val op2_sel = Bits(1 bits)
    val rd_phy = Bits(PIDX bits); val rs1_phy = Bits(PIDX bits); val rs2_phy = Bits(PIDX bits)
    val rs1_valid = Bits(1 bits); val rs2_valid = Bits(1 bits); val imm = Bits(32 bits); val rob_id = Bits(RIDX bits)
    val rd_arch = Bits(AIDX bits); val rs1_arch = Bits(AIDX bits); val rs2_arch = Bits(AIDX bits)
    val predict_taken = Bits(1 bits); val predict_target = Bits(32 bits); val kp = Bits(log2Up(cfg.ifWidth) bits); val inst_raw = Bits(32 bits)
    val prov = Bits(PROV bits)
    val is_atomic = Bits(1 bits); val amo_op = Bits(4 bits)   // RV32A (aExt)
    val is_csr = Bits(1 bits); val csr_ctrl = Bits(20 bits)   // Zicsr
  }
  private val intLayout = RsEntryLayout.int(cfg)
  private val intmLayout = RsEntryLayout.intm(cfg)
  private val memLayout = RsEntryLayout.mem(cfg)
  private val brLayout = RsEntryLayout.br(cfg)
  def intEntry(u: Uop): Bits = intLayout.pack(u)
  def intmEntry(u: Uop): Bits = intmLayout.pack(u)
  def memEntry(u: Uop): Bits = memLayout.pack(u)
  def brEntry(u: Uop): Bits = brLayout.pack(u)
  def rvfiBits(u: Uop)  = B(0, 1 bits) ## B(0, 64 bits) ## u.inst_raw ## u.rs1_arch ## u.rs2_arch ##
    B(0, 32 bits) ## B(0, 32 bits) ## u.rd_arch ## B(0, 32 bits) ## B(0, 5 bits) ## B(0, 32 bits) ##
    u.pc ## u.predict_target ## B(0, 32 bits) ## B(0, 4 bits) ## B(0, 4 bits) ## B(0, 32 bits) ## B(0, 32 bits) ## B(0, 1 bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val flush = Bool()                       // rob.backend_flush
    val flushCauses = if (cfg.distributedFlush) Bits(6 bits) else null
    def localFlush(): Bool = if (cfg.distributedFlush) {
      val replica=new ooo.common.FlushReplica
      replica.io.causes:=flushCauses
      replica.io.flush
    } else flush

    // sub-components
    val id = new IdStage(cfg);     id.io.clk := io.clk; id.io.rst := io.rst
    val rat = new Rat(cfg);        rat.io.clk := io.clk; rat.io.rst := io.rst; rat.io.backend_flush := localFlush()
    val fl = new FreeList(cfg);    fl.io.clk := io.clk; fl.io.rst := io.rst; fl.io.backend_flush := localFlush()
    val rob = new Rob(cfg);        rob.io.clk := io.clk; rob.io.rst := io.rst
    val rrf = new Rrf(cfg);        rrf.io.clk := io.clk; rrf.io.rst := io.rst
    val ds = new DsStage(cfg)
    val intRs = new IntRs(cfg);    intRs.io.clk := io.clk; intRs.io.rst := io.rst || localFlush()
    val intmRs = new IntmRs(cfg);  intmRs.io.clk := io.clk; intmRs.io.rst := io.rst || localFlush()
    val br = new BranchTop(cfg);   br.io.clk := io.clk; br.io.rst := io.rst; br.io.backend_flush := localFlush()
    val lsu = new LsuTop(cfg);     lsu.io.clk := io.clk; lsu.io.rst := io.rst; lsu.io.backend_flush := localFlush()
    val prf = new Prf(cfg);        prf.io.clk := io.clk
    val csr = if (cfg.zicsr) new Csr(cfg) else null
    if (cfg.zicsr) { csr.io.clk := io.clk; csr.io.rst := io.rst }

    flush := rob.io.backend_flush
    if (cfg.distributedFlush) { flushCauses:=rob.io.flush_causes;io.flush_causes:=flushCauses }
    io.backend_flush := rob.io.backend_flush
    io.backend_redirect_pc := rob.io.backend_redirect_pc

    // id_stage <-> from_fifo / rat / fl / rob
    id.io.from_fifo_valid := io.from_fifo_valid
    id.io.from_fifo_inst_flat := io.ff_inst_flat
    if (cfg.iqParallelDecode) id.io.from_fifo_decoded_flat := io.ff_decoded_flat
    id.io.from_fifo_valid_slots := io.ff_valid_slots
    id.io.from_fifo_pre_rs_type_flat := io.ff_pre_rs_type_flat
    id.io.from_fifo_pre_is_store  := io.ff_pre_is_store
    id.io.from_fifo_pre_is_atomic := io.ff_pre_is_atomic
    id.io.from_fifo_pre_has_rd    := io.ff_pre_has_rd
    io.from_fifo_ready := id.io.from_fifo_ready
    val dispatchValid = id.io.nxt_valid
    val dispatchReady = ds.io.prv_ready
    id.io.nxt_ready := dispatchReady
    id.io.to_fl_ready := fl.io.from_id_ready
    id.io.to_fl_free_idx_flat := fl.io.from_id_free_idx_flat
    id.io.to_rob_ready := rob.io.from_id_ready

    // rat
    rat.io.from_id_rs1_arch_flat := id.io.rs1_arch_flat
    rat.io.from_id_rs2_arch_flat := id.io.rs2_arch_flat
    rat.io.from_id_write_en := id.io.to_rat_write_en
    // early rename intent for the RAT read forward select: write_en WITHOUT the
    // fl/rob/dispatch readies (don't-care equivalent -- every read consumer latches
    // only when those readies are all true; see the Rat port note)
    rat.io.from_id_fwd_en := Cat((0 until IDW).map(i =>
      io.from_fifo_valid && id.io.uops_valid(i) && (id.io.rd_arch_flat(i * AIDX, AIDX bits) =/= 0)))
    rat.io.from_id_rd_arch_flat := id.io.rd_arch_flat
    rat.io.from_id_rd_phy_flat := fl.io.from_id_free_idx_flat   // to_rat.rd_phy = free_idx
    rat.io.rrf_mem_flat := rrf.io.rrf_mem_flat

    // free list
    fl.io.from_id_valid := id.io.to_fl_valid
    fl.io.from_rrf_valid := rrf.io.to_fl_valid
    fl.io.from_rrf_stale_idx_flat := rrf.io.to_fl_stale_idx_flat

    // rob (id side)
    rob.io.from_id_valid := id.io.to_rob_valid
    rob.io.from_id_inst_valid := id.io.uops_valid
    rob.io.from_id_rd_phy_flat := id.io.uop_rd_phy_flat
    rob.io.from_id_rd_arch_flat := id.io.rd_arch_flat
    rob.io.from_id_is_store := id.io.is_store
    if (cfg.mmio) {
      rob.io.from_id_memory := Cat((0 until IDW).map(i =>
        sl(id.io.rs_type_flat,i,2) === B"2'b11" && !id.io.is_atomic(i) && !id.io.is_csr(i)))
      rob.io.from_id_compressed := io.ff_is_compressed
      rob.io.device_mark := lsu.io.device_mark; rob.io.device_mark_id := lsu.io.device_mark_id
      lsu.io.device_go := rob.io.device_go; lsu.io.device_go_id := rob.io.device_go_id
      io.mmio <> lsu.io.mmio
    }
    if (cfg.lowPower) {
      lsu.io.aon_clk := io.aon_clk
      rob.io.wfi_held := lsu.io.csr_wfi_held
      io.sleep_request := rob.io.sleep_request
      io.wfi_wake := csr.io.wfi_wake
      io.memory_idle := lsu.io.memory_idle
    }
    // Zicsr: CSR/mret entries are "serial at head" exactly like atomics -> same ROB bit
    rob.io.from_id_is_atomic := (if (cfg.zicsr) id.io.is_atomic | id.io.is_csr else id.io.is_atomic)

    // rrf (rob side)
    rrf.io.from_rob_valid := rob.io.to_rrf_valid
    rrf.io.from_rob_rd_phy_flat := rob.io.to_rrf_rd_phy_flat
    rrf.io.from_rob_rd_arch_flat := rob.io.to_rrf_rd_arch_flat

    // build uop[ID] from id decode + rat read + rob_id + packet
    val ffInst = io.ff_inst_flat.subdivideIn(IDW slices)
    val ffInstRaw = io.ff_inst_raw_flat.subdivideIn(IDW slices)
    val ffPredTgt = io.ff_predict_target_flat.subdivideIn(IDW slices)
    val ffPc = io.ff_pc_flat.subdivideIn(IDW slices)
    val ffKp = io.ff_kp_flat.subdivideIn(IDW slices)
    val ffProv = io.ff_prov_flat.subdivideIn(IDW slices)
    val ratRs1Phy = rat.io.from_id_rs1_phy_flat.subdivideIn(IDW slices)
    val ratRs2Phy = rat.io.from_id_rs2_phy_flat.subdivideIn(IDW slices)
    val robId = rob.io.from_id_rob_id_flat.subdivideIn(IDW slices)
    def sl(b: Bits, i: Int, w: Int) = b(i * w, w bits)

    val uops = Vec(Uop(), IDW)
    for (i <- 0 until IDW) {
      val u = uops(i)
      u.valid := id.io.uops_valid(i, 1 bits)
      u.pc := ffPc(i); u.inst := ffInst(i); u.is_compressed := io.ff_is_compressed(i, 1 bits)
      u.rs_type := sl(id.io.rs_type_flat, i, 2); u.fu_type := sl(id.io.fu_type_flat, i, 2)
      u.fu_opcode := sl(id.io.fu_opcode_flat, i, 4); u.op1_sel := id.io.op1_sel(i, 1 bits); u.op2_sel := id.io.op2_sel(i, 1 bits)
      u.rd_phy := sl(id.io.uop_rd_phy_flat, i, PIDX); u.rs1_phy := ratRs1Phy(i); u.rs2_phy := ratRs2Phy(i)
      u.rs1_valid := rat.io.from_id_rs1_valid(i, 1 bits); u.rs2_valid := rat.io.from_id_rs2_valid(i, 1 bits)
      u.imm := sl(id.io.imm_flat, i, 32); u.rob_id := robId(i)
      u.rd_arch := sl(id.io.rd_arch_flat, i, AIDX); u.rs1_arch := sl(id.io.rs1_arch_flat, i, AIDX); u.rs2_arch := sl(id.io.rs2_arch_flat, i, AIDX)
      u.predict_taken := io.ff_predict_taken(i, 1 bits); u.predict_target := ffPredTgt(i); u.kp := ffKp(i); u.inst_raw := ffInstRaw(i)
      u.prov := ffProv(i)
      u.is_atomic := id.io.is_atomic(i, 1 bits); u.amo_op := sl(id.io.amo_op_flat, i, 4)
      if (cfg.zicsr) { u.is_csr := id.io.is_csr(i, 1 bits); u.csr_ctrl := sl(id.io.csr_ctrl_flat, i, 20) }
      else { u.is_csr := 0; u.csr_ctrl := 0 }
    }
    // NoRvfi product config: the record keeps ONLY the load-bearing pc field
    // (rvfiArr.pc_rdata sources the violation/atomic redirect PC); every other
    // field ties to 0 so const-prop sweeps its storage inside the ROB.
    def rvfiBitsPcOnly(u: Uop) = B(0, 1 bits) ## B(0, 64 bits) ## B(0, 32 bits) ## B(0, AIDX bits) ## B(0, AIDX bits) ##
      B(0, 32 bits) ## B(0, 32 bits) ## B(0, AIDX bits) ## B(0, 32 bits) ## B(0, 5 bits) ## B(0, 32 bits) ##
      u.pc ## B(0, 32 bits) ## B(0, 32 bits) ## B(0, 4 bits) ## B(0, 4 bits) ## B(0, 32 bits) ## B(0, 32 bits) ## B(0, 1 bits)
    rob.io.from_id_rvfi_dbg_flat := Cat((0 until IDW).map(i =>
      if (cfg.rvfi) rvfiBits(uops(i)) else rvfiBitsPcOnly(uops(i))))

    // ds_stage
    ds.io.prv_valid := dispatchValid
    // Faulting instructions are already complete in the ROB. Sending them to
    // execution can create zero-mask memory requests on a speculative path.
    ds.io.uops_valid := (if (cfg.zicsr) id.io.uops_valid & ~id.io.exc_valid else id.io.uops_valid)
    ds.io.rs_type_flat := id.io.rs_type_flat
    ds.io.to_int_rs_ready := intRs.io.from_ds_ready
    ds.io.to_intm_rs_ready := intmRs.io.from_ds_ready
    ds.io.to_br_rs_ready := br.io.from_ds_ready
    ds.io.to_mem_rs_ready := lsu.io.from_ds_ready

    // per-RS entries
    intRs.io.from_ds_entry_flat := Cat((0 until IDW).map(i => intEntry(uops(i))))
    intRs.io.from_ds_valid := ds.io.to_int_rs_valid
    intmRs.io.from_ds_entry_flat := Cat((0 until IDW).map(i => intmEntry(uops(i))))
    intmRs.io.from_ds_valid := ds.io.to_intm_rs_valid
    val brUop = uops(ds.io.br_sel); val memUop = uops(ds.io.mem_sel)
    br.io.from_ds_valid := ds.io.to_br_rs_valid
    br.io.from_ds_entry_flat := brEntry(brUop)
    br.io.uop_rob_id := brUop.rob_id; br.io.uop_pc := brUop.pc; br.io.uop_fu_opcode := brUop.fu_opcode
    br.io.uop_kp := brUop.kp; br.io.uop_is_compressed := brUop.is_compressed(0); br.io.uop_inst := brUop.inst
    br.io.uop_prov := brUop.prov
    lsu.io.from_ds_valid := ds.io.to_mem_rs_valid
    lsu.io.mem_rs_entry_flat := memEntry(memUop)
    lsu.io.uop_rob_id := memUop.rob_id; lsu.io.uop_fu_opcode := memUop.fu_opcode
    lsu.io.uop_rd_arch := memUop.rd_arch; lsu.io.uop_rd_phy := memUop.rd_phy
    // Qualify serial-operation admission with its own reservation-station ready signal,
    // so unrelated backpressure cannot stall the atomic capture path.
    lsu.io.uop_is_atomic := (0 until IDW).map(i =>
      id.io.is_atomic(i) && id.io.uops_valid(i) && (sl(id.io.rs_type_flat, i, 2) === B"2'b11")).reduce(_ || _)
    lsu.io.uop_amo_op := memUop.amo_op
    lsu.io.atomic_go := rob.io.atomic_go; lsu.io.atomic_go_rob_id := rob.io.atomic_go_rob_id

    // Zicsr: decode exceptions -> ROB, CsrUnit <-> Csr file, traps, interrupts
    if (cfg.zicsr) {
      lsu.io.uop_is_csr := (0 until IDW).map(i =>
        id.io.is_csr(i) && id.io.uops_valid(i) && (sl(id.io.rs_type_flat, i, 2) === B"2'b11")).reduce(_ || _)
      io.fence_i_request := lsu.io.fence_i_request; lsu.io.fence_i_done := io.fence_i_done
      lsu.io.cache_flush_request := io.cache_flush_request; io.cache_flush_done := lsu.io.cache_flush_done
      lsu.io.uop_csr_ctrl := memUop.csr_ctrl
      rob.io.from_id_exc_valid      := id.io.exc_valid
      rob.io.from_id_exc_cause_flat := id.io.exc_cause_flat
      // mtval: the instruction for an illegal op (raw bits, so a compressed illegal
      // reports its 16-bit form), the pc for ebreak, 0 for ecall
      rob.io.from_id_exc_tval_flat := Cat((0 until IDW).map { i =>
        val cause = sl(id.io.exc_cause_flat, i, 4)
        val instBits = if (cfg.rvfi) ffInstRaw(i) else ffInst(i)
        Mux(cause === B(2, 4 bits), instBits, Mux(cause === B(3, 4 bits), ffPc(i), B(0, 32 bits)))
      })
      rob.io.exc_a_valid := lsu.io.exc_a_valid; rob.io.exc_a_rob_id := lsu.io.exc_a_rob_id
      rob.io.exc_a_cause := lsu.io.exc_a_cause; rob.io.exc_a_tval := lsu.io.exc_a_tval
      rob.io.exc_c_valid := lsu.io.exc_c_valid; rob.io.exc_c_rob_id := lsu.io.exc_c_rob_id
      csr.io.acc_en := lsu.io.csr_acc_en; csr.io.acc_addr := lsu.io.csr_acc_addr
      csr.io.acc_wdata := lsu.io.csr_acc_wdata; csr.io.acc_write := lsu.io.csr_acc_write
      csr.io.acc_op := lsu.io.csr_acc_op
      csr.io.acc_instret_adj := lsu.io.csr_acc_instret_adj
      lsu.io.go_older := rob.io.go_older
      lsu.io.csr_acc_rdata := csr.io.acc_rdata; lsu.io.csr_acc_illegal := csr.io.acc_illegal
      csr.io.mret_en := lsu.io.csr_mret_en
      rob.io.mret_held := lsu.io.csr_mret_held; rob.io.mret_pc := csr.io.mret_pc
      csr.io.trap_en := rob.io.trap_en; csr.io.trap_cause := rob.io.trap_cause
      csr.io.trap_epc := rob.io.trap_epc; csr.io.trap_tval := rob.io.trap_tval
      rob.io.trap_vector := csr.io.trap_vector
      csr.io.irq_timer := lsu.io.irq_timer; csr.io.irq_soft := lsu.io.irq_soft; csr.io.irq_ext := io.irq_ext
      rob.io.irq_pending := csr.io.irq_pending; rob.io.irq_cause := csr.io.irq_cause
      csr.io.instret_inc := rob.io.instret_inc
      csr.io.mtime := lsu.io.mtime
    }

    // CDB lanes: int0, int1, branch-or-intm, LSU. Branch has priority on lane 2.
    val cdbRobId = Vec(Bits(RIDX bits), CDBW); val cdbRdPhy = Vec(Bits(PIDX bits), CDBW)
    val cdbRdArch = Vec(Bits(AIDX bits), CDBW); val cdbRdVal = Vec(Bits(32 bits), CDBW)
    val cdbValid = Vec(Bool(), CDBW); val cdbRs1 = Vec(Bits(32 bits), CDBW); val cdbRs2 = Vec(Bits(32 bits), CDBW)
    def setLane(l: Int, robId: Bits, rdPhy: Bits, rdArch: Bits, rdVal: Bits, v: Bool, r1: Bits, r2: Bits): Unit = {
      cdbRobId(l) := robId; cdbRdPhy(l) := rdPhy; cdbRdArch(l) := rdArch; cdbRdVal(l) := rdVal; cdbValid(l) := v; cdbRs1(l) := r1; cdbRs2(l) := r2
    }
    setLane(0, sl(intRs.io.fu_cdb_rob_id_flat, 0, RIDX), sl(intRs.io.fu_cdb_rd_phy_flat, 0, PIDX), sl(intRs.io.fu_cdb_rd_arch_flat, 0, AIDX),
      sl(intRs.io.fu_cdb_rd_value_flat, 0, 32), intRs.io.fu_cdb_valid(0), sl(intRs.io.fu_cdb_rs1_dbg_flat, 0, 32), sl(intRs.io.fu_cdb_rs2_dbg_flat, 0, 32))
    setLane(1, sl(intRs.io.fu_cdb_rob_id_flat, 1, RIDX), sl(intRs.io.fu_cdb_rd_phy_flat, 1, PIDX), sl(intRs.io.fu_cdb_rd_arch_flat, 1, AIDX),
      sl(intRs.io.fu_cdb_rd_value_flat, 1, 32), intRs.io.fu_cdb_valid(1), sl(intRs.io.fu_cdb_rs1_dbg_flat, 1, 32), sl(intRs.io.fu_cdb_rs2_dbg_flat, 1, 32))
    val brValid = br.io.fu_cdb_valid
    intmRs.io.cdb_ready := !brValid
    setLane(2,
      Mux(brValid, br.io.fu_cdb_rob_id,  intmRs.io.fu_cdb_rob_id),
      Mux(brValid, br.io.fu_cdb_rd_phy,  intmRs.io.fu_cdb_rd_phy),
      Mux(brValid, br.io.fu_cdb_rd_arch, intmRs.io.fu_cdb_rd_arch),
      Mux(brValid, br.io.fu_cdb_rd_value, intmRs.io.fu_cdb_rd_value),
      brValid || intmRs.io.fu_cdb_valid,
      Mux(brValid, br.io.fu_cdb_rs1_dbg, intmRs.io.fu_cdb_rs1_dbg),
      Mux(brValid, br.io.fu_cdb_rs2_dbg, intmRs.io.fu_cdb_rs2_dbg))
    setLane(3, lsu.io.fu_cdb_rob_id, lsu.io.fu_cdb_rd_phy, lsu.io.fu_cdb_rd_arch, lsu.io.fu_cdb_rd_value, lsu.io.fu_cdb_valid, lsu.io.fu_cdb_rs1_value_dbg, lsu.io.fu_cdb_rs2_value_dbg)
    // lane-2 wakeup pre-resolve taps for memRs (RsEntry intmSplit): the three
    // registered rd_phy sources behind lane 2's tri-mux + the two mux selects.
    lsu.io.wk_intm_phy_br  := br.io.fu_cdb_rd_phy
    lsu.io.wk_intm_phy_div := intmRs.io.fu_cdb_rd_phy_div
    lsu.io.wk_intm_phy_mul := intmRs.io.fu_cdb_rd_phy_mul
    lsu.io.wk_intm_sel_br  := brValid
    lsu.io.wk_intm_sel_div := intmRs.io.fu_cdb_sel_div
    if (cfg.memCdbSpeculation) lsu.io.base_cdb_values :=
      intmRs.io.fu_cdb_value_mul ## intmRs.io.fu_cdb_value_div ##
      br.io.fu_cdb_rd_value ## intRs.io.fu_cdb_rd_value_flat
    // same pre-resolve taps for the INT RS (its dual cofactor issue arbiters)
    intRs.io.wk_intm_phy_br  := br.io.fu_cdb_rd_phy
    intRs.io.wk_intm_phy_div := intmRs.io.fu_cdb_rd_phy_div
    intRs.io.wk_intm_phy_mul := intmRs.io.fu_cdb_rd_phy_mul
    intRs.io.wk_intm_sel_br  := brValid
    intRs.io.wk_intm_sel_div := intmRs.io.fu_cdb_sel_div
    if (cfg.lsuWakeupPredecode && cfg.zicsr) {
      intRs.io.wk_lsu_phy_c := lsu.io.wk_lsu_phy_c_o
      intRs.io.wk_lsu_sel_c := lsu.io.wk_lsu_sel_c_o
    }
    intRs.io.wk_lsu_phy_a    := lsu.io.wk_lsu_phy_a_o
    intRs.io.wk_lsu_phy_l    := lsu.io.wk_lsu_phy_l_o
    intRs.io.wk_lsu_sel_a    := lsu.io.wk_lsu_sel_a_o
    if (cfg.intCsrSpeculation) {
      intRs.io.wk_lsu_sel_atomic := lsu.io.wk_lsu_sel_atomic_o
      intRs.io.lsu_valid_without_csr := lsu.io.lsu_valid_without_csr_o
    }
    // INTM uses the same producer tags before late lane selection.
    intmRs.io.wk_intm_phy_br  := br.io.fu_cdb_rd_phy
    intmRs.io.wk_intm_phy_div := intmRs.io.fu_cdb_rd_phy_div
    intmRs.io.wk_intm_phy_mul := intmRs.io.fu_cdb_rd_phy_mul
    intmRs.io.wk_intm_sel_br  := brValid
    intmRs.io.wk_intm_sel_div := intmRs.io.fu_cdb_sel_div
    if (cfg.lsuWakeupPredecode && cfg.zicsr) {
      intmRs.io.wk_lsu_phy_c := lsu.io.wk_lsu_phy_c_o
      intmRs.io.wk_lsu_sel_c := lsu.io.wk_lsu_sel_c_o
    }
    intmRs.io.wk_lsu_phy_a    := lsu.io.wk_lsu_phy_a_o
    intmRs.io.wk_lsu_phy_l    := lsu.io.wk_lsu_phy_l_o
    intmRs.io.wk_lsu_sel_a    := lsu.io.wk_lsu_sel_a_o

    val cdbRdPhyFlat = Cat((0 until CDBW).map(cdbRdPhy(_)))
    val cdbValidB = cdbValid.asBits
    val cdbRdValFlat = Cat((0 until CDBW).map(cdbRdVal(_)))
    val cdbRobIdFlat = Cat((0 until CDBW).map(cdbRobId(_)))
    val cdbRdArchFlat = Cat((0 until CDBW).map(cdbRdArch(_)))
    val cdbRs1Flat = Cat((0 until CDBW).map(cdbRs1(_)))
    val cdbRs2Flat = Cat((0 until CDBW).map(cdbRs2(_)))

    // distribute CDB
    for (r <- Seq(intRs.io.cdb_rd_phy_flat, intmRs.io.cdb_rd_phy_flat, br.io.cdb_rd_phy_flat, lsu.io.cdb_rd_phy_flat, rat.io.cdb_rd_phy_flat)) r := cdbRdPhyFlat
    for (v <- Seq(intRs.io.cdb_valid, intmRs.io.cdb_valid, br.io.cdb_valid, lsu.io.cdb_valid, rat.io.cdb_valid, prf.io.cdb_valid_flat)) v := cdbValidB
    rat.io.cdb_rd_arch_flat := cdbRdArchFlat
    rob.io.cdb_rob_id_flat := cdbRobIdFlat; rob.io.cdb_valid := cdbValidB; rob.io.cdb_rd_value_flat := cdbRdValFlat
    rob.io.cdb_rs1_dbg_flat := (if (cfg.rvfi) cdbRs1Flat else B(0, CDBW * 32 bits))
    rob.io.cdb_rs2_dbg_flat := (if (cfg.rvfi) cdbRs2Flat else B(0, CDBW * 32 bits))
    prf.io.cdb_rd_phy_flat := cdbRdPhyFlat; prf.io.cdb_rd_value_flat := cdbRdValFlat

    // Five ports: two integer operand pairs, two tied-off pre-read replacements,
    // and memory rs2. Memory rs1 and branch/INTM operands use the groups below.
    val RDP = cfg.prfReadPorts
    val BPW = ooo.execute.BypassT.width(cfg)
    val rsPhy1 = Vec(Bits(PIDX bits), RDP); val rsPhy2 = Vec(Bits(PIDX bits), RDP); val rsByp = Vec(Bits(BPW bits), RDP)
    rsPhy1(0) := sl(intRs.io.to_prf_rs1_phy_flat, 0, PIDX); rsPhy1(1) := sl(intRs.io.to_prf_rs1_phy_flat, 1, PIDX)
    rsPhy2(0) := sl(intRs.io.to_prf_rs2_phy_flat, 0, PIDX); rsPhy2(1) := sl(intRs.io.to_prf_rs2_phy_flat, 1, PIDX)
    rsByp(0)  := sl(intRs.io.to_prf_rs_bypass_flat, 0, BPW); rsByp(1) := sl(intRs.io.to_prf_rs_bypass_flat, 1, BPW)
    // Multiply/divide operands use ipre_*; tie off port 2 to eliminate its read mux.
    rsPhy1(2) := B(0, PIDX bits); rsPhy2(2) := B(0, PIDX bits); rsByp(2) := B(0, BPW bits)
    // Branch operands use bpre_*; tie off port 3 for the same reason.
    rsPhy1(3) := B(0, PIDX bits); rsPhy2(3) := B(0, PIDX bits); rsByp(3) := B(0, BPW bits)
    // Port 4 carries memory rs2; rs1 uses the pre-read group below.
    rsPhy1(4) := B(0, PIDX bits); rsPhy2(4) := lsu.io.to_prf_rs2_phy; rsByp(4) := lsu.io.to_prf_rs_bypass
    prf.io.from_rs_rs1_phy_flat := Cat((0 until RDP).map(rsPhy1(_)))
    prf.io.from_rs_rs2_phy_flat := Cat((0 until RDP).map(rsPhy2(_)))
    prf.io.from_rs_rs_bypass_flat := Cat((0 until RDP).map(rsByp(_)))
    val prfV1 = prf.io.from_rs_rs1_value_flat.subdivideIn(RDP slices)
    val prfV2 = prf.io.from_rs_rs2_value_flat.subdivideIn(RDP slices)
    intRs.io.to_prf_rs1_value_flat := prfV1(1) ## prfV1(0)   // issue1(hi)=port1, issue0(lo)=port0
    intRs.io.to_prf_rs2_value_flat := prfV2(1) ## prfV2(0)
    lsu.io.to_prf_rs2_value := prfV2(4)
    // memRs rs1 pre-read group: all D entry reads resolve from registered state
    if (cfg.memPrfPredecode) prf.io.pre_rs1_select_flat := lsu.io.to_prf_pre_rs1_select_flat
    prf.io.pre_rs1_phy_flat    := lsu.io.to_prf_pre_rs1_phy_flat
    prf.io.pre_rs1_bypass_flat := lsu.io.to_prf_pre_rs1_bypass_flat
    lsu.io.to_prf_pre_rs1_value_flat := prf.io.pre_rs1_value_flat
    lsu.io.cdb_lsu_value := cdbRdValFlat(cfg.cdbLsuLane * 32, 32 bits)
    // intmRs rs1+rs2 pre-read group (PRF-2): same construction, both operands
    prf.io.ipre_phy1_flat   := intmRs.io.to_prf_ipre_phy1_flat
    prf.io.ipre_phy2_flat   := intmRs.io.to_prf_ipre_phy2_flat
    prf.io.ipre_bypass_flat := intmRs.io.to_prf_ipre_bypass_flat
    intmRs.io.to_prf_ipre_value1_flat := prf.io.ipre_value1_flat
    intmRs.io.to_prf_ipre_value2_flat := prf.io.ipre_value2_flat
    intmRs.io.cdb_lsu_value := cdbRdValFlat(cfg.cdbLsuLane * 32, 32 bits)
    // brRs rs1+rs2 pre-read group (PRF-3): same construction again
    if (cfg.brPrfSharedPredecode) {
      prf.io.bpre_select1 := br.io.to_prf_bpre_select1
      prf.io.bpre_select2 := br.io.to_prf_bpre_select2
    }
    prf.io.bpre_phy1_flat   := br.io.to_prf_bpre_phy1_flat
    prf.io.bpre_phy2_flat   := br.io.to_prf_bpre_phy2_flat
    prf.io.bpre_bypass_flat := br.io.to_prf_bpre_bypass_flat
    br.io.to_prf_bpre_value1_flat := prf.io.bpre_value1_flat
    br.io.to_prf_bpre_value2_flat := prf.io.bpre_value2_flat
    br.io.cdb_lsu_value := cdbRdValFlat(cfg.cdbLsuLane * 32, 32 bits)

    // alu_bypass (produced by int_rs)
    val bypass = intRs.io.alu_bypass_flat
    if (cfg.aluAguFusion) lsu.io.alu_address_flat := intRs.io.alu_address_flat
    intmRs.io.alu_bypass_flat := bypass; br.io.alu_bypass_flat := bypass; lsu.io.alu_bypass_flat := bypass; prf.io.alu_bypass_flat := bypass

    // intm div externalisation
    io.div_prv_valid := intmRs.io.div_prv_valid; intmRs.io.div_prv_ready := io.div_prv_ready
    intmRs.io.div_nxt_valid := io.div_nxt_valid; io.div_nxt_ready := intmRs.io.div_nxt_ready
    io.div_iss_in := intmRs.io.div_iss_in; intmRs.io.div_cdb_out := io.div_cdb_out

    // branch_top <-> rob (cb_rob)
    rob.io.from_cb_rob_id := br.io.to_rob_rob_id; rob.io.from_cb_miss_predict := br.io.to_rob_miss_predict
    rob.io.from_cb_target_address := br.io.to_rob_target; rob.io.from_cb_ready := br.io.to_rob_ready
    br.io.to_rob_dequeue := rob.io.from_cb_dequeue
    // to_bp
    io.to_bp_update_en := br.io.to_bp_update_en; io.to_bp_pc := br.io.to_bp_pc; io.to_bp_fu_opcode := br.io.to_bp_fu_opcode
    io.to_bp_branch_taken := br.io.to_bp_branch_taken; io.to_bp_target := br.io.to_bp_target; io.to_bp_kp := br.io.to_bp_kp
    io.to_bp_is_call := br.io.to_bp_is_call; io.to_bp_is_ret := br.io.to_bp_is_ret; io.to_bp_is_compressed := br.io.to_bp_is_compressed
    io.to_bp_prov := br.io.to_bp_prov

    // lsu <-> rob (stq/ldq) + dcache dfp
    rob.io.from_stq_rob_id := lsu.io.st_rob_rob_id
    rob.io.from_stq_addr_dbg := (if (cfg.rvfi) lsu.io.st_rob_addr_dbg else B(0, 32 bits))
    rob.io.from_stq_wmask_dbg := (if (cfg.rvfi) lsu.io.st_rob_wmask_dbg else B(0, 4 bits))
    rob.io.from_stq_wdata_dbg := (if (cfg.rvfi) lsu.io.st_rob_wdata_dbg else B(0, 32 bits))
    rob.io.from_stq_rs1_value_dbg := (if (cfg.rvfi) lsu.io.st_rob_rs1_value_dbg else B(0, 32 bits))
    rob.io.from_stq_rs2_value_dbg := (if (cfg.rvfi) lsu.io.st_rob_rs2_value_dbg else B(0, 32 bits))
    rob.io.from_stq_valid := lsu.io.st_rob_valid; lsu.io.st_rob_ready := rob.io.from_stq_ready
    rob.io.from_ldq_rob_id := lsu.io.ld_rob_rob_id
    rob.io.from_ldq_addr_dbg := (if (cfg.rvfi) lsu.io.ld_rob_addr_dbg else B(0, 32 bits))
    rob.io.from_ldq_rmask_dbg := (if (cfg.rvfi) lsu.io.ld_rob_rmask_dbg else B(0, 4 bits))
    rob.io.from_ldq_rdata_dbg := (if (cfg.rvfi) lsu.io.ld_rob_rdata_dbg else B(0, 32 bits))
    rob.io.from_ldq_valid := lsu.io.ld_rob_valid; rob.io.from_ldq_violation := lsu.io.ld_rob_violation
    rob.io.from_ldq_violation_rob_id := lsu.io.ld_rob_violation_rob_id
    io.dfp_addr := lsu.io.dfp_addr; io.dfp_read := lsu.io.dfp_read; io.dfp_write := lsu.io.dfp_write; io.dfp_wdata := lsu.io.dfp_wdata
    if (cfg.bmemEarlyAddress) {
      io.dfp_read_addr := lsu.io.dfp_read_addr
      io.dfp_write_addr := lsu.io.dfp_write_addr
    }
    if (cfg.bmemBeatSpeculation) {
      lsu.io.dfp_write_beat := io.dfp_write_beat
      io.dfp_wdata_beat := lsu.io.dfp_wdata_beat
    }
    lsu.io.dfp_ready := io.dfp_ready; lsu.io.dfp_raddr := io.dfp_raddr; lsu.io.dfp_rdata := io.dfp_rdata; lsu.io.dfp_rvalid := io.dfp_rvalid

    // perf / rvfi outputs
    io.dbg_fu_br_valid := br.io.dbg_fu_br_valid; io.dbg_miss_predict := br.io.dbg_miss_predict; io.dbg_reg_out := br.io.dbg_reg_out
    io.dbg_id_rob_valid := id.io.to_rob_valid; io.dbg_id_rob_ready := rob.io.from_id_ready; io.dbg_id_rob_inst_valid := id.io.uops_valid
    io.dbg_mul_start := intmRs.io.dbg_mul_start; io.dbg_ldq_violation := lsu.io.ld_rob_violation
    io.dbg_stb_full := lsu.io.dbg_stb_full; io.dbg_stq_want_dequeue := lsu.io.dbg_stq_want_dequeue
    io.dbg_stq_counter := lsu.io.dbg_stq_counter; io.dbg_stq_rd_ptr_actual := lsu.io.dbg_stq_rd_ptr_actual
    io.dbg_stq_addr_valid_flat := lsu.io.dbg_stq_addr_valid_flat
    io.dbg_ldq_valid_flat := lsu.io.dbg_ldq_valid_flat; io.dbg_ldq_addr_valid_flat := lsu.io.dbg_ldq_addr_valid_flat
    io.dbg_ldq_issued_flat := lsu.io.dbg_ldq_issued_flat; io.dbg_ldq_issue_en := lsu.io.dbg_ldq_issue_en
    io.dbg_dc_stall := lsu.io.dbg_dc_stall; io.dbg_dc_hit := lsu.io.dbg_dc_hit; io.dbg_dc_rmask := lsu.io.dbg_dc_rmask; io.dbg_dc_wmask := lsu.io.dbg_dc_wmask
    io.dbg_ld_dmem_resp := lsu.io.dbg_ld_dmem_resp
    io.dbg_viol_flush := rob.io.dbg_viol_flush; io.dbg_pop := rob.io.dbg_pop; io.dbg_empty := rob.io.dbg_empty; io.dbg_branch_flush := rob.io.dbg_branch_flush
    io.dbg_commit_instr := rob.io.dbg_commit_instr; io.dbg_head_ptr_reg := rob.io.dbg_head_ptr_reg; io.dbg_tail_ptr_reg := rob.io.dbg_tail_ptr_reg
    io.rvfi_itf_flat := rob.io.rvfi_itf_flat
  }
}
