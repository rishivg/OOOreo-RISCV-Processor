package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Track store addresses and data until retirement into the store buffer. */
class StoreQueue(cfg: CpuConfig = CpuConfig()) extends Component {
  require(!cfg.storeVerdictPrecompute || (cfg.storeAgePrecompute && cfg.storePairPrecompute),
    "Store verdict precomputation requires age and pair precomputation")
  setDefinitionName("store_queue_spinal")
  val DEPTH = cfg.stqDepth
  val IDX   = cfg.stqIdx
  val LDQ   = cfg.ldqDepth
  val RIDX  = cfg.robIdx
  val TW    = IDX + 1          // pointer/tracker width (4)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    val device_addr = if (cfg.mmio) out Bits(32 bits) else null
    val from_ds_valid       = in  Bool()
    val from_ds_ready       = out Bool()
    val from_ds_uop_rob_id  = in  Bits (RIDX bits)
    val from_ds_uop_fu_opcode = in Bits (4 bits)
    val from_agu_valid = in Bool()
    val from_agu_data  = in Bits (AguLsq.width(cfg) bits)
    val agu_hi0 = if (cfg.storePairPrecompute && cfg.storePairSplitTag) in Bits(16 bits) else null
    val agu_hi1 = if (cfg.storePairPrecompute && cfg.storePairSplitTag) in Bits(16 bits) else null
    val agu_c16 = if (cfg.storePairPrecompute && cfg.storePairSplitTag) in Bool() else null
    val to_rob_ready         = in  Bool()
    val to_rob_valid         = out Bool()
    val to_rob_rob_id        = out Bits (RIDX bits)
    val to_rob_addr_dbg      = out Bits (32 bits)
    val to_rob_wmask_dbg     = out Bits (4 bits)
    val to_rob_wdata_dbg     = out Bits (32 bits)
    val to_rob_rs1_value_dbg = out Bits (32 bits)
    val to_rob_rs2_value_dbg = out Bits (32 bits)
    val to_stb_ready = in  Bool()
    val to_stb_valid = out Bool()
    val to_stb_wmask = out Bits (4 bits)
    val to_stb_addr  = out Bits (32 bits)
    val to_stb_wdata = out Bits (32 bits)
    val ldq_tracker_flat = in  Bits (LDQ * TW bits)
    val ldq_tracker_next_flat = if (cfg.storeAgePrecompute) in Bits(LDQ * TW bits) else null
    val ldq_addr_write = if (cfg.storePairPrecompute) in Bits(LDQ bits) else null
    val ldq_addr_flat    = in  Bits (LDQ * 32 bits)
    val ldq_rmask_flat   = in  Bits (LDQ * 4 bits)
    val stq_tail         = out Bits (TW bits)
    val stq_deq          = out Bool()
    val has_conflicting_store = out Bits (LDQ bits)
    val known_conflict        = out Bits (LDQ bits)
    val unknown_older         = out Bits (LDQ bits)
    val forward_en            = out Bits (LDQ bits)
    val forward_wdata_flat    = out Bits (LDQ * 32 bits)
    val forward_store_data_flat = if (cfg.lsuStoreForwardLanes) out Bits(DEPTH * 32 bits) else null
    val forward_store_select_flat = if (cfg.lsuStoreForwardLanes) out Bits(LDQ * DEPTH bits) else null
    // perf_monitor taps
    val dbg_want_dequeue   = out Bool()
    val dbg_counter        = out Bits (TW bits)
    val dbg_rd_ptr_actual  = out Bits (IDX bits)
    val dbg_addr_valid_flat = out Bits (DEPTH bits)
  }
  noIoPrefix()

  // agu_lsq_t slices (MSB->LSB: rob_id, addr, wdata, mask, rs1_dbg, rs2_dbg)
  val aguRobId = AguLsq.robId(io.from_agu_data, cfg)
  val aguAddr  = AguLsq.addr(io.from_agu_data)
  val aguWdata = AguLsq.wdata(io.from_agu_data)
  val aguMask  = AguLsq.mask(io.from_agu_data)
  // Tie off debug data at the consumer too: hierarchical synthesis does not
  // propagate producer constants across module ports to prune queue storage.
  val aguRs1   = if (cfg.rvfi) AguLsq.rs1Dbg(io.from_agu_data) else B(0, 32 bits)
  val aguRs2   = if (cfg.rvfi) AguLsq.rs2Dbg(io.from_agu_data) else B(0, 32 bits)
  def ldqTracker(i: Int) = io.ldq_tracker_flat(i * TW, TW bits).asUInt
  def ldqAddr(i: Int)    = io.ldq_addr_flat(i * 32, 32 bits)
  def ldqRmask(i: Int)   = io.ldq_rmask_flat(i * 4, 4 bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // Payloads are unreset; enqueue initializes address validity.
    val robId     = Vec(Reg(Bits(RIDX bits)), DEPTH)
    val addrValid = Vec(Reg(Bool()), DEPTH)
    val addr      = Vec(Reg(Bits(32 bits)), DEPTH)
    val mask      = Vec(Reg(Bits(4 bits)), DEPTH)
    val wdata     = Vec(Reg(Bits(32 bits)), DEPTH)
    if (cfg.lsuStoreForwardLanes) io.forward_store_data_flat := wdata.asBits
    val rs1dbg    = Vec(Reg(Bits(32 bits)), DEPTH)
    val rs2dbg    = Vec(Reg(Bits(32 bits)), DEPTH)
    val wrPtr   = RegInit(U(0, TW bits))
    val rdPtr   = RegInit(U(0, TW bits))
    val counter = RegInit(U(0, TW bits))
    val wrActual = wrPtr(IDX - 1 downto 0); val wrFlag = wrPtr(IDX)
    val rdActual = rdPtr(IDX - 1 downto 0); val rdFlag = rdPtr(IDX)

    val full  = (wrActual === rdActual) && (wrFlag === !rdFlag)
    val empty = wrPtr === rdPtr
    io.from_ds_ready := !full

    val enqueue     = io.from_ds_valid && !full && io.from_ds_uop_fu_opcode(3)
    val wantDequeue = Mux(empty, False, addrValid(rdActual))
    val dequeue     = wantDequeue && io.to_rob_ready && io.to_stb_ready
    val nextHead = if (cfg.storeAgePrecompute)
      Mux(io.rst || io.backend_flush, U(0, TW bits), rdPtr + dequeue.asUInt.resize(TW)) else null

    // pointers / counter (reset & flush clear)
    when(io.backend_flush) {
      wrPtr := 0; rdPtr := 0; counter := 0
    }.otherwise {
      when(enqueue) { wrPtr := wrPtr + 1 }
      when(dequeue) { rdPtr := rdPtr + 1 }
      counter := (counter + Mux(enqueue, U(1, TW bits), U(0, TW bits)) - Mux(dequeue, U(1, TW bits), U(0, TW bits))).resize(TW bits)
    }

    // Payload writes continue during flush; validity controls their visibility.
    when(io.from_agu_valid) {
      for (j <- 0 until DEPTH) {
        when(robId(j) === aguRobId) {
          addrValid(j) := True; addr(j) := aguAddr; mask(j) := aguMask
          wdata(j) := aguWdata; rs1dbg(j) := aguRs1; rs2dbg(j) := aguRs2
        }
      }
    }
    when(enqueue) {
      robId(wrActual) := io.from_ds_uop_rob_id
      addrValid(wrActual) := False
    }

    // drain to STB / ROB
    if (cfg.mmio) io.device_addr := addr(rdActual)
    io.to_stb_valid := wantDequeue && io.to_rob_ready
    io.to_stb_wmask := mask(rdActual)
    io.to_stb_addr  := addr(rdActual)(31 downto 2) ## B(0, 2 bits)
    io.to_stb_wdata := wdata(rdActual)
    io.to_rob_valid         := wantDequeue && io.to_stb_ready
    io.to_rob_rob_id        := robId(rdActual)
    io.to_rob_addr_dbg      := addr(rdActual)(31 downto 2) ## B(0, 2 bits)
    io.to_rob_wmask_dbg     := mask(rdActual)
    io.to_rob_wdata_dbg     := wdata(rdActual)
    io.to_rob_rs1_value_dbg := rs1dbg(rdActual)
    io.to_rob_rs2_value_dbg := rs2dbg(rdActual)
    io.stq_tail := counter.asBits
    io.stq_deq  := dequeue

    // speculative-load disambiguation + store-to-load forwarding
    val hasConf = Vec(Bool(), LDQ); val known = Vec(Bool(), LDQ)
    val unknown = Vec(Bool(), LDQ); val fwdEn = Vec(Bool(), LDQ)
    val fwdData = Vec(Bits(32 bits), LDQ)
    val pairCache = if (cfg.storePairPrecompute) new StorePairCache(cfg) else null
    if (cfg.storePairPrecompute) {
      pairCache.io.clk := io.clk; pairCache.io.rst := io.rst
      pairCache.io.store_addr_flat := addr.asBits; pairCache.io.store_mask_flat := mask.asBits
      pairCache.io.load_addr_flat := io.ldq_addr_flat; pairCache.io.load_mask_flat := io.ldq_rmask_flat
      pairCache.io.load_write := io.ldq_addr_write
      pairCache.io.agu_addr := aguAddr; pairCache.io.agu_mask := aguMask
      if (cfg.storePairSplitTag) {
        pairCache.io.agu_hi0 := io.agu_hi0; pairCache.io.agu_hi1 := io.agu_hi1
        pairCache.io.agu_c16 := io.agu_c16
      }
      for (j <- 0 until DEPTH)
        pairCache.io.store_write(j) := io.from_agu_valid && (robId(j) === aguRobId)
    }
    for (i <- 0 until LDQ) {
      val tracker = ldqTracker(i)
      val ageMask = if (cfg.storeVerdictPrecompute) {
        StoreAgeMask(nextHead, io.ldq_tracker_next_flat(i * TW, TW bits).asUInt,
          DEPTH, cfg.storeAgeLookup)
      } else if (cfg.storeAgePrecompute) {
        val nextTracker = io.ldq_tracker_next_flat(i * TW, TW bits).asUInt
        RegNext(StoreAgeMask(nextHead, nextTracker, DEPTH, cfg.storeAgeLookup))
      } else StoreAgeMask(rdPtr, tracker, DEPTH, cfg.storeAgeLookup)
      val sameAddr = Vec(Bool(), DEPTH); val potConf = Vec(Bool(), DEPTH)
      val unkOld   = Vec(Bool(), DEPTH); val ovlOld  = Vec(Bool(), DEPTH); val covOld = Vec(Bool(), DEPTH)
      for (j <- 0 until DEPTH) {
        // Fold addrValid into the tag compare: a match is only meaningful for a
        // valid store entry. This removes the separate `&& addrValid(j)` AND from
        // the ovl/cov cone (the speculative-load critical path) and lets the 30-bit
        // comparator output be masked for invalid (mostly idle) slots. Bit-identical.
        val avj = if (cfg.storeVerdictPrecompute)
          (addrValid(j) || pairCache.io.store_write(j)) && !(enqueue && wrActual === j)
        else addrValid(j)
        val pair = i * DEPTH + j
        val addrMatch = avj && (if (cfg.storeVerdictPrecompute) pairCache.io.next_tag(pair)
          else if (cfg.storePairPrecompute) pairCache.io.tag_match(pair)
          else addr(j)(31 downto 2) === ldqAddr(i)(31 downto 2))
        val rmaskOvl = if (cfg.storeVerdictPrecompute) pairCache.io.next_overlap(pair)
          else if (cfg.storePairPrecompute) pairCache.io.overlap(pair)
          else (ldqRmask(i) & ~mask(j)) =/= ldqRmask(i)
        val rmaskCov = if (cfg.storeVerdictPrecompute) pairCache.io.next_cover(pair)
          else if (cfg.storePairPrecompute) pairCache.io.cover(pair)
          else (ldqRmask(i) & ~mask(j)) === 0
        sameAddr(j) := !avj || (addrMatch && rmaskOvl)
        potConf(j) := ageMask(j)
        unkOld(j) := potConf(j) && !avj
        ovlOld(j) := potConf(j) && addrMatch && rmaskOvl
        covOld(j) := potConf(j) && addrMatch && rmaskCov
      }
      val tracked = if (cfg.storeVerdictPrecompute)
        io.ldq_tracker_next_flat(i * TW, TW bits).orR else tracker =/= 0
      val conflict = (sameAddr.asBits & potConf.asBits).orR
      val knownConflict = tracked && ovlOld.asBits.orR
      val unknownOlder = tracked && unkOld.asBits.orR
      val (forward, value) = StoreForwarding(tracked, unkOld.asBits.orR,
        ovlOld.asBits, covOld.asBits, wdata.toSeq)
      if (cfg.storeVerdictPrecompute) {
        hasConf(i) := RegNext(conflict)
        known(i) := RegNext(knownConflict); unknown(i) := RegNext(unknownOlder)
        fwdEn(i) := RegNext(forward)
        val select = RegNext(ovlOld.asBits & covOld.asBits)
        if (cfg.lsuStoreForwardLanes) io.forward_store_select_flat(i * DEPTH, DEPTH bits) := select
        fwdData(i) := Mux(fwdEn(i), ooo.OhSel(select, wdata.toSeq), B(0, 32 bits))
      } else {
        hasConf(i) := conflict; known(i) := knownConflict; unknown(i) := unknownOlder
        fwdEn(i) := forward; fwdData(i) := value
      }
    }
    io.has_conflicting_store := hasConf.asBits
    io.known_conflict        := known.asBits
    io.unknown_older         := unknown.asBits
    io.forward_en            := fwdEn.asBits
    io.forward_wdata_flat    := fwdData.asBits

    // perf taps
    io.dbg_want_dequeue  := wantDequeue
    io.dbg_counter       := counter.asBits
    io.dbg_rd_ptr_actual := rdActual.asBits
    io.dbg_addr_valid_flat := addrValid.asBits
  }
}
