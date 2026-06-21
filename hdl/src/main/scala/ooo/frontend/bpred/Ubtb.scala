package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** Single-port-array model for a block-read uBTB bank (1R1W): ROWS/2 rows x DW bits.
  * Synchronous read (address sampled at T, registered row at T+1 -- fakeram45 timing);
  * the reader presents the address one cycle early off blk_pc_next so the predicted
  * target stays aligned with the fetched block (RAS consumes it combinationally that
  * cycle). re gates the capture (holds on stall). Synchronous bit-masked write on an
  * independent commit port. Sim model sram/output/ubtb_bank_array; P&R maps it via
  * macro_wrappers.v -> fakeram45_16x256. */
class UbtbBankRam(addrW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("ubtb_bank_array")
  val io = new Bundle {
    val clk   = in  Bool()
    val re    = in  Bool();        val raddr = in  Bits(addrW bits); val rdata = out Bits(dw bits)
    val we    = in  Bool();        val waddr = in  Bits(addrW bits)
    val wdata = in  Bits(dw bits); val wmask = in  Bits(dw bits)
  }
  noIoPrefix()
}

/** SpinalHDL port of the micro-BTB -- now BLOCK-READ + SRAM-backed (area lever).
  *
  * Replaces the set-associative flop arrays (which did 4 slots x 2 banks = 8 independent
  * per-slot reads/cycle -- the single-port-SRAM blocker) with a TAGE-style block-read:
  * each bank is indexed ONCE per fetch block by the block-aligned PC, the row holds
  * LANES = 2*IFW per-slot lanes, and a slot picks its in-block halfword lane. The two
  * banks (br for conditional branches gated by gshare, jm for jumps) each split into
  * even/odd physical SRAM banks (bank = blkRow[0]) so the 2-block straddle reads land in
  * opposite banks (2 parallel reads). Targets are stored OFFSET-COMPRESSED (target -
  * branch_pc, OFFW-bit signed) so a row fits a narrow SRAM macro; far targets (offset out
  * of range) are not inserted -> predicted not-taken (mispredict caught by the back-end).
  * Each lane keeps a TAG (high block-PC bits) so multi-branch blocks and aliasing blocks
  * stay disambiguated. Direct-mapped per (row, lane) -- trades the old 4-way associativity
  * for the SRAM density win. Trained at commit (masked single-lane write).
  *
  * Named ubtb_spinal.
  */
