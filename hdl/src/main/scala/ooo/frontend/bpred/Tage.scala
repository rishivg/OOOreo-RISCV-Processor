package ooo.frontend.bpred

import spinal.core._
import ooo.{CpuConfig, OhSel}

/** TAGE bank with enabled synchronous reads and independent bit-masked writes.
  * Behavioral model: sram/output/tage_bank_array; ASIC binding: macro_wrappers.v. */
class TageBank(addrW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("tage_bank_array")
  addGeneric("DATA_WIDTH", dw); addGeneric("ADDR_WIDTH", addrW)  // size the sim model / macro to the config
  val io = new Bundle {
    val clk   = in  Bool()
    val re    = in  Bool();        val raddr = in  Bits(addrW bits); val rdata = out Bits(dw bits)
    val we    = in  Bool();        val waddr = in  Bits(addrW bits)
    val wdata = in  Bits(dw bits); val wmask = in  Bits(dw bits)
  }
  noIoPrefix()
}

/** Bimodal predictor bank with the same read/write timing as TageBank. */
class BimBank(addrW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("bim_bank_array")
  addGeneric("DATA_WIDTH", dw); addGeneric("ADDR_WIDTH", addrW)  // size the sim model / macro to the config
  val io = new Bundle {
    val clk   = in  Bool()
    val re    = in  Bool();        val raddr = in  Bits(addrW bits); val rdata = out Bits(dw bits)
    val we    = in  Bool();        val waddr = in  Bits(addrW bits)
    val wdata = in  Bits(dw bits); val wmask = in  Bits(dw bits)
  }
  noIoPrefix()
}

