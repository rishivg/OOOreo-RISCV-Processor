package ooo.frontend.bpred

import spinal.core._
import spinal.lib.UIntToOh
import ooo.{CpuConfig, OhSel}

/** Independent synchronous read and masked-write ports for a block-read uBTB bank.
  * Read addresses arrive one cycle before prediction; disabled reads retain the row.
  */
class UbtbBankRam(addrW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("ubtb_bank_array")
  addGeneric("DATA_WIDTH", dw); addGeneric("ADDR_WIDTH", addrW)  // size sim model/macro to swept ROWS/TTAG
  val io = new Bundle {
    val clk   = in  Bool()
    val re    = in  Bool();        val raddr = in  Bits(addrW bits); val rdata = out Bits(dw bits)
    val we    = in  Bool();        val waddr = in  Bits(addrW bits)
    val wdata = in  Bits(dw bits); val wmask = in  Bits(dw bits)
  }
  noIoPrefix()
}

/** SRAM-backed block-read micro-BTB for branch and jump targets. */
class Ubtb(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ubtb_spinal")
  val IFW   = cfg.ifWidth
  val LZ    = log2Up(IFW * 4)
  val LANES = 2 * IFW
  val ROWS  = cfg.ubtbRows     // logical rows (even/odd -> ROWS/2 per physical bank); sweep knob
  val RIDXW = log2Up(ROWS)
  val ADDRW = RIDXW - 1
  val TTAG  = cfg.ubtbTagW     // stored tag (block-PC bits above the row index); sweep knob
  val OFFW  = 18                   // stored target LOW bits (insert range +/-128KB, as the old signed offset)
  val EW    = 1 + TTAG + 2 + OFFW  // 30  per-lane entry {valid, tag, hi_adj, target_lo}
  val DW    = LANES * EW           // Packed lane entries
  val NCAND = cfg.predCandN    // blk_pc_next candidates (span,rst,flush,slots,seq)
  val CANDW = cfg.predCandW    // candidate bus = pc(predCandHi downto LZ); uses low RIDXW bits

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_cb_update_en      = in Bool()
    val from_cb_pc             = in Bits (32 bits)
    val from_cb_fu_opcode      = in Bits (4 bits)
    val from_cb_branch_taken   = in Bool()
    val from_cb_target_address = in Bits (32 bits)
    // Per-lane TAGE direction across both fetched blocks.
    val predict_taken_gshare_lane = in Bits (4 * IFW bits)
    // Per-slot {inB,lane} reconstructed in FrontendTop.
    val slot_sel       = in Bits (IFW * 4 bits)
    val re             = in Bool()           // fetch-advance enable (= if1 prv_ready); gates the sync SRAM read
    // hash-before-select early read address (see Tage): pre-sliced blk_pc_next
    // CANDIDATES (bits [predCandHi:LZ] of candidate / candidate+16) + one-hot select.
    val blk_pc_cand_a  = in Bits (NCAND * CANDW bits)
    val blk_pc_cand_b  = in Bits (NCAND * CANDW bits)
    val blk_pc_sel     = in Bits (NCAND bits)
    // Registered window base for tag comparison and target-high reconstruction.
    val blk_pc_base    = in Bits (32 - LZ bits)
    val blk_pc_normal = if (cfg.ubtbLateCarrySelect) in Bits(32 - LZ bits) else null
    val blk_pc_carried = if (cfg.ubtbLateCarrySelect) in Bits(32 - LZ bits) else null
    val carry_select = if (cfg.ubtbLateCarrySelect) in Bool() else null
    val predict_target = out Bits (IFW * 32 bits)
    val predict_taken  = out Bits (IFW bits)
    val case_taken = if (cfg.frontendPredictCofactors) Vec(out Bits(IFW bits),2) else null
    val case_target = if (cfg.frontendPredictCofactors) Vec(out Bits(IFW*32 bits),2) else null
    val case_initialized = if (cfg.frontendPredictCofactors) Vec(out Bits(IFW bits),2) else null
    val initialized_bitmap = if (cfg.frontendLaneValidity) in Bits((1 << cfg.iSetIdx) bits) else null
    val predict_initialized = if (cfg.frontendLaneValidity) out Bits(IFW bits) else null
  }
  noIoPrefix()

  // block-aligned indexing (pure PC, no history fold). lane = in-block halfword.
  def blkRow(pc: Bits): Bits = pc(RIDXW + LZ - 1 downto LZ)          // RIDXW bits
  def laneOf(pc: Bits): UInt = pc(LZ - 1 downto 1).asUInt            // 1 of LANES
  def tagOf(pc: Bits): Bits  = pc(RIDXW + LZ + TTAG - 1 downto RIDXW + LZ)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // one set of even/odd SRAM banks per class (br, jm)
    val brBank = Array.fill(2)(new UbtbBankRam(ADDRW, DW))
    val jmBank = Array.fill(2)(new UbtbBankRam(ADDRW, DW))
    for (b <- 0 until 2) {
      brBank(b).io.clk := io.clk; brBank(b).io.re := io.re
      jmBank(b).io.clk := io.clk; jmBank(b).io.re := io.re
    }

    // read address (presented one cycle early, FE-2 hash-before-select)
    // fetch block row (A) + next 16B block row (B); A and B always land in opposite banks
    // since consecutive blocks differ in blkRow LSB. No history fold -> br/jm share the
    // address; the routing bit is registered (re-gated) to un-route the T+1 row.
    // Per pre-sliced candidate (bus bit k = candidate PC bit k+LZ, so blkRow = low RIDXW
    // bits) derive the bank-routed addresses, then one-hot-select the finished pair.
    val candA = io.blk_pc_cand_a.subdivideIn(NCAND slices)
    val candB = io.blk_pc_cand_b.subdivideIn(NCAND slices)
    // Select the shared block-PC component once; retain per-lane offsets for prediction.
    val selRowA = OhSel(io.blk_pc_sel, (0 until NCAND).map(c => candA(c)(RIDXW - 1 downto 0)))
    val selRowB = OhSel(io.blk_pc_sel, (0 until NCAND).map(c => candB(c)(RIDXW - 1 downto 0)))
    val bkA     = selRowA(0)
    val aA      = selRowA(RIDXW - 1 downto 1); val aB = selRowB(RIDXW - 1 downto 1)
    val raddr0=if (cfg.frontendHistoryCofactors) OhSel(io.blk_pc_sel,(0 until NCAND).map(c=>
      Mux(candA(c)(0),candB(c)(RIDXW-1 downto 1),candA(c)(RIDXW-1 downto 1)))) else Mux(bkA,aB,aA)
    val raddr1=if (cfg.frontendHistoryCofactors) OhSel(io.blk_pc_sel,(0 until NCAND).map(c=>
      Mux(candA(c)(0),candA(c)(RIDXW-1 downto 1),candB(c)(RIDXW-1 downto 1)))) else Mux(bkA,aA,aB)
    for (bk <- Seq(brBank, jmBank)) { bk(0).io.raddr := raddr0; bk(1).io.raddr := raddr1 }
    val bankAReg = RegNextWhen(bkA, io.re)
    def rowAof(bk: Array[UbtbBankRam]) = Mux(bankAReg === False, bk(0).io.rdata, bk(1).io.rdata)
    def rowBof(bk: Array[UbtbBankRam]) = Mux(bankAReg === False, bk(1).io.rdata, bk(0).io.rdata)
    val brRowA = rowAof(brBank); val brRowB = rowBof(brBank)
    val jmRowA = rowAof(jmBank); val jmRowB = rowBof(jmBank)

    // precompute-per-lane, select-late (see Tage): the valid + tag-match and the
    // fully RECONSTRUCTED target of every (block, lane) combo derive from the
    // REGISTERED rows and the EARLY block base (blk_pc_base; block B = base+1 -- the
    // realign window is 16B, so a slot's block is A or A+16). Target reconstruct =
    // {blockHi 3:1-muxed by the stored hi-adjust, stored target-lo}; pc bits above
    // OFFW are per-block constants, so NO per-slot adder exists anymore. Only the
    // (inB, lane) select and the gshare gate stay after the realigned instPc on the
    // pcNext loop.
    val jHitL = Vec(Bool(), 2 * LANES); val jTgtL = Vec(Bits(32 bits), 2 * LANES)
    val bHitL = Vec(Bool(), 2 * LANES); val bTgtL = Vec(Bits(32 bits), 2 * LANES)
    if (cfg.ubtbLateCarrySelect) {
      val choices = Seq(io.blk_pc_normal, io.blk_pc_carried).map { base =>
        val decode = new UbtbBaseDecode(cfg)
        decode.io.base := base
        if (cfg.ubtbParallelTagCompare) {
          decode.io.bank_select := bankAReg
          decode.io.br_a := brBank(0).io.rdata; decode.io.br_b := brBank(1).io.rdata
          decode.io.jm_a := jmBank(0).io.rdata; decode.io.jm_b := jmBank(1).io.rdata
        } else {
          decode.io.br_a := brRowA; decode.io.br_b := brRowB
          decode.io.jm_a := jmRowA; decode.io.jm_b := jmRowB
        }
        decode
      }
      jHitL.assignFromBits(Mux(io.carry_select, choices(1).io.j_hit, choices(0).io.j_hit))
      bHitL.assignFromBits(Mux(io.carry_select, choices(1).io.b_hit, choices(0).io.b_hit))
      jTgtL.assignFromBits(Mux(io.carry_select, choices(1).io.j_target, choices(0).io.j_target))
      bTgtL.assignFromBits(Mux(io.carry_select, choices(1).io.b_target, choices(0).io.b_target))
    } else {
    val baseB = ooo.FastAdd.addPow2(io.blk_pc_base.asUInt,0,cfg.fpgaNativeAdd).asBits             // next 16B block base (early, off-loop)
    def tagOfBase(b: Bits): Bits = b(RIDXW + TTAG - 1 downto RIDXW)
    def hi3(b: Bits): Vec[Bits] = {                            // pc[31:OFFW] and +/-1 (adj 00 / 01 / 1x)
      val h = b(31 - LZ downto OFFW - LZ)
      Vec(h,ooo.FastAdd.addPow2(h.asUInt,0,cfg.fpgaNativeAdd).asBits,
        ooo.FastAdd.dec(h.asUInt,cfg.fpgaNativeAdd).asBits)
    }
    val tagA = tagOfBase(io.blk_pc_base); val tagB = tagOfBase(baseB)
    val hiA  = hi3(io.blk_pc_base);       val hiB  = hi3(baseB)
    // per-(block, lane) hit + reconstructed target: [0..LANES) = block A, [LANES..) = B
    for (l <- 0 until LANES) {
      def unpack(row: Bits): (Bool, Bits, Bits, Bits) = {      // (valid, tag, hi_adj, target_lo)
        val s = row.subdivideIn(LANES slices)(l)
        (s(EW - 1), s(EW - 2 downto OFFW + 2), s(OFFW + 1 downto OFFW), s(OFFW - 1 downto 0))
      }
      def tgt(hi: Vec[Bits], adj: Bits, lo: Bits): Bits = Mux(adj(1), hi(2), Mux(adj(0), hi(1), hi(0))) ## lo
      val (jva, jta, jaa, jla) = unpack(jmRowA); jHitL(l) := jva && (jta === tagA); jTgtL(l) := tgt(hiA, jaa, jla)
      val (bva, bta, baa, bla) = unpack(brRowA); bHitL(l) := bva && (bta === tagA); bTgtL(l) := tgt(hiA, baa, bla)
      val (jvb, jtb, jab, jlb) = unpack(jmRowB); jHitL(LANES + l) := jvb && (jtb === tagB); jTgtL(LANES + l) := tgt(hiB, jab, jlb)
      val (bvb, btb, bab, blb) = unpack(brRowB); bHitL(LANES + l) := bvb && (btb === tagB); bTgtL(LANES + l) := tgt(hiB, bab, blb)
    }
    }
    // Combine gshare and target hits per lane, then perform a single slot selection.
    // Branch hits have priority over jump hits; fall-through targets are reconstructed outside this module.
    val useBrL  = Vec(Bool(), 2 * LANES)
    val takenL  = Vec(Bool(), 2 * LANES)
    val tgtHitL = Vec(Bits(32 bits), 2 * LANES)
    for (l <- 0 until 2 * LANES) {
      useBrL(l)  := io.predict_taken_gshare_lane(l) && bHitL(l)   // br has priority over jm
      takenL(l)  := jHitL(l) || useBrL(l)
      tgtHitL(l) := Mux(useBrL(l), bTgtL(l), jTgtL(l))
    }
    val initializedL=if (cfg.frontendLaneValidity) Vec((0 until 2*LANES).map { l =>
      val branch=ooo.common.CacheValidityLookup(io.initialized_bitmap,bTgtL(l),cfg)
      val jump=ooo.common.CacheValidityLookup(io.initialized_bitmap,jTgtL(l),cfg)
      Mux(useBrL(l),branch,jump)
    }) else null
    if (cfg.frontendPredictCofactors) {
      for (direction <- 0 until 2) {
        val taken=Vec(Bool(),2*LANES)
        val target=Vec(Bits(32 bits),2*LANES)
        val initialized=Vec(Bool(),2*LANES)
        for (l <- 0 until 2*LANES) {
          val branch=if (direction == 1) bHitL(l) else False
          taken(l):=jHitL(l) || branch
          target(l):=Mux(branch,bTgtL(l),jTgtL(l))
          initialized(l):=Mux(branch,
            ooo.common.CacheValidityLookup(io.initialized_bitmap,bTgtL(l),cfg),
            ooo.common.CacheValidityLookup(io.initialized_bitmap,jTgtL(l),cfg))
        }
        for (slot <- 0 until IFW) {
          val lane=io.slot_sel(slot*4,4 bits).asUInt
          io.case_taken(direction)(slot):=taken(lane)
          io.case_target(direction)(slot*32,32 bits):=target(lane)
          io.case_initialized(direction)(slot):=initialized(lane)
        }
      }
    }
    // predict_target is valid only when taken. FrontendTop reconstructs fall-through payloads
    // from seqNext so sequential-PC arithmetic does not enter the predictor feedback loop.
    val ptaken  = Vec(Bool(), IFW)
    val ptarget = Vec(Bits(32 bits), IFW)
    for (w <- 0 until IFW) {
      val sel = io.slot_sel(4 * w, 4 bits).asUInt              // {inB, lane}
      if (cfg.ubtbOneHotSlots) {
        val selected = UIntToOh(sel, 2 * LANES)
        ptaken(w) := ooo.OhSel.bool(selected, takenL.toSeq)
        ptarget(w) := ooo.OhSel(selected, tgtHitL.toSeq)
        if (cfg.frontendLaneValidity) io.predict_initialized(w) := ooo.OhSel.bool(selected, initializedL.toSeq)
      } else {
        ptaken(w) := takenL(sel)
        if (cfg.frontendLaneValidity) io.predict_initialized(w) := initializedL(sel)
        ptarget(w) := tgtHitL(sel)
      }                               // valid when ptaken(w)
    }
    io.predict_taken  := ptaken.asBits
    io.predict_target := ptarget.asBits

    // training (commit): masked single-lane write of {valid, tag, hi_adj, target_lo}.
    val uRow  = blkRow(io.from_cb_pc); val uLane = laneOf(io.from_cb_pc); val uTag = tagOf(io.from_cb_pc)
    // Keep the target-range subtractor off a serial carry chain at commit.
    val (difference, _) = ooo.FastAdd.withCout(io.from_cb_target_address.asUInt,
      (~io.from_cb_pc).asUInt,carryIn=True,nativeCarry=cfg.fpgaNativeAdd)
    val uDiff = difference.asSInt
    val uOff  = uDiff(OFFW - 1 downto 0)                                       // SInt(OFFW)
    val uInRange = (uOff.resize(32 bits) === uDiff)                            // target within +/-2^(OFFW-1) of pc
    // hi-adjust = (target[31:OFFW] - pc[31:OFFW]) mod 4 -- in {0,+1,-1} for any in-range
    // target (low 2 subtract bits depend only on the low 2 operand bits). The predict
    // side rebuilds target[31:OFFW] = blockHi + adj with a 3:1 mux; the full add is here,
    // at commit, off every loop.
    val uAdj = (io.from_cb_target_address(OFFW + 1 downto OFFW).asUInt -
                io.from_cb_pc(OFFW + 1 downto OFFW).asUInt).asBits
    val uLo  = io.from_cb_target_address(OFFW - 1 downto 0)
    val isJump = io.from_cb_fu_opcode(3)
    val uBankW = uRow(0); val uAddrW = uRow(RIDXW - 1 downto 1)
    val laneData = B(True) ## uTag ## uAdj ## uLo                              // {valid, tag, hi_adj, target_lo} = EW bits
    val rowData = Vec(Bits(EW bits), LANES); val rowMask = Vec(Bits(EW bits), LANES)
    for (k <- 0 until LANES) {
      rowData(k) := laneData
      rowMask(k) := Mux(uLane === U(k, log2Up(LANES) bits), B((BigInt(1) << EW) - 1, EW bits), B(0, EW bits))
    }
    val doWrCommon = io.from_cb_update_en && io.from_cb_branch_taken && uInRange
    def wireWrite(bk: Array[UbtbBankRam], classWr: Bool): Unit = {
      for (b <- 0 until 2) {
        bk(b).io.we    := doWrCommon && classWr && (if (b == 0) (uBankW === False) else (uBankW === True))
        bk(b).io.waddr := uAddrW
        bk(b).io.wdata := rowData.asBits
        bk(b).io.wmask := rowMask.asBits
      }
    }
    wireWrite(brBank, !isJump)
    wireWrite(jmBank, isJump)
  }
}