class Ubtb(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ubtb_spinal")
  val IFW   = cfg.ifWidth      // 4
  val LZ    = log2Up(IFW * 4)  // 4   (in-block byte-addr width)
  val LANES = 2 * IFW          // 8   (in-block halfword lanes)
  val ROWS  = 32               // logical rows (even/odd -> ROWS/2 per physical bank)
  val RIDXW = log2Up(ROWS)     // 5
  val ADDRW = RIDXW - 1        // 4   (rows per physical bank = 16)
  val TTAG  = 13               // stored tag (block-PC bits above the row index)
  val OFFW  = 18               // signed target offset (+/-128KB), target = branch_pc + offset
  val EW    = 1 + TTAG + OFFW  // 32  per-lane entry {valid, tag, offset}
  val DW    = LANES * EW       // 256 row width -> fakeram45_16x256

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // cb_bp_itf.bp from_cb (fields ubtb trains on)
    val from_cb_update_en      = in Bool()
    val from_cb_pc             = in Bits (32 bits)
    val from_cb_fu_opcode      = in Bits (4 bits)
    val from_cb_branch_taken   = in Bool()
    val from_cb_target_address = in Bits (32 bits)
    val predict_taken_gshare = in Bits (IFW bits)
    val inst_pc        = in Bits (IFW * 32 bits)
    val seq_next       = in Bits (IFW * 32 bits)
    val re             = in Bool()           // fetch-advance enable (= if1 prv_ready); gates the sync SRAM read
    val blk_pc_next    = in Bits (32 bits)   // next-fetch block PC (= pcNext); the early read address
    val predict_target = out Bits (IFW * 32 bits)
    val predict_taken  = out Bits (IFW bits)
  }
  noIoPrefix()

  // block-aligned indexing (pure PC, no history fold). lane = in-block halfword.
  def blkRow(pc: Bits): Bits = pc(RIDXW + LZ - 1 downto LZ)          // RIDXW bits
  def laneOf(pc: Bits): UInt = pc(LZ - 1 downto 1).asUInt            // 1 of LANES
  def tagOf(pc: Bits): Bits  = pc(RIDXW + LZ + TTAG - 1 downto RIDXW + LZ)
  def blkOf(pc: Bits): Bits  = pc(31 downto LZ)                      // 16B block id (straddle test)

  def laneEntry(row: Bits, lane: UInt): (Bool, Bits, Bits) = {       // (valid, tag, offset)
    val sel = row.subdivideIn(LANES slices)(lane)                    // EW bits
    (sel(EW - 1), sel(EW - 2 downto OFFW), sel(OFFW - 1 downto 0))
  }

  val instPc  = io.inst_pc.subdivideIn(IFW slices)
  val seqNext = io.seq_next.subdivideIn(IFW slices)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // ---- one set of even/odd SRAM banks per class (br, jm) ----
    val brBank = Array.fill(2)(new UbtbBankRam(ADDRW, DW))
    val jmBank = Array.fill(2)(new UbtbBankRam(ADDRW, DW))
    for (b <- 0 until 2) {
      brBank(b).io.clk := io.clk; brBank(b).io.re := io.re
      jmBank(b).io.clk := io.clk; jmBank(b).io.re := io.re
    }

    // ---- read address (presented one cycle early off blk_pc_next) ----
    // fetch block row (A) + next 16B block row (B); A and B always land in opposite banks
    // since consecutive blocks differ in blkRow LSB. No history fold -> br/jm share the
    // address; the routing bit is registered (re-gated) to un-route the T+1 row.
    val blkBpcE = (io.blk_pc_next.asUInt + U(1 << LZ, 32 bits)).asBits
    val rowIdxA = blkRow(io.blk_pc_next); val rowIdxB = blkRow(blkBpcE)
    val bankA   = rowIdxA(0)
    val addrA   = rowIdxA(RIDXW - 1 downto 1); val addrB = rowIdxB(RIDXW - 1 downto 1)
    for (bk <- Seq(brBank, jmBank)) {
      bk(0).io.raddr := Mux(bankA === False, addrA, addrB)
      bk(1).io.raddr := Mux(bankA === False, addrB, addrA)
    }
    val bankAReg = RegNextWhen(bankA, io.re)
    def rowAof(bk: Array[UbtbBankRam]) = Mux(bankAReg === False, bk(0).io.rdata, bk(1).io.rdata)
    def rowBof(bk: Array[UbtbBankRam]) = Mux(bankAReg === False, bk(1).io.rdata, bk(0).io.rdata)
    val brRowA = rowAof(brBank); val brRowB = rowBof(brBank)
    val jmRowA = rowAof(jmBank); val jmRowB = rowBof(jmBank)

    // ---- prediction (T+1, on the registered rows): per slot pick its block's row, its
    //      in-block halfword lane, tag-check, reconstruct target = inst_pc + offset. ----
    val ptaken  = Vec(Bool(), IFW)
    val ptarget = Vec(Bits(32 bits), IFW)
    for (w <- 0 until IFW) {
      val pc   = instPc(w)
      val lane = laneOf(pc); val sTag = tagOf(pc)
      val inB  = blkOf(pc) =/= blkOf(instPc(0))        // slot in the next block?
      val (jV, jT, jOff) = laneEntry(Mux(inB, jmRowB, jmRowA), lane)
      val (bV, bT, bOff) = laneEntry(Mux(inB, brRowB, brRowA), lane)
      val jTgt = (pc.asUInt + jOff.asSInt.resize(32 bits).asUInt).asBits
      val bTgt = (pc.asUInt + bOff.asSInt.resize(32 bits).asUInt).asBits
      val jHit  = jV && (jT === sTag)
      val brHit = io.predict_taken_gshare(w) && bV && (bT === sTag)
      ptaken(w)  := False
      ptarget(w) := seqNext(w)
      when(jHit)  { ptarget(w) := jTgt; ptaken(w) := True }
      when(brHit) { ptarget(w) := bTgt; ptaken(w) := True }
    }
    io.predict_taken  := ptaken.asBits
    io.predict_target := ptarget.asBits

    // ---- training (commit): masked single-lane write of {valid, tag, offset}. ----
    val uRow  = blkRow(io.from_cb_pc); val uLane = laneOf(io.from_cb_pc); val uTag = tagOf(io.from_cb_pc)
    val uDiff = io.from_cb_target_address.asSInt - io.from_cb_pc.asSInt        // signed 32b
    val uOff  = uDiff(OFFW - 1 downto 0)                                       // SInt(OFFW)
    val uInRange = (uOff.resize(32 bits) === uDiff)                            // offset fits OFFW signed
    val isJump = io.from_cb_fu_opcode(3)
    val uBankW = uRow(0); val uAddrW = uRow(RIDXW - 1 downto 1)
    val laneData = B(True) ## uTag ## uOff.asBits                              // {valid, tag, offset} = EW bits
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