/** Block-read TAGE direction predictor with per-lane prediction and commit-time training. */
class Tage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("tage_spinal")
  val IFW     = cfg.ifWidth
  val GHR     = cfg.ghrLen         // [GHR_LEN]
  val NUM     = cfg.tageNum
  val TIDX    = cfg.tageIdx
  val TAGB    = cfg.tageTagBits
  val CTRB    = cfg.tageCtrBits
  val UB      = cfg.tageUBits
  val PHTI    = cfg.phtIdx
  val HIST    = cfg.tageHistLen
  val PROVW   = log2Up(NUM)
  val NCAND   = cfg.predCandN      // blk_pc_next candidates (span,rst,flush,slots,seq)
  val CANDW   = cfg.predCandW      // candidate bus = pc(predCandHi downto LZ)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_cb_update_en    = in Bool()
    val from_cb_pc           = in Bits (32 bits)
    val from_cb_branch_taken = in Bool()
    // Drop kp same-packet older branches from commit history to reconstruct the fetch snapshot.
    val from_cb_kp           = in Bits (log2Up(IFW) bits)
    // Predict-time {hit,ctr,u} per table plus bimodal counter; training needs no table reread.
    val from_cb_prov         = in Bits (NUM * (1 + CTRB + UB) + 2 bits)
    // Per-slot {inB,lane}, reconstructed from predecode and registered carry state.
    val slot_sel       = in Bits (IFW * 4 bits)
    val re             = in Bool()           // fetch-advance enable (= if1 prv_ready); gates the sync SRAM read capture
    // Hash candidate PC slices and their straddle rows in parallel, then select one-hot.
    val blk_pc_cand_a  = in Bits (NCAND * CANDW bits)
    val blk_pc_cand_b  = in Bits (NCAND * CANDW bits)
    val blk_pc_sel     = in Bits (NCAND bits)
    val flush          = in Bool()
    val spec_update_en = in Bool()
    val spec_br_valid  = in Bits (IFW bits)
    val spec_br_taken  = in Bits (IFW bits)
    val kp_flat        = out Bits (IFW * log2Up(IFW) bits)   // per-slot same-packet older-ctrl count
    // Combine gshare and target hits per lane, then perform a single slot selection.
    // Branch hits have priority over jump hits; fall-through targets are reconstructed outside this module.
    val case_br_valid = if (cfg.frontendHistoryCofactors) in Bits(NCAND*IFW bits) else null
    val case_br_taken = if (cfg.frontendHistoryCofactors) in Bits(NCAND*IFW bits) else null
    val predict_taken_lane = out Bits (4 * IFW bits)
    // per-slot provider snapshot (bimodal 2b ## NUM x {hit(1),ctr(CTRB),u(UB)}) -> commit
    val prov_snapshot_flat = out Bits (IFW * (NUM * (1 + CTRB + UB) + 2) bits)
  }
  val PB  = 1 + CTRB + UB     // per-table provider-snapshot bits (= 6)
  val PBT = NUM * PB + 2      // total per-slot snapshot bits (tables ## bimodal 2b) (= 26)
  noIoPrefix()

  case class TageEntry() extends Bundle {
    val tag = Bits(TAGB bits)
    val ctr = SInt(CTRB bits)
    val u   = UInt(UB bits)
  }

  // history fold (XOR-tree of h[0..L) into `width` bits)
  def foldGen(h: Bits, L: Int, width: Int): Bits = {
    val bits = (0 until width).map { j =>
      val terms = (0 until L).filter(_ % width == j).map(i => h(i))
      if (terms.isEmpty) False else terms.reduce(_ ^ _)
    }
    Vec(bits).asBits
  }
  // Incremental folded-history update: given the current fold `ch` (width W) of
  // GHR[0..L), shifting in one new bit `bin` at GHR[0] (and dropping GHR[L-1]==`bout`
  // out of the L-window) gives ch' = rol(ch,1) ^ {bin@0} ^ {bout@(L%W)}. Lets the
  // predict path read a fold REGISTER instead of XOR-folding L history bits live.
  def rolXor(ch: Bits, L: Int, bin: Bool, bout: Bool): Bits = {
    val W = ch.getWidth
    val rolled = ch(W - 2 downto 0) ## ch(W - 1)                 // rotate-left by 1
    val inj = Vec(Bool(), W)
    for (i <- 0 until W) {
      if (i == 0 && i == (L % W)) inj(i) := bin ^ bout
      else if (i == 0)            inj(i) := bin
      else if (i == (L % W))      inj(i) := bout
      else                        inj(i) := False
    }
    rolled ^ inj.asBits
  }

  // PC combined with a history fold + RVC de-alias (pc[1] into the LSB).
  def tagComb(pc: Bits, ftag: Bits): Bits =
    (pc(TAGB + 1 downto 3) ## (pc(2) ^ pc(1))) ^ ftag ^ pc(2 * TAGB + 1 downto TAGB + 2)

  // Read the current and following fetch block once, then select lanes from the registered rows.
  val LZ    = log2Up(IFW * 4)
  val LANES = 2 * IFW
  def blkIdx(pc: Bits, fidx: Bits): Bits = pc(TIDX + LZ - 1 downto LZ) ^ fidx
  def laneOf(pc: Bits): UInt = pc(LZ - 1 downto 1).asUInt

  // SRAM banking: bank = blkIdx[0] (consecutive blocks A/B always differ in blkIdx LSB
  // -> opposite banks -> 2 parallel reads), within-bank addr = blkIdx[TIDX-1:1].
  val EW    = TAGB + CTRB + UB
  val DW    = LANES * EW
  val ADDRW = TIDX - 1

  // bimodal base PHT, block-read (NO history fold -- pure PC base predictor)
  // Row = block-aligned PC (drop in-block offset); LANES 2b counters selected by the
  // in-block halfword (laneOf). BROWI rows x LANES = cfg.phtDepth entries. Banked even/odd
  // (bank=row[0]) so the 2-block straddle reads hit opposite banks, like the tagged
  // tables. Counter (2b) forwarded at commit -> bimodal commit is also write-only.
  val BROWI = PHTI - log2Up(LANES)
  val BEW   = 2                      // 2b saturating counter / lane
  val BDW   = LANES * BEW
  val BADDR = BROWI - 1
  def bRowOf(pc: Bits): Bits = pc(BROWI + LZ - 1 downto LZ)        // pc(10:4), 7 bits

  def ctrUpd(c: SInt, taken: Bool): SInt = {
    val maxv = S((1 << (CTRB - 1)) - 1, CTRB bits)   // +3
    val minv = S(-(1 << (CTRB - 1)), CTRB bits)      // -4
    Mux(taken, Mux(c === maxv, c, (c + 1).resize(CTRB bits)),
               Mux(c === minv, c, (c - 1).resize(CTRB bits)))
  }
  def uInc(u: UInt): UInt = Mux(u === ((1 << UB) - 1), u, (u + 1).resize(UB bits))
  def uDec(u: UInt): UInt = Mux(u === 0, u, (u - 1).resize(UB bits))

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // state
    val ghrSpec   = RegInit(B(0, GHR bits))
    val EXTW = GHR + IFW - 1   // commit history extended so train can drop up to IFW-1 newest bits
    val ghrCommitExt = RegInit(B(0, EXTW bits))
    // folded-history registers (spec path): invariant fidxSpec(t)==foldGen(ghrSpec,HIST(t),TIDX)
    // etc. Init 0 == foldGen(0). Maintained incrementally in lockstep with ghrSpec.
    val fidxSpec = Array.tabulate(NUM)(_ => RegInit(B(0, TIDX bits)))
    val ftagSpec = Array.tabulate(NUM)(_ => RegInit(B(0, TAGB bits)))
    val altCounterBits = cfg.tageAltCounterBits
    val altCounterMax = (BigInt(1) << altCounterBits) - 1
    val useAltOnNa = RegInit(U(BigInt(1) << (altCounterBits - 1), altCounterBits bits))
    // bimodal base PHT -> block-read SRAM banks (even/odd by bRow[0]); 2 reads (straddle)
    // + write-only commit (forwarded counter). Sim model inits to 01/lane (warm-up parity).
    val bimBank = Array.fill(2)(new BimBank(BADDR, BDW))
    for (b <- 0 until 2) { bimBank(b).io.clk := io.clk; bimBank(b).io.re := io.re }
    // tagged tables self-correct (a stale tag just mispredicts, then is overwritten)
    // No reset: avoids reset flops across all predictor entries.
    // block-read tables -> per-table even/odd SRAM banks (1R1W): bank=blkIdx[0],
    // addr=blkIdx[TIDX-1:1]. Predict reads BOTH banks (rowA/rowB land in opposite banks
    // since consecutive blocks differ in blkIdx LSB); commit writes one bank (masked,
    // single lane). Phase 3c: replaces the Phase-1 flop tables -> SRAM area/FF/LUT win.
    val bank = Array.tabulate(NUM)(_ => Array.fill(2)(new TageBank(ADDRW, DW)))
    for (t <- 0 until NUM; b <- 0 until 2) { bank(t)(b).io.clk := io.clk; bank(t)(b).io.re := io.re }

    // per-slot kp export (prefix counts of the spec-shift valids -- the exact
    // set of bits the packet's snapshot excludes)
    val KPW = log2Up(IFW)
    val kpS = Vec(Bits(KPW bits), IFW)
    var kpAcc: UInt = U(0, KPW bits)
    for (i <- 0 until IFW) {
      kpS(i) := kpAcc.asBits
      kpAcc = Mux(io.spec_br_valid(i), (kpAcc + 1).resize(KPW bits), kpAcc)
    }
    io.kp_flat := kpS.asBits

    // Shift speculative history and its folds together; each fold removes bit L-1.
    val fidxFetch = Array.tabulate(NUM)(t => fidxSpec(t): Bits)
    val ftagFetch = Array.tabulate(NUM)(t => ftagSpec(t): Bits)
    var ghrSpecFetch: Bits = ghrSpec
    if (!cfg.tageHistoryStateCofactors) {
      if (cfg.tageParallelHistory) {
        val shifts = HistoryFold.plan(io.spec_br_valid, io.spec_br_taken)
        ghrSpecFetch = HistoryFold.shiftPairs(ghrSpec, io.spec_br_valid, io.spec_br_taken)
        for (t <- 0 until NUM) {
          fidxFetch(t) = HistoryFold.update(fidxSpec(t), ghrSpec, HIST(t), shifts)
          ftagFetch(t) = HistoryFold.update(ftagSpec(t), ghrSpec, HIST(t), shifts)
        }
      } else for (i <- 0 until IFW) {
        val v = io.spec_br_valid(i)
        val tk = io.spec_br_taken(i)
        val h = ghrSpecFetch
        for (t <- 0 until NUM) {
          val length = HIST(t)
          fidxFetch(t) = Mux(v, rolXor(fidxFetch(t), length, tk, h(length - 1)), fidxFetch(t))
          ftagFetch(t) = Mux(v, rolXor(ftagFetch(t), length, tk, h(length - 1)), ftagFetch(t))
        }
        ghrSpecFetch = Mux(v, h(GHR - 2 downto 0) ## tk, h)
      }
    }
    val caseHistory=if (cfg.tageHistoryStateCofactors) (0 until NCAND).map { c=>
      val choice=new TageHistoryChoice(cfg,HIST,TIDX,TAGB,GHR)
      choice.io.history:=ghrSpec
      choice.io.fidx:=Vec(fidxSpec.toSeq).asBits
      choice.io.ftag:=Vec(ftagSpec.toSeq).asBits
      choice.io.valid:=io.case_br_valid(c*IFW,IFW bits)
      choice.io.taken:=io.case_br_taken(c*IFW,IFW bits)
      choice
    } else Seq.empty[TageHistoryChoice]
    if (cfg.tageHistoryStateCofactors) {
      ghrSpecFetch=OhSel(io.blk_pc_sel,caseHistory.map(_.io.next_history))
      for (t <- 0 until NUM) {
        fidxFetch(t)=OhSel(io.blk_pc_sel,caseHistory.map(_.io.next_fidx(t*TIDX,TIDX bits)))
        ftagFetch(t)=OhSel(io.blk_pc_sel,caseHistory.map(_.io.next_ftag(t*TAGB,TAGB bits)))
      }
    }
    val ghrCommitExtNext = Mux(io.from_cb_update_en,
      ghrCommitExt(EXTW - 2 downto 0) ## io.from_cb_branch_taken, ghrCommitExt)
    val ghrCommitNext = ghrCommitExtNext(GHR - 1 downto 0)

    // commit-side folds stay combinational (training path at commit, not the fetch loop)
    // exact snapshot reconstruction: drop the kp newest committed bits (the
    // branch's same-packet older ctrl slots, committed just before it)
    val trainGhr = (ghrCommitExt >> io.from_cb_kp.asUInt)(GHR - 1 downto 0)
    val fidxC = (0 until NUM).map(t => foldGen(trainGhr, HIST(t), TIDX))
    val ftagC = (0 until NUM).map(t => foldGen(trainGhr, HIST(t), TAGB))

    // prediction
    // 2-block read: a fetch window can straddle the 16-byte block boundary (esp. RVC
    // mid-block starts after taken branches), so read the fetch block's row (A) AND the
    // next block's row (B); each slot picks the row of ITS block, then its in-block
    // halfword lane. 2 row-reads/table (vs the per-slot 4) -- straddle-correct.
    // SYNC-READ retiming: the SRAM banks register their output, so present the read
    // ADDRESS one cycle early off blk_pc_next (= pcNext, the block that becomes pcReg next
    // cycle) XOR the EARLY fold -- the registered row then lands at T+1 aligned with pcReg,
    // exactly like the I-cache's blkPcNext read. EARLY fold = the value that becomes
    // fidxSpec next cycle: fidxFetch on a normal advance, the resync fold on flush.
    val earlyFidx = Array.tabulate(NUM)(t =>
      Mux(io.flush, foldGen(ghrCommitNext, HIST(t), TIDX), fidxFetch(t)))
    // Candidate buses start at PC bit LZ. Consecutive A/B blocks use opposite banks;
    // route each bank address before the final one-hot candidate selection.
    val candA = io.blk_pc_cand_a.subdivideIn(NCAND slices)
    val candB = io.blk_pc_cand_b.subdivideIn(NCAND slices)
    // Select the shared block-PC component once; retain per-lane offsets for prediction.
    val selA = OhSel(io.blk_pc_sel, (0 until NCAND).map(candA(_)))
    val selB = OhSel(io.blk_pc_sel, (0 until NCAND).map(candB(_)))
    val bankASel = Vec(Bool(), NUM)
    for (t <- 0 until NUM) {
      val idxA  = selA(TIDX - 1 downto 0) ^ earlyFidx(t)
      val idxB  = selB(TIDX - 1 downto 0) ^ earlyFidx(t)
      val bkA   = idxA(0)
      val addrA = idxA(TIDX - 1 downto 1); val addrB = idxB(TIDX - 1 downto 1)
      if (cfg.frontendHistoryCofactors) {
        val reads=(0 until NCAND).map { c=>
          val choice=new TageReadChoice(cfg,HIST(t),TIDX,GHR)
          choice.io.fold:=fidxSpec(t);choice.io.history:=ghrSpec
          if (cfg.tageHistoryStateCofactors) choice.io.fetch_fold:=caseHistory(c).io.next_fidx(t*TIDX,TIDX bits)
          choice.io.valid:=io.case_br_valid(c*IFW,IFW bits)
          choice.io.taken:=io.case_br_taken(c*IFW,IFW bits)
          choice.io.flush:=io.flush
          choice.io.recovery:=foldGen(ghrCommitNext,HIST(t),TIDX)
          choice.io.pc_a:=candA(c)(TIDX-1 downto 0)
          choice.io.pc_b:=candB(c)(TIDX-1 downto 0)
          choice
        }
        bank(t)(0).io.raddr:=OhSel(io.blk_pc_sel,reads.map(_.io.address_0))
        bank(t)(1).io.raddr:=OhSel(io.blk_pc_sel,reads.map(_.io.address_1))
        bankASel(t):=OhSel(io.blk_pc_sel,reads.map(_.io.bank.asBits))(0)
      } else {
        bank(t)(0).io.raddr := Mux(bkA, addrB, addrA)
        bank(t)(1).io.raddr := Mux(bkA, addrA, addrB)
        bankASel(t) := bkA
      }
    }
    // routing bit registered (re-gated, holds on stall) so the T+1 registered rdata un-routes correctly
    val bankAReg = Array.tabulate(NUM)(t => RegNextWhen(bankASel(t), io.re))
    val rowA = Array.tabulate(NUM)(t => Mux(bankAReg(t) === False, bank(t)(0).io.rdata, bank(t)(1).io.rdata))
    val rowB = Array.tabulate(NUM)(t => Mux(bankAReg(t) === False, bank(t)(1).io.rdata, bank(t)(0).io.rdata))
    // bimodal block-read (same 2-bank straddle, NO history fold -> pure candidate slices)
    // same select-once identity, reusing the shared selA/selB (no history fold here)
    val bimIdxA = selA(BROWI - 1 downto 0); val bimIdxB = selB(BROWI - 1 downto 0)
    val bBkA  = bimIdxA(0)
    val bAA   = bimIdxA(BROWI - 1 downto 1); val bAB = bimIdxB(BROWI - 1 downto 1)
    if (cfg.frontendHistoryCofactors) {
      bimBank(0).io.raddr:=OhSel(io.blk_pc_sel,(0 until NCAND).map(c=>
        Mux(candA(c)(0),candB(c)(BROWI-1 downto 1),candA(c)(BROWI-1 downto 1))))
      bimBank(1).io.raddr:=OhSel(io.blk_pc_sel,(0 until NCAND).map(c=>
        Mux(candA(c)(0),candA(c)(BROWI-1 downto 1),candB(c)(BROWI-1 downto 1))))
    } else {
      bimBank(0).io.raddr := Mux(bBkA, bAB, bAA)
      bimBank(1).io.raddr := Mux(bBkA, bAA, bAB)
    }
    val bBankAReg = RegNextWhen(bBkA, io.re)
    val bRowA = Mux(bBankAReg === False, bimBank(0).io.rdata, bimBank(1).io.rdata)
    val bRowB = Mux(bBankAReg === False, bimBank(1).io.rdata, bimBank(0).io.rdata)
    // Compute the table-independent PC portion of each tag before history/table selection.
    val pcBusA = OhSel(io.blk_pc_sel, candA)   // == blk_pc_next(predCandHi downto LZ)
    val pcBusB = OhSel(io.blk_pc_sel, candB)   // == (blk_pc_next+16)(predCandHi downto LZ)
    def pcPartComb(bus: Bits, l: Int): Bits = {
      val lb = U(l, log2Up(LANES) bits)
      ((bus(TAGB + 1 - LZ downto 0) ## lb(log2Up(LANES) - 1)) ## (lb(1) ^ lb(0))) ^
        bus(2 * TAGB + 1 - LZ downto TAGB + 2 - LZ)
    }
    def selectedPcPart(candidates: Vec[Bits], bus: Bits, lane: Int): Bits =
      if (cfg.tagePcPrehash) OhSel(io.blk_pc_sel, candidates.map(c => pcPartComb(c, lane)))
      else pcPartComb(bus, lane)
    val pcPartA = Vec.tabulate(LANES)(l => RegNextWhen(selectedPcPart(candA, pcBusA, l), io.re))
    val pcPartB = Vec.tabulate(LANES)(l => RegNextWhen(selectedPcPart(candB, pcBusB, l), io.re))
    // Capture the expected tag with the row, keeping history XOR out of tag matching.
    // The held-PC arm also covers history recovery while reads are stalled.
    val expectedTagA = if (cfg.tageRegisteredTags) Array.tabulate(NUM) { t =>
      val nextFold = Mux(io.rst, B(0, TAGB bits),
        Mux(io.flush, foldGen(ghrCommitNext, HIST(t), TAGB),
          Mux(io.spec_update_en, ftagFetch(t), ftagSpec(t))))
      RegNext(Mux(io.re, selectedPcPart(candA, pcBusA, 0), pcPartA(0)) ^ nextFold)
        .setName("expected_tag_a_" + t)
    } else Array.empty[Bits]
    val expectedTagB = if (cfg.tageRegisteredTags) Array.tabulate(NUM) { t =>
      val nextFold = Mux(io.rst, B(0, TAGB bits),
        Mux(io.flush, foldGen(ghrCommitNext, HIST(t), TAGB),
          Mux(io.spec_update_en, ftagFetch(t), ftagSpec(t))))
      RegNext(Mux(io.re, selectedPcPart(candB, pcBusB, 0), pcPartB(0)) ^ nextFold)
        .setName("expected_tag_b_" + t)
    } else Array.empty[Bits]
    // Evaluate predictor decisions per lane before the late slot selector arrives.
    def lanePred(rowOf: Int => Bits, bRow: Bits, pcPartL: Bits, l: Int, registeredTags: Array[Bits], inB: Boolean): (Bool, Bits) = {
      val bimCtr   = bRow.subdivideIn(LANES slices)(l).asUInt         // 2b base counter
      val basePred = bimCtr >= U(2)
      val pEnt = Vec(TageEntry(), NUM)
      val pHit = Vec(Bool(), NUM)
      val directions = if (cfg.tageLateBankSelect) Vec(Bool(), NUM) else null
      val weakFlags = if (cfg.tageLateBankSelect) Vec(Bool(), NUM) else null
      for (t <- 0 until NUM) {
        val sel = rowOf(t).subdivideIn(LANES slices)(l)               // EW bits {tag,ctr,u}
        pEnt(t).tag := sel(EW - 1 downto CTRB + UB)
        pEnt(t).ctr := sel(CTRB + UB - 1 downto UB).asSInt
        pEnt(t).u   := sel(UB - 1 downto 0).asUInt
        val expected = if (cfg.tageRegisteredTags)
          registeredTags(t) ^ pcPartComb(B(0, CANDW bits), l)
          else pcPartL ^ ftagSpec(t)
        if (cfg.tageLateBankSelect) {
          val matched = new TageBankMatch(cfg)
          matched.io.row_0 := bank(t)(0).io.rdata.subdivideIn(LANES slices)(l)
          matched.io.row_1 := bank(t)(1).io.rdata.subdivideIn(LANES slices)(l)
          matched.io.expected := expected
          matched.io.bank := (if (inB) !bankAReg(t) else bankAReg(t))
          pHit(t) := matched.io.hit
          directions(t) := matched.io.direction
          weakFlags(t) := matched.io.weak_counter
        } else pHit(t) := pEnt(t).tag === expected
      }
      // snapshot the predict-time provider entries (bimodal 2b ## per-table {hit,ctr,u});
      // decoded back at commit (from_cb_prov) so the commit re-reads neither tt nor bimodal.
      val snapL = bimCtr.asBits ## Vec((0 until NUM).map(t => pHit(t).asBits ## pEnt(t).ctr.asBits ## pEnt(t).u.asBits)).asBits
      var provV: Bool   = False
      var provCtr: SInt = S(0, CTRB bits)
      var provU: UInt   = U(0, UB bits)
      var altP: Bool    = basePred
      for (t <- 0 until NUM) {
        val hit    = pHit(t)
        val newAlt = Mux(provV, provCtr >= 0, basePred)
        altP    = Mux(hit, newAlt, altP)
        provCtr = Mux(hit, pEnt(t).ctr, provCtr)
        provU   = Mux(hit, pEnt(t).u, provU)
        provV   = provV | hit
      }
      val provWeak = provV && (provU === 0) && ((provCtr === 0) || (provCtr === S(-1, CTRB bits)))
      val prediction=if(cfg.tageParallelPredict) {
        val choices=new TagePredCases(cfg)
        choices.io.counters:=Vec((0 until NUM).map(t=>pEnt(t).ctr.asBits)).asBits
        choices.io.usefulness:=Vec((0 until NUM).map(t=>pEnt(t).u.asBits)).asBits
        choices.io.base:=basePred;choices.io.use_alt:=useAltOnNa.msb
        choices.io.predictions(pHit.asBits.asUInt)
      } else if (cfg.tageRegisteredTags || cfg.tageLateBankSelect) {
        val selected = new TagePriorityPrediction(cfg, decoded = cfg.tageLateBankSelect)
        selected.io.hits := pHit.asBits
        if (cfg.tageLateBankSelect) {
          selected.io.directions := directions.asBits
          selected.io.weak_flags := weakFlags.asBits
        } else {
          selected.io.counters := Vec((0 until NUM).map(t => pEnt(t).ctr.asBits)).asBits
          selected.io.usefulness := Vec((0 until NUM).map(t => pEnt(t).u.asBits)).asBits
        }
        selected.io.base := basePred; selected.io.use_alt := useAltOnNa.msb
        selected.io.prediction
      } else Mux(provWeak && useAltOnNa.msb, altP, Mux(provV, provCtr >= 0, basePred))
      (prediction,snapL)
    }
    // index space: [0..LANES) = block-A lanes, [LANES..2*LANES) = block-B lanes
    val laneTk   = Vec(Bool(), 2 * LANES)
    val laneSnap = Vec(Bits(PBT bits), 2 * LANES)
    for (l <- 0 until LANES) {
      val (ta, sa) = lanePred(t => rowA(t), bRowA, pcPartA(l), l, expectedTagA, inB = false)
      val (tb, sb) = lanePred(t => rowB(t), bRowB, pcPartB(l), l, expectedTagB, inB = true)
      laneTk(l)         := ta; laneSnap(l)         := sa
      laneTk(LANES + l) := tb; laneSnap(LANES + l) := sb
    }
    // Ubtb selects direction per lane; only provider snapshots select per FIFO slot.
    val snap = Vec(Bits(PBT bits), IFW)   // per-slot: bimodal 2b ## {hit,ctr,u}xNUM
    for (i <- 0 until IFW) {
      val sel = io.slot_sel(4 * i, 4 bits).asUInt                   // {inB, lane}
      snap(i) := laneSnap(sel)
    }
    io.predict_taken_lane := laneTk.asBits
    io.prov_snapshot_flat := snap.asBits

    // training derivation at commit
    val uTaken    = io.from_cb_branch_taken
    // commit is WRITE-ONLY for both tagged tables AND bimodal: provider entries + the 2b
    // bimodal counter come from the forwarded predict-time snapshot (from_cb_prov), no
    // re-read. Layout: [NUM*PB-1:0] = tables (table t at slice t), [NUM*PB+1:NUM*PB] = bim.
    val fwdBimCtr = io.from_cb_prov(NUM * PB + 1 downto NUM * PB).asUInt   // forwarded 2b base counter
    val basePredC = fwdBimCtr >= U(2)

    val uIdx  = Vec(UInt(TIDX bits), NUM)
    val uLane = laneOf(io.from_cb_pc)
    val uEnt  = Vec(TageEntry(), NUM)
    val uHit  = Vec(Bool(), NUM)
    val uProvDec = io.from_cb_prov(NUM * PB - 1 downto 0).subdivideIn(NUM slices)   // table t at slice t
    for (t <- 0 until NUM) {
      uIdx(t) := blkIdx(io.from_cb_pc, fidxC(t)).asUInt
      uHit(t)     := uProvDec(t)(PB - 1)                          // bit PB-1 = hit
      uEnt(t).tag := B(0, TAGB bits)                              // unused at commit
      uEnt(t).ctr := uProvDec(t)(UB + CTRB - 1 downto UB).asSInt  // [UB +: CTRB] = ctr
      uEnt(t).u   := uProvDec(t)(UB - 1 downto 0).asUInt          // [0 +: UB] = u
    }

    var uProvV: Bool    = False
    var uProvIdx: UInt  = U(0, PROVW bits)
    var uProvCtr: SInt  = S(0, CTRB bits)
    var uProvU: UInt    = U(0, UB bits)
    var uAltPred: Bool  = basePredC
    for (t <- 0 until NUM) {
      val hit    = uHit(t)
      val newAlt = Mux(uProvV, uProvCtr >= 0, basePredC)
      uAltPred = Mux(hit, newAlt, uAltPred)
      uProvIdx = Mux(hit, U(t, PROVW bits), uProvIdx)
      uProvCtr = Mux(hit, uEnt(t).ctr, uProvCtr)
      uProvU   = Mux(hit, uEnt(t).u, uProvU)
      uProvV   = uProvV | hit
    }
    val uProvPred  = Mux(uProvV, uProvCtr >= 0, basePredC)
    val uProvWeak  = uProvV && (uProvU === 0) && ((uProvCtr === 0) || (uProvCtr === S(-1, CTRB bits)))
    val finalPred  = Mux(uProvWeak && useAltOnNa.msb, uAltPred, uProvPred)
    val mispredict = finalPred =/= uTaken

    // allocation search: first component longer than the provider with u==0
    val allocStart = Mux(uProvV, (uProvIdx.resize(3 bits) + 1), U(0, 3 bits))
    var allocValid: Bool = False
    var allocTable: UInt = U(0, PROVW bits)
    for (t <- 0 until NUM) {
      val cond = !allocValid && (U(t, 3 bits) >= allocStart) && (uEnt(t).u === 0)
      allocTable = Mux(cond, U(t, PROVW bits), allocTable)
      allocValid = allocValid | cond
    }

    // ungated per-cycle state
    ghrCommitExt := ghrCommitExtNext
    when(io.flush) {
      ghrSpec := ghrCommitNext
      // resync folds from the committed history (combinational fold here is on the
      // flush/redirect path, not the fetch read loop)
      for (t <- 0 until NUM) {
        fidxSpec(t) := foldGen(ghrCommitNext, HIST(t), TIDX)
        ftagSpec(t) := foldGen(ghrCommitNext, HIST(t), TAGB)
      }
    }.elsewhen(io.spec_update_en) {
      ghrSpec := ghrSpecFetch
      for (t <- 0 until NUM) {
        fidxSpec(t) := fidxFetch(t)
        ftagSpec(t) := ftagFetch(t)
      }
    }
    when(io.from_cb_update_en) {
      when(uProvWeak && (uProvPred =/= uAltPred)) {
        when(uAltPred === uTaken) { useAltOnNa := Mux(useAltOnNa === altCounterMax, useAltOnNa, (useAltOnNa + 1).resize(altCounterBits bits)) }
        .otherwise                { useAltOnNa := Mux(useAltOnNa === 0,  useAltOnNa, (useAltOnNa - 1).resize(altCounterBits bits)) }
      }
    }

    // bimodal base PHT bank write (commit-gated, WRITE-ONLY via forwarded counter)
    // Update only when no tagged provider hit (same policy as the flop version); the new
    // counter is computed from the forwarded fwdBimCtr (no re-read). Masked single lane.
    val bNew = Mux(uTaken, Mux(fwdBimCtr === 3, fwdBimCtr, (fwdBimCtr + 1).resize(2 bits)),
                           Mux(fwdBimCtr === 0, fwdBimCtr, (fwdBimCtr - 1).resize(2 bits)))
    val bDoWr   = io.from_cb_update_en && !uProvV
    val bWrIdx  = bRowOf(io.from_cb_pc)
    val bWrLane = laneOf(io.from_cb_pc)
    val bRowData = Vec(Bits(BEW bits), LANES); val bRowMask = Vec(Bits(BEW bits), LANES)
    for (k <- 0 until LANES) {
      bRowData(k) := bNew.asBits
      bRowMask(k) := Mux(bWrLane === U(k, log2Up(LANES) bits), B((1 << BEW) - 1, BEW bits), B(0, BEW bits))
    }
    val bBankW = bWrIdx(0)
    val bAddrW = bWrIdx(BROWI - 1 downto 1)
    for (b <- 0 until 2) {
      bimBank(b).io.we    := bDoWr && (if (b == 0) (bBankW === False) else (bBankW === True))
      bimBank(b).io.waddr := bAddrW
      bimBank(b).io.wdata := bRowData.asBits
      bimBank(b).io.wmask := bRowMask.asBits
    }

    // tagged-table SRAM bank writes (commit-gated, masked single lane at uLane)
    // Per-FIELD mask: provider updates ctr(+u), alloc writes the full lane, the aged path
    // writes u only. tag for non-alloc is masked off so it's preserved (uEnt.tag is unused
    // the forward-state snapshot carries no tag). Same 3 cases as the flop version.
    for (t <- 0 until NUM) {
      val newTag = Bits(TAGB bits); val newCtr = SInt(CTRB bits); val newU = UInt(UB bits)
      val tagWr = Bool(); val ctrWr = Bool(); val uWr = Bool()
      newTag := uEnt(t).tag; newCtr := uEnt(t).ctr; newU := uEnt(t).u
      tagWr := False; ctrWr := False; uWr := False
      when(uProvV && (U(t, PROVW bits) === uProvIdx)) {
        newCtr := ctrUpd(uEnt(t).ctr, uTaken); ctrWr := True
        when(uProvPred =/= uAltPred) {
          newU := Mux(uProvPred === uTaken, uInc(uEnt(t).u), uDec(uEnt(t).u)); uWr := True
        }
      }.elsewhen(mispredict && allocValid && (U(t, PROVW bits) === allocTable)) {
        newTag := tagComb(io.from_cb_pc, ftagC(t))
        newCtr := Mux(uTaken, S(0, CTRB bits), S(-1, CTRB bits)); newU := U(0, UB bits)
        tagWr := True; ctrWr := True; uWr := True
      }.elsewhen(mispredict && !allocValid && (U(t, 3 bits) >= allocStart)) {
        newU := uDec(uEnt(t).u); uWr := True
      }
      val doWr = io.from_cb_update_en && (tagWr || ctrWr || uWr)
      val laneData = newTag ## newCtr.asBits ## newU.asBits
      val laneMask = Mux(tagWr, B((1 << TAGB) - 1, TAGB bits), B(0, TAGB bits)) ##
                     Mux(ctrWr, B((1 << CTRB) - 1, CTRB bits), B(0, CTRB bits)) ##
                     Mux(uWr,   B((1 << UB)   - 1, UB   bits), B(0, UB   bits))
      val rowData = Vec(Bits(EW bits), LANES); val rowMask = Vec(Bits(EW bits), LANES)
      for (k <- 0 until LANES) {
        rowData(k) := laneData
        rowMask(k) := Mux(uLane === U(k, log2Up(LANES) bits), laneMask, B(0, EW bits))
      }
      val bankW = uIdx(t)(0)
      val addrW = uIdx(t)(TIDX - 1 downto 1).asBits
      for (b <- 0 until 2) {
        bank(t)(b).io.we    := doWr && (if (b == 0) (bankW === False) else (bankW === True))
        bank(t)(b).io.waddr := addrW
        bank(t)(b).io.wdata := rowData.asBits
        bank(t)(b).io.wmask := rowMask.asBits
      }
    }
  }
}
