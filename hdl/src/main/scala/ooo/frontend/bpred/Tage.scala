package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** Single-port-array model for a block-read TAGE table bank (1R1W): 64 rows x 112b.
  * Combinational read (predict) + synchronous bit-masked write (commit). Sim model in
  * sram/output/tage_bank_array; P&R maps it via macro_wrappers.v -> fakeram45_64x124. */
class TageBank(addrW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("tage_bank_array")
  val io = new Bundle {
    val clk   = in  Bool()
    val re    = in  Bool();        val raddr = in  Bits(addrW bits); val rdata = out Bits(dw bits)
    val we    = in  Bool();        val waddr = in  Bits(addrW bits)
    val wdata = in  Bits(dw bits); val wmask = in  Bits(dw bits)
  }
  noIoPrefix()
}

/** Block-read bimodal (base PHT) bank (1R1W): 64 rows x 16b (= 8 lanes x 2b). Same
  * 1R1W combinational-read / masked-write contract as TageBank but a narrow 16b row.
  * Sim model sram/output/bim_bank_array; P&R maps it via macro_wrappers.v. */
class BimBank(addrW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("bim_bank_array")
  val io = new Bundle {
    val clk   = in  Bool()
    val re    = in  Bool();        val raddr = in  Bits(addrW bits); val rdata = out Bits(dw bits)
    val we    = in  Bool();        val waddr = in  Bits(addrW bits)
    val wdata = in  Bits(dw bits); val wmask = in  Bits(dw bits)
  }
  noIoPrefix()
}

/** SpinalHDL port of `hdl/frontend/branch_predictor/tage.sv` -- the TAGE direction
  * predictor: a bimodal base + TAGE_NUM tagged components with geometric history
  * lengths, spec/commit global history, use_alt_on_newly_allocated policy counter,
  * and at-commit training (strengthen provider / allocate longer / age usefulness).
  *
  * Named tage_spinal; sim/swap_shims/tage.sv carries `cb_bp_itf.bp from_cb` and the
  * packed-2D inst_pc port. The provider/alt selection loops are Scala folds (carry
  * the provider's ctr/u/index as hardware expressions) so the SV's sequential
  * `prov_t` read does not become a combinational self-reference. SV clock-gated
  * tables -> plain enabled Regs (RegInit covers the gated rst).
  */
