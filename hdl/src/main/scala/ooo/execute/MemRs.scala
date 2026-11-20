package ooo.execute

import spinal.core._
import ooo.{CpuConfig, PrioSelect}
import ooo.memory.{AguReg, FuAgu}

/** Memory reservation station feeding address generation and store-data reads. */
class MemRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("mem_rs_spinal")
  val D    = cfg.memrsDepth
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val EW   = RsEntryLayout.mem(cfg).width
  val AGULSQ = cfg.aguLsqW
  val BPW  = BypassT.width(cfg)
  val SELW = log2Up(cfg.intIssueWidth)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_entry_flat = in Bits (EW bits)
    val from_ds_valid      = in Bool()
    val from_ds_ready      = out Bool()
    val to_prf_rs2_phy   = out Bits (PIDX bits)
    val to_prf_rs_bypass = out Bits (BPW bits)
    val to_prf_rs2_value = in  Bits (32 bits)
    // Read all registered rs1 addresses before the late grant selects an operand.
    val to_prf_pre_rs1_select_flat = if (cfg.memPrfPredecode) out Bits(D * (cfg.prfDepth - 1) bits) else null
    val to_prf_pre_rs1_phy_flat    = out Bits (D * PIDX bits)
    val to_prf_pre_rs1_bypass_flat = out Bits (D * BPW bits)
    val to_prf_pre_rs1_value_flat  = in  Bits (D * 32 bits)
    // LSU data is inserted after the PRF lookup when its producer matches.
    val cdb_lsu_value = in Bits (32 bits)
    val base_cdb_values = if (cfg.memCdbSpeculation) in Bits(160 bits) else null
    val cdb_lsu_way_value_flat = if (cfg.lsuWaySpeculation) in Bits(cfg.lsuBypassCandidates * 32 bits) else null
    val cdb_lsu_way_select = if (cfg.lsuWaySpeculation) in Bits(cfg.lsuBypassCandidates bits) else null
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits)
    val cdb_valid       = in Bits (CDBW bits)
    // CDB-lane wakeup pre-resolve sources (RsEntry wkPreResolve): the muxed
    // rd_phy buses' register-output sources + their (early) mux selects.
    val wk_intm_phy_br  = in Bits (PIDX bits)
    val wk_intm_phy_div = in Bits (PIDX bits)
    val wk_intm_phy_mul = in Bits (PIDX bits)
    val wk_intm_sel_br  = in Bool()
    val wk_intm_sel_div = in Bool()
    val wk_lsu_phy_c = if (cfg.lsuWakeupPredecode && cfg.zicsr) in Bits(PIDX bits) else null
    val wk_lsu_sel_c = if (cfg.lsuWakeupPredecode && cfg.zicsr) in Bool() else null
    val wk_lsu_phy_a    = in Bits (PIDX bits)   // AtomicUnit result phy
    val wk_lsu_phy_l    = in Bits (PIDX bits)   // LDQ load result phy
    val wk_lsu_sel_a    = in Bool()          // atomic-broadcast select (aCdbV)
    val alu_bypass_flat = in Bits (NFB * cfg.bypassNetW bits)
    val alu_address_flat = if (cfg.aluAguFusion) in Bits(NFB * ooo.memory.AluAddressSource.width bits) else null
    val stb_match_targets = if (cfg.lsuCarryFreeStoreMatch) in Bits((cfg.stbDepth+1)*32 bits) else null
    val to_lsq_stb_matches = if (cfg.lsuCarryFreeStoreMatch) out Bits(cfg.stbDepth+1 bits) else null
    val to_lsq_valid = out Bool()
    val to_lsq_data  = out Bits (AGULSQ bits)
    // AGU hi16 split pass-through (see FuAgu): early conditional sums + c16 for
    // the request-side capture points; to_lsq_data keeps the merged addr.
    val to_lsq_hi0 = out Bits (16 bits)
    val to_lsq_hi1 = out Bits (16 bits)
    val to_lsq_c16 = out Bool()
    val to_lsq_ordered = if (cfg.mmio) out Bool() else null
    val to_lsq_clint = if (cfg.zicsr) out Bool() else null
    val to_lsq_clint_read_sel = if (cfg.zicsr) out Bits(ooo.memory.Clint.offsets.size bits) else null
    val to_lsq_misaligned = if (cfg.zicsr) out Bool() else null   // Zicsr (see FuAgu)
    val to_lsq_is_store   = if (cfg.zicsr) out Bool() else null
  }
  noIoPrefix()

  val agu = if (cfg.lsuEntrySpeculation) null else new FuAgu(cfg)
  if (!cfg.lsuEntrySpeculation) { agu.io.clk := io.clk; agu.io.rst := io.rst }

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.mem(cfg), wkPreResolve = true))

    val wcdb = RsUtil.wakeupVec(io.cdb_rd_phy_flat, io.cdb_valid, cfg)
    val fb = RsUtil.bypassVec(io.alu_bypass_flat, cfg)

    val rs_valid   = Vec(Bool(), D)
    val rs_req_v0  = Vec(Bool(), D)   // request cofactor, LSU-lane cdb_valid = 0
    val rs_req_v1  = Vec(Bool(), D)   // request cofactor, LSU-lane cdb_valid = 1
    val rs_entry   = Vec(Bits(EW bits), D)
    val rs_bypass  = Vec(BypassT(cfg), D)
    val push_en    = Vec(Bool(), D)

    val notValid = (0 until D).map(i => !rs_valid(i))
    val doPush = io.from_ds_valid && io.from_ds_ready
    if (cfg.rvfi && cfg.aguSignedImmediate) {
      when(doPush) {
        val immediate = MemRsEntry.imm(io.from_ds_entry_flat)
        assert(immediate(31 downto 12) === B(20 bits,default -> immediate(11)))
      }
    }
    val firstFree = RsUtil.firstOneHot(notValid)
    for (i <- 0 until D) push_en(i) := doPush && firstFree(i)
    val rs_grant = Vec(Bool(), D)
    // Evaluate issue selection for both LSU-valid cofactors and select the result late.
    val vLsu = io.cdb_valid(cfg.cdbLsuLane)
    val (any0, grant0, issued0) = PrioSelect((0 until D).map(rs_req_v0(_)), (0 until D).map(rs_entry(_)))
    val (any1, grant1, issued1) = PrioSelect((0 until D).map(rs_req_v1(_)), (0 until D).map(rs_entry(_)))
    val issueAny = Mux(vLsu, any1, any0)
    val issued   = Mux(vLsu, issued1, issued0)
    for (i <- 0 until D) rs_grant(i) := Mux(vLsu, grant1(i), grant0(i))

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := io.from_ds_entry_flat
      e.io.clear       := False
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
      rs_valid(i)   := e.io.valid
      rs_req_v0(i)  := e.io.request_v0
      rs_req_v1(i)  := e.io.request_v1
      rs_entry(i)   := e.io.entry
      rs_bypass(i)  := e.io.rs_bypass
    }

    io.from_ds_ready := notValid.reduce(_ || _)

    // Resolve bypass fields separately for each LSU-valid cofactor, keeping the late valid bit
    // out of the PRF lookup. Each response is consumed only under its matching cofactor.
    val g0 = Vec(Bool(), D); val g1 = Vec(Bool(), D)
    for (i <- 0 until D) { g0(i) := grant0(i); g1(i) := grant1(i) }
    val L    = cfg.cdbLsuLane
    val bypV0 = (0 until D).map(i => RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, L, False, False))
    val bypV1 = (0 until D).map(i => RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, L, entries(i).io.m1_lsu, entries(i).io.m2_lsu))
    val byp0 = RsUtil.orMux(g0.asBits, bypV0)
    val byp1 = RsUtil.orMux(g1.asBits, bypV1)
    val bypM = Mux(vLsu, byp1, byp0)

    // Compute operand/offset choices for both issue cofactors. The late LSU-valid bit
    // selects the matching pair; store data uses the selected entry’s single read.
    val i_fu_opcode = MemRsEntry.fuOpcode(issued)
    val i_imm0      = MemRsEntry.imm(issued0)
    val i_imm1      = MemRsEntry.imm(issued1)
    val i_rs2_phy   = MemRsEntry.rs2Phy(issued, cfg)
    val i_rob_id    = MemRsEntry.robId(issued, cfg)
    // Disable fast bypass during PRF reads to keep ALU data off that path.
    // This is valid only because hoist() reinserts the selected bypass value.
    val FB = CDBW                                    // fast-bypass bit in rs{1,2}_en
    // Keep stable registered addresses unmasked; adding valid gating would introduce transitions.
    val shareReads = (cfg.prfReadSharing & 1) != 0
    val readBypass = (0 until D).map { i =>
      val b = CombInit(bypV0(i))
      b(2 * SELW + (CDBW + 1) + FB) := False
      if (cfg.memCdbSpeculation)
        b(BPW - 1 downto BPW - (CDBW + 1)) := 0
      b
    }
    if (cfg.memPrfPredecode) {
      val decoded = Bits(cfg.prfDepth - 1 bits)
      for (r <- 1 until cfg.prfDepth)
        decoded(r - 1) := MemRsEntry.rs1Phy(io.from_ds_entry_flat,cfg).asUInt === r
      for (i <- 0 until D) {
        val select = Reg(Bits(cfg.prfDepth - 1 bits))
        when(push_en(i)) { select := decoded }
        io.to_prf_pre_rs1_select_flat(i * (cfg.prfDepth - 1),cfg.prfDepth - 1 bits) := select
      }
    }
    val read_phy = (0 until D).map(i => MemRsEntry.rs1Phy(rs_entry(i), cfg))
    for (i <- 0 until D) io.to_prf_pre_rs1_phy_flat(i * PIDX, PIDX bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(rs_grant.asBits, read_phy) else B(0, PIDX bits) } else read_phy(i))
    for (i <- 0 until D) io.to_prf_pre_rs1_bypass_flat(i * BPW, BPW bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(rs_grant.asBits, readBypass) else B(0, BPW bits) } else readBypass(i))
    val preVal = (0 until D).map(i => io.to_prf_pre_rs1_value_flat((if (shareReads) 0 else i) * 32, 32 bits))
    // A physical register has one producer. An LSU match therefore selects LSU
    // data directly; without a match, both issue paths use the pre-read value.
    val preVal1 = (0 until D).map(i => Mux(entries(i).io.m1_lsu, io.cdb_lsu_value, preVal(i)))
    // Select stored/CDB operands and the bypass lane using the grant, then insert ALU data last.
    // The operand’s one-hot bypass field makes the discarded stored value a don’t-care.
    val fbEn  = (0 until D).map(i => rs_bypass(i).rs1_bypass_en(FB))
    val fbSel = (0 until D).map(i => rs_bypass(i).rs1_bypass_sel)
    def hoist(g: Vec[Bool], base: collection.Seq[Bits]): Bits = {
      val useFb = (0 until D).map(i => g(i) && fbEn(i)).reduce(_ || _)
      val sel   = RsUtil.orMux(g.asBits, fbSel)      // early (registered compares)
      // rs1_bypass_sel is an INDEX into the lanes, matching Prf.aluBypassRdValue(sel)
      val fbVal = Vec((0 until NFB).map(k => fb(k).rd_value))(sel.asUInt)
      Mux(useFb, fbVal, RsUtil.orMux(g.asBits, base))
    }
    val rs1V0 = hoist(g0, preVal)
    val rs1V1 = hoist(g1, preVal1)
    io.to_prf_rs2_phy     := i_rs2_phy
    // The primary PRF port reads only rs2; rs1 comes from the pre-read group.
    io.to_prf_rs_bypass := B(0, CDBW + 1 bits) ##
                           bypM(BPW - (CDBW + 1) - 1 downto 2 * SELW) ##
                           B(0, SELW bits) ##
                           bypM(SELW - 1 downto 0)

    // FuAgu receives operands for both LSU-valid cases and selects the issued
    // address and debug values after the arithmetic.
    if (cfg.lsuEntrySpeculation) {
      // Keep the late issue grant after arithmetic and region classification.
      val candidates = (0 until D).map { i =>
        val unit = new FuAgu(cfg,sharedImmediate=true)
        if (cfg.lsuCarryFreeStoreMatch) unit.io.stb_match_targets:=io.stb_match_targets
        val e = rs_entry(i)
        val offset = MemRsEntry.imm(e)
        val fastValue = Vec((0 until NFB).map(k => fb(k).rd_value))(fbSel(i).asUInt)
        def operand(base: Bits): Bits = if (cfg.aluAguFusion) base else Mux(fbEn(i),fastValue,base)
        if (cfg.aluAguFusion) {
          unit.io.fast_sources_flat := io.alu_address_flat
          unit.io.fast_value := fastValue
          for (k <- 0 until NFB) unit.io.fast_select(k) := fbEn(i) && fbSel(i).asUInt === k
        }
        unit.io.clk := io.clk; unit.io.rst := io.rst
        unit.io.prv_valid := rs_grant(i)
        unit.io.agu_reg_in := AguReg.pack(MemRsEntry.robId(e,cfg),MemRsEntry.fuOpcode(e),
          offset,operand(preVal(i)),io.to_prf_rs2_value)
        unit.io.alt_rs1_value := operand(Mux(entries(i).io.m1_lsu,io.cdb_lsu_value,preVal(i)))
        unit.io.alt_imm := offset
        if (cfg.memCdbSpeculation) {
          unit.io.base_sources_flat := io.base_cdb_values
          val en = bypV0(i)(BPW - 1 downto BPW - (CDBW + 1)) & B((BigInt(1) << CDBW) - 1,CDBW + 1 bits)
          val stored = en === 0; val alu0 = en === 1; val alu1 = en === 2; val intm = en === 4
          unit.io.base_source_select(0) := stored
          unit.io.base_source_select(1) := alu0
          unit.io.base_source_select(2) := alu1
          unit.io.base_source_select(3) := intm && io.wk_intm_sel_br
          unit.io.base_source_select(4) := intm && !io.wk_intm_sel_br && io.wk_intm_sel_div
          unit.io.base_source_select(5) := intm && !io.wk_intm_sel_br && !io.wk_intm_sel_div
          unit.io.base_source_select(6) := !(stored || alu0 || alu1 || intm)
        }
        unit.io.alt_sel := vLsu
        if (cfg.lsuOperandSpeculation) unit.io.alt_operand_select := entries(i).io.m1_lsu
        if (cfg.lsuWaySpeculation) {
          unit.io.alt_way_select := io.cdb_lsu_way_select
          for (w <- 0 until cfg.lsuBypassCandidates)
            unit.io.alt_way_rs1_flat(w * 32,32 bits) := operand(
              if (cfg.lsuOperandSpeculation) io.cdb_lsu_way_value_flat(w * 32,32 bits)
              else Mux(entries(i).io.m1_lsu,io.cdb_lsu_way_value_flat(w * 32,32 bits),preVal(i)))
        }
        unit
      }
      def selected(value: FuAgu => Bits): Bits = ooo.OhSel(rs_grant.asBits,candidates.map(value))
      io.to_lsq_valid := issueAny
      io.to_lsq_data := selected(_.io.to_lsq)
      io.to_lsq_hi0 := selected(_.io.agu_hi0)
      io.to_lsq_hi1 := selected(_.io.agu_hi1)
      io.to_lsq_c16 := selected(_.io.agu_c16.asBits)(0)
      if (cfg.lsuCarryFreeStoreMatch) io.to_lsq_stb_matches:=selected(_.io.agu_stb_matches)
      if (cfg.mmio) io.to_lsq_ordered := selected(_.io.agu_ordered.asBits)(0)
      if (cfg.zicsr) {
        io.to_lsq_clint := selected(_.io.agu_clint.asBits)(0)
        io.to_lsq_clint_read_sel := selected(_.io.agu_clint_read_sel)
        io.to_lsq_misaligned := selected(_.io.agu_misaligned.asBits)(0)
        io.to_lsq_is_store := selected(_.io.agu_is_store.asBits)(0)
      }
    } else {
      val agu_reg = AguReg.pack(i_rob_id, i_fu_opcode, i_imm0, rs1V0, io.to_prf_rs2_value)
      agu.io.prv_valid  := issueAny
      agu.io.agu_reg_in := agu_reg
      if (cfg.lsuWaySpeculation) {
        agu.io.alt_way_select := io.cdb_lsu_way_select
        for (w <- 0 until cfg.lsuBypassCandidates) {
          val values = (0 until D).map(i => Mux(entries(i).io.m1_lsu,
            io.cdb_lsu_way_value_flat(w * 32,32 bits),preVal(i)))
          agu.io.alt_way_rs1_flat(w * 32,32 bits) := hoist(g1,values)
        }
      }
      agu.io.alt_rs1_value := rs1V1
      agu.io.alt_imm       := i_imm1
      agu.io.alt_sel       := vLsu
      io.to_lsq_valid := agu.io.nxt_valid
      io.to_lsq_data  := agu.io.to_lsq
      io.to_lsq_hi0   := agu.io.agu_hi0
      io.to_lsq_hi1   := agu.io.agu_hi1
      io.to_lsq_c16   := agu.io.agu_c16
      if (cfg.mmio) io.to_lsq_ordered := agu.io.agu_ordered
      if (cfg.zicsr) { io.to_lsq_clint := agu.io.agu_clint; io.to_lsq_clint_read_sel := agu.io.agu_clint_read_sel }
      if (cfg.zicsr) { io.to_lsq_misaligned := agu.io.agu_misaligned; io.to_lsq_is_store := agu.io.agu_is_store }
    }

  }
}
