package ooo.frontend

import spinal.core._
import spinal.lib._
import ooo.{CpuConfig, FastAdd, PrioSelect, OhSel}
import ooo.frontend.bpred.{Tage, Ubtb, Ras}

/** Fetch, prediction, realignment, and instruction-queue payload assembly. */
class FrontendTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("frontend_top_spinal")
  val IFW  = cfg.ifWidth
  val PROV = cfg.bpProvW
  val PMAX = 2 * IFW              // 8 parcels
  val LZ   = log2Up(IFW * 4)      // block byte-offset bits (4)
  val PCW  = cfg.parcelCntW
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val halt_fetch = if (cfg.lowPower || cfg.zicsr) in Bool() else null
    val invalidate = if (cfg.zicsr) in Bool() else null
    val backend_flush = in Bool()
    val backend_redirect_pc = in Bits (32 bits)
    val to_fifo_valid = out Bool(); val to_fifo_ready = in Bool()
    val to_fifo_inst_flat     = out Bits (IFW * 32 bits)
    val to_fifo_pre_flat = if (cfg.frontendPayloadSpeculation) out Bits(IFW * DispatchPredecode.width bits) else null
    val to_fifo_inst_raw_flat = out Bits (IFW * 32 bits)
    val to_fifo_is_compressed = out Bits (IFW bits)
    val to_fifo_predict_taken = out Bits (IFW bits)
    val to_fifo_predict_target_flat = out Bits (IFW * 32 bits)
    val to_fifo_pc_flat       = out Bits (IFW * 32 bits)
    val to_fifo_valid_slots   = out Bits (IFW bits)
    val to_fifo_kp_flat       = out Bits (IFW * log2Up(IFW) bits)
    val to_fifo_prov_flat     = out Bits (IFW * PROV bits)   // per-slot TAGE provider snapshot
    val icache_addr   = out Bits (32 bits); val icache_read = out Bool(); val icache_write = out Bool()
    val icache_wdata  = out Bits (256 bits); val icache_ready = in Bool(); val icache_raddr = in Bits (32 bits)
    val icache_rdata  = in  Bits (256 bits); val icache_rvalid = in Bool()
    val from_cb_update_en      = in Bool()
    val from_cb_pc             = in Bits (32 bits)
    val from_cb_fu_opcode      = in Bits (4 bits)
    val from_cb_branch_taken   = in Bool()
    val from_cb_target_address = in Bits (32 bits)
    val from_cb_kp             = in Bits (log2Up(IFW) bits)
    val from_cb_is_call        = in Bool()
    val from_cb_is_ret         = in Bool()
    val from_cb_is_compressed  = in Bool()
    val from_cb_prov           = in Bits (PROV bits)   // forwarded provider snapshot (committing branch)
    // perf tap
    val dbg_icache_unresponsive = out Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val prevRst = Reg(Bool()); prevRst := io.rst

    val carryValid = RegInit(False)
    val carryLo = Reg(Bits(16 bits)); val carryPc = Reg(Bits(32 bits))

    // IF1 fetch stage (produces pc + raw block words)
    val pcNext = Bits(32 bits)
    val if1 = new If1Stage(cfg)
    if1.io.clk := io.clk; if1.io.rst := io.rst; if1.io.flush := io.backend_flush
    if1.io.prv_valid := (if (cfg.lowPower || cfg.zicsr) !io.halt_fetch || io.backend_flush else True)
    if1.io.nxt_ready := io.to_fifo_ready && (if (cfg.lowPower || cfg.zicsr) !io.halt_fetch else True)
    if (cfg.zicsr) if1.io.invalidate := io.invalidate
    if1.io.pc_next := pcNext
    val if1Valid = if1.io.nxt_valid
    val pc = if1.io.pc
    val insts = if1.io.insts
    io.icache_addr := if1.io.icache_addr; io.icache_read := if1.io.icache_read; io.icache_write := if1.io.icache_write
    io.icache_wdata := if1.io.icache_wdata
    if1.io.icache_ready := io.icache_ready; if1.io.icache_raddr := io.icache_raddr
    if1.io.icache_rdata := io.icache_rdata; if1.io.icache_rvalid := io.icache_rvalid
    io.dbg_icache_unresponsive := if1.io.dbg_icache_unresponsive

    // C-ext parcel window
    val instWords = insts.subdivideIn(IFW slices)
    val blkParcels = Vec(Bits(16 bits), PMAX)
    for (w <- 0 until IFW) { blkParcels(2 * w) := instWords(w)(15 downto 0); blkParcels(2 * w + 1) := instWords(w)(31 downto 16) }
    val po = pc(LZ - 1 downto 1).asUInt                       // halfword offset

    val faParcels = Vec(Bits(16 bits), PMAX)
    val faPc = Bits(32 bits); val faNValid = UInt(PCW bits)
    when(carryValid) {
      faParcels(0) := carryLo
      for (k <- 1 until PMAX) faParcels(k) := blkParcels(k - 1)
      faPc := carryPc; faNValid := U(PMAX, PCW bits)
    }.otherwise {
      for (k <- 0 until PMAX) {
        faParcels(k) := B(0, 16 bits)
        when((po +^ k) < PMAX) { faParcels(k) := blkParcels((po + k).resize(log2Up(PMAX) bits)) }
      }
      faPc := pc; faNValid := (U(PMAX, PCW bits) - po).resize(PCW bits)
    }

    // fetch_align (C-ext realign + decompress)
    // FetchAlign builds FIFO payload and spanning parcels; prediction uses predecode below.
    val fa = if (!cfg.frontendPayloadSpeculation) new FetchAlign(cfg,flowOutputs=false) else null
    if (!cfg.frontendPayloadSpeculation) {
      fa.io.pc := faPc; fa.io.parcels := faParcels.asBits; fa.io.n_valid := faNValid.asBits
    }
    val payload = if (cfg.frontendPayloadSpeculation) new FetchPayload(cfg) else null
    if (cfg.frontendPayloadSpeculation) {
      payload.io.inst_arms := if1.io.inst_arms; payload.io.arm_select := if1.io.data_arm_select
      payload.io.pc := pc; payload.io.carry_valid := carryValid
      payload.io.carry_lo := carryLo; payload.io.carry_pc := carryPc
      io.to_fifo_pre_flat := payload.io.pre
    }
    val faInstPc = if (cfg.frontendPayloadSpeculation) payload.io.inst_pc else fa.io.inst_pc
    val faSpanLo = if (cfg.frontendPayloadSpeculation) payload.io.span_lo else fa.io.span_lo
    val faInst = if (cfg.frontendPayloadSpeculation) payload.io.inst else fa.io.inst
    val faRaw = if (cfg.frontendPayloadSpeculation) payload.io.raw else fa.io.inst_raw
    val faComp = if (cfg.frontendPayloadSpeculation) payload.io.comp else fa.io.inst_comp

    // Predecode each halfword lane’s control, call, and return flags before realignment.
    val ctrlL = Vec(Bool(), PMAX)
    val callL = Vec(Bool(), PMAX); val retL  = Vec(Bool(), PMAX)
    for (p <- 0 until PMAX) {
      ctrlL(p) := if1.io.flags(p * 3)
      callL(p) := if1.io.flags(p * 3 + 1)
      retL(p)  := if1.io.flags(p * 3 + 2)
    }
    // Spanning slot zero joins the held parcel with carryLo; flags matter only under carryValid.
    val (spanCtrl, spanCall, spanRet) = DispatchPredecode.controlFlags(blkParcels(0) ## carryLo, False)

    // Reconstruct each slot from predecoded lane offsets and the registered entry/carry state.
    val entryLane = Mux(carryValid, U(1, 3 bits), po)       // carry: slots >=1 chain from block lane 1
    val NARM   = cfg.iFetchWays + 1                            // hold + ways
    val pdArm   = if1.io.pd_arms.subdivideIn(NARM slices)
    val compArm = if1.io.comp_arms.subdivideIn(NARM slices)
    val rc = (0 until NARM).map { a =>
      val u = new RealignChain(cfg)
      u.io.pd          := pdArm(a)
      u.io.comp        := compArm(a)
      u.io.entry_lane  := entryLane
      u.io.carry_valid := carryValid
      u
    }
    val armSel = if1.io.arm_sel
    val laneSb  = OhSel(armSel, rc.map(_.io.lane_s))
    val snSb    = OhSel(armSel, rc.map(_.io.sn_s))
    val validSb = OhSel(armSel, rc.map(_.io.valid_s))
    val laneS = Vec(UInt(4 bits), IFW); val snS = Vec(UInt(4 bits), IFW)
    val validS = Vec(Bool(), IFW)
    for (s <- 0 until IFW) {
      laneS(s)  := laneSb(s * 4, 4 bits).asUInt
      snS(s)    := snSb(s * 4, 4 bits).asUInt
      validS(s) := validSb(s)
    }
    val chP   = OhSel(armSel, rc.map(_.io.ch_p.asBits)).asUInt
    val spanR = OhSel(armSel, rc.map(_.io.span_r.asBits))(0)
    // next fetch PC / per-slot fall-through: {blkBase(+1 on block overflow), lane, 0}.
    // In carry cycles pc IS the current block base, so blkBase is correct in both arms.
    val fBlkBase   = pc(31 downto LZ)
    val fBlkBaseP1 = FastAdd.addPow2(fBlkBase.asUInt,0,cfg.fpgaNativeAdd).asBits
    def lanePc(c: UInt): Bits = Mux(c(3), fBlkBaseP1, fBlkBase) ## c(2 downto 0).asBits ## B(0, 1 bits)
    val nextPcR = lanePc(chP)
    val seqS = Vec(Bits(32 bits), IFW)
    for (s <- 0 until IFW) seqS(s) := lanePc(snS(s))
    // per-slot predictor select {inB, lane}: all non-carry slots share the fetch
    // block (A); carry slot 0 is the spanner in A (prev block, lane 7), slots >=1
    // sit in the next block (B).
    val slotSel = Vec(Bits(4 bits), IFW)
    for (s <- 0 until IFW) slotSel(s) := (if (s == 0) False.asBits else carryValid.asBits) ## laneS(s)(2 downto 0).asBits
    // per-slot flags (slot 0 in carry = the registered spanner's decode)
    val ctrlS = Vec(Bool(), IFW); val callS = Vec(Bool(), IFW); val retS = Vec(Bool(), IFW)
    for (s <- 0 until IFW) {
      val li = laneS(s)(2 downto 0)
      if (s == 0) {
        ctrlS(0) := Mux(carryValid, spanCtrl, ctrlL(li))
        callS(0) := Mux(carryValid, spanCall, callL(li))
        retS(0)  := Mux(carryValid, spanRet,  retL(li))
      } else {
        ctrlS(s) := ctrlL(li); callS(s) := callL(li); retS(s) := retL(li)
      }
    }

    val predictTakenGshare = Bits(4 * IFW bits)   // per-LANE TAGE direction (2*LANES)
    val predictTargetUbtb = Bits(IFW * 32 bits); val predictTakenUbtb = Bits(IFW bits)
    val predictTaken = Bits(IFW bits); val predictTarget = Bits(IFW * 32 bits)
    val effPredictTaken = Bits(IFW bits)
    val fetchFire = io.to_fifo_valid && io.to_fifo_ready

    // prediction gating (non-control slots -> not-taken / fall-through)
    val effPt = Vec(Bool(), IFW); val effPtgt = Vec(Bits(32 bits), IFW); val isC = Vec(Bool(), IFW)
    for (i <- 0 until IFW) {
      isC(i) := ctrlS(i)
      effPt(i) := isC(i) && predictTaken(i)
      // Taken predictions carry a target; other slots carry their sequential PC.
      // This payload mux ends at the instruction queue, outside the next-PC loop.
      effPtgt(i) := Mux(isC(i) && predictTaken(i), predictTarget(i * 32, 32 bits), seqS(i))
    }
    effPredictTaken := effPt.asBits

    // Select the first valid predicted-taken instruction.
    val ptReq = (0 until IFW).map(i => validS(i) && effPt(i))
    // Only taken control-flow targets are consumed by priority selection; other target values are don’t-cares.
    val slotTgt = (0 until IFW).map(i => predictTarget(i * 32, 32 bits))
    val (ptEn, ptOH, ptTarget) = PrioSelect(ptReq, slotTgt)
    val spanCarry = spanR && !ptEn

    val blkPc = pc(31 downto LZ) ## B(0, LZ bits)
    if (!cfg.frontendPredictCofactors) {
    if (!cfg.frontendPcOneHot) when(prevRst) { pcNext := B(0xaaaaa000L, 32 bits) }
      .elsewhen(io.backend_flush) { pcNext := io.backend_redirect_pc }
      .elsewhen(ptEn) { pcNext := ptTarget }
      // Allow synthesis to restructure this fetch incrementer instead of preserving prefix nodes.
      .elsewhen(spanCarry) { pcNext := FastAdd.addPow2(blkPc.asUInt,LZ,cfg.fpgaNativeAdd).asBits }
      .otherwise { pcNext := nextPcR }

    }

    when(io.backend_flush) { carryValid := False }
      .elsewhen(fetchFire) { carryValid := spanCarry; carryLo := (if (cfg.frontendFastCarry) blkParcels(PMAX - 1) else faSpanLo); carryPc := nextPcR }

    if (cfg.frontendFastCarry && cfg.rvfi) when(!io.backend_flush && fetchFire && spanCarry) {
      assert(faSpanLo === blkParcels(PMAX - 1))
    }

    // Predictor PC hashes are computed before the late candidate select.
    val NCAND = cfg.predCandN   // IFW + 4
    val CANDW = cfg.predCandW
    val candSel=Bits(NCAND bits)
    val candA=Vec(Bits(CANDW bits),NCAND)
    val candB=Vec(Bits(CANDW bits),NCAND)
    if (!cfg.frontendPredictCofactors) {
    val candPc = Vec(Bits(32 bits), NCAND)
    candPc(0) := nextPcR                     // == span_pc (identical expression in fetchAlign)
    candPc(1) := B(cfg.resetPc, 32 bits)
    candPc(2) := io.backend_redirect_pc
    // Hash each slot target in parallel with priority selection.
    // A selected slot has isC(i), so slotTgt and effPtgt agree for that candidate.
    for (i <- 0 until IFW) candPc(3 + i) := slotTgt(i)
    candPc(NCAND - 1) := nextPcR
    if (cfg.frontendValidSpeculation) {
      val cachePc=Vec(Bits(32 bits),NCAND)
      cachePc(0):=FastAdd.addPow2(blkPc.asUInt,LZ,cfg.fpgaNativeAdd).asBits
      cachePc(1):=B(0xaaaaa000L,32 bits)
      cachePc(2):=io.backend_redirect_pc
      for (i <- 0 until IFW) cachePc(3+i):=slotTgt(i)
      cachePc(NCAND-1):=nextPcR
      val normal= !prevRst && !io.backend_flush
      val select=Vec(Bool(),NCAND)
      select(0):=normal && !ptEn && spanCarry
      select(1):=prevRst
      select(2):= !prevRst && io.backend_flush
      for (i <- 0 until IFW) select(3+i):=normal && ptOH(i)
      select(NCAND-1):=normal && !ptEn && !spanCarry
      if (cfg.frontendPcOneHot) pcNext := OhSel(select.asBits,cachePc)
      val sets=cachePc.map(_(cfg.iOffsetIdx,cfg.iSetIdx bits))
      if1.io.set_candidates:=Vec(sets).asBits
      if1.io.set_select:=select.asBits
      if (cfg.rvfi) {
        assert(CountOne(select.asBits) === 1)
        assert(OhSel(select.asBits,sets) === pcNext(cfg.iOffsetIdx,cfg.iSetIdx bits))
      }
    }
    val sSpan  = spanCarry && !io.backend_flush
    val sRst   = prevRst && !sSpan
    val sFlush = io.backend_flush && !prevRst && !sSpan
    val sSlot  = (0 until IFW).map(i => ptOH(i) && !prevRst && !io.backend_flush) // ptOH(i) -> !spanCarry
    val sSeq   = !ptEn && !prevRst && !io.backend_flush && !sSpan
    candSel := Vec(Seq(sSpan, sRst, sFlush) ++ sSlot :+ sSeq).asBits
    for (c <- 0 until NCAND) {
      val slice = candPc(c)(cfg.predCandHi downto LZ)
      candA(c) := slice
      // Use a prefix incrementer for the adjacent fetch block.
      candB(c) := FastAdd.incBits(slice.asUInt)(CANDW - 1 downto 0)
    }

    }

    // speculative branch predecode. Slots after the first taken slot are masked:
    // (ptEn && i > ptIdx) === "a lower slot already granted" === OR of ptOH(j), j<i
    // (exclusive prefix-OR over the one-hot; bit-exact, drops the index comparators).
    val pktValid = Vec(Bool(), IFW)
    var ptBelow: Bool = False
    for (i <- 0 until IFW) { pktValid(i) := validS(i) && !ptBelow; ptBelow = ptBelow | ptOH(i) }
    val specBrValid = Vec(Bool(), IFW)
    for (i <- 0 until IFW) specBrValid(i) := pktValid(i) && ctrlS(i)

    // TAGE
    val tage = new Tage(cfg)
    tage.io.clk := io.clk; tage.io.rst := io.rst
    tage.io.from_cb_update_en := io.from_cb_update_en; tage.io.from_cb_pc := io.from_cb_pc
    tage.io.from_cb_branch_taken := io.from_cb_branch_taken; tage.io.from_cb_kp := io.from_cb_kp
    tage.io.from_cb_prov := io.from_cb_prov
    io.to_fifo_prov_flat := tage.io.prov_snapshot_flat
    tage.io.slot_sel := slotSel.asBits; tage.io.flush := io.backend_flush
    // Read predictor SRAMs on fetch advance using the next block's PC candidates.
    // A spanning instruction retains carryPc so its prediction uses the starting block.
    tage.io.re := if1.io.prv_ready
    tage.io.blk_pc_cand_a := candA.asBits; tage.io.blk_pc_cand_b := candB.asBits
    tage.io.blk_pc_sel := candSel
    tage.io.spec_update_en := fetchFire; tage.io.spec_br_valid := specBrValid.asBits
    tage.io.spec_br_taken := effPredictTaken
    predictTakenGshare := tage.io.predict_taken_lane   // per-lane, not per-slot

    // uBTB
    val ubtb = new Ubtb(cfg)
    ubtb.io.clk := io.clk; ubtb.io.rst := io.rst
    ubtb.io.from_cb_update_en := io.from_cb_update_en; ubtb.io.from_cb_pc := io.from_cb_pc
    ubtb.io.from_cb_fu_opcode := io.from_cb_fu_opcode; ubtb.io.from_cb_branch_taken := io.from_cb_branch_taken
    ubtb.io.from_cb_target_address := io.from_cb_target_address
    ubtb.io.predict_taken_gshare_lane := predictTakenGshare; ubtb.io.slot_sel := slotSel.asBits
    // sync-read SRAM: same early-address scheme as TAGE (address off the next-cycle fetch
    // block PC, captured on the fetch advance) so the registered target lands at T+1.
    ubtb.io.re := if1.io.prv_ready
    ubtb.io.blk_pc_cand_a := candA.asBits; ubtb.io.blk_pc_cand_b := candB.asBits
    ubtb.io.blk_pc_sel := candSel
    // realign-window block base, register-derived (carry regs / if1 pc reg) -- EARLY,
    // unlike faInst_pc(0) which routes through the realign mux network; sources the
    // uBTB tag compares + target-hi reconstruct off the pcNext loop.
    if (cfg.ubtbLateCarrySelect) {
      ubtb.io.blk_pc_normal := pc(31 downto LZ)
      ubtb.io.blk_pc_carried := carryPc(31 downto LZ)
      ubtb.io.carry_select := carryValid
    }
    ubtb.io.blk_pc_base := faPc(31 downto LZ)
    predictTargetUbtb := ubtb.io.predict_target; predictTakenUbtb := ubtb.io.predict_taken

    // RAS
    val ras = new Ras(cfg)
    ras.io.clk := io.clk; ras.io.rst := io.rst; ras.io.flush := io.backend_flush; ras.io.fetch_fire := fetchFire
    ras.io.seq_next := seqS.asBits; ras.io.inst_valid := validS.asBits
    ras.io.is_call := callS.asBits; ras.io.is_ret := retS.asBits
    ras.io.predict_taken_in := predictTakenUbtb; ras.io.predict_target_in := predictTargetUbtb
    ras.io.from_cb_update_en := io.from_cb_update_en; ras.io.from_cb_pc := io.from_cb_pc
    ras.io.from_cb_is_call := io.from_cb_is_call; ras.io.from_cb_is_ret := io.from_cb_is_ret
    ras.io.from_cb_is_compressed := io.from_cb_is_compressed
    predictTaken := ras.io.predict_taken_out; predictTarget := ras.io.predict_target_out
    if (cfg.frontendLaneValidity) {
      val bitmap=if1.io.initialized_bitmap
      ubtb.io.initialized_bitmap:=bitmap
      ras.io.initialized_bitmap:=bitmap
      ras.io.predict_initialized_in:=ubtb.io.predict_initialized
      val current=ooo.common.CacheValidityLookup(bitmap,blkPc,cfg)
      val followingPc=FastAdd.addPow2(blkPc.asUInt,LZ,cfg.fpgaNativeAdd).asBits
      val following=ooo.common.CacheValidityLookup(bitmap,followingPc,cfg)
      val sequential=Mux(chP(3),following,current)
      val taken=OhSel(Vec(ptOH).asBits,ras.io.predict_initialized_out.subdivideIn(IFW slices))(0)
      val resetValue=ooo.common.CacheValidityLookup(bitmap,B(0xaaaaa000L,32 bits),cfg)
      val redirectValue=ooo.common.CacheValidityLookup(bitmap,io.backend_redirect_pc,cfg)
      if (!cfg.frontendPredictCofactors) if1.io.request_initialized:=Mux(prevRst,resetValue,Mux(io.backend_flush,redirectValue,
        Mux(ptEn,taken,Mux(spanCarry,following,sequential))))
      if (cfg.rvfi) {
        assert((validSb & (validSb.asUInt + 1).asBits) === 0)
        assert(if1.io.request_initialized === bitmap(pcNext(cfg.iOffsetIdx,cfg.iSetIdx bits).asUInt))
      }
    }

    if (cfg.frontendPredictCofactors) {
      ras.io.case_taken_in:=ubtb.io.case_taken
      ras.io.case_target_in:=ubtb.io.case_target
      ras.io.case_initialized_in:=ubtb.io.case_initialized
      val directions=Vec((0 until IFW).map(i=>predictTakenGshare(slotSel(i).asUInt))).asBits.asUInt
      val bitmap=if1.io.initialized_bitmap
      val following=FastAdd.addPow2(blkPc.asUInt,LZ,cfg.fpgaNativeAdd).asBits
      val choices=(0 until NCAND).map { mask=>
        val choice=new FetchControlChoice(cfg)
        choice.io.valid:=validS.asBits;choice.io.ctrl:=ctrlS.asBits
        for (slot <- 0 until IFW) {
          val direction=(mask>>slot)&1
          choice.io.taken(slot):=ras.io.case_taken_out(direction)(slot)
          choice.io.targets(slot*32,32 bits):=ras.io.case_target_out(direction)(slot*32,32 bits)
          choice.io.initialized(slot):=ras.io.case_initialized_out(direction)(slot)
        }
        choice.io.span:=spanR;choice.io.reset:=prevRst;choice.io.flush:=io.backend_flush
        choice.io.sequential:=nextPcR;choice.io.following:=following
        choice.io.redirect:=io.backend_redirect_pc
        choice.io.reset_initialized:=ooo.common.CacheValidityLookup(bitmap,B(0xaaaaa000L,32 bits),cfg)
        choice.io.redirect_initialized:=ooo.common.CacheValidityLookup(bitmap,io.backend_redirect_pc,cfg)
        choice.io.sequential_initialized:=ooo.common.CacheValidityLookup(bitmap,nextPcR,cfg)
        choice.io.following_initialized:=ooo.common.CacheValidityLookup(bitmap,following,cfg)
        val slice=choice.io.predictor_pc(cfg.predCandHi downto LZ)
        candA(mask):=slice
        candB(mask):=FastAdd.incBits(slice.asUInt)(CANDW-1 downto 0)
        choice
      }
      if (cfg.frontendHistoryCofactors) {
        tage.io.case_br_valid:=Vec(choices.map(_.io.branch_valid)).asBits
        tage.io.case_br_taken:=Vec(choices.map(_.io.branch_taken)).asBits
      }
      if (cfg.frontendOutcomeOneHot) {
        val decode=new FetchOutcomeDecode(IFW)
        decode.io.direction:=directions.asBits
        candSel:=decode.io.selected
        pcNext:=OhSel(candSel,choices.map(_.io.next_pc))
        if1.io.request_initialized:=OhSel.bool(candSel,choices.map(_.io.request_initialized))
      } else {
        candSel:=UIntToOh(directions,NCAND)
        pcNext:=Vec(choices.map(_.io.next_pc))(directions)
        if1.io.request_initialized:=Vec(choices.map(_.io.request_initialized))(directions)
      }
      if1.io.set_candidates:=Vec(choices.map(_.io.next_pc(cfg.iOffsetIdx,cfg.iSetIdx bits))).asBits
      if1.io.set_select:=candSel
      if (cfg.rvfi) {
        assert(pcNext === Mux(prevRst,B(0xaaaaa000L,32 bits),Mux(io.backend_flush,
          io.backend_redirect_pc,Mux(ptEn,ptTarget,Mux(spanCarry,following,nextPcR)))))
      }
    }

    // to_fifo packet assembly
    io.to_fifo_valid := if1Valid && (if (cfg.lowPower || cfg.zicsr) !io.halt_fetch else True)
    io.to_fifo_inst_flat := faInst
    // NoRvfi product config: inst_raw feeds only the rvfi record -- tie it so
    // the IQ's raw storage const-prop sweeps (the decoder consumes inst).
    io.to_fifo_inst_raw_flat := (if (cfg.rvfi) faRaw else B(0, IFW * 32 bits))
    io.to_fifo_is_compressed := faComp
    io.to_fifo_pc_flat := faInstPc
    io.to_fifo_predict_taken := effPredictTaken
    io.to_fifo_predict_target_flat := effPtgt.asBits
    io.to_fifo_valid_slots := pktValid.asBits
    io.to_fifo_kp_flat := tage.io.kp_flat
  }
}
