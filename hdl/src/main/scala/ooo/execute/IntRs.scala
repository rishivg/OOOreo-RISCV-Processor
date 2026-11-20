package ooo.execute

import spinal.core._
import ooo.CpuConfig
import ooo.backend.decode.DecodeConsts._

/** Compacting integer reservation station with two-wide issue. */
class IntRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("int_rs_spinal")

  val D    = cfg.intrsDepth
  val W    = cfg.intIssueWidth
  val IDW  = cfg.idWidth
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val AIDX = cfg.arfIdx
  val RIDX = cfg.robIdx
  require(D >= IDW, "Integer reservation station must fit a dispatch group")
  val EW   = IntRsEntry.width(cfg)
  val IDX  = log2Up(D)
  val BPW  = BypassT.width(cfg)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // Dispatch payload and handshake
    val from_ds_entry_flat = in  Bits (IDW * EW bits)
    val from_ds_valid      = in  Bits (IDW bits)
    val from_ds_ready      = out Bool()
    val to_prf_rs1_phy_flat   = out Bits (W * PIDX bits)
    val to_prf_rs2_phy_flat   = out Bits (W * PIDX bits)
    val to_prf_rs_bypass_flat = out Bits (W * BPW bits)
    val to_prf_rs1_value_flat = in  Bits (W * 32 bits)
    val to_prf_rs2_value_flat = in  Bits (W * 32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits)
    val cdb_valid       = in Bits (CDBW bits)
    // CDB-lane wakeup pre-resolve sources (RsEntry wkPreResolve; see MemRs) --
    // keeps the request_v0/v1 cofactors early so the dual cofactor arbiters
    // finish before the late D$-hit bit selects between them.
    val wk_intm_phy_br  = in Bits (PIDX bits)
    val wk_intm_phy_div = in Bits (PIDX bits)
    val wk_intm_phy_mul = in Bits (PIDX bits)
    val wk_intm_sel_br  = in Bool()
    val wk_intm_sel_div = in Bool()
    val wk_lsu_phy_c = if (cfg.lsuWakeupPredecode && cfg.zicsr) in Bits(PIDX bits) else null
    val wk_lsu_sel_c = if (cfg.lsuWakeupPredecode && cfg.zicsr) in Bool() else null
    val wk_lsu_phy_a    = in Bits (PIDX bits)
    val wk_lsu_phy_l    = in Bits (PIDX bits)
    val wk_lsu_sel_a    = in Bool()
    val wk_lsu_sel_atomic = cfg.intCsrSpeculation generate (in Bool())
    val lsu_valid_without_csr = cfg.intCsrSpeculation generate (in Bool())
    val fu_cdb_rob_id_flat   = out Bits (W * RIDX bits)
    val fu_cdb_rd_phy_flat    = out Bits (W * PIDX bits)
    val fu_cdb_rd_arch_flat   = out Bits (W * AIDX bits)
    val fu_cdb_rd_value_flat  = out Bits (W * 32 bits)
    val fu_cdb_rs1_dbg_flat   = out Bits (W * 32 bits)
    val fu_cdb_rs2_dbg_flat   = out Bits (W * 32 bits)
    val fu_cdb_valid          = out Bits (W bits)
    val alu_bypass_flat = out Bits (NFB * cfg.bypassNetW bits)
    val alu_address_flat = if (cfg.aluAguFusion) out Bits(NFB * ooo.memory.AluAddressSource.width bits) else null
  }
  noIoPrefix()

  // Precompute issue with and without LSU wakeup. Optionally separate all LSU
  // producers, keeping both CSR and atomic validity outside priority networks.
  val arb0 = new IssueArbiter(cfg)
  val arb1 = new IssueArbiter(cfg)
  val arbCsr = if (cfg.intCsrSpeculation) new IssueArbiter(cfg) else null
  val arbAtomic = if (cfg.intCsrSpeculation) new IssueArbiter(cfg) else null
  if (cfg.intCsrSpeculation) {
    // Keep the late CSR selector outside the priority networks during mapping.
    Seq(arb0, arb1, arbCsr, arbAtomic).foreach(_.addAttribute("keep_hierarchy", "yes"))
  }
  val alus = (0 until W).map { _ => val a = new FuAlu(cfg); a.io.clk := io.clk; a.io.rst := io.rst; a }

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.int(cfg),
      wkPreResolve = true, csrPreResolve = cfg.intCsrSpeculation))

    val from_ds_entry = (0 until IDW).map(w => io.from_ds_entry_flat(w * EW, EW bits))

    val wcdb = RsUtil.wakeupVec(io.cdb_rd_phy_flat, io.cdb_valid, cfg)
    val fb = Vec(BypassNet(cfg), NFB)
    for (k <- 0 until NFB) { fb(k) := BypassNet.fromBits(alus(k).io.bypass, cfg) }

    val rs_valid     = Vec(Bool(), D)
    val rs_req_v0    = Vec(Bool(), D)
    val rs_req_v1    = Vec(Bool(), D)
    val rs_entry_out = Vec(Bits(EW bits), D)
    val rs_entry     = Vec(Bits(EW bits), D)
    val rs_bypass    = Vec(BypassT(cfg), D)
    val push_en  = Vec(Bool(), D)
    val clear    = Vec(Bool(), D)
    val entry_in = Vec(Bits(EW bits), D)

    val vLsu = if (cfg.intCsrSpeculation) io.lsu_valid_without_csr else io.cdb_valid(cfg.cdbLsuLane)
    def selectIssue[T <: Data](without: T, withLsu: T, withCsr: => T, withAtomic: => T): T = {
      if (cfg.intCsrSpeculation) {
        Mux(io.wk_lsu_sel_c, withCsr,
          Mux(io.wk_lsu_sel_atomic, withAtomic, Mux(vLsu, withLsu, without)))
      } else Mux(vLsu, withLsu, without)
    }
    for (i <- 0 until D) {
      val e = entries(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := entry_in(i)
      e.io.clear       := clear(i)
      e.io.fast_bypass := fb
      e.io.wakeup_cdb  := wcdb
      e.io.wk_intm_phy_br  := io.wk_intm_phy_br
      e.io.wk_intm_phy_div := io.wk_intm_phy_div
      e.io.wk_intm_phy_mul := io.wk_intm_phy_mul
      e.io.wk_intm_sel_br  := io.wk_intm_sel_br
      e.io.wk_intm_sel_div := io.wk_intm_sel_div
      if (cfg.lsuWakeupPredecode && cfg.zicsr) {
        e.io.wk_lsu_phy_c := io.wk_lsu_phy_c
        e.io.wk_lsu_sel_c := io.wk_lsu_sel_c
      }
      e.io.wk_lsu_phy_a    := io.wk_lsu_phy_a
      e.io.wk_lsu_phy_l    := io.wk_lsu_phy_l
      e.io.wk_lsu_sel_a    := io.wk_lsu_sel_a
      rs_valid(i)     := e.io.valid
      rs_req_v0(i)    := e.io.request_v0
      rs_req_v1(i)    := (if (cfg.intCsrSpeculation) e.io.request_load else e.io.request_v1)
      rs_entry_out(i) := e.io.entry_out
      rs_entry(i)     := e.io.entry
      rs_bypass(i)    := e.io.rs_bypass
    }

    // Select completed decisions; CSR has priority over atomic/load wakeup.
    arb0.io.rs_request := rs_req_v0.asBits
    arb1.io.rs_request := rs_req_v1.asBits
    if (cfg.intCsrSpeculation) arbCsr.io.rs_request := Vec(entries.map(_.io.request_csr)).asBits
    if (cfg.intCsrSpeculation) arbAtomic.io.rs_request := Vec(entries.map(_.io.request_atomic)).asBits
    val rs_grant      = selectIssue(arb0.io.rs_grant, arb1.io.rs_grant, arbCsr.io.rs_grant, arbAtomic.io.rs_grant)
    val compress_flat = selectIssue(arb0.io.rs_compress_flat, arb1.io.rs_compress_flat,
      arbCsr.io.rs_compress_flat, arbAtomic.io.rs_compress_flat)
    for (i <- 0 until D) entries(i).io.grant := rs_grant(i)
    val comp       = (0 until D).map(i => compress_flat(i * 2, 2 bits))
    // Complete payload and bypass selection independently for each decision.
    val fu_issue0 = (0 until W).map(k => arb0.io.fu_issue_flat(k * D, D bits))
    val fu_issue1 = (0 until W).map(k => arb1.io.fu_issue_flat(k * D, D bits))
    val fu_issueCsr = if (cfg.intCsrSpeculation)
      (0 until W).map(k => arbCsr.io.fu_issue_flat(k * D, D bits)) else null
    val fu_issueAtomic = if (cfg.intCsrSpeculation)
      (0 until W).map(k => arbAtomic.io.fu_issue_flat(k * D, D bits)) else null

    // Compaction keeps valid entries contiguous from slot zero.
    io.from_ds_ready := !rs_valid(D - IDW)
    val ds_ready = io.from_ds_ready

    val int_rs_top = Reg(UInt(IDX bits)) init (0)
    val int_rs_valid = (0 until W).map(k => selectIssue(fu_issue0(k).orR, fu_issue1(k).orR,
      fu_issueCsr(k).orR, fu_issueAtomic(k).orR))
    val pops = (0 until W).map(k => int_rs_valid(k).asUInt).reduce(_ +^ _)
    val top_after_pop = (int_rs_top - pops).resize(IDX)
    val doPush0 = io.from_ds_valid(0) && ds_ready
    val doPush1 = io.from_ds_valid(1) && ds_ready
    val slot0 = top_after_pop
    val slot1 = (top_after_pop + doPush0.asUInt).resize(IDX)
    int_rs_top := (slot1 + doPush1.asUInt).resize(IDX)

    val rs_push = Vec(Bits(IDW bits), D)
    for (i <- 0 until D) {
      val sel0 = doPush0 && (slot0 === i)
      val sel1 = doPush1 && (slot1 === i)
      rs_push(i) := sel1 ## sel0
    }
    val rs_push_entry = (0 until D).map(i => RsUtil.orMux(rs_push(i), from_ds_entry))

    // Dispatch replaces vacated slots; survivors shift down by one or two entries.
    for (i <- 0 until D) {
      when(rs_push(i).orR) {
        push_en(i) := True;  clear(i) := False; entry_in(i) := rs_push_entry(i)
      } .elsewhen(rs_valid(i) && comp(i).orR) {
        when(comp(i) === B"2'b10") {
          if (i + 2 < D) { push_en(i) := rs_valid(i + 2); clear(i) := !rs_valid(i + 2); entry_in(i) := rs_entry_out(i + 2) }
          else           { push_en(i) := False; clear(i) := True; entry_in(i) := B(0, EW bits) }
        } otherwise {
          if (i + 1 < D) { push_en(i) := rs_valid(i + 1); clear(i) := !rs_valid(i + 1); entry_in(i) := rs_entry_out(i + 1) }
          else           { push_en(i) := False; clear(i) := True; entry_in(i) := B(0, EW bits) }
        }
      } .otherwise {
        push_en(i) := False; clear(i) := False; entry_in(i) := B(0, EW bits)
      }
    }

    // Substitute each arm's LSU match bits in the selected bypass payload.
    // Other producer enables remain intact, including arbitrary multi-hit cases.
    val issued = (0 until W).map(k => IntRsEntry.fromBits(
      selectIssue(RsUtil.orMux(fu_issue0(k), rs_entry), RsUtil.orMux(fu_issue1(k), rs_entry),
        RsUtil.orMux(fu_issueCsr(k), rs_entry), RsUtil.orMux(fu_issueAtomic(k), rs_entry)), cfg))
    val L    = cfg.cdbLsuLane
    val bypV0 = (0 until D).map(i => RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, L, False, False))
    val bypV1 = (0 until D).map { i =>
      val e = entries(i)
      val m1 = if (cfg.intCsrSpeculation) e.io.m1_load else e.io.m1_lsu
      val m2 = if (cfg.intCsrSpeculation) e.io.m2_load else e.io.m2_lsu
      RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, L, m1, m2)
    }
    val bypCsr = if (cfg.intCsrSpeculation) (0 until D).map(i =>
      RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, L, entries(i).io.m1_csr, entries(i).io.m2_csr)) else null
    val bypAtomic = if (cfg.intCsrSpeculation) (0 until D).map(i =>
      RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, L, entries(i).io.m1_atomic, entries(i).io.m2_atomic)) else null
    val rs1_value = (0 until W).map(k => io.to_prf_rs1_value_flat(k * 32, 32 bits))
    val rs2_value = (0 until W).map(k => io.to_prf_rs2_value_flat(k * 32, 32 bits))

    for (k <- 0 until W) {
      io.to_prf_rs1_phy_flat(k * PIDX, PIDX bits) := issued(k).rs1_phy
      io.to_prf_rs2_phy_flat(k * PIDX, PIDX bits) := issued(k).rs2_phy
      io.to_prf_rs_bypass_flat(k * BPW, BPW bits) :=
        selectIssue(RsUtil.orMux(fu_issue0(k), bypV0), RsUtil.orMux(fu_issue1(k), bypV1),
          RsUtil.orMux(fu_issueCsr(k), bypCsr), RsUtil.orMux(fu_issueAtomic(k), bypAtomic))

      // Select operands before the ALU input registers to keep its adder path clear.
      val opA = Mux(issued(k).op1_sel === OP1_RS1, rs1_value(k), B(0, 32 bits))
      val opB = Mux(issued(k).op2_sel === OP2_RS2, rs2_value(k), issued(k).imm)
      val falu = issued(k).rob_id ## issued(k).rd_arch ## issued(k).rd_phy ## issued(k).fu_opcode ##
                 opA ## opB ## rs1_value(k) ## rs2_value(k)
      alus(k).io.int_rs_valid  := int_rs_valid(k)
      alus(k).io.fu_alu_reg_in := falu

      io.fu_cdb_rob_id_flat(k * RIDX, RIDX bits)   := alus(k).io.cdb_rob_id
      io.fu_cdb_rd_phy_flat(k * PIDX, PIDX bits)   := alus(k).io.cdb_rd_phy
      io.fu_cdb_rd_arch_flat(k * AIDX, AIDX bits)  := alus(k).io.cdb_rd_arch
      io.fu_cdb_rd_value_flat(k * 32, 32 bits) := alus(k).io.cdb_rd_value
      io.fu_cdb_rs1_dbg_flat(k * 32, 32 bits)  := alus(k).io.cdb_rs1_value_dbg
      io.fu_cdb_rs2_dbg_flat(k * 32, 32 bits)  := alus(k).io.cdb_rs2_value_dbg
      io.fu_cdb_valid(k) := alus(k).io.cdb_valid

      io.alu_bypass_flat(k * cfg.bypassNetW, cfg.bypassNetW bits) := alus(k).io.bypass
      if (cfg.aluAguFusion) io.alu_address_flat(k * ooo.memory.AluAddressSource.width,ooo.memory.AluAddressSource.width bits) := alus(k).io.address_source
    }
  }
}
