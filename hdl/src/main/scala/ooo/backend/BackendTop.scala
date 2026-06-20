package ooo.backend

import spinal.core._
import spinal.lib._
import ooo.CpuConfig
import ooo.rename.{Rat, FreeList, Rob, Rrf}
import ooo.execute.{IntRs, IntmRs, BranchTop, Prf}
import ooo.memory.LsuTop

/** SpinalHDL port of `hdl/backend/backend_top.sv` -- the out-of-order back-end
  * cluster. Composes id_stage + rat + free_list + rob + rrf + ds_stage + int_rs +
  * intm_rs + branch_top + lsu_top + prf, with the 5-lane CDB bus, the 5-port PRF
  * read fabric, and the fast-ALU bypass network. Builds the uop datapath (decode ->
  * rename -> per-RS entry) and the rob RVFI record. The divider (fu_div) is
  * externalised to the shim (div_* ports) -- it keeps the DW_div_seq blackbox and
  * the perf tap fu_div_i.div_start native.
  *
  * Named backend_top_spinal; sim/swap_shims/backend_top.sv carries the external SV
  * interfaces (fifo_backend_itf, cacheline_itf.master, cb_bp_itf.cb), instantiates
  * the real SV fu_div, and recreates every perf_monitor-tapped sub-scope + the
  * rob_i.rvfi_itf record.
  */
class BackendTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("backend_top_spinal")
  val IDW = cfg.idWidth; val CDBW = cfg.cdbWidth; val NFB = cfg.numFastBypass
  val IIW = cfg.intIssueWidth   // 2
  val PIDX = cfg.prfIdx; val AIDX = cfg.arfIdx; val RIDX = cfg.robIdx; val GHR = cfg.ghrLen
  val PROV = cfg.tageNum * (1 + cfg.tageCtrBits + cfg.tageUBits) + 2   // +2 = forwarded bimodal counter
  val BNW = 1 + PIDX + 32       // 39
  val RVFIW = 413
  val REGW = 85; val CDBR = 113 // intm div iss/cdb
  val FBRW = 183
  val PPI = cfg.robPtrIdx + 1  // rob head/tail ptr width (6)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = out Bool(); val backend_redirect_pc = out Bits (32 bits)
    // fifo_backend_itf.backend from_fifo (decode_packet_t)
    val from_fifo_valid = in Bool(); val from_fifo_ready = out Bool()
    val ff_inst_flat = in Bits (IDW * 32 bits); val ff_inst_raw_flat = in Bits (IDW * 32 bits)
    val ff_is_compressed = in Bits (IDW bits); val ff_predict_taken = in Bits (IDW bits)
    val ff_predict_target_flat = in Bits (IDW * 32 bits); val ff_pc_flat = in Bits (IDW * 32 bits)
    val ff_valid_slots = in Bits (IDW bits); val ff_ghr_flat = in Bits (IDW * GHR bits)
    val ff_prov_flat = in Bits (IDW * PROV bits)
    // dcache dfp
    val dfp_addr = out Bits (32 bits); val dfp_read = out Bool(); val dfp_write = out Bool()
    val dfp_wdata = out Bits (256 bits); val dfp_ready = in Bool(); val dfp_raddr = in Bits (32 bits)
    val dfp_rdata = in Bits (256 bits); val dfp_rvalid = in Bool()
    // cb_bp_itf.cb to_bp
    val to_bp_update_en = out Bool(); val to_bp_pc = out Bits (32 bits); val to_bp_fu_opcode = out Bits (4 bits)
    val to_bp_branch_taken = out Bool(); val to_bp_target = out Bits (32 bits); val to_bp_ghr = out Bits (GHR bits)
    val to_bp_is_call = out Bool(); val to_bp_is_ret = out Bool(); val to_bp_is_compressed = out Bool()
    val to_bp_prov = out Bits (PROV bits)
    // externalised fu_div
    val div_prv_valid = out Bool(); val div_prv_ready = in Bool()
    val div_nxt_valid = in Bool(); val div_nxt_ready = out Bool()
    val div_iss_in = out Bits (REGW bits); val div_cdb_out = in Bits (CDBR bits)
    // perf dbg
    val dbg_fu_br_valid = out Bool(); val dbg_miss_predict = out Bool(); val dbg_reg_out = out Bits (FBRW bits)
    val dbg_perf_int = out Bits (32 bits); val dbg_perf_intm = out Bits (32 bits)
    val dbg_perf_br = out Bits (32 bits); val dbg_perf_mem = out Bits (32 bits)
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
  }
  noIoPrefix()

  // ---- uop bundle (all fields Bits for clean ## packing) ----
  case class Uop() extends Bundle {
    val valid = Bits(1 bits); val pc = Bits(32 bits); val inst = Bits(32 bits); val is_compressed = Bits(1 bits)
    val rs_type = Bits(2 bits); val fu_type = Bits(2 bits); val fu_opcode = Bits(4 bits)
    val op1_sel = Bits(1 bits); val op2_sel = Bits(1 bits)
    val rd_phy = Bits(PIDX bits); val rs1_phy = Bits(PIDX bits); val rs2_phy = Bits(PIDX bits)
    val rs1_valid = Bits(1 bits); val rs2_valid = Bits(1 bits); val imm = Bits(32 bits); val rob_id = Bits(RIDX bits)
    val rd_arch = Bits(AIDX bits); val rs1_arch = Bits(AIDX bits); val rs2_arch = Bits(AIDX bits)
    val predict_taken = Bits(1 bits); val predict_target = Bits(32 bits); val ghr = Bits(GHR bits); val inst_raw = Bits(32 bits)
    val prov = Bits(PROV bits)
    val is_atomic = Bits(1 bits); val amo_op = Bits(4 bits)   // RV32A (aExt)
  }
  def intEntry(u: Uop)  = u.rob_id ## u.rs1_phy ## u.rs1_valid ## u.rs2_phy ## u.rs2_valid ## u.rd_phy ## u.rd_arch ## u.op1_sel ## u.op2_sel ## u.imm ## u.fu_opcode
  def intmEntry(u: Uop) = u.rob_id ## u.rs1_phy ## u.rs1_valid ## u.rs2_phy ## u.rs2_valid ## u.rd_phy ## u.rd_arch ## u.fu_opcode
  def memEntry(u: Uop)  = u.rob_id ## u.rs1_phy ## u.rs1_valid ## u.rs2_phy ## u.rs2_valid ## u.imm ## u.fu_opcode
  def brEntry(u: Uop)   = u.rob_id ## u.rs1_phy ## u.rs1_valid ## u.rs2_phy ## u.rs2_valid ## u.rd_phy ## u.rd_arch ## u.imm ## u.pc ## u.fu_opcode ## u.is_compressed ## u.predict_taken ## u.predict_target
  def rvfiBits(u: Uop)  = B(0, 1 bits) ## B(0, 64 bits) ## u.inst_raw ## u.rs1_arch ## u.rs2_arch ##
    B(0, 32 bits) ## B(0, 32 bits) ## u.rd_arch ## B(0, 32 bits) ## B(0, 5 bits) ## B(0, 32 bits) ##
    u.pc ## u.predict_target ## B(0, 32 bits) ## B(0, 4 bits) ## B(0, 4 bits) ## B(0, 32 bits) ## B(0, 32 bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val flush = Bool()                       // rob.backend_flush

    // ---- sub-components ----
    val id = new IdStage(cfg);     id.io.clk := io.clk; id.io.rst := io.rst
    val rat = new Rat(cfg);        rat.io.clk := io.clk; rat.io.rst := io.rst; rat.io.backend_flush := flush
    val fl = new FreeList(cfg);    fl.io.clk := io.clk; fl.io.rst := io.rst; fl.io.backend_flush := flush
    val rob = new Rob(cfg);        rob.io.clk := io.clk; rob.io.rst := io.rst
    val rrf = new Rrf(cfg);        rrf.io.clk := io.clk; rrf.io.rst := io.rst
    val ds = new DsStage(cfg);     ds.io.clk := io.clk; ds.io.rst := io.rst
    val intRs = new IntRs(cfg);    intRs.io.clk := io.clk; intRs.io.rst := io.rst || flush
    val intmRs = new IntmRs(cfg);  intmRs.io.clk := io.clk; intmRs.io.rst := io.rst || flush
    val br = new BranchTop(cfg);   br.io.clk := io.clk; br.io.rst := io.rst; br.io.backend_flush := flush
    val lsu = new LsuTop(cfg);     lsu.io.clk := io.clk; lsu.io.rst := io.rst; lsu.io.backend_flush := flush
    val prf = new Prf(cfg);        prf.io.clk := io.clk

    flush := rob.io.backend_flush
    io.backend_flush := rob.io.backend_flush
    io.backend_redirect_pc := rob.io.backend_redirect_pc

    // ---- id_stage <-> from_fifo / rat / fl / rob ----
    id.io.from_fifo_valid := io.from_fifo_valid
    id.io.from_fifo_inst_flat := io.ff_inst_flat
    id.io.from_fifo_valid_slots := io.ff_valid_slots
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
    rob.io.from_id_is_atomic := id.io.is_atomic

    // rrf (rob side)
    rrf.io.from_rob_valid := rob.io.to_rrf_valid
    rrf.io.from_rob_rd_phy_flat := rob.io.to_rrf_rd_phy_flat
    rrf.io.from_rob_rd_arch_flat := rob.io.to_rrf_rd_arch_flat

    // ---- build uop[ID] from id decode + rat read + rob_id + packet ----
    val ffInst = io.ff_inst_flat.subdivideIn(IDW slices)
    val ffInstRaw = io.ff_inst_raw_flat.subdivideIn(IDW slices)
    val ffPredTgt = io.ff_predict_target_flat.subdivideIn(IDW slices)
    val ffPc = io.ff_pc_flat.subdivideIn(IDW slices)
    val ffGhr = io.ff_ghr_flat.subdivideIn(IDW slices)
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
      u.predict_taken := io.ff_predict_taken(i, 1 bits); u.predict_target := ffPredTgt(i); u.ghr := ffGhr(i); u.inst_raw := ffInstRaw(i)
      u.prov := ffProv(i)
      u.is_atomic := id.io.is_atomic(i, 1 bits); u.amo_op := sl(id.io.amo_op_flat, i, 4)
    }
    rob.io.from_id_rvfi_dbg_flat := Cat((0 until IDW).map(i => rvfiBits(uops(i))))

    // ---- ds_stage ----
    ds.io.prv_valid := dispatchValid
    ds.io.uops_valid := id.io.uops_valid
    ds.io.rs_type_flat := id.io.rs_type_flat
    ds.io.uop_rs_type_flat := id.io.rs_type_flat
    ds.io.to_int_rs_ready := intRs.io.from_ds_ready
    ds.io.to_intm_rs_ready := intmRs.io.from_ds_ready
    ds.io.to_br_rs_ready := br.io.from_ds_ready
    ds.io.to_mem_rs_ready := lsu.io.from_ds_ready

    // ---- per-RS entries ----
    intRs.io.from_ds_entry_flat := Cat((0 until IDW).map(i => intEntry(uops(i))))
    intRs.io.from_ds_valid := ds.io.to_int_rs_valid
    intmRs.io.from_ds_entry_flat := Cat((0 until IDW).map(i => intmEntry(uops(i))))
    intmRs.io.from_ds_valid := ds.io.to_intm_rs_valid
    val brUop = uops(ds.io.br_sel); val memUop = uops(ds.io.mem_sel)
    br.io.from_ds_valid := ds.io.to_br_rs_valid
    br.io.from_ds_entry_flat := brEntry(brUop)
    br.io.uop_rob_id := brUop.rob_id; br.io.uop_pc := brUop.pc; br.io.uop_fu_opcode := brUop.fu_opcode
    br.io.uop_ghr := brUop.ghr; br.io.uop_is_compressed := brUop.is_compressed(0); br.io.uop_inst := brUop.inst
    br.io.uop_prov := brUop.prov
    lsu.io.from_ds_valid := ds.io.to_mem_rs_valid
    lsu.io.mem_rs_entry_flat := memEntry(memUop)
    lsu.io.uop_rob_id := memUop.rob_id; lsu.io.uop_fu_opcode := memUop.fu_opcode
    lsu.io.uop_rd_arch := memUop.rd_arch; lsu.io.uop_rd_phy := memUop.rd_phy
    lsu.io.uop_is_atomic := memUop.is_atomic(0); lsu.io.uop_amo_op := memUop.amo_op
    lsu.io.atomic_go := rob.io.atomic_go; lsu.io.atomic_go_rob_id := rob.io.atomic_go_rob_id

    // ---- CDB bus (lane 0,4=int; 1=intm; 2=branch; 3=lsu) ----
    val cdbRobId = Vec(Bits(RIDX bits), CDBW); val cdbRdPhy = Vec(Bits(PIDX bits), CDBW)
    val cdbRdArch = Vec(Bits(AIDX bits), CDBW); val cdbRdVal = Vec(Bits(32 bits), CDBW)
    val cdbValid = Vec(Bool(), CDBW); val cdbRs1 = Vec(Bits(32 bits), CDBW); val cdbRs2 = Vec(Bits(32 bits), CDBW)
    def setLane(l: Int, robId: Bits, rdPhy: Bits, rdArch: Bits, rdVal: Bits, v: Bool, r1: Bits, r2: Bits): Unit = {
      cdbRobId(l) := robId; cdbRdPhy(l) := rdPhy; cdbRdArch(l) := rdArch; cdbRdVal(l) := rdVal; cdbValid(l) := v; cdbRs1(l) := r1; cdbRs2(l) := r2
    }
    setLane(0, sl(intRs.io.fu_cdb_rob_id_flat, 0, RIDX), sl(intRs.io.fu_cdb_rd_phy_flat, 0, PIDX), sl(intRs.io.fu_cdb_rd_arch_flat, 0, AIDX),
      sl(intRs.io.fu_cdb_rd_value_flat, 0, 32), intRs.io.fu_cdb_valid(0), sl(intRs.io.fu_cdb_rs1_dbg_flat, 0, 32), sl(intRs.io.fu_cdb_rs2_dbg_flat, 0, 32))
    setLane(4, sl(intRs.io.fu_cdb_rob_id_flat, 1, RIDX), sl(intRs.io.fu_cdb_rd_phy_flat, 1, PIDX), sl(intRs.io.fu_cdb_rd_arch_flat, 1, AIDX),
      sl(intRs.io.fu_cdb_rd_value_flat, 1, 32), intRs.io.fu_cdb_valid(1), sl(intRs.io.fu_cdb_rs1_dbg_flat, 1, 32), sl(intRs.io.fu_cdb_rs2_dbg_flat, 1, 32))
    setLane(1, intmRs.io.fu_cdb_rob_id, intmRs.io.fu_cdb_rd_phy, intmRs.io.fu_cdb_rd_arch, intmRs.io.fu_cdb_rd_value, intmRs.io.fu_cdb_valid, intmRs.io.fu_cdb_rs1_dbg, intmRs.io.fu_cdb_rs2_dbg)
    setLane(2, br.io.fu_cdb_rob_id, br.io.fu_cdb_rd_phy, br.io.fu_cdb_rd_arch, br.io.fu_cdb_rd_value, br.io.fu_cdb_valid, br.io.fu_cdb_rs1_dbg, br.io.fu_cdb_rs2_dbg)
    setLane(3, lsu.io.fu_cdb_rob_id, lsu.io.fu_cdb_rd_phy, lsu.io.fu_cdb_rd_arch, lsu.io.fu_cdb_rd_value, lsu.io.fu_cdb_valid, lsu.io.fu_cdb_rs1_value_dbg, lsu.io.fu_cdb_rs2_value_dbg)

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
    rob.io.cdb_rs1_dbg_flat := cdbRs1Flat; rob.io.cdb_rs2_dbg_flat := cdbRs2Flat
    prf.io.cdb_rd_phy_flat := cdbRdPhyFlat; prf.io.cdb_rd_value_flat := cdbRdValFlat

    // ---- PRF read fabric (lane 0,4=int; 1=intm; 2=branch; 3=lsu) ----
    val rsPhy1 = Vec(Bits(PIDX bits), CDBW); val rsPhy2 = Vec(Bits(PIDX bits), CDBW); val rsByp = Vec(Bits(14 bits), CDBW)
    rsPhy1(0) := sl(intRs.io.to_prf_rs1_phy_flat, 0, PIDX); rsPhy1(4) := sl(intRs.io.to_prf_rs1_phy_flat, 1, PIDX)
    rsPhy2(0) := sl(intRs.io.to_prf_rs2_phy_flat, 0, PIDX); rsPhy2(4) := sl(intRs.io.to_prf_rs2_phy_flat, 1, PIDX)
    rsByp(0)  := sl(intRs.io.to_prf_rs_bypass_flat, 0, 14); rsByp(4) := sl(intRs.io.to_prf_rs_bypass_flat, 1, 14)
    rsPhy1(1) := intmRs.io.to_prf_rs1_phy; rsPhy2(1) := intmRs.io.to_prf_rs2_phy; rsByp(1) := intmRs.io.to_prf_rs_bypass
    rsPhy1(2) := br.io.to_prf_rs1_phy; rsPhy2(2) := br.io.to_prf_rs2_phy; rsByp(2) := br.io.to_prf_rs_bypass
    rsPhy1(3) := lsu.io.to_prf_rs1_phy; rsPhy2(3) := lsu.io.to_prf_rs2_phy; rsByp(3) := lsu.io.to_prf_rs_bypass
    prf.io.from_rs_rs1_phy_flat := Cat((0 until CDBW).map(rsPhy1(_)))
    prf.io.from_rs_rs2_phy_flat := Cat((0 until CDBW).map(rsPhy2(_)))
    prf.io.from_rs_rs_bypass_flat := Cat((0 until CDBW).map(rsByp(_)))
    val prfV1 = prf.io.from_rs_rs1_value_flat.subdivideIn(CDBW slices)
    val prfV2 = prf.io.from_rs_rs2_value_flat.subdivideIn(CDBW slices)
    intRs.io.to_prf_rs1_value_flat := prfV1(4) ## prfV1(0)   // lane1(hi)=idx4, lane0(lo)=idx0
    intRs.io.to_prf_rs2_value_flat := prfV2(4) ## prfV2(0)
    intmRs.io.to_prf_rs1_value := prfV1(1); intmRs.io.to_prf_rs2_value := prfV2(1)
    br.io.to_prf_rs1_value := prfV1(2); br.io.to_prf_rs2_value := prfV2(2)
    lsu.io.to_prf_rs1_value := prfV1(3); lsu.io.to_prf_rs2_value := prfV2(3)

    // ---- alu_bypass (produced by int_rs) ----
    val bypass = intRs.io.alu_bypass_flat
    intmRs.io.alu_bypass_flat := bypass; br.io.alu_bypass_flat := bypass; lsu.io.alu_bypass_flat := bypass; prf.io.alu_bypass_flat := bypass

    // ---- intm div externalisation ----
    io.div_prv_valid := intmRs.io.div_prv_valid; intmRs.io.div_prv_ready := io.div_prv_ready
    intmRs.io.div_nxt_valid := io.div_nxt_valid; io.div_nxt_ready := intmRs.io.div_nxt_ready
    io.div_iss_in := intmRs.io.div_iss_in; intmRs.io.div_cdb_out := io.div_cdb_out

    // ---- branch_top <-> rob (cb_rob) ----
    rob.io.from_cb_rob_id := br.io.to_rob_rob_id; rob.io.from_cb_miss_predict := br.io.to_rob_miss_predict
    rob.io.from_cb_target_address := br.io.to_rob_target; rob.io.from_cb_ready := br.io.to_rob_ready
    br.io.to_rob_dequeue := rob.io.from_cb_dequeue
    // to_bp
    io.to_bp_update_en := br.io.to_bp_update_en; io.to_bp_pc := br.io.to_bp_pc; io.to_bp_fu_opcode := br.io.to_bp_fu_opcode
    io.to_bp_branch_taken := br.io.to_bp_branch_taken; io.to_bp_target := br.io.to_bp_target; io.to_bp_ghr := br.io.to_bp_ghr
    io.to_bp_is_call := br.io.to_bp_is_call; io.to_bp_is_ret := br.io.to_bp_is_ret; io.to_bp_is_compressed := br.io.to_bp_is_compressed
    io.to_bp_prov := br.io.to_bp_prov

    // ---- lsu <-> rob (stq/ldq) + dcache dfp ----
    rob.io.from_stq_rob_id := lsu.io.st_rob_rob_id; rob.io.from_stq_addr_dbg := lsu.io.st_rob_addr_dbg
    rob.io.from_stq_wmask_dbg := lsu.io.st_rob_wmask_dbg; rob.io.from_stq_wdata_dbg := lsu.io.st_rob_wdata_dbg
    rob.io.from_stq_rs1_value_dbg := lsu.io.st_rob_rs1_value_dbg; rob.io.from_stq_rs2_value_dbg := lsu.io.st_rob_rs2_value_dbg
    rob.io.from_stq_valid := lsu.io.st_rob_valid; lsu.io.st_rob_ready := rob.io.from_stq_ready
    rob.io.from_ldq_rob_id := lsu.io.ld_rob_rob_id; rob.io.from_ldq_addr_dbg := lsu.io.ld_rob_addr_dbg
    rob.io.from_ldq_rmask_dbg := lsu.io.ld_rob_rmask_dbg; rob.io.from_ldq_rdata_dbg := lsu.io.ld_rob_rdata_dbg
    rob.io.from_ldq_valid := lsu.io.ld_rob_valid; rob.io.from_ldq_violation := lsu.io.ld_rob_violation
    rob.io.from_ldq_violation_rob_id := lsu.io.ld_rob_violation_rob_id
    io.dfp_addr := lsu.io.dfp_addr; io.dfp_read := lsu.io.dfp_read; io.dfp_write := lsu.io.dfp_write; io.dfp_wdata := lsu.io.dfp_wdata
    lsu.io.dfp_ready := io.dfp_ready; lsu.io.dfp_raddr := io.dfp_raddr; lsu.io.dfp_rdata := io.dfp_rdata; lsu.io.dfp_rvalid := io.dfp_rvalid

    // ---- perf / rvfi outputs ----
    io.dbg_fu_br_valid := br.io.dbg_fu_br_valid; io.dbg_miss_predict := br.io.dbg_miss_predict; io.dbg_reg_out := br.io.dbg_reg_out
    io.dbg_perf_int := ds.io.dbg_perf_int; io.dbg_perf_intm := ds.io.dbg_perf_intm; io.dbg_perf_br := ds.io.dbg_perf_br; io.dbg_perf_mem := ds.io.dbg_perf_mem
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
