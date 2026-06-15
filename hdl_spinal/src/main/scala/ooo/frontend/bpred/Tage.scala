package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

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
  val GHR     = cfg.ghrLen         // 64
  val NUM     = cfg.tageNum        // 4
  val TDEPTH  = cfg.tageDepth      // 256
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
    val inst_pc        = in Bits (IFW * 32 bits)
    val flush          = in Bool()
    val spec_update_en = in Bool()
    val spec_br_valid  = in Bits (IFW bits)
    val spec_br_taken  = in Bits (IFW bits)
    val ghr_snapshot   = out Bits (GHR bits)
    val predict_taken  = out Bits (IFW bits)
  }
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
  // PC combined with a history fold + RVC de-alias (pc[1] into the LSB).
  def idxComb(pc: Bits, fidx: Bits): Bits = (pc(TIDX + 1 downto 3) ## (pc(2) ^ pc(1))) ^ fidx
  def tagComb(pc: Bits, ftag: Bits): Bits =
    (pc(TAGB + 1 downto 3) ## (pc(2) ^ pc(1))) ^ ftag ^ pc(2 * TAGB + 1 downto TAGB + 2)
  def bidx(pc: Bits): Bits = pc(PHTI + 1 downto 3) ## (pc(2) ^ pc(1))

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
    val useAltOnNa = RegInit(U(8, 4 bits))
    val bimodal = Vec.fill(PHTD)(RegInit(U(1, 2 bits)))                 // base predictor (init 01)
    val tt = Array.tabulate(NUM)(_ => Vec.fill(TDEPTH)(RegInit(zeroEntry())))

    io.ghr_snapshot := ghrSpec

    // ---- speculative history shift across fetched branches ----
    val ghrSpecFetch = {
      var h: Bits = ghrSpec
      for (i <- 0 until IFW) h = Mux(io.spec_br_valid(i), h(GHR - 2 downto 0) ## io.spec_br_taken(i), h)
      h
    }
    val ghrCommitNext = Mux(io.from_cb_update_en, ghrCommit(GHR - 2 downto 0) ## io.from_cb_branch_taken, ghrCommit)

    // per-component folds (shared)
    val fidxS = (0 until NUM).map(t => foldGen(ghrSpec, HIST(t), TIDX))
    val ftagS = (0 until NUM).map(t => foldGen(ghrSpec, HIST(t), TAGB))
    val fidxC = (0 until NUM).map(t => foldGen(io.from_cb_ghr, HIST(t), TIDX))
    val ftagC = (0 until NUM).map(t => foldGen(io.from_cb_ghr, HIST(t), TAGB))

    // ===== prediction (one lookup per fetch slot) =====
    val ptaken = Vec(Bool(), IFW)
    for (i <- 0 until IFW) {
      val pc = instPc(i)
      val basePred = bimodal(bidx(pc).asUInt) >= U(2)
      val pEnt = Vec(TageEntry(), NUM)
      val pHit = Vec(Bool(), NUM)
      for (t <- 0 until NUM) {
        pEnt(t) := tt(t)(idxComb(pc, fidxS(t)).asUInt)
        pHit(t) := pEnt(t).tag === tagComb(pc, ftagS(t))
      }
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

    // ===== training derivation at commit =====
    val uTaken    = io.from_cb_branch_taken
    val bimWidx   = bidx(io.from_cb_pc).asUInt
    val basePredC = bimodal(bimWidx) >= U(2)

    val uIdx = Vec(UInt(TIDX bits), NUM)
    val uEnt = Vec(TageEntry(), NUM)
    val uHit = Vec(Bool(), NUM)
    for (t <- 0 until NUM) {
      uIdx(t) := idxComb(io.from_cb_pc, fidxC(t)).asUInt
      uEnt(t) := tt(t)(uIdx(t))
      uHit(t) := uEnt(t).tag === tagComb(io.from_cb_pc, ftagC(t))
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
    when(io.flush)              { ghrSpec := ghrCommitNext }
    .elsewhen(io.spec_update_en) { ghrSpec := ghrSpecFetch }
    when(io.from_cb_update_en) {
      when(uProvWeak && (uProvPred =/= uAltPred)) {
        when(uAltPred === uTaken) { useAltOnNa := Mux(useAltOnNa === 15, useAltOnNa, (useAltOnNa + 1).resize(4 bits)) }
        .otherwise                { useAltOnNa := Mux(useAltOnNa === 0,  useAltOnNa, (useAltOnNa - 1).resize(4 bits)) }
      }
    }

    // ===== gated tables (write only at commit; rst via RegInit) =====
    when(io.from_cb_update_en) {
      when(!uProvV) {
        when(uTaken) { bimodal(bimWidx) := Mux(bimodal(bimWidx) === 3, bimodal(bimWidx), (bimodal(bimWidx) + 1).resize(2 bits)) }
        .otherwise   { bimodal(bimWidx) := Mux(bimodal(bimWidx) === 0, bimodal(bimWidx), (bimodal(bimWidx) - 1).resize(2 bits)) }
      }
      for (t <- 0 until NUM) {
        when(uProvV && (U(t, PROVW bits) === uProvIdx)) {
          tt(t)(uIdx(t)).ctr := ctrUpd(uEnt(t).ctr, uTaken)
          when(uProvPred =/= uAltPred) {
            when(uProvPred === uTaken) { tt(t)(uIdx(t)).u := uInc(uEnt(t).u) }
            .otherwise                 { tt(t)(uIdx(t)).u := uDec(uEnt(t).u) }
          }
        }.elsewhen(mispredict && allocValid && (U(t, PROVW bits) === allocTable)) {
          tt(t)(uIdx(t)).tag := tagComb(io.from_cb_pc, ftagC(t))
          tt(t)(uIdx(t)).ctr := Mux(uTaken, S(0, CTRB bits), S(-1, CTRB bits))
          tt(t)(uIdx(t)).u   := U(0, UB bits)
        }.elsewhen(mispredict && !allocValid && (U(t, 3 bits) >= allocStart)) {
          tt(t)(uIdx(t)).u := uDec(uEnt(t).u)
        }
      }
    }
  }
}