class Tage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("tage_spinal")
  val IFW     = cfg.ifWidth        // 4
  val GHR     = cfg.ghrLen         // [GHR_LEN]
  val NUM     = cfg.tageNum        // 4
  val TDEPTH  = cfg.tageDepth      // [TAGE_DEPTH]
  val TIDX    = cfg.tageIdx        // 8
  val TAGB    = cfg.tageTagBits    // 9
  val CTRB    = cfg.tageCtrBits    // 3
  val UB      = cfg.tageUBits      // 2
  val PHTD    = cfg.phtDepth       // 1024
  val PHTI    = cfg.phtIdx         // 10
  val HIST    = cfg.tageHistLen    // Seq(7,15,31,63)
  val PROVW   = log2Up(NUM)        // 2

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // cb_bp_itf.bp from_cb (fields tage.sv reads)
    val from_cb_update_en    = in Bool()
    val from_cb_pc           = in Bits (32 bits)
    val from_cb_branch_taken = in Bool()
    val from_cb_ghr          = in Bits (GHR bits)
    // forwarded predict-time provider snapshot for the committing branch (per-table
    // {hit,ctr,u} PLUS the 2b bimodal counter); replaces the commit-side re-read of the
    // tagged tables AND the bimodal -> commit is write-only for both.
    val from_cb_prov         = in Bits (NUM * (1 + CTRB + UB) + 2 bits)
    val inst_pc        = in Bits (IFW * 32 bits)
    val re             = in Bool()           // fetch-advance enable (= if1 prv_ready); gates the sync SRAM read capture
    val blk_pc_next    = in Bits (32 bits)   // next-fetch block PC (= pcNext); the early read address
    val flush          = in Bool()
    val spec_update_en = in Bool()
    val spec_br_valid  = in Bits (IFW bits)
    val spec_br_taken  = in Bits (IFW bits)
    val ghr_snapshot   = out Bits (GHR bits)
    val predict_taken  = out Bits (IFW bits)
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
  def zeroEntry(): TageEntry = { val e = TageEntry(); e.tag := 0; e.ctr := 0; e.u := 0; e }

  val instPc = io.inst_pc.subdivideIn(IFW slices)

  // ---- history fold (XOR-tree of h[0..L) into `width` bits) ----
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
  def idxComb(pc: Bits, fidx: Bits): Bits = (pc(TIDX + 1 downto 3) ## (pc(2) ^ pc(1))) ^ fidx
  def tagComb(pc: Bits, ftag: Bits): Bits =
    (pc(TAGB + 1 downto 3) ## (pc(2) ^ pc(1))) ^ ftag ^ pc(2 * TAGB + 1 downto TAGB + 2)
  def bidx(pc: Bits): Bits = pc(PHTI + 1 downto 3) ## (pc(2) ^ pc(1))

  // ---- block-read (read-once-per-fetch-block) organization ----
  // Index each tagged table ONCE per fetch block by the block-aligned PC (drop the
  // in-block offset pc[LZ-1:0]) XOR the folded history; the row holds LANES=2*IFW
  // per-slot lanes selected by the in-block halfword offset. Per-slot TAGS stay
  // full-PC (tagComb) so multi-branch blocks remain disambiguated. Collapses the 4
  // slot-reads/table to 1 row-read/table -- the predictors->SRAM enabler (Phase 1:
  // FLOPS, validates the algorithm's IPC; Phase 3 swaps the row store to an SRAM macro).
  val LZ    = log2Up(IFW * 4)     // 4  (in-block byte-addr width)
  val LANES = 2 * IFW             // 8  (in-block halfword lanes)
  def blkIdx(pc: Bits, fidx: Bits): Bits = pc(TIDX + LZ - 1 downto LZ) ^ fidx
  def laneOf(pc: Bits): UInt = pc(LZ - 1 downto 1).asUInt

  // SRAM banking: bank = blkIdx[0] (consecutive blocks A/B always differ in blkIdx LSB
  // -> opposite banks -> 2 parallel reads), within-bank addr = blkIdx[TIDX-1:1].
  val EW    = TAGB + CTRB + UB     // 14  (per-lane entry {tag,ctr,u})
  val DW    = LANES * EW           // 112 (row width)
  val ADDRW = TIDX - 1            // 6   (rows/bank = TDEPTH/2 = 64)
  def laneEntry(row: Bits, lane: UInt): TageEntry = {
    val sel = row.subdivideIn(LANES slices)(lane)   // EW bits {tag,ctr,u}
    val e = TageEntry()
    e.tag := sel(EW - 1 downto CTRB + UB)
    e.ctr := sel(CTRB + UB - 1 downto UB).asSInt
    e.u   := sel(UB - 1 downto 0).asUInt
    e
  }

  // ---- bimodal base PHT, block-read (NO history fold -- pure PC base predictor) ----
  // Row = block-aligned PC (drop in-block offset); LANES 2b counters selected by the
  // in-block halfword (laneOf). BROWI rows x LANES = PHTD entries. Banked even/odd
  // (bank=row[0]) so the 2-block straddle reads hit opposite banks, like the tagged
  // tables. Counter (2b) forwarded at commit -> bimodal commit is also write-only.
  val BROWI = PHTI - log2Up(LANES)   // 7  (rows = 128; 128 x 8 lanes = 1024 = PHTD)
  val BEW   = 2                      // 2b saturating counter / lane
  val BDW   = LANES * BEW            // 16 (row width)
  val BADDR = BROWI - 1              // 6  (rows/bank = 64)
  def bRowOf(pc: Bits): Bits = pc(BROWI + LZ - 1 downto LZ)        // pc(10:4), 7 bits
  def bCtr(row: Bits, lane: UInt): UInt = row.subdivideIn(LANES slices)(lane).asUInt  // 2b

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
    // ---- state ----
    val ghrSpec   = RegInit(B(0, GHR bits))
    val ghrCommit = RegInit(B(0, GHR bits))
    // folded-history registers (spec path): invariant fidxSpec(t)==foldGen(ghrSpec,HIST(t),TIDX)
    // etc. Init 0 == foldGen(0). Maintained incrementally in lockstep with ghrSpec.
    val fidxSpec = Array.tabulate(NUM)(_ => RegInit(B(0, TIDX bits)))
    val ftagSpec = Array.tabulate(NUM)(_ => RegInit(B(0, TAGB bits)))
    val useAltOnNa = RegInit(U(8, 4 bits))
    // bimodal base PHT -> block-read SRAM banks (even/odd by bRow[0]); 2 reads (straddle)
    // + write-only commit (forwarded counter). Sim model inits to 01/lane (warm-up parity).
    val bimBank = Array.fill(2)(new BimBank(BADDR, BDW))
    for (b <- 0 until 2) { bimBank(b).io.clk := io.clk; bimBank(b).io.re := io.re }
    // tagged tables self-correct (a stale tag just mispredicts, then is overwritten)
    // -> no reset: drops ~NUM*TDEPTH*entryW reset flops off the predictor.
    // block-read tables -> per-table even/odd SRAM banks (1R1W): bank=blkIdx[0],
    // addr=blkIdx[TIDX-1:1]. Predict reads BOTH banks (rowA/rowB land in opposite banks
    // since consecutive blocks differ in blkIdx LSB); commit writes one bank (masked,
    // single lane). Phase 3c: replaces the Phase-1 flop tables -> SRAM area/FF/LUT win.
    val bank = Array.tabulate(NUM)(_ => Array.fill(2)(new TageBank(ADDRW, DW)))
    for (t <- 0 until NUM; b <- 0 until 2) { bank(t)(b).io.clk := io.clk; bank(t)(b).io.re := io.re }

    io.ghr_snapshot := ghrSpec

    // ---- speculative history shift across fetched branches, plus the matching
    //      incremental fold update (bout = the GHR bit leaving each component's
    //      L-window on that shift = the running ghr's bit L-1) ----
    val fidxFetch = Array.tabulate(NUM)(t => fidxSpec(t): Bits)
    val ftagFetch = Array.tabulate(NUM)(t => ftagSpec(t): Bits)
    val ghrSpecFetch = {
      var h: Bits = ghrSpec
      for (i <- 0 until IFW) {
        val v  = io.spec_br_valid(i)
        val tk = io.spec_br_taken(i)
        for (t <- 0 until NUM) {
          val Lt = HIST(t)
          fidxFetch(t) = Mux(v, rolXor(fidxFetch(t), Lt, tk, h(Lt - 1)), fidxFetch(t))
          ftagFetch(t) = Mux(v, rolXor(ftagFetch(t), Lt, tk, h(Lt - 1)), ftagFetch(t))
        }
        h = Mux(v, h(GHR - 2 downto 0) ## tk, h)
      }
      h
    }
    val ghrCommitNext = Mux(io.from_cb_update_en, ghrCommit(GHR - 2 downto 0) ## io.from_cb_branch_taken, ghrCommit)

    // commit-side folds stay combinational (training path at commit, not the fetch loop)
    val fidxC = (0 until NUM).map(t => foldGen(io.from_cb_ghr, HIST(t), TIDX))
    val ftagC = (0 until NUM).map(t => foldGen(io.from_cb_ghr, HIST(t), TAGB))

    // ===== prediction =====
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
    val blkBpcE = (io.blk_pc_next.asUInt + U(1 << LZ, 32 bits)).asBits   // next 16B block (early)
    // bank reads: A and B always map to opposite banks (blkIdx LSB differs); bank0 reads
    // whichever of A/B has bank-bit 0, bank1 the other; route rdata back to rowA/rowB.
    val bankA = Array.tabulate(NUM)(t => blkIdx(io.blk_pc_next, earlyFidx(t))(0))
    for (t <- 0 until NUM) {
      val idxA = blkIdx(io.blk_pc_next, earlyFidx(t)); val idxB = blkIdx(blkBpcE, earlyFidx(t))
      val addrA = idxA(TIDX - 1 downto 1); val addrB = idxB(TIDX - 1 downto 1)
      bank(t)(0).io.raddr := Mux(bankA(t) === False, addrA, addrB)
      bank(t)(1).io.raddr := Mux(bankA(t) === False, addrB, addrA)
    }
    // routing bit registered (re-gated, holds on stall) so the T+1 registered rdata un-routes correctly
    val bankAReg = Array.tabulate(NUM)(t => RegNextWhen(bankA(t), io.re))
    val rowA = Array.tabulate(NUM)(t => Mux(bankAReg(t) === False, bank(t)(0).io.rdata, bank(t)(1).io.rdata))
    val rowB = Array.tabulate(NUM)(t => Mux(bankAReg(t) === False, bank(t)(1).io.rdata, bank(t)(0).io.rdata))
    // bimodal block-read (same 2-bank straddle, NO history fold -> address purely off blk_pc_next)
    val bBankA = bRowOf(io.blk_pc_next)(0)
    val bAddrA = bRowOf(io.blk_pc_next)(BROWI - 1 downto 1); val bAddrB = bRowOf(blkBpcE)(BROWI - 1 downto 1)
    bimBank(0).io.raddr := Mux(bBankA === False, bAddrA, bAddrB)
    bimBank(1).io.raddr := Mux(bBankA === False, bAddrB, bAddrA)
    val bBankAReg = RegNextWhen(bBankA, io.re)
    val bRowA = Mux(bBankAReg === False, bimBank(0).io.rdata, bimBank(1).io.rdata)
    val bRowB = Mux(bBankAReg === False, bimBank(1).io.rdata, bimBank(0).io.rdata)
    // #7: precompute the table-INDEPENDENT PC-part of tagComb per in-block lane, off
    // blk_pc_next at T+0, registered (re-gated like the bank routing). instPc(i) ==
    // blockBase ## (lane<<1), so pcPart(blockBase, laneOf(instPc(i))) == the pc-part of
    // tagComb(instPc(i)); the T+1 tag-compare becomes row.tag === (pcPartReg(lane) ^ ftag)
    // -- one XOR layer instead of the full pc-fold on the realigned instPc. Bit-identical.
    def pcPartComb(bp: Bits, l: Int): Bits = {
      val lb = U(l, log2Up(LANES) bits)
      ((bp(TAGB + 1 downto 4) ## lb(log2Up(LANES) - 1)) ## (lb(1) ^ lb(0))) ^ bp(2 * TAGB + 1 downto TAGB + 2)
    }
    val pcPartA = Vec.tabulate(LANES)(l => RegNextWhen(pcPartComb(io.blk_pc_next, l), io.re))
    val pcPartB = Vec.tabulate(LANES)(l => RegNextWhen(pcPartComb(blkBpcE, l), io.re))
    val ptaken = Vec(Bool(), IFW)
    val snap   = Vec(Bits(PBT bits), IFW)   // per-slot: bimodal 2b ## {hit,ctr,u}xNUM
    for (i <- 0 until IFW) {
      val pc = instPc(i)
      val inB = pc(31 downto LZ) =/= instPc(0)(31 downto LZ)       // slot in the next block?
      val bimCtrSlot = bCtr(Mux(inB, bRowB, bRowA), laneOf(pc))   // 2b base counter
      val basePred = bimCtrSlot >= U(2)
      val pcPartSel = Mux(inB, pcPartB(laneOf(pc)), pcPartA(laneOf(pc)))  // #7: precomputed pc-part
      val pEnt = Vec(TageEntry(), NUM)
      val pHit = Vec(Bool(), NUM)
      for (t <- 0 until NUM) {
        pEnt(t) := laneEntry(Mux(inB, rowB(t), rowA(t)), laneOf(pc))
        pHit(t) := pEnt(t).tag === (pcPartSel ^ ftagSpec(t))
      }
      // snapshot the predict-time provider entries (bimodal 2b ## per-table {hit,ctr,u});
      // decoded back at commit (from_cb_prov) so the commit re-reads neither tt nor bimodal.
      snap(i) := bimCtrSlot.asBits ## Vec((0 until NUM).map(t => pHit(t).asBits ## pEnt(t).ctr.asBits ## pEnt(t).u.asBits)).asBits
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
      ptaken(i) := Mux(provWeak && useAltOnNa(3), altP, Mux(provV, provCtr >= 0, basePred))
    }
    io.predict_taken := ptaken.asBits
    io.prov_snapshot_flat := snap.asBits

    // ===== training derivation at commit =====
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
    val finalPred  = Mux(uProvWeak && useAltOnNa(3), uAltPred, uProvPred)
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

    // ===== ungated per-cycle state =====
    ghrCommit := ghrCommitNext
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
        when(uAltPred === uTaken) { useAltOnNa := Mux(useAltOnNa === 15, useAltOnNa, (useAltOnNa + 1).resize(4 bits)) }
        .otherwise                { useAltOnNa := Mux(useAltOnNa === 0,  useAltOnNa, (useAltOnNa - 1).resize(4 bits)) }
      }
    }

    // ===== bimodal base PHT bank write (commit-gated, WRITE-ONLY via forwarded counter) =====
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

    // ===== tagged-table SRAM bank writes (commit-gated, masked single lane at uLane) =====
    // Per-FIELD mask: provider updates ctr(+u), alloc writes the full lane, the aged path
    // writes u only. tag for non-alloc is masked off so it's preserved (uEnt.tag is unused
    // -- the forward-state snapshot carries no tag). Same 3 cases as the flop version.
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
