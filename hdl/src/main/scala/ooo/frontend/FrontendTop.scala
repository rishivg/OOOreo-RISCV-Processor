package ooo.frontend

import spinal.core._
import spinal.lib._
import ooo.CpuConfig
import ooo.frontend.bpred.{Tage, Ubtb, Ras}

/** SpinalHDL port of `hdl/frontend/frontend_top.sv` -- the front-end cluster.
  *
  * Composes the validated SpinalHDL leaves: If1Stage (icache fetch), FetchAlign
  * (C-ext realign + decompress), and the Tage / Ubtb / Ras predictors -- plus the
  * C-extension parcel-window glue (carry across block boundary), prediction gating
  * (non-control slots forced not-taken), the pc_next redirect mux, speculative
  * history predecode, and the to_fifo fetch-packet assembly.
  *
  * Named frontend_top_spinal; sim/swap_shims/frontend_top.sv carries the external
  * SV interfaces (frontend_fifo_itf, cacheline_itf.master, cb_bp_itf.bp) and
  * recreates the perf-tapped if1_stage_i.icache_unresponsive scope. FetchAlign
  * re-emits fetch_align + decompressor -> EXTRA_EXCLUDE those SV files.
  */
class FrontendTop(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("frontend_top_spinal")
  val IFW  = cfg.ifWidth          // 4
  val GHR  = cfg.ghrLen           // [GHR_LEN]
  val PROV = cfg.tageNum * (1 + cfg.tageCtrBits + cfg.tageUBits) + 2   // +2 = forwarded bimodal counter
  val IFIDX = log2Up(IFW)         // 2
  val PMAX = 2 * IFW              // 8 parcels
  val LZ   = log2Up(IFW * 4)      // block byte-offset bits (4)
  val PCW  = cfg.parcelCntW       // 4

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    val backend_redirect_pc = in Bits (32 bits)
    // frontend_fifo_itf.frontend to_fifo (fetch_packet_t out)
    val to_fifo_valid = out Bool(); val to_fifo_ready = in Bool()
    val to_fifo_inst_flat     = out Bits (IFW * 32 bits)
    val to_fifo_inst_raw_flat = out Bits (IFW * 32 bits)
    val to_fifo_is_compressed = out Bits (IFW bits)
    val to_fifo_predict_taken = out Bits (IFW bits)
    val to_fifo_predict_target_flat = out Bits (IFW * 32 bits)
    val to_fifo_pc_flat       = out Bits (IFW * 32 bits)
    val to_fifo_valid_slots   = out Bits (IFW bits)
    val to_fifo_ghr           = out Bits (GHR bits)
    val to_fifo_prov_flat     = out Bits (IFW * PROV bits)   // per-slot TAGE provider snapshot
    // cacheline_itf.master icache_itf
    val icache_addr   = out Bits (32 bits); val icache_read = out Bool(); val icache_write = out Bool()
    val icache_wdata  = out Bits (256 bits); val icache_ready = in Bool(); val icache_raddr = in Bits (32 bits)
    val icache_rdata  = in  Bits (256 bits); val icache_rvalid = in Bool()
    // cb_bp_itf.bp from_cb
    val from_cb_update_en      = in Bool()
    val from_cb_pc             = in Bits (32 bits)
    val from_cb_fu_opcode      = in Bits (4 bits)
    val from_cb_branch_taken   = in Bool()
    val from_cb_target_address = in Bits (32 bits)
    val from_cb_ghr            = in Bits (GHR bits)
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

    // --- IF1 fetch stage (produces pc + raw block words) ---
    val pcNext = Bits(32 bits)
    val if1 = new If1Stage(cfg)
    if1.io.clk := io.clk; if1.io.rst := io.rst; if1.io.flush := io.backend_flush
    if1.io.prv_valid := True
    if1.io.nxt_ready := io.to_fifo_ready
    if1.io.pc_next := pcNext
    val if1Valid = if1.io.nxt_valid
    val pc = if1.io.pc
    val insts = if1.io.insts
    io.icache_addr := if1.io.icache_addr; io.icache_read := if1.io.icache_read; io.icache_write := if1.io.icache_write
    io.icache_wdata := if1.io.icache_wdata
    if1.io.icache_ready := io.icache_ready; if1.io.icache_raddr := io.icache_raddr
    if1.io.icache_rdata := io.icache_rdata; if1.io.icache_rvalid := io.icache_rvalid
    io.dbg_icache_unresponsive := if1.io.dbg_icache_unresponsive

    // --- C-ext parcel window ---
    val instWords = insts.subdivideIn(IFW slices)
    val blkParcels = Vec(Bits(16 bits), PMAX)
    for (w <- 0 until IFW) { blkParcels(2 * w) := instWords(w)(15 downto 0); blkParcels(2 * w + 1) := instWords(w)(31 downto 16) }
    val po = pc(LZ - 1 downto 1).asUInt                       // halfword offset (IFIDX+1 bits)

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

    // --- fetch_align (C-ext realign + decompress) ---
    val fa = new FetchAlign(cfg)
    fa.io.pc := faPc; fa.io.parcels := faParcels.asBits; fa.io.n_valid := faNValid.asBits
    val faInst = fa.io.inst.subdivideIn(IFW slices)
    val faInstPc = fa.io.inst_pc
    val faSeqNext = fa.io.seq_next.subdivideIn(IFW slices)
    val faInstValid = fa.io.inst_valid
    val faSpan = fa.io.span; val faSpanLo = fa.io.span_lo; val faSpanPc = fa.io.span_pc; val faNextPc = fa.io.next_pc

    // ---- raw control predecode (keeps the decompressor OFF the pc_next loop) ----
    // Classify is_ctrl/is_call/is_ret directly from the raw (compressed-or-32b)
    // encoding. Bit-exact with isCtrl(decompressed) and the RAS call/ret rules on
    // the expanded form, so prediction/redirect no longer depends on the (heavy)
    // decompressor -- it now only feeds the FIFO/decode payload.
    val faRaw   = fa.io.inst_raw.subdivideIn(IFW slices)
    val ctrlRaw = Vec(Bool(), IFW); val callRaw = Vec(Bool(), IFW); val retRaw = Vec(Bool(), IFW)
    for (i <- 0 until IFW) {
      val R = faRaw(i); val comp = fa.io.inst_comp(i)
      // 32-bit form
      val op32 = R(6 downto 0); val rd32 = R(11 downto 7); val rs1_32 = R(19 downto 15)
      val linkRd32 = (rd32 === 1) || (rd32 === 5); val linkRs1_32 = (rs1_32 === 1) || (rs1_32 === 5)
      val jal32 = op32 === B"7'b1101111"; val jalr32 = op32 === B"7'b1100111"; val br32 = op32 === B"7'b1100011"
      val ctrl32 = br32 || jal32 || jalr32
      val call32 = (jal32 || jalr32) && linkRd32
      val ret32  = jalr32 && linkRs1_32 && !linkRd32
      // compressed form (low 16b; the raw upper half is 0 on compressed slots)
      val q = R(1 downto 0); val f3 = R(15 downto 13); val i12 = R(12)
      val rs2h = R(6 downto 2); val rs1h = R(11 downto 7)
      val cJal  = (q === B"2'b01") && (f3 === B"3'b001")                                   // c.jal  -> jal x1
      val cJ    = (q === B"2'b01") && (f3 === B"3'b101")                                   // c.j    -> jal x0
      val cBeqz = (q === B"2'b01") && (f3 === B"3'b110")                                   // c.beqz
      val cBnez = (q === B"2'b01") && (f3 === B"3'b111")                                   // c.bnez
      val cJr   = (q === B"2'b10") && (f3 === B"3'b100") && !i12 && (rs2h === 0)           // c.jr   -> jalr x0,rs1
      val cJalr = (q === B"2'b10") && (f3 === B"3'b100") && i12 && (rs2h === 0) && (rs1h =/= 0) // c.jalr -> jalr x1,rs1
      val ctrlC = cJal || cJ || cBeqz || cBnez || cJr || cJalr
      val callC = cJal || cJalr
      val retC  = cJr && ((rs1h === 1) || (rs1h === 5))
      ctrlRaw(i) := Mux(comp, ctrlC, ctrl32)
      callRaw(i) := Mux(comp, callC, call32)
      retRaw(i)  := Mux(comp, retC, ret32)
    }

    // --- predictors ---
    val predictTakenGshare = Bits(IFW bits)
    val predictTargetUbtb = Bits(IFW * 32 bits); val predictTakenUbtb = Bits(IFW bits)
    val predictTaken = Bits(IFW bits); val predictTarget = Bits(IFW * 32 bits)
    val ghrSnapshot = Bits(GHR bits)
    val effPredictTaken = Bits(IFW bits)
    val fetchFire = io.to_fifo_valid && io.to_fifo_ready

    // prediction gating (non-control slots -> not-taken / fall-through)
    val ptVec = predictTaken.subdivideIn(IFW slices) // per-slot predict_taken from RAS
    val ptgtVec = predictTarget.subdivideIn(IFW slices)
    val effPt = Vec(Bool(), IFW); val effPtgt = Vec(Bits(32 bits), IFW); val isC = Vec(Bool(), IFW)
    for (i <- 0 until IFW) {
      isC(i) := ctrlRaw(i)
      effPt(i) := isC(i) && predictTaken(i)
      effPtgt(i) := Mux(isC(i), predictTarget(i * 32, 32 bits), faSeqNext(i))
    }
    effPredictTaken := effPt.asBits

    // first valid taken slot -> redirect index
    val ptEn = Bool(); ptEn := False
    val ptIdx = UInt(IFIDX bits); ptIdx := 0
    for (i <- IFW - 1 downto 0) { when(faInstValid(i) && effPt(i)) { ptEn := True; ptIdx := U(i, IFIDX bits) } }
    val spanCarry = faSpan && !ptEn

    val blkPc = pc(31 downto LZ) ## B(0, LZ bits)
    when(prevRst) { pcNext := B(0xaaaaa000L, 32 bits) }
      .elsewhen(io.backend_flush) { pcNext := io.backend_redirect_pc }
      .elsewhen(ptEn) { pcNext := effPtgt(ptIdx) }
      .elsewhen(spanCarry) { pcNext := (blkPc.asUInt + (IFW * 4)).asBits }
      .otherwise { pcNext := faNextPc }

    when(io.backend_flush) { carryValid := False }
      .elsewhen(fetchFire) { carryValid := spanCarry; carryLo := faSpanLo; carryPc := faSpanPc }

    // speculative branch predecode
    val pktValid = Vec(Bool(), IFW)
    for (i <- 0 until IFW) pktValid(i) := faInstValid(i) && !(ptEn && (U(i, IFIDX bits) > ptIdx))
    val specBrValid = Vec(Bool(), IFW)
    for (i <- 0 until IFW) specBrValid(i) := pktValid(i) && ctrlRaw(i)

    // TAGE
    val tage = new Tage(cfg)
    tage.io.clk := io.clk; tage.io.rst := io.rst
    tage.io.from_cb_update_en := io.from_cb_update_en; tage.io.from_cb_pc := io.from_cb_pc
    tage.io.from_cb_branch_taken := io.from_cb_branch_taken; tage.io.from_cb_ghr := io.from_cb_ghr
    tage.io.from_cb_prov := io.from_cb_prov
    io.to_fifo_prov_flat := tage.io.prov_snapshot_flat
    tage.io.inst_pc := faInstPc; tage.io.flush := io.backend_flush
    // sync-read SRAM: address presented one cycle early off the NEXT-cycle fetch PC,
    // captured on the fetch advance (if1 prv_ready). Next-cycle faPc is carryPc on a span
    // carry (C-ext 32b straddling the block) else pcNext -- so the early read keys off the
    // same block the prediction will (mirrors the original instPc(0)=faPc read).
    tage.io.re := if1.io.prv_ready
    tage.io.blk_pc_next := Mux(spanCarry && !io.backend_flush, faSpanPc, pcNext)
    tage.io.spec_update_en := fetchFire; tage.io.spec_br_valid := specBrValid.asBits
    tage.io.spec_br_taken := effPredictTaken
    ghrSnapshot := tage.io.ghr_snapshot; predictTakenGshare := tage.io.predict_taken

    // uBTB
    val ubtb = new Ubtb(cfg)
    ubtb.io.clk := io.clk; ubtb.io.rst := io.rst
    ubtb.io.from_cb_update_en := io.from_cb_update_en; ubtb.io.from_cb_pc := io.from_cb_pc
    ubtb.io.from_cb_fu_opcode := io.from_cb_fu_opcode; ubtb.io.from_cb_branch_taken := io.from_cb_branch_taken
    ubtb.io.from_cb_target_address := io.from_cb_target_address
    ubtb.io.predict_taken_gshare := predictTakenGshare; ubtb.io.inst_pc := faInstPc; ubtb.io.seq_next := fa.io.seq_next
    // sync-read SRAM: same early-address scheme as TAGE (address off the next-cycle fetch
    // block PC, captured on the fetch advance) so the registered target lands at T+1.
    ubtb.io.re := if1.io.prv_ready
    ubtb.io.blk_pc_next := Mux(spanCarry && !io.backend_flush, faSpanPc, pcNext)
    predictTargetUbtb := ubtb.io.predict_target; predictTakenUbtb := ubtb.io.predict_taken

    // RAS
    val ras = new Ras(cfg)
    ras.io.clk := io.clk; ras.io.rst := io.rst; ras.io.flush := io.backend_flush; ras.io.fetch_fire := fetchFire
    ras.io.inst_pc := faInstPc; ras.io.seq_next := fa.io.seq_next; ras.io.inst_valid := faInstValid
    ras.io.is_call := callRaw.asBits; ras.io.is_ret := retRaw.asBits
    ras.io.predict_taken_in := predictTakenUbtb; ras.io.predict_target_in := predictTargetUbtb
    ras.io.from_cb_update_en := io.from_cb_update_en; ras.io.from_cb_pc := io.from_cb_pc
    ras.io.from_cb_is_call := io.from_cb_is_call; ras.io.from_cb_is_ret := io.from_cb_is_ret
    ras.io.from_cb_is_compressed := io.from_cb_is_compressed
    predictTaken := ras.io.predict_taken_out; predictTarget := ras.io.predict_target_out

    // --- to_fifo packet assembly ---
    io.to_fifo_valid := if1Valid
    io.to_fifo_inst_flat := fa.io.inst
    io.to_fifo_inst_raw_flat := fa.io.inst_raw
    io.to_fifo_is_compressed := fa.io.inst_comp
    io.to_fifo_pc_flat := faInstPc
    io.to_fifo_predict_taken := effPredictTaken
    io.to_fifo_predict_target_flat := effPtgt.asBits
    io.to_fifo_valid_slots := pktValid.asBits
    io.to_fifo_ghr := ghrSnapshot
  }
}
