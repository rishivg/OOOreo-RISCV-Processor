package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Track speculative loads, forwarding, disambiguation, and ordering violations. */
class LoadQueue(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("load_queue_spinal")
  val LDQ  = cfg.ldqDepth
  val IDX  = cfg.ldqIdx
  val STW  = cfg.stqIdx + 1    // track/tail width (4)
  val RIDX = cfg.robIdx
  val PIDX = cfg.prfIdx
  val AIDX = cfg.arfIdx
  def MEM_LB  = B"4'b0000"; def MEM_LH = B"4'b0001"; def MEM_LW = B"4'b0010"
  def MEM_LBU = B"4'b0100"; def MEM_LHU = B"4'b0101"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    val device_go = if (cfg.mmio) in Bool() else null
    val device_go_id = if (cfg.mmio) in Bits(RIDX bits) else null
    val block_regular = if (cfg.zicsr || cfg.mmio || cfg.lowPower) in Bool() else null
    val dmem_rob_id = if (cfg.mmio) out Bits(RIDX bits) else null
    val dmem_original_addr = if (cfg.mmio) out Bits(32 bits) else null
    val dmem_cache_valid = if (cfg.mmio) out Bool() else null
    val dmem_external = if (cfg.mmio) out Bool() else null
    val from_ds_valid        = in  Bool()
    val from_ds_ready        = out Bool()
    val from_ds_uop_rob_id   = in  Bits (RIDX bits)
    val from_ds_uop_fu_opcode = in Bits (4 bits)
    val from_ds_uop_rd_arch  = in  Bits (AIDX bits)
    val from_ds_uop_rd_phy   = in  Bits (PIDX bits)
    val from_agu_valid = in Bool()
    val from_agu_data  = in Bits (AguLsq.width(cfg) bits)
    // AGU hi16 split (early conditional sums; from_agu_data keeps the merged addr
    // for the entry/lsr captures). Forwarded on the dmem port for the D$'s split
    // tag capture -- the registered-entry issue case sends {addr hi, addr hi, 0}.
    val agu_hi0 = in Bits (16 bits)
    val agu_hi1 = in Bits (16 bits)
    val agu_c16 = in Bool()
    val agu_ordered = if (cfg.mmio) in Bool() else null
    val agu_clint = if (cfg.zicsr) in Bool() else null
    val agu_clint_read_sel = if (cfg.zicsr) in Bits(Clint.offsets.size bits) else null
    val dmem_clint = if (cfg.zicsr) out Bool() else null
    val dmem_clint_read_sel = if (cfg.zicsr) out Bits(Clint.offsets.size bits) else null
    val cdb_rob_id        = out Bits (RIDX bits)
    val cdb_rd_phy        = out Bits (PIDX bits)
    val cdb_rd_arch       = out Bits (AIDX bits)
    val cdb_forward_select = if (cfg.lsuForwardSpeculation) out Bits(cfg.lsuForwardCandidates bits) else null
    val cdb_forward_enable = if (cfg.lsuForwardSpeculation) out Bool() else null
    val cdb_way_value_flat = if (cfg.lsuWaySpeculation) out Bits(cfg.lsuBypassCandidates * 32 bits) else null
    val cdb_rd_value      = out Bits (32 bits)
    val cdb_rs1_value_dbg = out Bits (32 bits)
    val cdb_rs2_value_dbg = out Bits (32 bits)
    val cdb_valid         = out Bool()
    val to_rob_rob_id           = out Bits (RIDX bits)
    val to_rob_addr_dbg         = out Bits (32 bits)
    val to_rob_rmask_dbg        = out Bits (4 bits)
    val to_rob_rdata_dbg        = out Bits (32 bits)
    val to_rob_valid            = out Bool()
    val to_rob_violation        = out Bool()
    val to_rob_violation_rob_id = out Bits (RIDX bits)
    val dmem_valid = out Bool()
    // The early qualifier may overapproximate requests; it only enables memory reads and never grants a transaction.
    val dmem_valid_early = out Bool()
    val dmem_ready = in  Bool()
    val dmem_addr  = out Bits (32 bits)
    val dmem_hi0   = out Bits (16 bits)   // hi16 split: Mux(c16,hi1,hi0) == dmem_addr(31:16)
    val dmem_hi1   = out Bits (16 bits)
    val dmem_c16   = out Bool()
    val dmem_rmask = out Bits (4 bits)
    // word-in-line one-hot (== decode(dmem_addr(OFFW-1:2))), built per issue
    // cofactor so the AGU cone reaches the D$ word-bank chip-enables through
    // ONE decode gate + the winnerIsAgu 2:1 instead of re-deriving from the
    // muxed addr behind the arbiter (the alus_0->AGU->ce_in critical tail).
    val dmem_word_oh = out Bits ((1 << (cfg.dOffsetIdx - 2)) bits)
    val dmem_resp  = in  Bool()
    val dmem_rdata = in  Bits (32 bits)
    val dmem_way_rdata_flat = if (cfg.lsuWaySpeculation) in Bits(cfg.lsuCacheCandidates * 32 bits) else null
    val stq_tail              = in  Bits (STW bits)
    val stq_deq               = in  Bool()
    val stq_has_conf          = in  Bits (LDQ bits)
    val stq_known_conflict    = in  Bits (LDQ bits)
    val stq_unknown_older     = in  Bits (LDQ bits)
    val stq_forward_en        = in  Bits (LDQ bits)
    val stq_forward_wdata_flat = in Bits (LDQ * 32 bits)
    val stq_store_data_flat = if (cfg.lsuStoreForwardLanes) in Bits(cfg.stqDepth * 32 bits) else null
    val stq_store_select_flat = if (cfg.lsuStoreForwardLanes) in Bits(LDQ * cfg.stqDepth bits) else null
    val ldq_tracker_flat = out Bits (LDQ * STW bits)
    val ldq_tracker_next_flat = if (cfg.storeAgePrecompute) out Bits(LDQ * STW bits) else null
    val ldq_addr_write = if (cfg.storePairPrecompute) out Bits(LDQ bits) else null
    val ldq_addr_flat    = out Bits (LDQ * 32 bits)
    val ldq_rmask_flat   = out Bits (LDQ * 4 bits)
    val stb_has_conf      = in  Bits (LDQ bits)
    val stb_forward_en    = in  Bits (LDQ bits)
    val stb_forward_wdata_flat = in Bits (LDQ * 32 bits)
    val stb_store_data_flat = if (cfg.lsuBufferForwardLanes) in Bits(cfg.stbDepth * 32 bits) else null
    val stb_store_select_flat = if (cfg.lsuBufferForwardLanes) in Bits(LDQ * cfg.stbDepth bits) else null
    val stb_ldq_addr_flat  = out Bits (LDQ * 32 bits)
    val stb_ldq_rmask_flat = out Bits (LDQ * 4 bits)
    // perf taps
    val dbg_valid_flat      = out Bits (LDQ bits)
    val dbg_addr_valid_flat = out Bits (LDQ bits)
    val dbg_issued_flat     = out Bits (LDQ bits)
    val dbg_issue_en        = out Bool()
  }
  noIoPrefix()

  // agu_lsq_t slices (MSB->LSB: rob_id, addr, wdata, mask, rs1_dbg, rs2_dbg)
  val aguRobId = AguLsq.robId(io.from_agu_data, cfg)
  val aguAddr  = AguLsq.addr(io.from_agu_data)
  val aguMask  = AguLsq.mask(io.from_agu_data)
  // Tie off debug data at the consumer too: hierarchical synthesis does not
  // propagate producer constants across module ports to prune queue storage.
  val aguRs1   = if (cfg.rvfi) AguLsq.rs1Dbg(io.from_agu_data) else B(0, 32 bits)
  val aguRs2   = if (cfg.rvfi) AguLsq.rs2Dbg(io.from_agu_data) else B(0, 32 bits)
  def stqFwdWdata(i: UInt) = io.stq_forward_wdata_flat.subdivideIn(LDQ slices)(i)
  def stbFwdWdata(i: UInt) = io.stb_forward_wdata_flat.subdivideIn(LDQ slices)(i)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val valid     = Vec(RegInit(False), LDQ)
    val addrValid = Vec(Reg(Bool()), LDQ)
    val issued    = Vec(Reg(Bool()), LDQ)
    val spec      = Vec(Reg(Bool()), LDQ)
    val track     = Vec(Reg(UInt(STW bits)), LDQ)
    val robId     = Vec(Reg(Bits(RIDX bits)), LDQ)
    val fuOp      = Vec(Reg(Bits(4 bits)), LDQ)
    val addr      = Vec(Reg(Bits(32 bits)), LDQ)
    val mask      = Vec(Reg(Bits(4 bits)), LDQ)
    val rdArch    = Vec(Reg(Bits(AIDX bits)), LDQ)
    val rdPhy     = Vec(Reg(Bits(PIDX bits)), LDQ)
    val rs1dbg    = Vec(Reg(Bits(32 bits)), LDQ)
    val rs2dbg    = Vec(Reg(Bits(32 bits)), LDQ)

    // push select (first free slot)
    val canPush = io.from_ds_valid && io.from_ds_ready && !io.from_ds_uop_fu_opcode(3)
    val pushEn = Bool(); pushEn := False
    val pushIdx = UInt(IDX bits); pushIdx := 0
    for (i <- LDQ - 1 downto 0) { when(canPush && !valid(i)) { pushEn := True; pushIdx := U(i, IDX bits) } }
    io.from_ds_ready := (0 until LDQ).map(i => !valid(i)).reduce(_ || _)

    // AGU-address bypass
    val aguHit   = Vec(Bool(), LDQ)
    // The STQ/STB disambiguation matrices see only the REGISTERED addr/mask now: the
    // AGU fast path issues ungated (verdict at the response, when the AGU write has
    // landed), the registered-entry issue gate + response verdict + spec/violation
    // machinery all key off registered entries. This removes the same-cycle
    // AGU->matrices arc from the D$ load-use critical loop entirely (and is what
    // makes the response verdict loop-free: matrices never see the live AGU addr).
    for (i <- 0 until LDQ) {
      aguHit(i)    := io.from_agu_valid && valid(i) && !addrValid(i) && (robId(i) === aguRobId)
      if (cfg.storePairPrecompute)
        io.ldq_addr_write(i) := io.from_agu_valid && (robId(i) === aguRobId) && !io.backend_flush
      io.ldq_tracker_flat(i * STW, STW bits) := track(i).asBits
      io.ldq_addr_flat(i * 32, 32 bits)      := addr(i)
      io.ldq_rmask_flat(i * 4, 4 bits)       := mask(i)
      io.stb_ldq_addr_flat(i * 32, 32 bits)  := addr(i)
      io.stb_ldq_rmask_flat(i * 4, 4 bits)   := mask(i)
    }

    // Issue the lowest ready queued load, or an eligible AGU-bypass load.
    // Keep selection and disambiguation aligned with the same winner.
    val block = if (cfg.mmio || cfg.lowPower) io.block_regular else False
    val regOpen = Bits(LDQ bits)
    val regBlocked = Bits(LDQ bits)
    for (i <- 0 until LDQ) {
      val stbFwd = io.stb_forward_en(i) && !io.stq_has_conf(i)
      val gateOk = (!io.stq_known_conflict(i) && !io.stb_has_conf(i)) || io.stq_forward_en(i) || stbFwd
      val ready = valid(i) && !issued(i) && addrValid(i)
      val ordered = if (cfg.mmio) DeviceRegion.ordered(addr(i), cfg) else False
      val device = if (cfg.mmio) io.device_go && (robId(i) === io.device_go_id) else False
      regOpen(i) := ready && Mux(ordered, device, gateOk)
      regBlocked(i) := ready && ordered && device
    }
    def firstIndex(ready: Bits): UInt = {
      val index = UInt(IDX bits); index := 0
      for (i <- LDQ - 1 downto 0) when(ready(i)) { index := U(i, IDX bits) }
      index
    }
    val idxOpen = firstIndex(regOpen)
    val idxBlocked = firstIndex(regBlocked)
    val issueIdxReg = Mux(block, idxBlocked, idxOpen)
    val issueEnReg = Mux(block, regBlocked.orR, regOpen.orR)
    val aguOkV = Bits(LDQ bits)
    val aguOrdered = if (cfg.mmio) io.agu_ordered else False
    for (i <- 0 until LDQ) aguOkV(i) := aguHit(i) && !issued(i)
    val winnerOpen = !aguOrdered && (0 until LDQ).map(i => aguOkV(i) && !regOpen(i downto 0).orR).reduce(_ || _)
    val winnerIsAgu = !block && winnerOpen
    val aguIdx = UInt(IDX bits)
    for (b <- 0 until IDX) {
      aguIdx(b) := (0 until LDQ).filter(i => ((i >> b) & 1) == 1).map(aguOkV(_)).reduce(_ || _)
    }
    val issueEn = Mux(block, regBlocked.orR, regOpen.orR || (!aguOrdered && aguOkV.orR))
    val issueIdx = Mux(winnerIsAgu, aguIdx, issueIdxReg)
    // Resolve ordering after each priority encoder and payload selection.
    def regRead(data: Vec[Bits]): Bits = Mux(block, data(idxBlocked), data(idxOpen))
    def issueRead(data: Vec[Bits], agu: Bits): Bits =
      Mux(block, data(idxBlocked), Mux(winnerOpen, agu, data(idxOpen)))
    io.dmem_valid := issueEn && !io.backend_flush
    if (cfg.mmio) {
      def external(ready: Bits): Bool = (0 until LDQ).map { i =>
        val first = if (i == 0) True else !ready(i - 1 downto 0).orR
        val selected = (ready(i) && first) || (if (i == 0) !ready.orR else False)
        selected && DeviceRegion.external(addr(i)(31 downto 2) ## B(0, 2 bits), cfg)
      }.reduce(_ || _)
      val externalOpen = external(regOpen)
      val externalBlocked = external(regBlocked)
      if (cfg.lsuCachePermission) {
        // Device-go is included in block_regular by LsuTop. Without it, every
        // ready registered load is cache/internal and priority cannot suppress a request.
        io.dmem_cache_valid := !io.backend_flush && Mux(block,
          regBlocked.orR && !externalBlocked, regOpen.orR || (!aguOrdered && aguOkV.orR))
        if (cfg.rvfi) assert(!io.device_go || io.block_regular)
      } else io.dmem_cache_valid := !io.backend_flush && Mux(block,
        regBlocked.orR && !externalBlocked, winnerOpen || (regOpen.orR && !externalOpen))
      io.dmem_external := Mux(block, externalBlocked, !winnerOpen && externalOpen)
    }
    // enable-only superset: |aguOkV -> from_agu_valid (aguHit ANDs it in), so
    // issueEnReg || from_agu_valid covers every issueEn cycle. All three terms are
    // registered or register-driven -- the aguOkV CAM is off this cone entirely.
    io.dmem_valid_early := (issueEnReg || io.from_agu_valid) && !io.backend_flush && (if (cfg.zicsr || cfg.lowPower || cfg.mmio) !io.block_regular else True)

    // next-state (mirrors ldq_arr_nxt)
    val nValid = Vec(Bool(), LDQ); val nAddrValid = Vec(Bool(), LDQ); val nIssued = Vec(Bool(), LDQ)
    val nSpec = Vec(Bool(), LDQ); val nTrack = Vec(UInt(STW bits), LDQ); val nRobId = Vec(Bits(RIDX bits), LDQ)
    val nFuOp = Vec(Bits(4 bits), LDQ); val nAddr = Vec(Bits(32 bits), LDQ); val nMask = Vec(Bits(4 bits), LDQ)
    val nRdArch = Vec(Bits(AIDX bits), LDQ); val nRdPhy = Vec(Bits(PIDX bits), LDQ)
    val nRs1 = Vec(Bits(32 bits), LDQ); val nRs2 = Vec(Bits(32 bits), LDQ)
    for (i <- 0 until LDQ) {
      nValid(i) := valid(i); nAddrValid(i) := addrValid(i); nIssued(i) := issued(i); nSpec(i) := spec(i)
      nTrack(i) := track(i); nRobId(i) := robId(i); nFuOp(i) := fuOp(i); nAddr(i) := addr(i)
      nMask(i) := mask(i); nRdArch(i) := rdArch(i); nRdPhy(i) := rdPhy(i); nRs1(i) := rs1dbg(i); nRs2(i) := rs2dbg(i)
    }
    when(io.stq_deq) { for (i <- 0 until LDQ) { nTrack(i) := Mux(track(i) === 0, U(0, STW bits), track(i) - 1) } }
    when(io.from_agu_valid) {
      for (i <- 0 until LDQ) when(robId(i) === aguRobId) {
        nAddrValid(i) := True; nAddr(i) := aguAddr; nMask(i) := aguMask; nRs1(i) := aguRs1; nRs2(i) := aguRs2
      }
    }
    for (i <- 0 until LDQ) {
      when(valid(i) && issued(i) && spec(i) && (io.stq_known_conflict(i) || !io.stq_unknown_older(i))) { nValid(i) := False }
    }
    when(pushEn) {
      nValid(pushIdx) := True; nAddrValid(pushIdx) := False; nIssued(pushIdx) := False; nSpec(pushIdx) := False
      nTrack(pushIdx) := Mux(io.stq_deq, (io.stq_tail.asUInt - 1).resize(STW bits), io.stq_tail.asUInt)
      nRobId(pushIdx) := io.from_ds_uop_rob_id; nFuOp(pushIdx) := io.from_ds_uop_fu_opcode
      nRdArch(pushIdx) := io.from_ds_uop_rd_arch; nRdPhy(pushIdx) := io.from_ds_uop_rd_phy
    }
    when(issueEn && io.dmem_ready) {
      nIssued(issueIdx) := True    // entry stays valid; freed/parked/re-armed at the RESPONSE
    }
    if (cfg.storeAgePrecompute) {
      for (i <- 0 until LDQ)
        io.ldq_tracker_next_flat(i * STW, STW bits) := Mux(io.backend_flush, track(i), nTrack(i)).asBits
    }

    // register next-state (valid cleared on rst/flush; rest hold on flush)
    when(io.backend_flush) {
      for (i <- 0 until LDQ) valid(i) := False
    }.otherwise {
      for (i <- 0 until LDQ) {
        valid(i) := nValid(i); addrValid(i) := nAddrValid(i); issued(i) := nIssued(i); spec(i) := nSpec(i)
        track(i) := nTrack(i); robId(i) := nRobId(i); fuOp(i) := nFuOp(i); addr(i) := nAddr(i)
        mask(i) := nMask(i); rdArch(i) := nRdArch(i); rdPhy(i) := nRdPhy(i); rs1dbg(i) := nRs1(i); rs2dbg(i) := nRs2(i)
      }
    }

    // memory-ordering violation (highest matching slot wins)
    io.to_rob_violation := False; io.to_rob_violation_rob_id := 0
    for (i <- 0 until LDQ) {
      when(valid(i) && issued(i) && spec(i) && io.stq_known_conflict(i)) {
        io.to_rob_violation := True; io.to_rob_violation_rob_id := robId(i)
      }
    }

    // The selected load’s masks, address, and ROB ID travel together to the D-cache.
    val dmemAddr = issueRead(addr, aguAddr)(31 downto 2) ## B(0, 2 bits)
    io.dmem_addr  := dmemAddr
    if (cfg.zicsr) {
      io.dmem_clint := Mux(winnerIsAgu,io.agu_clint,regRead(addr)(31 downto 16) === B(cfg.clintHi16,16 bits))
      io.dmem_clint_read_sel := Mux(winnerIsAgu,io.agu_clint_read_sel,Clint.registerSelect(regRead(addr)))
    }
    if (cfg.mmio) { io.dmem_rob_id := issueRead(robId, aguRobId); io.dmem_original_addr := issueRead(addr, aguAddr) }
    io.dmem_rmask := issueRead(mask, aguMask)
    // hi16 split fields for the D$ split tag capture: the AGU arm carries the
    // EARLY conditional sums (the registered arm's hi is already merged -- send
    // it on both, c16 = 0).
    io.dmem_hi0 := Mux(winnerIsAgu, io.agu_hi0, regRead(addr)(31 downto 16))
    io.dmem_hi1 := Mux(winnerIsAgu, io.agu_hi1, regRead(addr)(31 downto 16))
    io.dmem_c16 := winnerIsAgu && io.agu_c16
    // word one-hot per cofactor: each arm is a decode of 3 addr bits (always
    // exactly one bit set), so the mux of the two arms is one-hot too and equals
    // decode(dmem_addr(OFFW-1:2)) by the same disjoint-arm argument as dmemAddr.
    val NWD = 1 << (cfg.dOffsetIdx - 2)
    val aguWordDec = Bits(NWD bits); val regWordDec = Bits(NWD bits)
    // Qualify each address-compare arm with its winner bit before merging the result.
    for (b <- 0 until NWD) {
      aguWordDec(b) := winnerIsAgu && (aguAddr(cfg.dOffsetIdx - 1 downto 2).asUInt === b)
      regWordDec(b) := !winnerIsAgu && (regRead(addr)(cfg.dOffsetIdx - 1 downto 2).asUInt === b)
    }
    io.dmem_word_oh := aguWordDec | regWordDec

    // load stage register
    // Resolve forwarding at response from registered state, keeping issue off the late AGU path.
    val lsrIdx = Reg(UInt(IDX bits))
    val lsrIdxOh = if (cfg.lsuResponsePredecode) Reg(Bits(LDQ bits)).setName("lsrIdxOh") else null
    val lsrRobId = Reg(Bits(RIDX bits)); val lsrAddr2 = Reg(UInt(2 bits)); val lsrFuOp = Reg(Bits(4 bits))
    val lsrRdArch = Reg(Bits(AIDX bits)); val lsrRdPhy = Reg(Bits(PIDX bits)); val lsrAddrDbg = Reg(Bits(32 bits))
    val lsrMaskDbg = Reg(Bits(4 bits)); val lsrRs1 = Reg(Bits(32 bits)); val lsrRs2 = Reg(Bits(32 bits))
    val formatSelect = if (cfg.lsuFormatPredecode) {
      lsrFuOp.setName("lsrFormatOp"); lsrAddr2.setName("lsrFormatOffset")
      val accepted = io.dmem_valid && io.dmem_ready
      // Capture the held-state decode too, establishing coherence on every core edge.
      val nextOp = Mux(accepted,fuOp(issueIdx),lsrFuOp)
      val nextOffset = Mux(accepted,issueRead(addr,aguAddr)(1 downto 0).asUInt,lsrAddr2)
      RegNext(LoadResultFormat.control(nextOp,nextOffset)).setName("lsrFormatSelect")
    } else null
    when(io.dmem_valid && io.dmem_ready) {
      lsrIdx := issueIdx
      if (cfg.lsuResponsePredecode) {
        for (i <- 0 until LDQ) lsrIdxOh(i) := issueIdx === i
      }
      lsrRobId := issueRead(robId, aguRobId)   // winner-AGU: robId(aguIdx) === aguRobId
      lsrAddr2 := issueRead(addr, aguAddr)(1 downto 0).asUInt
      lsrFuOp := fuOp(issueIdx)
      lsrRdArch := rdArch(issueIdx); lsrRdPhy := rdPhy(issueIdx); lsrAddrDbg := dmemAddr
      lsrMaskDbg := io.dmem_rmask
      lsrRs1 := issueRead(rs1dbg, aguRs1)
      lsrRs2 := issueRead(rs2dbg, aguRs2)
    }

    // Compare pending stores against the selected load’s address and byte mask.
    // Unknown older addresses or conflicting stores block/violate the speculative load.
    val respDevice = if (cfg.mmio) DeviceRegion.ordered(lsrAddrDbg,cfg) else False
    val respFwdEn = Bool(); val respKill = Bool(); val respFwdWdata = Bits(32 bits)
    if (cfg.lsuResponsePredecode) {
      val forward = Bits(LDQ bits); val kill = Bits(LDQ bits)
      val stqSelect = Bits(LDQ bits); val stbSelect = Bits(LDQ bits)
      for (i <- 0 until LDQ) {
        val stq = io.stq_forward_en(i)
        val stb = io.stb_forward_en(i) && !io.stq_has_conf(i)
        forward(i) := stq || stb
        kill(i) := (io.stq_known_conflict(i) || io.stb_has_conf(i)) && !forward(i)
        stqSelect(i) := lsrIdxOh(i) && stq
        stbSelect(i) := lsrIdxOh(i) && !stq && stb
      }
      respFwdEn := !respDevice && (lsrIdxOh & forward).orR
      respKill := !respDevice && (lsrIdxOh & kill).orR
      respFwdWdata := ooo.OhSel(stqSelect,(0 until LDQ).map(i => stqFwdWdata(U(i, IDX bits)))) | ooo.OhSel(stbSelect,(0 until LDQ).map(i => stbFwdWdata(U(i, IDX bits))))
    } else {
      val respStbFwd = io.stb_forward_en(lsrIdx) && !io.stq_has_conf(lsrIdx)
      respFwdEn := !respDevice && (io.stq_forward_en(lsrIdx) || respStbFwd)
      respKill := !respDevice && (io.stq_known_conflict(lsrIdx) || io.stb_has_conf(lsrIdx)) && !respFwdEn
      respFwdWdata := Mux(io.stq_forward_en(lsrIdx), stqFwdWdata(lsrIdx), stbFwdWdata(lsrIdx))
    }
    when(io.dmem_resp) {
      when(respKill)                            { nIssued(lsrIdx) := False }
        .elsewhen(io.stq_unknown_older(lsrIdx) && !respDevice) { nSpec(lsrIdx)   := True }
        .otherwise                              { nValid(lsrIdx)  := False }
    }

    // load result formatting
    val dmemRdata = Mux(respFwdEn, respFwdWdata, io.dmem_rdata)
    def format(data: Bits): Bits = if (cfg.lsuFormatPredecode)
      LoadResultFormat.decoded(data,formatSelect) else LoadResultFormat(data,lsrFuOp,lsrAddr2)
    val rdataWb = format(dmemRdata)
    if (cfg.lsuWaySpeculation) {
      for (w <- 0 until cfg.lsuCacheCandidates) {
        val raw = io.dmem_way_rdata_flat(w * 32,32 bits)
        val word = if (cfg.lsuForwardSpeculation) raw else Mux(respFwdEn,respFwdWdata,raw)
        io.cdb_way_value_flat(w * 32,32 bits) := format(word)
      }
      if (cfg.lsuForwardSpeculation) {
        io.cdb_forward_enable := respFwdEn
        if (cfg.lsuStoreForwardLanes) {
          for (store <- 0 until cfg.stqDepth) {
            io.cdb_forward_select(store) := !respDevice && (0 until LDQ).map(i =>
              lsrIdxOh(i) && io.stq_forward_en(i) &&
                io.stq_store_select_flat(i * cfg.stqDepth + store)).reduce(_ || _)
            io.cdb_way_value_flat((cfg.lsuCacheCandidates + store) * 32,32 bits) :=
              format(io.stq_store_data_flat(store * 32,32 bits))
          }
        } else {
          for (i <- 0 until LDQ) {
            io.cdb_forward_select(i) := !respDevice && lsrIdxOh(i) && io.stq_forward_en(i)
            io.cdb_way_value_flat((cfg.lsuCacheCandidates + i) * 32,32 bits) :=
              format(stqFwdWdata(U(i, IDX bits)))
          }
        }
        if (cfg.lsuBufferForwardLanes) {
          for (store <- 0 until cfg.stbDepth) {
            io.cdb_forward_select(cfg.lsuStqForwardCandidates + store) := !respDevice &&
              (0 until LDQ).map(i => lsrIdxOh(i) && !io.stq_forward_en(i) &&
                io.stb_forward_en(i) && !io.stq_has_conf(i) &&
                io.stb_store_select_flat(i * cfg.stbDepth + store)).reduce(_ || _)
            io.cdb_way_value_flat((cfg.lsuCacheCandidates + cfg.lsuStqForwardCandidates + store) * 32,32 bits) :=
              format(io.stb_store_data_flat(store * 32,32 bits))
          }
        } else {
        for (i <- 0 until LDQ) {
          io.cdb_forward_select(cfg.lsuStqForwardCandidates + i) := !respDevice && lsrIdxOh(i) &&
            !io.stq_forward_en(i) && io.stb_forward_en(i) && !io.stq_has_conf(i)
          io.cdb_way_value_flat((cfg.lsuCacheCandidates + cfg.lsuStqForwardCandidates + i) * 32,32 bits) :=
            format(stbFwdWdata(U(i, IDX bits)))
        }
        }
        for (w <- cfg.lsuCacheCandidates + cfg.lsuForwardCandidates until cfg.lsuBypassCandidates)
          io.cdb_way_value_flat(w * 32,32 bits) := 0
      }
    }

    // CDB + ROB outputs (combinational pass-through on dmem.resp)
    // respKill is computed from registered state (early in the cycle) -- one AND
    // with an early side input on the late dmem_resp, not a new late term.
    io.cdb_valid         := io.dmem_resp && !respKill
    io.cdb_rob_id        := lsrRobId
    io.cdb_rd_phy        := lsrRdPhy
    io.cdb_rd_arch       := lsrRdArch
    io.cdb_rd_value      := rdataWb
    io.cdb_rs1_value_dbg := lsrRs1
    io.cdb_rs2_value_dbg := lsrRs2
    io.to_rob_valid     := io.dmem_resp && !respKill
    io.to_rob_rob_id    := lsrRobId
    io.to_rob_addr_dbg  := lsrAddrDbg
    io.to_rob_rmask_dbg := lsrMaskDbg
    io.to_rob_rdata_dbg := dmemRdata

    // perf taps
    io.dbg_valid_flat      := valid.asBits
    io.dbg_addr_valid_flat := addrValid.asBits
    io.dbg_issued_flat     := issued.asBits
    io.dbg_issue_en        := issueEn
  }
}
