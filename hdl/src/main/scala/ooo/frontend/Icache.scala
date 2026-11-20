package ooo.frontend

import spinal.core._
import ooo.CpuConfig
import ooo.memory.{LruArray, PlruUpdate}

/** One fetch block per bank: reads enable one bank; refill enables both. */
class IcacheDataBank(setW: Int) extends BlackBox {
  setBlackBoxName("icache_data_bank"); addGeneric("ADDR_WIDTH", setW)
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val wmask0 = in Bits(16 bits); val addr0 = in Bits(setW bits)
    val din0 = in Bits(128 bits); val dout0 = out Bits(128 bits)
  }
  noIoPrefix()
}
/** Predecode block bank (32b = one block's row half); mirrors IcacheDataBank. */
class IcachePdBank(setW: Int, dw: Int) extends BlackBox {
  setBlackBoxName("icache_pd_bank"); addGeneric("ADDR_WIDTH", setW); addGeneric("DATA_WIDTH", dw)
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(dw bits); val dout0 = out Bits(dw bits)
  }
  noIoPrefix()
}
class IcacheTagArray(setW: Int) extends BlackBox {
  setBlackBoxName("icache_tag_array"); addGeneric("ADDR_WIDTH", setW)
  val io = new Bundle {     // Fixed 24-bit macro interface
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(24 bits); val dout0 = out Bits(24 bits)
  }
  noIoPrefix()
}
/** Instruction-cache datapath with banked data and fill-time predecode. */
class Icache(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("icache_spinal")
  val IFW  = cfg.ifWidth
  val WAYS = cfg.iNumWays
  val FETCHWAYS = cfg.iFetchWays
  val WAYB = log2Up(WAYS)
  val SETW = cfg.iSetIdx
  val OFFW = cfg.iOffsetIdx
  val TAG  = cfg.iTagIdx
  val TAW  = TAG + 1
  val PLRU = WAYS - 1
  val LZ_OFF = log2Up(IFW * 4) // block byte-offset bits (4); ufp_addr is block-aligned

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val invalidate = if (cfg.zicsr) in Bool() else null
    val ufp_addr  = in  Bits (32 bits)
    val set_candidates = if (cfg.frontendValidSpeculation) in Bits(cfg.predCandN * cfg.iSetIdx bits) else null
    val set_select = if (cfg.frontendValidSpeculation) in Bits(cfg.predCandN bits) else null
    val initialized_bitmap = if (cfg.frontendLaneValidity) out Bits((1 << cfg.iSetIdx) bits) else null
    val request_initialized = if (cfg.frontendLaneValidity) in Bool() else null
    val ufp_read  = in  Bool()
    // Early SRAM enable is a superset of ufp_read; stalled miss results are ignored.
    val ufp_read_early = in Bool()
    val ufp_rdata = out Bits (IFW * 32 bits)
    val ufp_data_ways = if (cfg.frontendPayloadSpeculation) out Bits(FETCHWAYS * IFW * 32 bits) else null
    val ufp_data_select = if (cfg.frontendPayloadSpeculation) out Bits(FETCHWAYS bits) else null
    // Export per-way predecode with local one-hot selects to avoid serial hit/hold muxes.
    val ufp_pd_ways = out Bits (FETCHWAYS * 2 * IFW * 4 bits)  // per-way block-selected rows
    val ufp_pd_sel  = out Bits (FETCHWAYS bits)                // one-hot with ufp_resp==OR(sel)
    // Per-way compressed-instruction bits; zero without C. Selected with the same one-hot.
    val ufp_comp_ways = out Bits (FETCHWAYS * 2 * IFW bits)
    // Per-lane {ret,call,ctrl}, decoded alongside tag comparison.
    // Spanning parcel zero uses the held instruction path under carryValid.
    val ufp_flag_ways = out Bits (FETCHWAYS * 2 * IFW * 3 bits)
    val ufp_resp  = out Bool()
    val kill      = in  Bool()
    val dfp_addr   = out Bits (32 bits)
    val dfp_read   = out Bool()
    val dfp_write  = out Bool()
    val dfp_wdata  = out Bits (256 bits)
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rdata  = in  Bits (256 bits)
    val dfp_rvalid = in  Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val ufpOffset = io.ufp_addr(OFFW - 1 downto 0)
    val ufpSet    = io.ufp_addr(SETW + OFFW - 1 downto OFFW)
    val ufpTag    = io.ufp_addr(TAG + SETW + OFFW - 1 downto SETW + OFFW)

    val srRead   = RegInit(False)
    val srOffset = Reg(UInt(OFFW bits)); val srSet = Reg(UInt(SETW bits)); val srTagStorage = Reg(Bits(TAG bits))
    val srTag = if (cfg.frontendInvertedTag) ~srTagStorage else srTagStorage

    val hit = Bool(); val hitWay = UInt(WAYB bits); val replaceWay = UInt(WAYB bits)
    val stall = Bool(); val allocateDone = Bool(); val plruDin1 = Bits(PLRU bits)
    val wayMatch = Vec(Bool(), WAYS)   // assigned with the pd exports below
    val validity = new ooo.common.LazyCacheValidity(SETW,ufpSet.asUInt,srSet,
      !io.rst && (!stall || io.kill),allocateDone,if (cfg.zicsr) io.invalidate else False,
      if (cfg.frontendValidSpeculation) Some((io.set_candidates,io.set_select)) else None,
      if (cfg.frontendLaneValidity) Some(io.request_initialized) else None,
      requestIncludesPublication=cfg.frontendPublishedValidity)
    if (cfg.frontendLaneValidity) io.initialized_bitmap:=validity.lookupBitmap

    val sramSet = if (cfg.frontendCacheAddressOneHot) {
      val advance = !stall || io.kill
      val selected = io.set_select & B(cfg.predCandN bits, default -> advance)
      ooo.OhSel(selected,io.set_candidates.subdivideIn(cfg.predCandN slices)) |
        (srSet.asBits & B(SETW bits, default -> !advance))
    } else Mux(!stall || io.kill, ufpSet.asBits, srSet.asBits)
    // Bank data and predecode by fetch block; ordinary reads enable only the addressed bank.
    val dataCsb = Vec(Vec(Bool(), 2), WAYS); val tagCsb = Vec(Bool(), WAYS)
    val dataWeb = Vec(Bool(), WAYS); val tagWeb = Vec(Bool(), WAYS)
    val dataWmask = Bits(32 bits); val dataDin = Bits(256 bits)
    val dataDout = Vec(Vec(Bits(128 bits), 2), WAYS); val tagDout = Vec(Bits(TAW bits), WAYS); val validDout = Vec(Bool(), WAYS)
    val ufpBlk = ufpOffset(OFFW - 1 downto LZ_OFF)   // live request's block-in-line bit

    // refill stamps {valid=1, tag}; macro is 24b wide (upper 2 unused)
    val tagDin = (B(0, 24 - TAW bits) ## True.asBits ## srTag)

    // Store compressed-instruction and control-flow predecode alongside each cache refill.
    val PDLANES = 2 * IFW               // 8 halfword lanes / 16B block
    val PDBLKS  = 1 << (OFFW - LZ_OFF)  // 2 blocks / line
    val PDW     = PDBLKS * PDLANES * 4  // 64b / line
    require(PDBLKS == 2, "block banking assumes 2 blocks/line")
    val fillParcels = io.dfp_rdata.subdivideIn(PDBLKS * PDLANES slices)
    val pdDin = Cat((0 until PDBLKS).map(b => IcachePredecode.encode(fillParcels.slice(b * PDLANES, (b + 1) * PDLANES),cfg.cExt,cfg.frontendLengthPredecode)))   // block 0 at LSB
    val pdDout = Vec(Vec(Bits(PDW / PDBLKS bits), PDBLKS), WAYS)

    for (i <- 0 until WAYS) {
      for (b <- 0 until PDBLKS) {
        val da = new IcacheDataBank(SETW)
        da.io.clk0 := io.clk; da.io.csb0 := dataCsb(i)(b); da.io.web0 := dataWeb(i)
        da.io.wmask0 := dataWmask(b * 16, 16 bits); da.io.addr0 := sramSet
        da.io.din0 := dataDin(b * 128, 128 bits)
        dataDout(i)(b) := da.io.dout0
        // side predecode bank: lockstep with its data bank (same csb/addr;
        // web asserts only at allocate on the replace way) -> always consistent.
        val pa = new IcachePdBank(SETW, PDW / PDBLKS)
        pa.io.clk0 := io.clk; pa.io.csb0 := dataCsb(i)(b); pa.io.web0 := dataWeb(i)
        pa.io.addr0 := sramSet; pa.io.din0 := pdDin(b * (PDW / PDBLKS), PDW / PDBLKS bits)
        pdDout(i)(b) := pa.io.dout0
      }
      val ta = new IcacheTagArray(SETW)
      ta.io.clk0 := io.clk; ta.io.csb0 := tagCsb(i); ta.io.web0 := tagWeb(i)
      ta.io.addr0 := sramSet
      ta.io.din0 := Mux(validity.initializeOnAllocate && replaceWay =/= i, B(0,24 bits), tagDin)
      tagDout(i) := ta.io.dout0(TAW - 1 downto 0)
      validDout(i) := validity.rowInitialized && tagDout(i)(TAG)
    }

    val plruCsb0 = stall
    val plruCsb1 = !io.ufp_resp
    val plruWeb1 = plruCsb1
    val lru = new LruArray(SETW, PLRU)
    lru.io.clk0 := io.clk; lru.io.rst0 := io.rst
    lru.io.csb0 := plruCsb0; lru.io.addr0 := ufpSet.asBits
    lru.io.csb1 := plruCsb1; lru.io.web1 := plruWeb1; lru.io.addr1 := srSet.asBits; lru.io.din1 := plruDin1

    // miss FSM (reused twin)
    val ctrl = new IcacheCtrl(cfg)
    ctrl.io.clk := io.clk; ctrl.io.rst := io.rst
    ctrl.io.kill := io.kill; ctrl.io.read := srRead
    ctrl.io.tag := srTag; ctrl.io.set := srSet.asBits
    ctrl.io.tag_arr_flat := Cat((0 until WAYS).map(i => tagDout(i)))   // way0 at LSB
    ctrl.io.valid_arr_flat := validDout.asBits
    // Derive the predecode read/hold decision locally from way matches to avoid serial control feedback.
    stall := srRead && !wayMatch.asBits.orR
    for (b <- 0 until WAYB) {
      hitWay(b) := (0 until WAYS).filter(w => ((w >> b) & 1) == 1).map(wayMatch(_)).reduce(_ || _)
    }
    allocateDone := ctrl.io.allocate_done
    hit := False
    io.dfp_addr := ctrl.io.dfp_addr; io.dfp_read := ctrl.io.dfp_read; io.dfp_write := ctrl.io.dfp_write
    ctrl.io.dfp_ready := io.dfp_ready; ctrl.io.dfp_raddr := io.dfp_raddr; ctrl.io.dfp_rvalid := io.dfp_rvalid

    val pu = new PlruUpdate(WAYS, PLRU, WAYB)
    pu.io.current_plru := lru.io.dout0; plruDin1 := pu.io.next_plru
    pu.io.hit_way := hitWay.asBits; replaceWay := pu.io.replace_way.asUInt

    // FETCH-stage register
    when(io.rst) { srRead := False }
      .elsewhen(!stall || io.kill) { srRead := io.ufp_read; srOffset := ufpOffset.asUInt; srSet := ufpSet.asUInt; srTagStorage := (if (cfg.frontendInvertedTag) ~ufpTag else ufpTag) }

    // Enable only the addressed data/predecode bank on reads; refill writes update both banks.
    for (i <- 0 until WAYS; b <- 0 until PDBLKS) dataCsb(i)(b) := True
    for (i <- 0 until WAYS) { tagCsb(i) := True; dataWeb(i) := True; tagWeb(i) := True }
    when((!stall || io.kill) && io.ufp_read_early) {
      for (i <- 0 until WAYS) { dataCsb(i)(ufpBlk.asUInt) := False; tagCsb(i) := False }
    }
    when(allocateDone) {
      for (b <- 0 until PDBLKS) dataCsb(replaceWay)(b) := False
      tagCsb(replaceWay) := False
      dataWeb(replaceWay) := False; tagWeb(replaceWay) := False
      when(validity.initializeOnAllocate) {
        for(i <- 0 until WAYS) { tagCsb(i) := False; tagWeb(i) := False }
      }
    }

    // SRAM din
    dataWmask := B(0, 32 bits); dataDin := B(0, 256 bits)
    when(allocateDone) { dataWmask := B(32 bits, default -> True); dataDin := io.dfp_rdata }

    // PROCESS stage / ufp
    io.dfp_wdata := B(0, 256 bits)
    // ufp_addr is always IF_BLK_SIZE-aligned (If1Stage.blkPcNext zeros bits [LZ-1:0]),
    // so srOffset is always a multiple of IFW*4 -> the read is just a block-within-line
    // select, NOT a byte-granular barrel shift. Picking the IFW*32-bit block by
    // srOffset(OFFW-1 downto LZ) collapses four 256:1 byte-muxes (+ a *8 multiply) to a
    // (line/block)-way block mux. Bit-identical given the alignment precondition.
    val rd = Vec(Bits(32 bits), IFW)
    // Block-select each way FIRST (by the early, registered srOffset), THEN 4:1 way-mux
    // (by the LATE hitWay off the tag compare). Bit-identical to muxing the way then the
    // block, but the critical late hitWay now drives a 128b (IFW*32) mux instead of the
    // full 256b line -> halves the one-hot way-select fanout that repair_design buffers on
    // the icache -> fetchAlign critical path. The per-way block-selects ride the early
    // srOffset, off the hit path.
    val blkSel = srOffset(OFFW - 1 downto LZ_OFF)
    def payloadBlock(data: Bits, metadata: Bits): Bits = {
      if (!cfg.frontendLengthPredecode) data
      else Vec((0 until PDLANES).map(p =>
        data(p * 16 + 2,14 bits) ## metadata(p * 4,2 bits))).asBits
    }
    val wayBlk = Vec(Bits(IFW * 32 bits), WAYS)
    for (w <- 0 until WAYS) { wayBlk(w) := payloadBlock(dataDout(w)(blkSel),pdDout(w)(blkSel)) }
    if (cfg.frontendPayloadSpeculation) {
      val blocks = for (w <- 0 until WAYS; b <- 0 until cfg.iFetchBanks)
        yield if (cfg.frontendBankSpeculation) payloadBlock(dataDout(w)(b),pdDout(w)(b)) else wayBlk(w)
      io.ufp_data_ways := Vec(blocks).asBits
      for (w <- 0 until WAYS; b <- 0 until cfg.iFetchBanks)
        io.ufp_data_select(w * cfg.iFetchBanks + b) := (hitWay === w) &&
          (if (cfg.frontendBankSpeculation) blkSel === b else True)
    }
    val rdBlk = wayBlk(hitWay)
    for (i <- 0 until IFW) { rd(i) := rdBlk(32 * i, 32 bits) }
    io.ufp_rdata := rd.asBits
    // per-way block-BANK select (early srOffset) for the predecode row; the
    // way pick moves to If1Stage's fused OhSel (see the port note). The per-way
    // tag matches drive the selects directly -- no hit-OR, no encoded-hitWay decode.
    val pdWayBlk = Vec(Bits(PDLANES * 4 bits), FETCHWAYS)
    val compWays = Vec(Bits(PDLANES bits), FETCHWAYS)
    for (w <- 0 until WAYS)
      wayMatch(w) := (tagDout(w)(TAG - 1 downto 0) === srTag) && validDout(w)
    for (w <- 0 until WAYS; b <- 0 until cfg.iFetchBanks) {
      val arm = w * cfg.iFetchBanks + b
      val encoded = if (cfg.frontendBankSpeculation) pdDout(w)(b) else pdDout(w)(blkSel)
      val decoded=if (cfg.frontendLengthPredecode) IcachePredecode.decode(encoded,cfg.cExt)
        else (encoded,B(0,PDLANES bits))
      pdWayBlk(arm) := decoded._1
      val block = if (cfg.frontendBankSpeculation) dataDout(w)(b) else dataDout(w)(blkSel)
      val par = block.subdivideIn(PDLANES slices)
      val comps = (0 until PDLANES).map(p =>
        if (cfg.cExt) par(p)(1 downto 0) =/= B"2'b11" else False)
      compWays(arm) := (if (cfg.frontendLengthPredecode) decoded._2 else Cat(comps))   // lane 0 at LSB
      if (cfg.frontendLengthPredecode && cfg.rvfi) when(srRead && !stall && wayMatch(w) && (if (cfg.frontendBankSpeculation) blkSel === b else True)) {
        assert(decoded._2 === Cat(comps))
        assert(decoded._1 === IcachePredecode.encode(par.toSeq,cfg.cExt,packed=false))
      }
      // per-lane raw control flags (lane p's 32b form reads parcels {p+1, p};
      // a lane-7 32b op is never a complete slot -> upper half don't-care)
      for (p <- 0 until PDLANES) {
        val hiP = if (p + 1 < PDLANES) par(p + 1) else B(0, 16 bits)
        val quadrant = encoded(p * 4,2 bits)
        val flagRaw = if (cfg.frontendLengthPredecode)
          hiP ## par(p)(15 downto 2) ## quadrant else hiP ## par(p)
        if (cfg.frontendLengthPredecode && cfg.rvfi) when(srRead && !stall && wayMatch(w) &&
          (if (cfg.frontendBankSpeculation) blkSel === b else True)) {
          assert(quadrant === par(p)(1 downto 0))
        }
        val (fc, fca, fr) = DispatchPredecode.controlFlags(flagRaw,compWays(arm)(p))
        io.ufp_flag_ways(arm * PDLANES * 3 + p * 3, 3 bits) := fr ## fca ## fc
      }
    }
    io.ufp_comp_ways := compWays.asBits
    io.ufp_pd_ways := pdWayBlk.asBits
    io.ufp_pd_sel  := Vec(for (w <- 0 until WAYS; b <- 0 until cfg.iFetchBanks) yield
      srRead && wayMatch(w) && (if (cfg.frontendBankSpeculation) blkSel === b else True)).asBits   // way0 at LSB
    io.ufp_resp  := srRead && !stall
  }
}
