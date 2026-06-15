package ooo.frontend

import spinal.core._
import spinal.lib._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/inst_queue.sv` -- the compacting instruction
  * queue. Buffers IF_WIDTH-wide fetch packets and streams up to ID_WIDTH instrs/
  * cycle to the back-end, draining a wide packet over multiple cycles via rd_slot,
  * compacting valid candidates (head slots from rd_slot, then head+1 slots) and
  * capping at one branch per output bundle.
  *
  * Named inst_queue_spinal; sim/swap_shims/inst_queue.sv carries frontend_fifo_itf
  * (fetch_packet_t in) + fifo_backend_itf (decode_packet_t out) via per-field
  * extraction, and surfaces the perf-tapped `empty`.
  */
class InstQueue(cfg: CpuConfig = CpuConfig(), val depth: Int = 8) extends Component {
  setDefinitionName("inst_queue_spinal")
  val IFW  = cfg.ifWidth       // 4
  val OW   = cfg.idWidth       // 2
  val GHR  = cfg.ghrLen        // 64
  val DEPTH = depth            // 8
  val AIDX = log2Up(DEPTH)     // 3
  val NC   = 2 * IFW           // 8 candidates
  val NAVW = log2Up(OW + 1)    // 2
  val SRCW = log2Up(NC)        // 3

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // frontend_fifo_itf.fifo in (fetch_packet_t)
    val in_valid = in  Bool(); val in_ready = out Bool()
    val in_inst_flat     = in Bits (IFW * 32 bits)
    val in_inst_raw_flat = in Bits (IFW * 32 bits)
    val in_is_compressed = in Bits (IFW bits)
    val in_predict_taken = in Bits (IFW bits)
    val in_predict_target_flat = in Bits (IFW * 32 bits)
    val in_pc_flat       = in Bits (IFW * 32 bits)
    val in_valid_slots   = in Bits (IFW bits)
    val in_ghr           = in Bits (GHR bits)
    // fifo_backend_itf.fifo out (decode_packet_t)
    val out_valid = out Bool(); val out_ready = in Bool()
    val out_inst_flat     = out Bits (OW * 32 bits)
    val out_inst_raw_flat = out Bits (OW * 32 bits)
    val out_is_compressed = out Bits (OW bits)
    val out_predict_taken = out Bits (OW bits)
    val out_predict_target_flat = out Bits (OW * 32 bits)
    val out_pc_flat       = out Bits (OW * 32 bits)
    val out_valid_slots   = out Bits (OW bits)
    val out_ghr_flat      = out Bits (OW * GHR bits)
    val dbg_empty = out Bool()
  }
  noIoPrefix()

  case class FetchPkt() extends Bundle {
    val inst = Vec(Bits(32 bits), IFW); val inst_raw = Vec(Bits(32 bits), IFW)
    val is_compressed = Bits(IFW bits); val predict_taken = Bits(IFW bits)
    val predict_target = Vec(Bits(32 bits), IFW); val pc = Vec(Bits(32 bits), IFW)
    val valid = Bits(IFW bits); val ghr = Bits(GHR bits)
  }
  def isBranch(inst: Bits): Bool = {
    val op = inst(6 downto 0)
    (op === B"7'b1100011") || (op === B"7'b1101111") || (op === B"7'b1100111")
  }

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val fifo  = Vec(Reg(FetchPkt()), DEPTH)
    val wrPtr = RegInit(U(0, AIDX + 1 bits))
    val rdPtr = RegInit(U(0, AIDX + 1 bits))
    val rdSlot = RegInit(U(0, AIDX bits))
    val wrActual = wrPtr(AIDX - 1 downto 0)
    val rdActual = rdPtr(AIDX - 1 downto 0)
    val rdP1Actual = (rdActual + 1).resize(AIDX bits)

    val nEntries = (wrPtr - rdPtr).resize(AIDX + 1 bits)
    val full  = nEntries === DEPTH
    val empty = nEntries === 0
    val haveH  = nEntries >= 1
    val haveH1 = nEntries >= 2
    io.in_ready := !full
    io.dbg_empty := empty

    val head  = fifo(rdActual)
    val head1 = fifo(rdP1Actual)

    // ---- candidate stream (head slots from rd_slot, then head+1 slots) ----
    val cV = Vec(Bool(), NC); val cInst = Vec(Bits(32 bits), NC); val cRaw = Vec(Bits(32 bits), NC)
    val cComp = Vec(Bool(), NC); val cPc = Vec(Bits(32 bits), NC); val cGhr = Vec(Bits(GHR bits), NC)
    val cPt = Vec(Bool(), NC); val cPtgt = Vec(Bits(32 bits), NC); val cBr = Vec(Bool(), NC)
    val cInh = Vec(Bool(), NC)
    for (s <- 0 until IFW) {
      cInh(s) := True
      cV(s) := haveH && (U(s, AIDX bits) >= rdSlot) && head.valid(s)
      cInst(s) := head.inst(s); cRaw(s) := head.inst_raw(s); cComp(s) := head.is_compressed(s)
      cPc(s) := head.pc(s); cGhr(s) := head.ghr; cPt(s) := head.predict_taken(s)
      cPtgt(s) := head.predict_target(s); cBr(s) := isBranch(head.inst(s))
      cInh(IFW + s) := False
      cV(IFW + s) := haveH1 && head1.valid(s)
      cInst(IFW + s) := head1.inst(s); cRaw(IFW + s) := head1.inst_raw(s); cComp(IFW + s) := head1.is_compressed(s)
      cPc(IFW + s) := head1.pc(s); cGhr(IFW + s) := head1.ghr; cPt(IFW + s) := head1.predict_taken(s)
      cPtgt(IFW + s) := head1.predict_target(s); cBr(IFW + s) := isBranch(head1.inst(s))
    }

    // ---- compact valid candidates into <=OW stream slots ----
    val sInst = Vec(Bits(32 bits), OW); val sRaw = Vec(Bits(32 bits), OW); val sComp = Vec(Bool(), OW)
    val sPc = Vec(Bits(32 bits), OW); val sGhr = Vec(Bits(GHR bits), OW); val sPt = Vec(Bool(), OW)
    val sPtgt = Vec(Bits(32 bits), OW); val sBr = Vec(Bool(), OW); val sSrc = Vec(UInt(SRCW bits), OW)
    for (i <- 0 until OW) {
      sInst(i) := 0; sRaw(i) := 0; sComp(i) := False; sPc(i) := 0; sGhr(i) := 0
      sPt(i) := False; sPtgt(i) := 0; sBr(i) := False; sSrc(i) := 0
    }
    var k: UInt = U(0, NAVW bits)
    for (j <- 0 until NC) {
      val take = cV(j) && (k < OW)
      for (slot <- 0 until OW) {
        when(take && (k === slot)) {
          sInst(slot) := cInst(j); sRaw(slot) := cRaw(j); sComp(slot) := cComp(j); sPc(slot) := cPc(j)
          sGhr(slot) := cGhr(j); sPt(slot) := cPt(j); sPtgt(slot) := cPtgt(j); sBr(slot) := cBr(j)
          sSrc(slot) := U(j, SRCW bits)
        }
      }
      k = Mux(take, (k + 1).resize(NAVW bits), k)
    }
    val nAvail = k

    // ---- one-branch-per-bundle ----
    val bv = Vec(Bool(), OW); for (i <- 0 until OW) bv(i) := False
    var brSeen: Bool = False
    for (i <- 0 until OW) {
      if (i == 0) when(U(0, NAVW bits) < nAvail) { bv(0) := True }
      else when((U(i, NAVW bits) < nAvail) && bv(i - 1) && !(sBr(i) && brSeen)) { bv(i) := True }
      brSeen = brSeen | (bv(i) && sBr(i))
    }
    val bundleCount = CountOne(bv)

    // ---- output bundle ----
    val headEmpty = haveH && (head.valid === 0)
    io.out_valid := haveH && !headEmpty && (nAvail =/= 0)
    io.out_valid_slots := bv.asBits
    io.out_inst_flat := sInst.asBits
    io.out_inst_raw_flat := sRaw.asBits
    io.out_is_compressed := sComp.asBits
    io.out_predict_taken := sPt.asBits
    io.out_predict_target_flat := sPtgt.asBits
    io.out_pc_flat := sPc.asBits
    io.out_ghr_flat := sGhr.asBits

    // ---- advance rd_ptr / rd_slot ----
    val deqFire = io.out_valid && io.out_ready
    val lastSrc = sSrc((bundleCount - 1).resize(log2Up(OW) bits))

    val headMore = Bool(); val headNxSlot = UInt(AIDX bits)
    headMore := False; headNxSlot := 0
    when((lastSrc + 1) < IFW) { headNxSlot := (lastSrc + 1).resize(AIDX bits); headMore := head.valid(headNxSlot.resize(log2Up(IFW) bits)) }

    val h1Cur = (lastSrc - IFW).resize(AIDX bits)
    val h1More = Bool(); val h1NxSlot = UInt(AIDX bits)
    h1More := False; h1NxSlot := 0
    when((h1Cur + 1) < IFW) { h1NxSlot := (h1Cur + 1).resize(AIDX bits); h1More := head1.valid(h1NxSlot.resize(log2Up(IFW) bits)) }

    val nxtRdPtr  = cloneOf(rdPtr); val nxtRdSlot = cloneOf(rdSlot)
    nxtRdPtr := rdPtr; nxtRdSlot := rdSlot
    when(headEmpty) {
      nxtRdPtr := (rdPtr + 1).resize(AIDX + 1 bits); nxtRdSlot := 0
    }.elsewhen(deqFire) {
      when(cInh(lastSrc)) {
        when(headMore) { nxtRdPtr := rdPtr; nxtRdSlot := headNxSlot }
          .otherwise   { nxtRdPtr := (rdPtr + 1).resize(AIDX + 1 bits); nxtRdSlot := 0 }
      }.otherwise {
        when(h1More) { nxtRdPtr := (rdPtr + 1).resize(AIDX + 1 bits); nxtRdSlot := h1NxSlot }
          .otherwise { nxtRdPtr := (rdPtr + 2).resize(AIDX + 1 bits); nxtRdSlot := 0 }
      }
    }

    // ---- registered update ----
    val enqData = FetchPkt()
    enqData.inst := io.in_inst_flat.subdivideIn(IFW slices)
    enqData.inst_raw := io.in_inst_raw_flat.subdivideIn(IFW slices)
    enqData.is_compressed := io.in_is_compressed
    enqData.predict_taken := io.in_predict_taken
    enqData.predict_target := io.in_predict_target_flat.subdivideIn(IFW slices)
    enqData.pc := io.in_pc_flat.subdivideIn(IFW slices)
    enqData.valid := io.in_valid_slots
    enqData.ghr := io.in_ghr
    when(io.in_valid && !full) {
      fifo(wrActual) := enqData
      wrPtr := (wrPtr + 1).resize(AIDX + 1 bits)
    }
    rdPtr := nxtRdPtr
    rdSlot := nxtRdSlot
  }
}
