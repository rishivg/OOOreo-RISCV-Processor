package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Word-banked data SRAM: accesses enable one bank; refill enables every bank.
  * Dirty writeback reads the full victim line before asserting dfp_write.
  */
class DcacheDataBank(setW: Int) extends BlackBox {
  setBlackBoxName("dcache_data_bank")
  addGeneric("ADDR_WIDTH", setW)
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val wmask0 = in Bits(4 bits); val addr0 = in Bits(setW bits)
    val din0 = in Bits(32 bits); val dout0 = out Bits(32 bits)
  }
  noIoPrefix()
}
class DcacheTagArray(setW: Int, tagW: Int) extends BlackBox {
  setBlackBoxName("dcache_tag_array")
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(tagW bits); val dout0 = out Bits(tagW bits)
  }
  noIoPrefix()
}
/** Data-cache datapath with word banks, epoch validity, and dirty writeback. */
class Dcache(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("dcache_spinal")
  val WAYS = cfg.dNumWays
  val WAYB = log2Up(WAYS)
  val SETW = cfg.dSetIdx
  val OFFW = cfg.dOffsetIdx
  val TAG  = cfg.dTagIdx
  val TAW  = TAG + 2 // Valid epoch and dirty bit accompany each tag.
  val PLRU = WAYS - 1
  val io = new Bundle {
    val idle = if (cfg.zicsr || cfg.mmio || cfg.lowPower) out Bool() else null
    val flush_request = if (cfg.zicsr) in Bool() else null
    val flush_done = if (cfg.zicsr) out Bool() else null
    val clk = in Bool(); val rst = in Bool()
    val ufp_addr  = in  Bits (32 bits)
    // AGU hi16 split: addr(31:16) as conditional sums + the carry into bit 16
    // (Mux(c16, hi1, hi0) == ufp_addr(31:16)). The tag capture registers THESE
    // (ready a block-carry-merge earlier than the merged addr on the load fast
    // path) and composes the tag in the response cycle, where it beats the tag
    // SRAM q. ufp_addr(31:16) itself is NOT consumed here.
    val ufp_hi0   = in  Bits (16 bits)
    val ufp_hi1   = in  Bits (16 bits)
    val ufp_c16   = in  Bool()
    val ufp_rmask = in  Bits (4 bits)
    val ufp_wmask = in  Bits (4 bits)
    // early request-fire from the arbiter, == (|rmask || |wmask) but computed
    // from valid&&registered-ready (skips the mask muxes/orR the csb cone
    // otherwise waits on). Consumed ONLY by chip-enable/plru-enable arms: even
    // a superset here is bit-identical at the consumers (a spurious enable =
    // an extra non-destructive read whose dout is never consumed) -- the same
    // argument as the I$ ufp_read_early fix.
    val ufp_req_early = in Bool()
    // Decode the selected request’s word index per arbiter arm before combining bank enables.
    val ufp_word_oh = in Bits ((1 << (cfg.dOffsetIdx - 2)) bits)
    val ufp_way_rdata_flat = if (cfg.lsuWaySpeculation) out Bits(cfg.lsuCacheCandidates * 32 bits) else null
    val ufp_selected_way = if (cfg.lsuWaySpeculation) out Bits(cfg.lsuCacheCandidates bits) else null
    val ufp_rdata = out Bits (32 bits)
    val ufp_wdata = in  Bits (32 bits)
    val ufp_resp  = out Bool()
    val dfp_addr   = out Bits (32 bits)
    val dfp_read   = out Bool()
    val dfp_write  = out Bool()
    val dfp_wdata  = out Bits (256 bits)
    val dfp_write_beat = if (cfg.bmemBeatSpeculation) in Bits(2 bits) else null
    val dfp_wdata_beat = if (cfg.bmemBeatSpeculation) out Bits(64 bits) else null
    val dfp_read_addr = if (cfg.bmemEarlyAddress) out Bits(32 bits) else null
    val dfp_write_addr = if (cfg.bmemEarlyAddress) out Bits(32 bits) else null
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rdata  = in  Bits (256 bits)
    val dfp_rvalid = in  Bool()
    val dbg_stall = out Bool()
    val dbg_hit   = out Bool()
    val dbg_rmask = out Bits (4 bits)
    val dbg_wmask = out Bits (4 bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val TAGLO = 16 - SETW - OFFW   // tag bits below the hi16 boundary (addr 15:SETW+OFFW)
    require(TAGLO > 0 && TAG == 16 + TAGLO, s"hi16 split needs SETW+OFFW < 16 and TAG = ${16 + TAGLO}")
    val ufpOffset = io.ufp_addr(OFFW - 1 downto 0)
    val ufpSet    = io.ufp_addr(SETW + OFFW - 1 downto OFFW)
    val ufpTagLo  = io.ufp_addr(15 downto SETW + OFFW)

    // FETCH-stage register (dcache_stage_reg_t)
    val srRmask  = RegInit(B(0, 4 bits)); val srWmask = RegInit(B(0, 4 bits))
    val srWdata  = Reg(Bits(32 bits)); val srOffset = Reg(UInt(OFFW bits))
    val srSet    = Reg(UInt(SETW bits))
    // Capture split tag sums; consumers select the high half in the response cycle.
    val srHi0 = if (!cfg.dcacheMergedTag) Reg(Bits(16 bits)) else null
    val srHi1 = if (!cfg.dcacheMergedTag) Reg(Bits(16 bits)) else null
    val srC16 = if (!cfg.dcacheMergedTag) Reg(Bool()) else null
    val srTagLo = if (!cfg.dcacheMergedTag) Reg(Bits(TAGLO bits)) else null
    val srMergedTag = if (cfg.dcacheMergedTag) Reg(Bits(TAG bits)).setName("srMergedTag") else null
    val srTag = if (cfg.dcacheMergedTag) srMergedTag else Mux(srC16, srHi1, srHi0) ## srTagLo

    // datapath signals (declared up front; driven below)
    val hit = Bool(); val hitWay = UInt(WAYB bits); val replaceWay = UInt(WAYB bits)
    val stall = Bool(); val allocateDone = Bool(); val writeHitRec = Bool(); val writeHit = Bool()
    val plruDin1 = Bits(PLRU bits)

    val maintenance = if (cfg.zicsr) new CacheFlushController(SETW,WAYB) else null
    val maintenanceBusy = if (cfg.zicsr) maintenance.io.busy else False
    val sramSet = Mux(writeHit || stall, srSet.asBits, ufpSet)
    if (cfg.zicsr) when(maintenanceBusy) { sramSet := maintenance.io.set.asBits }

    // A resettable bit per set masks arbitrary/stale SRAM tag contents.
    // The first refill initializes every tag-valid bit in that row without
    // delaying the normal refill response or adding per-line valid flops.
    val validity = new ooo.common.LazyCacheValidity(SETW,ufpSet.asUInt,srSet,
      !stall,allocateDone)

    val NW = 1 << (OFFW - 2)   // words per line (8): data is WORD-BANKED, see DcacheDataBank
    val dataCsb = Vec(Vec(Bool(), NW), WAYS); val tagCsb = Vec(Bool(), WAYS)
    val dataWeb = Vec(Bool(), WAYS); val tagWeb = Vec(Bool(), WAYS)
    val dataWmask = Bits(32 bits); val dataDin = Bits(256 bits); val tagDin = Bits(TAW bits)
    val dataDout = Vec(Vec(Bits(32 bits), NW), WAYS); val tagDout = Vec(Bits(TAW bits), WAYS); val validDout = Vec(Bool(), WAYS)
    val srWordOh = Reg(Bits(NW bits)).setName("srWordOh")
    val srWord  = srOffset(OFFW - 1 downto 2)      // captured request's word-in-line

    for (i <- 0 until WAYS) {
      for (b <- 0 until NW) {
        val da = new DcacheDataBank(SETW)
        da.io.clk0 := io.clk; da.io.csb0 := dataCsb(i)(b); da.io.web0 := dataWeb(i)
        da.io.wmask0 := dataWmask(b * 4, 4 bits); da.io.addr0 := sramSet
        da.io.din0 := dataDin(b * 32, 32 bits)
        dataDout(i)(b) := da.io.dout0
      }
      val ta = new DcacheTagArray(SETW, TAW)
      ta.io.clk0 := io.clk; ta.io.csb0 := tagCsb(i); ta.io.web0 := tagWeb(i)
      ta.io.addr0 := sramSet
      ta.io.din0 := Mux(validity.initializeOnAllocate && replaceWay =/= i, B(0,TAW bits), tagDin)
      tagDout(i) := ta.io.dout0
      validDout(i) := validity.rowInitialized && tagDout(i)(TAW - 1)     // epoch MSB == global -> valid
    }

    // LRU array (read port0 on ufp_set, write port1 on srSet). Read only on live
    // requests (same argument as the tag/data csb): the update write is resp-gated
    // and replaceWay during a miss uses the dout HELD from that miss's own request
    // cycle, which has ufpReq set.
    val plruCsb0 = stall || !io.ufp_req_early
    val plruCsb1 = !io.ufp_resp
    val plruWeb1 = plruCsb1
    val lru = new LruArray(SETW, PLRU, cfg.dcacheLruReadCache)
    lru.io.clk0 := io.clk; lru.io.rst0 := io.rst
    lru.io.csb0 := plruCsb0; lru.io.addr0 := ufpSet.asBits
    lru.io.csb1 := plruCsb1; lru.io.web1 := plruWeb1; lru.io.addr1 := srSet.asBits; lru.io.din1 := plruDin1
    val plruDout0 = lru.io.dout0

    // Compare both conditional high tags before selecting with the late carry.
    val hd = new ooo.memory.HitDetection(cfg, splitHigh = !cfg.dcacheMergedTag)
    hd.io.tag := srTag
    if (!cfg.dcacheMergedTag) {
      hd.io.hi0 := srHi0; hd.io.hi1 := srHi1; hd.io.carry := srC16
    }
    hd.io.tag_arr_flat := Cat((0 until WAYS).map(i => tagDout(i)))   // way0 at LSB
    hd.io.valid_arr_flat := validDout.asBits
    hit := hd.io.hit; hitWay := hd.io.hit_way.asUInt

    val replaceWayDirty = PlruSelect(plruDout0,
      (0 until WAYS).map(w => tagDout(w)(TAG) && validDout(w)), replaceWay)
    val hitWayDirty     = tagDout(hitWay)(TAG) && validDout(hitWay)

    // control FSM (reused twin)
    val ctrl = new ooo.memory.DcacheCtrl(cfg)
    if (cfg.zicsr || cfg.mmio || cfg.lowPower) io.idle := ctrl.io.idle && !maintenanceBusy
    ctrl.io.clk := io.clk; ctrl.io.rst := io.rst
    ctrl.io.hit := hit; ctrl.io.dirty := replaceWayDirty
    ctrl.io.rmask := srRmask; ctrl.io.wmask := srWmask
    when(maintenanceBusy) { ctrl.io.rmask := 0; ctrl.io.wmask := 0 }
    stall := ctrl.io.stall; allocateDone := ctrl.io.allocate_done
    writeHitRec := ctrl.io.write_hit_rec; writeHit := ctrl.io.write_hit
    ctrl.io.dfp_addr := io.dfp_addr
    // dirty-victim writeback support: the word-banked array can only supply the
    // requested WORD at the miss-detect cycle -- the full victim line needs a
    // one-cycle all-banks re-read (stall holds sramSet = srSet) before dfp_write
    // may hand wdata to the bmem arbiter (it captures on the assert cycle).
    // Costs at most one cycle per DIRTY miss (nothing when dfp wasn't ready).
    val victimRdy = RegInit(False)
    val victimRd  = ctrl.io.dfp_write && !victimRdy
    when(victimRd) { victimRdy := True }
    when(!ctrl.io.dfp_write) { victimRdy := False }

    io.dfp_read := ctrl.io.dfp_read
    io.dfp_write := ctrl.io.dfp_write && victimRdy
    ctrl.io.dfp_ready := io.dfp_ready && (!ctrl.io.dfp_write || victimRdy)
    ctrl.io.dfp_raddr := io.dfp_raddr; ctrl.io.dfp_rvalid := io.dfp_rvalid

    // plru update (blackbox)
    val pu = new PlruUpdate(WAYS, PLRU, WAYB)
    pu.io.current_plru := plruDout0; plruDin1 := pu.io.next_plru
    pu.io.hit_way := hitWay.asBits; replaceWay := pu.io.replace_way.asUInt

    // FETCH-stage register update
    when(!stall && !maintenanceBusy) {
      srRmask := io.ufp_rmask; srWmask := io.ufp_wmask; srWdata := io.ufp_wdata
      srOffset := ufpOffset.asUInt; srSet := ufpSet.asUInt
      for (b <- 0 until NW) srWordOh(b) := ufpOffset(OFFW - 1 downto 2).asUInt === b
      if (cfg.dcacheMergedTag) srMergedTag := Mux(io.ufp_c16,io.ufp_hi1,io.ufp_hi0) ## ufpTagLo
      else {
        srHi0 := io.ufp_hi0; srHi1 := io.ufp_hi1; srC16 := io.ufp_c16; srTagLo := ufpTagLo
      }
    }

    // Enable reads only for live requests, while preserving refill/writeback control.
    // An enable-only superset may perform harmless extra reads but must not grant a transaction.
    val ufpReq = io.ufp_req_early   // == rmask.orR || wmask.orR, ~1.2ns earlier

    for (i <- 0 until WAYS; b <- 0 until NW) dataCsb(i)(b) := True
    for (i <- 0 until WAYS) tagCsb(i) := True
    // live request: the addressed word's bank in every way (+ the tags). The
    // word select comes PRE-DECODED per requester arm (ufp_word_oh, exactly
    // one bit set) so each bank's enable folds one ready bit instead of
    // waiting on a decode of the arbiter-muxed addr -- the AGU cone's last
    // segment on the alus_0->bypass->AGU->ce_in critical path.
    when(!stall && ufpReq) {
      for (i <- 0 until WAYS) { tagCsb(i) := False }
      for (i <- 0 until WAYS; b <- 0 until NW) {
        when(if (cfg.dcacheReadAllBanks) True else io.ufp_word_oh(b)) { dataCsb(i)(b) := False }
      }
    }
    // store-hit write cycle: only the captured word's bank of the hit way
    // (tags stay enabled for the dirty-bit write, as before)
    when(writeHit) {
      dataCsb(hitWay)(srWord) := False
      for (i <- 0 until WAYS) tagCsb(i) := False
    }
    // post-write recovery read (rare): refresh everything
    // Recovery must refresh a back-to-back request's word in every way.
    when(writeHitRec) {
      for (i <- 0 until WAYS) dataCsb(i)(srWord) := False
      for (i <- 0 until WAYS) tagCsb(i) := False
    }

    // dirty-victim full-line read (see victimRdy above)
    when(victimRd) { for (i <- 0 until WAYS; b <- 0 until NW) dataCsb(i)(b) := False }
    when(allocateDone) {
      for (b <- 0 until NW) dataCsb(replaceWay)(b) := False
      tagCsb(replaceWay) := False
      when(validity.initializeOnAllocate) { for(i <- 0 until WAYS) tagCsb(i) := False }
    }

    // write-enable
    for (i <- 0 until WAYS) { dataWeb(i) := True; tagWeb(i) := True }
    when(allocateDone) {
      dataWeb(replaceWay) := False; tagWeb(replaceWay) := False
      when(validity.initializeOnAllocate) { for(i <- 0 until WAYS) tagWeb(i) := False }
    }
    when(writeHit) { dataWeb(hitWay) := False; tagWeb(hitWay) := hitWayDirty }

    // SRAM wmask + din
    dataWmask := B(0, 32 bits); dataDin := B(0, 256 bits)
    when(writeHit) {
      for (i <- 0 until 4) when(srWmask(i)) { dataWmask((srOffset + U(i, OFFW bits)).resize(OFFW bits)) := True }
      dataDin := Cat(Seq.fill(8)(srWdata))
    }.elsewhen(allocateDone) {
      dataWmask := B(32 bits, default -> True)
      dataDin := io.dfp_rdata
    }
    tagDin := True.asBits ## srWmask.orR ## srTag   // {valid, dirty, tag}

    // PROCESS stage / dfp + ufp
    val writeAddress = PlruSelect(plruDout0,
      tagDout.toSeq.map(_(TAG - 1 downto 0)), replaceWay) ## srSet.asBits ## B(0, OFFW bits)
    val readAddress = srTag ## srSet.asBits ## B(0, OFFW bits)
    io.dfp_addr := Mux(io.dfp_write, writeAddress, readAddress)
    if (cfg.bmemEarlyAddress) {
      io.dfp_read_addr := readAddress
      io.dfp_write_addr := writeAddress
    }
    io.dfp_wdata := PlruSelect(plruDout0,
      (0 until WAYS).map(w => Cat((0 until NW).map(b => dataDout(w)(b)))), replaceWay)
    val writeBeats = if (cfg.bmemBeatSpeculation) ooo.common.CacheWriteBeat(
      (0 until WAYS).map(w => Cat((0 until NW).map(b => dataDout(w)(b)))),
      io.dfp_write_beat.asUInt) else null
    if (cfg.bmemBeatSpeculation)
      io.dfp_wdata_beat := PlruSelect(plruDout0, writeBeats.toSeq, replaceWay)
    // Select a word in each way before the late hit-way selection.
    val wayWord = Vec(Bits(32 bits), WAYS)
    // Requests are word-aligned; srWordOh identifies the captured word bank.
    for (w <- 0 until WAYS) { wayWord(w) := ooo.OhSel(srWordOh,dataDout(w).toSeq) }
    io.ufp_rdata := ooo.OhSel(hd.io.selected_way, wayWord.toSeq)
    if (cfg.lsuWaySpeculation) {
      if (cfg.lsuWordSpeculation) {
        // Serial/uncached results can bypass before any cache transaction.
        val wordSelect = Mux(io.rst || !(srRmask.orR || srWmask.orR),B(1,NW bits),srWordOh)
        for (w <- 0 until WAYS; b <- 0 until NW) {
          val index = w * NW + b
          io.ufp_selected_way(index) := hd.io.selected_way(w) && wordSelect(b)
          io.ufp_way_rdata_flat(index * 32,32 bits) := dataDout(w)(b)
        }
      } else {
        io.ufp_selected_way := hd.io.selected_way
        for (w <- 0 until WAYS) io.ufp_way_rdata_flat(w * 32,32 bits) := wayWord(w)
      }
    }
    io.ufp_resp  := (srRmask.orR || srWmask.orR) && !stall
    if (cfg.zicsr) {
      val way = maintenance.io.way
      maintenance.io.clk := io.clk; maintenance.io.rst := io.rst
      maintenance.io.request := io.flush_request
      maintenance.io.can_start := ctrl.io.idle && !io.ufp_req_early
      maintenance.io.dirty := validity.initialized(maintenance.io.set) &&
        tagDout(way)(TAW - 1) && tagDout(way)(TAG)
      maintenance.io.write_ready := io.dfp_ready
      io.flush_done := maintenance.io.done
      when(maintenanceBusy) {
        io.ufp_resp := False
        io.dfp_read := False; io.dfp_write := maintenance.io.writeback
        io.dfp_addr := tagDout(way)(TAG - 1 downto 0) ## maintenance.io.set.asBits ## B(0,OFFW bits)
        if (cfg.bmemEarlyAddress) {
          io.dfp_read_addr := io.dfp_addr
          io.dfp_write_addr := io.dfp_addr
        }
        io.dfp_wdata := Cat((0 until NW).map(b => dataDout(way)(b)))
        if (cfg.bmemBeatSpeculation) io.dfp_wdata_beat := writeBeats(way)
        for (i <- 0 until WAYS) {
          tagCsb(i) := True; tagWeb(i) := True; dataWeb(i) := True
          for (b <- 0 until NW) dataCsb(i)(b) := True
        }
        when(maintenance.io.read_row) {
          tagCsb(way) := False
          for (b <- 0 until NW) dataCsb(way)(b) := False
        }
        when(maintenance.io.invalidate) { tagCsb(way) := False; tagWeb(way) := False }
        tagDin := 0
      }
    }

    // perf taps
    io.dbg_stall := stall; io.dbg_hit := hit; io.dbg_rmask := srRmask; io.dbg_wmask := srWmask
  }
}
