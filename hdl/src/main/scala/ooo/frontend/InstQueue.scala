package ooo.frontend

import spinal.core._
import spinal.lib._
import ooo.{CpuConfig, OhSel}
import ooo.backend.decode.DecoderPayload

/** Compacting fetch-packet queue with two-wide decoded output. */
class InstQueue(cfg: CpuConfig, val depth: Int) extends Component {
  def this(cfg: CpuConfig) = this(cfg,cfg.instQueueDepth)
  def this() = this(CpuConfig())
  setDefinitionName("inst_queue_spinal")
  val IFW  = cfg.ifWidth
  val OW   = cfg.idWidth
  val KPW  = log2Up(cfg.ifWidth)   // kp width (GHR pointer-file compression)
  val PROV = cfg.bpProvW
  val DEPTH = depth
  require(depth >= 2 && (depth & (depth - 1)) == 0, "Instruction queue needs power-of-two depth >= 2")
  val AIDX = log2Up(DEPTH)
  val NC   = 2 * IFW           // 8 candidates
  val NAVW = log2Up(OW + 1)
  val SRCW = log2Up(NC)
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val in_valid = in  Bool(); val in_ready = out Bool()
    val in_inst_flat     = in Bits (IFW * 32 bits)
    val in_pre_flat = if (cfg.frontendPayloadSpeculation) in Bits(IFW * DispatchPredecode.width bits) else null
    val in_inst_raw_flat = in Bits (IFW * 32 bits)
    val in_is_compressed = in Bits (IFW bits)
    val in_predict_taken = in Bits (IFW bits)
    val in_predict_target_flat = in Bits (IFW * 32 bits)
    val in_pc_flat       = in Bits (IFW * 32 bits)
    val in_valid_slots   = in Bits (IFW bits)
    val in_kp_flat       = in Bits (IFW * KPW bits)   // per-slot same-packet older-ctrl count
    val in_prov_flat     = in Bits (IFW * PROV bits)
    val out_valid = out Bool(); val out_ready = in Bool()
    val out_inst_flat     = out Bits (OW * 32 bits)
    val out_decoded_flat = if (cfg.iqParallelDecode) out Bits(OW * DecoderPayload.width(cfg) bits) else null
    val out_inst_raw_flat = out Bits (OW * 32 bits)
    val out_is_compressed = out Bits (OW bits)
    val out_predict_taken = out Bits (OW bits)
    val out_predict_target_flat = out Bits (OW * 32 bits)
    val out_pc_flat       = out Bits (OW * 32 bits)
    val out_valid_slots   = out Bits (OW bits)
    val out_kp_flat       = out Bits (OW * KPW bits)
    val out_prov_flat     = out Bits (OW * PROV bits)
    // enqueue-time pre-decode, slot-aligned with out_inst_flat. IdStage
    // uses these for the dispatch-control chain instead of decoding read data.
    val out_pre_rs_type_flat = out Bits (OW * 2 bits)
    val out_pre_is_store     = out Bits (OW bits)
    val out_pre_is_atomic    = out Bits (OW bits)
    val out_pre_has_rd       = out Bits (OW bits)
    val dbg_empty = out Bool()
  }
  noIoPrefix()

  case class FetchPkt() extends Bundle {
    val inst = Vec(Bits(32 bits), IFW)
    // inst_raw feeds only the rvfi record -- not elaborated in the NoRvfi
    // product config (port-level constant-tying can't sweep across hierarchy)
    val inst_raw = if (cfg.rvfi) Vec(Bits(32 bits), IFW) else null
    val is_compressed = Bits(IFW bits); val predict_taken = Bits(IFW bits)
    val predict_target = Vec(Bits(32 bits), IFW)
    // Store packet PC high bits once; each slot carries low bits and whether its high part crossed the boundary.
    val pcBase = Bits(28 bits); val pcBaseP1 = Bits(28 bits)
    val pcCross = Bits(IFW bits); val pcLo = Vec(Bits(4 bits), IFW)
    val valid = Bits(IFW bits); val kp = Vec(Bits(KPW bits), IFW)
    val prov = Vec(Bits(PROV bits), IFW)
    val pre = Vec(DispatchPredecode.DispatchFields(), IFW)   // enqueue-time dispatch-control pre-decode
  }

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val fifo  = Vec(Reg(FetchPkt()), DEPTH)
    val wrPtr = RegInit(U(0, AIDX + 1 bits))
    val rdPtr = RegInit(U(0, AIDX + 1 bits))
    // Packet address width and instruction slot width are independent.
    val rdSlot = RegInit(U(0, KPW bits))
    val wrActual = wrPtr(AIDX - 1 downto 0)
    val rdActual = rdPtr(AIDX - 1 downto 0)
    val rdP1Actual = (rdActual + 1).resize(AIDX bits)

    // wrPtr - rdPtr, kept as a register (updated from the nxt pointers below) so
    // haveH/haveH1 feed the candidate valids without the subtract on the read path
    val nEntries = RegInit(U(0, AIDX + 1 bits))
    val full  = nEntries === DEPTH
    val empty = nEntries === 0
    val haveH  = nEntries >= 1
    val haveH1 = nEntries >= 2
    io.in_ready := !full
    io.dbg_empty := empty

    val headSelect = if (cfg.iqOneHotHead)
      Reg(Bits(DEPTH bits)).setName("iqHeadSelect") init(B(1, DEPTH bits)) else null
    def selectPacket(select: Bits): FetchPkt = {
      val packet = FetchPkt()
      packet.assignFromBits(OhSel(select, fifo.map(_.asBits)))
      packet
    }
    def rotateHead(distance: Int): Bits = {
      val rotated = Bits(DEPTH bits)
      for (i <- 0 until DEPTH) rotated(i) := headSelect((i + DEPTH - distance % DEPTH) % DEPTH)
      rotated
    }
    val head  = if (cfg.iqOneHotHead) selectPacket(headSelect) else fifo(rdActual)
    val head1 = if (cfg.iqOneHotHead) selectPacket(rotateHead(1)) else fifo(rdP1Actual)

    val decodedWidth = DecoderPayload.width(cfg)
    val decodedRows = if (cfg.iqParallelDecode) (0 until DEPTH).map { row =>
      (0 until IFW).map(slot => DecoderPayload.decode(fifo(row).inst(slot), cfg).asBits)
    } else null
    val decodedHead = if (cfg.iqParallelDecode && !cfg.iqMergedDecodeSelect) (0 until IFW).map { slot =>
      OhSel(headSelect, decodedRows.map(_(slot)))
    } else null
    val decodedHead1 = if (cfg.iqParallelDecode && !cfg.iqMergedDecodeSelect) (0 until IFW).map { slot =>
      OhSel(rotateHead(1), decodedRows.map(_(slot)))
    } else null
    val decodedZero = if (cfg.iqParallelDecode) DecoderPayload.decode(B(0,32 bits),cfg).asBits else null
    val cDecoded = if (cfg.iqParallelDecode && !cfg.iqMergedDecodeSelect) decodedHead ++ decodedHead1 else null
    val sDecoded = if (cfg.iqParallelDecode) Vec(Bits(decodedWidth bits),OW) else null

    // candidate stream (head slots from rd_slot, then head+1 slots)
    val cV = Vec(Bool(), NC); val cInst = Vec(Bits(32 bits), NC); val cRaw = Vec(Bits(32 bits), NC)
    val cComp = Vec(Bool(), NC); val cPc = Vec(Bits(32 bits), NC); val cKp = Vec(Bits(KPW bits), NC)
    val cPt = Vec(Bool(), NC); val cPtgt = Vec(Bits(32 bits), NC); val cBr = Vec(Bool(), NC)
    val cInh = Vec(Bool(), NC); val cProv = Vec(Bits(PROV bits), NC)
    val cPre = Vec(DispatchPredecode.DispatchFields(), NC)
    def pktPc(p: FetchPkt, s: Int): Bits = Mux(p.pcCross(s), p.pcBaseP1, p.pcBase) ## p.pcLo(s)
    for (s <- 0 until IFW) {
      cInh(s) := True
      cV(s) := haveH && (U(s, KPW bits) >= rdSlot) && head.valid(s)
      cInst(s) := head.inst(s); cRaw(s) := (if (cfg.rvfi) head.inst_raw(s) else B(0, 32 bits)); cComp(s) := head.is_compressed(s)
      cPc(s) := pktPc(head, s); cKp(s) := head.kp(s); cPt(s) := head.predict_taken(s)
      cPtgt(s) := head.predict_target(s); cProv(s) := head.prov(s)
      cPre(s) := head.pre(s); cBr(s) := head.pre(s).isBr   // off the stored bit
      cInh(IFW + s) := False
      cV(IFW + s) := haveH1 && head1.valid(s)
      cInst(IFW + s) := head1.inst(s); cRaw(IFW + s) := (if (cfg.rvfi) head1.inst_raw(s) else B(0, 32 bits)); cComp(IFW + s) := head1.is_compressed(s)
      cPc(IFW + s) := pktPc(head1, s); cKp(IFW + s) := head1.kp(s); cPt(IFW + s) := head1.predict_taken(s)
      cPtgt(IFW + s) := head1.predict_target(s); cProv(IFW + s) := head1.prov(s)
      cPre(IFW + s) := head1.pre(s); cBr(IFW + s) := head1.pre(s).isBr
    }

    // compact valid candidates into <=OW stream slots
    val sInst = Vec(Bits(32 bits), OW); val sRaw = Vec(Bits(32 bits), OW); val sComp = Vec(Bool(), OW)
    val sPc = Vec(Bits(32 bits), OW); val sKp = Vec(Bits(KPW bits), OW); val sPt = Vec(Bool(), OW)
    val sPtgt = Vec(Bits(32 bits), OW); val sBr = Vec(Bool(), OW); val sSrc = Vec(UInt(SRCW bits), OW)
    val sProv = Vec(Bits(PROV bits), OW)
    // the pre-decoded control bits ride the SAME OhSel one-hot as the
    // instruction they belong to, so they stay slot-aligned through compaction.
    val sRsType = Vec(Bits(2 bits), OW); val sIsStore = Vec(Bool(), OW)
    val sIsAtomic = Vec(Bool(), OW); val sHasRd = Vec(Bool(), OW)
    // Use a saturating prefix count to rank valid candidates, then select each output by rank.
    def satAdd(a: UInt, b: UInt): UInt = { val s = a +^ b; Mux(s > OW, U(OW, NAVW bits), s(NAVW - 1 downto 0)) }
    var cnt: IndexedSeq[UInt] = (0 until NC).map(j => Mux(cV(j), U(1, NAVW bits), U(0, NAVW bits)))
    var dd = 1
    while (dd < NC) {
      cnt = IndexedSeq.tabulate(NC)(j => if (j >= dd) satAdd(cnt(j), cnt(j - dd)) else cnt(j))
      dd *= 2
    }
    val nAvail = cnt(NC - 1)
    for (slot <- 0 until OW) {
      val oh = Vec(Bool(), NC)
      for (j <- 0 until NC) {
        val excl = if (j == 0) U(0, NAVW bits) else cnt(j - 1)   // count of takes below j
        oh(j) := cV(j) && (excl === slot)
      }
      val sel = oh.asBits
      if (cfg.iqParallelDecode) {
        if (cfg.iqMergedDecodeSelect) {
          val selects = for (row <- 0 until DEPTH; lane <- 0 until IFW) yield
            (headSelect(row) && oh(lane)) || (rotateHead(1)(row) && oh(IFW + lane))
          val values = decodedRows.flatMap(identity)
          sDecoded(slot) := Mux(sel.orR,OhSel(Vec(selects).asBits,values),decodedZero)
        } else sDecoded(slot) := Mux(sel.orR,OhSel(sel,cDecoded),decodedZero)
      }
      sInst(slot) := OhSel(sel, cInst); sRaw(slot) := OhSel(sel, cRaw)
      sComp(slot) := OhSel.bool(sel, cComp); sPc(slot) := OhSel(sel, cPc)
      sKp(slot) := OhSel(sel, cKp); sPt(slot) := OhSel.bool(sel, cPt)
      sPtgt(slot) := OhSel(sel, cPtgt); sBr(slot) := OhSel.bool(sel, cBr)
      sProv(slot) := OhSel(sel, cProv)
      sSrc(slot) := OhSel(sel, (0 until NC).map(j => B(j, SRCW bits))).asUInt
      sRsType(slot)   := OhSel(sel, cPre.map(_.rsType))
      sIsStore(slot)  := OhSel.bool(sel, cPre.map(_.isStore))
      sIsAtomic(slot) := OhSel.bool(sel, cPre.map(_.isAtomic))
      sHasRd(slot)    := OhSel.bool(sel, cPre.map(_.hasRd))
    }

    // one-branch-per-bundle
    val bv = Vec(Bool(), OW); for (i <- 0 until OW) bv(i) := False
    var brSeen: Bool = False
    for (i <- 0 until OW) {
      if (i == 0) when(U(0, NAVW bits) < nAvail) { bv(0) := True }
      else when((U(i, NAVW bits) < nAvail) && bv(i - 1) && !(sBr(i) && brSeen)) { bv(i) := True }
      brSeen = brSeen | (bv(i) && sBr(i))
    }
    val bundleCount = CountOne(bv)

    // output bundle
    val headEmpty = haveH && (head.valid === 0)
    io.out_valid := haveH && !headEmpty && (nAvail =/= 0)
    io.out_valid_slots := bv.asBits
    io.out_inst_flat := sInst.asBits
    if (cfg.iqParallelDecode) io.out_decoded_flat := sDecoded.asBits
    io.out_inst_raw_flat := sRaw.asBits
    io.out_is_compressed := sComp.asBits
    io.out_predict_taken := sPt.asBits
    if (cfg.gateFetchPayload) {
      // FrontendTop.effPtgt uses the sequential PC whenever prediction is not
      // taken. Reconstruct that value instead of clocking 32 target bits/slot.
      val effectiveTargets = Vec(Bits(32 bits),OW)
      for (i <- 0 until OW) effectiveTargets(i) := Mux(sPt(i),sPtgt(i),
        ooo.FastAdd.pcNext(sPc(i),sComp(i),cfg.fpgaNativeAdd))
      io.out_predict_target_flat := effectiveTargets.asBits
    } else io.out_predict_target_flat := sPtgt.asBits
    io.out_pc_flat := sPc.asBits
    io.out_kp_flat := sKp.asBits
    io.out_prov_flat := sProv.asBits
    io.out_pre_rs_type_flat := sRsType.asBits
    io.out_pre_is_store  := sIsStore.asBits
    io.out_pre_is_atomic := sIsAtomic.asBits
    io.out_pre_has_rd    := sHasRd.asBits

    // advance rd_ptr / rd_slot
    val deqFire = io.out_valid && io.out_ready
    val lastSrc = sSrc((bundleCount - 1).resize(log2Up(OW) bits))

    // These hold slot/candidate indices in the 2*IFW candidate space, so they must be
    // sized log2Up(2*IFW) -- NOT AIDX (= log2Up(depth)), which only coincides at depth=8.
    val SLOTW = log2Up(2 * IFW)
    val headMore = Bool(); val headNxSlot = UInt(SLOTW bits)
    headMore := False; headNxSlot := 0
    when((lastSrc + 1) < IFW) { headNxSlot := (lastSrc + 1).resize(SLOTW bits); headMore := head.valid(headNxSlot.resize(log2Up(IFW) bits)) }

    val h1Cur = (lastSrc - IFW).resize(SLOTW bits)
    val h1More = Bool(); val h1NxSlot = UInt(SLOTW bits)
    h1More := False; h1NxSlot := 0
    when((h1Cur + 1) < IFW) { h1NxSlot := (h1Cur + 1).resize(SLOTW bits); h1More := head1.valid(h1NxSlot.resize(log2Up(IFW) bits)) }

    val nxtRdPtr  = cloneOf(rdPtr); val nxtRdSlot = cloneOf(rdSlot)
    val headStep = if (cfg.iqOneHotHead) UInt(2 bits) else null
    if (cfg.iqOneHotHead) headStep := 0
    nxtRdPtr := rdPtr; nxtRdSlot := rdSlot
    when(headEmpty) {
      nxtRdPtr := (rdPtr + 1).resize(AIDX + 1 bits); nxtRdSlot := 0
      if (cfg.iqOneHotHead) headStep := 1
    }.elsewhen(deqFire) {
      when(cInh(lastSrc)) {
        when(headMore) { nxtRdPtr := rdPtr; nxtRdSlot := headNxSlot.resize(rdSlot.getWidth bits) }
          .otherwise {
            nxtRdPtr := (rdPtr + 1).resize(AIDX + 1 bits); nxtRdSlot := 0
            if (cfg.iqOneHotHead) headStep := 1
          }
      }.otherwise {
        when(h1More) {
          nxtRdPtr := (rdPtr + 1).resize(AIDX + 1 bits); nxtRdSlot := h1NxSlot.resize(rdSlot.getWidth bits)
          if (cfg.iqOneHotHead) headStep := 1
        }.otherwise {
          nxtRdPtr := (rdPtr + 2).resize(AIDX + 1 bits); nxtRdSlot := 0
          if (cfg.iqOneHotHead) headStep := 2
        }
      }
    }
    if (cfg.iqOneHotHead) {
      when(headStep === 1) { headSelect := rotateHead(1) }
        .elsewhen(headStep === 2) { headSelect := rotateHead(2) }
    }

    // registered update
    val enqData = FetchPkt()
    enqData.inst := io.in_inst_flat.subdivideIn(IFW slices)
    if (cfg.rvfi) enqData.inst_raw := io.in_inst_raw_flat.subdivideIn(IFW slices)
    enqData.is_compressed := io.in_is_compressed
    enqData.predict_taken := io.in_predict_taken
    enqData.predict_target := io.in_predict_target_flat.subdivideIn(IFW slices)
    val inPc = io.in_pc_flat.subdivideIn(IFW slices)
    enqData.pcBase   := inPc(0)(31 downto 4)
    enqData.pcBaseP1 := ooo.FastAdd.addPow2(inPc(0)(31 downto 4).asUInt,0,cfg.fpgaNativeAdd).asBits   // enqueue-side, slack-rich
    enqData.pcCross  := Cat((0 until IFW).map(s => inPc(s)(4) =/= inPc(0)(4)))   // slot 0 at LSB
    for (s <- 0 until IFW) enqData.pcLo(s) := inPc(s)(3 downto 0)
    enqData.valid := io.in_valid_slots
    enqData.kp := io.in_kp_flat.subdivideIn(IFW slices)
    enqData.prov := io.in_prov_flat.subdivideIn(IFW slices)
    // decode the control bits HERE, one cycle before they are needed and
    // on a path with slack, rather than at the head of the dispatch handshake.
    for (s <- 0 until IFW) {
      if (cfg.frontendPayloadSpeculation)
        enqData.pre(s).assignFromBits(io.in_pre_flat(s * DispatchPredecode.width,DispatchPredecode.width bits))
      else enqData.pre(s) := DispatchPredecode.decode(enqData.inst(s),cfg)
    }
    val enqFire = io.in_valid && !full
    val nxtWrPtr = Mux(enqFire, (wrPtr + 1).resize(AIDX + 1 bits), wrPtr)
    when(enqFire) {
      if (!cfg.gateFetchPayload) fifo(wrActual) := enqData
      else {
        val destination = fifo(wrActual)
        destination.valid := enqData.valid
        destination.pcBase := enqData.pcBase
        when((enqData.pcCross & enqData.valid).orR) { destination.pcBaseP1 := enqData.pcBaseP1 }
        for (s <- 0 until IFW) when(enqData.valid(s)) {
          destination.inst(s) := enqData.inst(s)
          if (cfg.rvfi) destination.inst_raw(s) := enqData.inst_raw(s)
          destination.is_compressed(s) := enqData.is_compressed(s)
          destination.predict_taken(s) := enqData.predict_taken(s)
          when(enqData.predict_taken(s)) { destination.predict_target(s) := enqData.predict_target(s) }
          destination.pcCross(s) := enqData.pcCross(s); destination.pcLo(s) := enqData.pcLo(s)
          destination.kp(s) := enqData.kp(s); destination.prov(s) := enqData.prov(s)
          destination.pre(s) := enqData.pre(s)
        }
      }
    }
    wrPtr := nxtWrPtr
    rdPtr := nxtRdPtr
    rdSlot := nxtRdSlot
    nEntries := (nxtWrPtr - nxtRdPtr).resize(AIDX + 1 bits)
  }
}
