package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Branch reservation station with operand pre-reads and fast bypass. */
class BrRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("br_rs_spinal")
  val D    = cfg.brrsDepth
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val AIDX = cfg.arfIdx
  val RIDX = cfg.robIdx
  val EW   = RsEntryLayout.br(cfg).width
  val FBRW = cfg.fuBrRegW
  val BPW  = BypassT.width(cfg)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_entry_flat = in Bits (EW bits)
    val from_ds_valid      = in Bool()
    val from_ds_ready      = out Bool()
    val branch_ready       = in Bool()
    // Read registered operands before the late grant selects a value pair.
    val to_prf_bpre_select1 = if (cfg.brPrfSharedPredecode) out Bits(cfg.prfDepth - 1 bits) else null
    val to_prf_bpre_select2 = if (cfg.brPrfSharedPredecode) out Bits(cfg.prfDepth - 1 bits) else null
    val to_prf_bpre_phy1_flat   = out Bits (D * PIDX bits)
    val to_prf_bpre_phy2_flat   = out Bits (D * PIDX bits)
    val to_prf_bpre_bypass_flat = out Bits (D * BPW bits)
    val to_prf_bpre_value1_flat = in  Bits (D * 32 bits)
    val to_prf_bpre_value2_flat = in  Bits (D * 32 bits)
    // LSU data is inserted after the PRF lookup when its producer matches.
    val cdb_lsu_value = in Bits (32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * PIDX bits)
    val cdb_valid       = in Bits (CDBW bits)
    val alu_bypass_flat = in Bits (NFB * cfg.bypassNetW bits)
    val fu_cdb_rob_id = out Bits (RIDX bits);  val fu_cdb_rd_phy = out Bits (PIDX bits)
    val fu_cdb_rd_arch = out Bits (AIDX bits); val fu_cdb_rd_value = out Bits (32 bits)
    val fu_cdb_rs1_dbg = out Bits (32 bits); val fu_cdb_rs2_dbg = out Bits (32 bits)
    val fu_cdb_valid = out Bool()
    val br_cdb_rob_id = out Bits (RIDX bits); val br_cdb_miss_predict = out Bool()
    val br_cdb_target_address = out Bits (32 bits); val br_cdb_valid = out Bool()
    val br_cdb_branch_taken = out Bool()
    // debug taps for perf_monitor (br_rs_i.fu_br_i.*)
    val dbg_fu_br_valid = out Bool(); val dbg_miss_predict = out Bool(); val dbg_reg_out = out Bits (FBRW bits)
  }
  noIoPrefix()

  val fubr = new FuBr(cfg); fubr.io.clk := io.clk; fubr.io.rst := io.rst

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.br(cfg)))

    val wcdb = RsUtil.wakeupVec(io.cdb_rd_phy_flat, io.cdb_valid, cfg)
    val fb = RsUtil.bypassVec(io.alu_bypass_flat, cfg)

    val rs_valid   = Vec(Bool(), D)
    val rs_request = Vec(Bool(), D)
    val rs_entry   = Vec(Bits(EW bits), D)
    val rs_bypass  = Vec(BypassT(cfg), D)
    val push_en    = Vec(Bool(), D)

    val notValid = (0 until D).map(i => !rs_valid(i))
    val doPush = io.from_ds_valid && io.branch_ready
    val firstFree = RsUtil.firstOneHot(notValid)
    for (i <- 0 until D) push_en(i) := doPush && firstFree(i)

    val rs_grant = RsUtil.firstOneHot(rs_request)

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := io.from_ds_entry_flat
      e.io.clear       := False
      e.io.fast_bypass := fb
      e.io.wakeup_cdb  := wcdb
      rs_valid(i)   := e.io.valid
      rs_request(i) := e.io.request
      rs_entry(i)   := e.io.entry
      rs_bypass(i)  := e.io.rs_bypass
    }

    io.from_ds_ready := notValid.reduce(_ || _)

    val grantBits = rs_grant.asBits
    val issued = RsUtil.orMux(grantBits, rs_entry)

    // Export registered operand addresses with LSU and fast bypass disabled.
    // Reinsert those lanes after the grant selection.
    val LL   = cfg.cdbLsuLane
    val FB   = CDBW                                  // fast-bypass bit in rs{1,2}_en
    val bypV0 = (0 until D).map(i => RsUtil.withBypassLaneEn(rs_bypass(i).toBits, cfg, LL, False, False))
    // Select the query before the PRF in the FPGA area configuration. Only the
    // granted entry consumes the broadcast response; the issue cycle is unchanged.
    val shareReads = (cfg.prfReadSharing & 4) != 0
    val readBypass = bypV0.map(RsUtil.withBypassLaneEn(_, cfg, FB, False, False))
    val read_phy1 = (0 until D).map(i => BrRsEntry.rs1Phy(rs_entry(i), cfg))
    for (i <- 0 until D) io.to_prf_bpre_phy1_flat(i * PIDX, PIDX bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(grantBits, read_phy1) else B(0, PIDX bits) } else read_phy1(i))
    val read_phy2 = (0 until D).map(i => BrRsEntry.rs2Phy(rs_entry(i), cfg))
    for (i <- 0 until D) io.to_prf_bpre_phy2_flat(i * PIDX, PIDX bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(grantBits, read_phy2) else B(0, PIDX bits) } else read_phy2(i))
    for (i <- 0 until D) io.to_prf_bpre_bypass_flat(i * BPW, BPW bits) :=
      (if (shareReads) { if (i == 0) RsUtil.orMux(grantBits, readBypass) else B(0, BPW bits) } else readBypass(i))
    if (cfg.brPrfSharedPredecode) {
      // Each comparison starts at the registered physical tag. Only the grant
      // remains on the final row select; no selected-address decoder follows it.
      for (row <- 1 until cfg.prfDepth) {
        io.to_prf_bpre_select1(row - 1) := ooo.OhSel.bool(grantBits,
          read_phy1.map(_ === B(row, PIDX bits)))
        io.to_prf_bpre_select2(row - 1) := ooo.OhSel.bool(grantBits,
          read_phy2.map(_ === B(row, PIDX bits)))
      }
    }
    val preV1 = (0 until D).map(i => io.to_prf_bpre_value1_flat((if (shareReads) 0 else i) * 32, 32 bits))
    val preV2 = (0 until D).map(i => io.to_prf_bpre_value2_flat((if (shareReads) 0 else i) * 32, 32 bits))
    // A matching LSU producer overrides the stored/CDB operand only when its lane is valid.
    // Fast ALU bypass is selected after the grant mux; each operand has a unique producer.
    val vLsu = io.cdb_valid(LL)
    val v1 = (0 until D).map(i => Mux(vLsu && entries(i).io.m1_lsu, io.cdb_lsu_value, preV1(i)))
    val v2 = (0 until D).map(i => Mux(vLsu && entries(i).io.m2_lsu, io.cdb_lsu_value, preV2(i)))
    // Select stored/CDB operands and the bypass lane using the grant, then insert ALU data last.
    // The operand’s one-hot bypass field makes the discarded stored value a don’t-care.
    val fb1En  = (0 until D).map(i => rs_bypass(i).rs1_bypass_en(FB))
    val fb2En  = (0 until D).map(i => rs_bypass(i).rs2_bypass_en(FB))
    val fb1Sel = (0 until D).map(i => rs_bypass(i).rs1_bypass_sel)
    val fb2Sel = (0 until D).map(i => rs_bypass(i).rs2_bypass_sel)
    def hoist(base: collection.Seq[Bits], en: collection.Seq[Bool],
              sl: collection.Seq[Bits]): Bits = {
      val useFb = (0 until D).map(i => grantBits(i) && en(i)).reduce(_ || _)
      val s     = RsUtil.orMux(grantBits, sl)
      val fbVal = Vec((0 until NFB).map(k => fb(k).rd_value))(s.asUInt)
      Mux(useFb, fbVal, RsUtil.orMux(grantBits, base))
    }
    val rs1Val = hoist(v1, fb1En, fb1Sel)
    val rs2Val = hoist(v2, fb2En, fb2Sel)

    val i_predict_target = BrRsEntry.predictTarget(issued)
    val i_predict_taken  = BrRsEntry.predictTaken(issued)
    val i_is_compressed  = BrRsEntry.isCompressed(issued)
    val i_fu_opcode      = BrRsEntry.fuOpcode(issued)
    val i_pc             = BrRsEntry.pc(issued)
    val i_imm            = BrRsEntry.imm(issued)
    val i_rd_arch        = BrRsEntry.rdArch(issued, cfg)
    val i_rd_phy         = BrRsEntry.rdPhy(issued, cfg)
    val i_rob_id         = BrRsEntry.robId(issued, cfg)

    val fbr = i_rob_id ## i_rd_arch ## i_rd_phy ## i_fu_opcode ## i_pc ## i_imm ##
              rs1Val ## rs2Val ## i_is_compressed ## i_predict_taken ## i_predict_target
    fubr.io.br_rs_valid  := rs_request.reduce(_ || _)
    fubr.io.fu_br_reg_in := fbr
  }

  io.fu_cdb_rob_id := fubr.io.cdb_rob_id; io.fu_cdb_rd_phy := fubr.io.cdb_rd_phy
  io.fu_cdb_rd_arch := fubr.io.cdb_rd_arch; io.fu_cdb_rd_value := fubr.io.cdb_rd_value
  io.fu_cdb_rs1_dbg := fubr.io.cdb_rs1_value_dbg; io.fu_cdb_rs2_dbg := fubr.io.cdb_rs2_value_dbg
  io.fu_cdb_valid := fubr.io.cdb_valid
  io.br_cdb_rob_id := fubr.io.br_cdb_rob_id; io.br_cdb_miss_predict := fubr.io.br_cdb_miss_predict
  io.br_cdb_target_address := fubr.io.br_cdb_target_address; io.br_cdb_valid := fubr.io.br_cdb_valid
  io.br_cdb_branch_taken := fubr.io.br_cdb_branch_taken
  io.dbg_fu_br_valid := fubr.io.dbg_fu_br_valid
  io.dbg_miss_predict := fubr.io.dbg_miss_predict
  io.dbg_reg_out := fubr.io.dbg_reg_out
}
