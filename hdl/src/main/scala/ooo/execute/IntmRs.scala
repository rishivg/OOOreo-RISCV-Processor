package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Multiply/divide reservation station sharing one CDB lane. */
class IntmRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("intm_rs_spinal")
  val D    = cfg.intmrsDepth
  val IDW  = cfg.idWidth
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val AIDX = cfg.arfIdx
  val RIDX = cfg.robIdx
  val EW   = RsEntryLayout.intm(cfg).width
  val REGW = cfg.intmRsRegW
  val CDBR = cfg.fuCdbRegW
  val BPW  = BypassT.width(cfg)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_entry_flat = in Bits (IDW * EW bits)
    val from_ds_valid      = in Bits (IDW bits)
    val from_ds_ready      = out Bool()
    // Read registered operands before the late grant selects a value pair.
    val to_prf_ipre_phy1_flat   = out Bits (D * PIDX bits)
    val to_prf_ipre_phy2_flat   = out Bits (D * PIDX bits)
    val to_prf_ipre_bypass_flat = out Bits (D * BPW bits)
    val to_prf_ipre_value1_flat = in  Bits (D * 32 bits)
    val to_prf_ipre_value2_flat = in  Bits (D * 32 bits)
    // LSU data is inserted after the PRF lookup when its producer matches.
    val cdb_lsu_value = in Bits (32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits)
    val cdb_valid       = in Bits (CDBW bits)
    val alu_bypass_flat = in Bits (NFB * cfg.bypassNetW bits)
    // Branch has priority on the shared INTM writeback lane.
    // cdb_ready=0 the cycle branch broadcasts -> intm freezes (holds its result).
    val cdb_ready       = in Bool()
    val fu_cdb_rob_id = out Bits (RIDX bits);  val fu_cdb_rd_phy = out Bits (PIDX bits)
    val fu_cdb_rd_arch = out Bits (AIDX bits); val fu_cdb_rd_value = out Bits (32 bits)
    val fu_cdb_rs1_dbg = out Bits (32 bits); val fu_cdb_rs2_dbg = out Bits (32 bits)
    val fu_cdb_valid = out Bool()
    // wakeup pre-resolve taps (RsEntry intmSplit): the two rd_phy sources behind
    // fu_cdb_rd_phy's div-priority mux (both register outputs) + the mux select.
    val fu_cdb_rd_phy_mul = out Bits (PIDX bits)
    val fu_cdb_rd_phy_div = out Bits (PIDX bits)
    val fu_cdb_sel_div    = out Bool()
    val fu_cdb_value_mul = if (cfg.memCdbSpeculation) out Bits(32 bits) else null
    val fu_cdb_value_div = if (cfg.memCdbSpeculation) out Bits(32 bits) else null
    // Pre-resolve producer tags so both issue decisions precede late LSU validity.
    // Feedback comes from the same registered producers as the normal CDB path.
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
    // Divider handshake and packed payload
    val div_prv_valid = out Bool(); val div_prv_ready = in Bool()
    val div_nxt_valid = in Bool();  val div_nxt_ready = out Bool()
    val div_iss_in  = out Bits (REGW bits)
    val div_cdb_out = in  Bits (CDBR bits)
    // Multiplier launch observation
    val dbg_mul_start = out Bool()
  }
  noIoPrefix()

  val fumul = new FuMul(cfg); fumul.io.clk := io.clk; fumul.io.rst := io.rst
  io.dbg_mul_start := fumul.io.mul_start

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.intm(cfg), wkPreResolve = true))
    val from_ds_entry = (0 until IDW).map(w => io.from_ds_entry_flat(w * EW, EW bits))

    val wcdb = RsUtil.wakeupVec(io.cdb_rd_phy_flat, io.cdb_valid, cfg)
    val fb = RsUtil.bypassVec(io.alu_bypass_flat, cfg)

    val rs_valid   = Vec(Bool(), D)
    val rs_req_v0  = Vec(Bool(), D)
    val rs_req_v1  = Vec(Bool(), D)
    val rs_entry   = Vec(Bits(EW bits), D)
    val rs_bypass  = Vec(BypassT(cfg), D)
    val push_en    = Vec(Bool(), D)
    val entry_in   = Vec(Bits(EW bits), D)

    val n_avail = (0 until D).map(i => (!rs_valid(i)).asUInt).reduce(_ +^ _)
    io.from_ds_ready := n_avail >= IDW
    val ds_ready = io.from_ds_ready

    // push: first/second free slot (dual dispatch)
    val notValid = (0 until D).map(i => !rs_valid(i))
    val firstFree  = RsUtil.firstOneHot(notValid)
    val notValid2  = (0 until D).map(i => notValid(i) && !firstFree(i))
    val secondFree = RsUtil.firstOneHot(notValid2)
    val p0 = io.from_ds_valid(0) && ds_ready
    val p1 = io.from_ds_valid(1) && ds_ready
    for (i <- 0 until D) {
      val en0 = p0 && firstFree(i)
      val en1 = p1 && secondFree(i)
      push_en(i) := en0 || en1
      entry_in(i) := RsUtil.orMux(en1 ## en0, from_ds_entry)
    }

    // Select the first ready multiply and divide independently; a ready divide has priority.
    // Compute both LSU-valid cofactors before the late LSU lane is selected.
    val fu_mul_ready = fumul.io.prv_ready
    val fu_div_ready = io.div_prv_ready
    case class GrantNet(req: collection.Seq[Bool]) extends Area {
      val mulReq = (0 until D).map(i => req(i) && !rs_entry(i)(2))
      val divReq = (0 until D).map(i => req(i) &&  rs_entry(i)(2))
      val mulFirst = RsUtil.firstOneHot(mulReq); val divFirst = RsUtil.firstOneHot(divReq)
      val mulG = Vec((0 until D).map(i => fu_mul_ready && mulFirst(i)))
      val divG = Vec((0 until D).map(i => fu_div_ready && divFirst(i)))
      val divGAny  = divG.reduce(_ || _)
      val grant    = Mux(divGAny, divG.asBits, mulG.asBits)
      val mulPrvValid = Mux(divGAny, False, mulReq.reduce(_ || _))   // fumul.prv_valid cofactor
      val divPrvValid = divReq.reduce(_ || _)                        // div_prv_valid cofactor
    }
    val vLsu = io.cdb_valid(cfg.cdbLsuLane)
    val g0 = GrantNet(rs_req_v0); val g1 = GrantNet(rs_req_v1)
    val rs_grant = Mux(vLsu, g1.grant, g0.grant)

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := entry_in(i)
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

    // Complete both issue buses before selecting with late LSU validity.
    val issued = Mux(vLsu, RsUtil.orMux(g1.grant, rs_entry), RsUtil.orMux(g0.grant, rs_entry))
    val i_fu_opcode = IntmRsEntry.fuOpcode(issued)
    val i_rd_arch   = IntmRsEntry.rdArch(issued, cfg)
    val i_rd_phy    = IntmRsEntry.rdPhy(issued, cfg)
    val i_rob_id    = IntmRsEntry.robId(issued, cfg)
    val LL   = cfg.cdbLsuLane
    val FB   = CDBW                                  // fast-bypass bit in rs{1,2}_en
    val bypV0 = (0 until D).map(i => RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, LL, False, False))

    // Export registered operand addresses with fast bypass disabled.
    // The selected ALU bypass is reinserted after the grant mux.
    val shareReads = (cfg.prfReadSharing & 2) != 0
    val readBypass = bypV0.map(RsUtil.withBypassLaneEn(_, cfg, FB, False, False))
    val read_phy1 = (0 until D).map(i => IntmRsEntry.rs1Phy(rs_entry(i), cfg))
    for (i <- 0 until D) io.to_prf_ipre_phy1_flat(i * PIDX, PIDX bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(rs_grant, read_phy1) else B(0, PIDX bits) } else read_phy1(i))
    val read_phy2 = (0 until D).map(i => IntmRsEntry.rs2Phy(rs_entry(i), cfg))
    for (i <- 0 until D) io.to_prf_ipre_phy2_flat(i * PIDX, PIDX bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(rs_grant, read_phy2) else B(0, PIDX bits) } else read_phy2(i))
    for (i <- 0 until D) io.to_prf_ipre_bypass_flat(i * BPW, BPW bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(rs_grant, readBypass) else B(0, BPW bits) } else readBypass(i))
    val preV1 = (0 until D).map(i => io.to_prf_ipre_value1_flat((if (shareReads) 0 else i) * 32, 32 bits))
    val preV2 = (0 until D).map(i => io.to_prf_ipre_value2_flat((if (shareReads) 0 else i) * 32, 32 bits))
    // Each physical register has one producer. Substitute LSU data only for
    // operands whose registered producer tag matches the LSU broadcast.
    val preV1c1 = (0 until D).map(i => Mux(entries(i).io.m1_lsu, io.cdb_lsu_value, preV1(i)))
    val preV2c1 = (0 until D).map(i => Mux(entries(i).io.m2_lsu, io.cdb_lsu_value, preV2(i)))
    // Select stored/CDB operands and the bypass lane using the grant, then insert ALU data last.
    // The operand’s one-hot bypass field makes the discarded stored value a don’t-care.
    val fb1En  = (0 until D).map(i => rs_bypass(i).rs1_bypass_en(FB))
    val fb2En  = (0 until D).map(i => rs_bypass(i).rs2_bypass_en(FB))
    val fb1Sel = (0 until D).map(i => rs_bypass(i).rs1_bypass_sel)
    val fb2Sel = (0 until D).map(i => rs_bypass(i).rs2_bypass_sel)
    def hoist(g: Bits, base: collection.Seq[Bits], en: collection.Seq[Bool],
              sl: collection.Seq[Bits]): Bits = {
      val useFb = (0 until D).map(i => g(i) && en(i)).reduce(_ || _)
      val s     = RsUtil.orMux(g, sl)
      val fbVal = Vec((0 until NFB).map(k => fb(k).rd_value))(s.asUInt)
      Mux(useFb, fbVal, RsUtil.orMux(g, base))
    }
    val rs1Val = Mux(vLsu, hoist(g1.grant, preV1c1, fb1En, fb1Sel),
                           hoist(g0.grant, preV1,   fb1En, fb1Sel))
    val rs2Val = Mux(vLsu, hoist(g1.grant, preV2c1, fb2En, fb2Sel),
                           hoist(g0.grant, preV2,   fb2En, fb2Sel))

    val intm_rs_in = IntmRsReg.pack(i_rob_id, i_rd_arch, i_rd_phy, i_fu_opcode, rs1Val, rs2Val)

    // FuMul (internal) handshake -- prv_valid cofactors muxed on the same late bit
    fumul.io.prv_valid := Mux(vLsu, g1.mulPrvValid, g0.mulPrvValid)
    fumul.io.iss_in    := intm_rs_in
    val fu_mul_valid = fumul.io.nxt_valid
    val fu_mul_cdb   = fumul.io.cdb_out

    // fu_div (external) handshake
    io.div_prv_valid := Mux(vLsu, g1.divPrvValid, g0.divPrvValid)
    io.div_iss_in    := intm_rs_in
    val fu_div_valid = io.div_nxt_valid
    val fu_div_cdb   = io.div_cdb_out

    // Division wins over multiplication. Branch writeback deasserts cdb_ready,
    // holding both FU results and preventing dequeue/broadcast.
    val cdb_valid     = fu_mul_valid || fu_div_valid
    fumul.io.nxt_ready := io.cdb_ready && !fu_div_valid   // cdb_mul_ready
    io.div_nxt_ready   := io.cdb_ready                    // cdb_div_ready
    val cdb_reg_in = Mux(fu_div_valid, fu_div_cdb, fu_mul_cdb)
    io.fu_cdb_valid   := cdb_valid && io.cdb_ready
    io.fu_cdb_rd_phy_mul := FuCdbReg.rdPhy(fu_mul_cdb, cfg)
    io.fu_cdb_rd_phy_div := FuCdbReg.rdPhy(fu_div_cdb, cfg)
    io.fu_cdb_sel_div    := fu_div_valid
    if (cfg.memCdbSpeculation) {
      io.fu_cdb_value_mul := FuCdbReg.rdValue(fu_mul_cdb)
      io.fu_cdb_value_div := FuCdbReg.rdValue(fu_div_cdb)
    }
    io.fu_cdb_rob_id  := FuCdbReg.robId(cdb_reg_in, cfg)
    io.fu_cdb_rd_arch := FuCdbReg.rdArch(cdb_reg_in, cfg)
    io.fu_cdb_rd_phy  := FuCdbReg.rdPhy(cdb_reg_in, cfg)
    io.fu_cdb_rd_value := FuCdbReg.rdValue(cdb_reg_in)
    io.fu_cdb_rs1_dbg := FuCdbReg.rs1Dbg(cdb_reg_in)
    io.fu_cdb_rs2_dbg := FuCdbReg.rs2Dbg(cdb_reg_in)
  }
}
