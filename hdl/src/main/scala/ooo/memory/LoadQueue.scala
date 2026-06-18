package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/memory/load_queue.sv` -- the load queue: holds in-flight
  * loads, fills addresses from the AGU (with same-cycle AGU-address bypass for
  * issue), issues to the D-cache once disambiguated (or forwards from the store
  * queue), parks speculative loads issued past unknown-address stores for
  * violation checking, and broadcasts the load result on the CDB.
  *
  * Named load_queue_spinal; sim/swap_shims/load_queue.sv carries the seven SV
  * interfaces and surfaces the perf_monitor-tapped per-entry valid/addr_valid/
  * issued + issue_en.
  */
class LoadQueue(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("load_queue_spinal")
  val LDQ  = cfg.ldqDepth      // 8
  val IDX  = cfg.ldqIdx        // 3
  val STW  = cfg.stqIdx + 1    // track/tail width (4)
  val RIDX = cfg.robIdx        // 6
  val PIDX = cfg.prfIdx        // 6
  val AIDX = cfg.arfIdx        // 5

  def MEM_LB  = B"4'b0000"; def MEM_LH = B"4'b0001"; def MEM_LW = B"4'b0010"
  def MEM_LBU = B"4'b0100"; def MEM_LHU = B"4'b0101"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    // ds_rs_mono_itf.rs from_ds
    val from_ds_valid        = in  Bool()
    val from_ds_ready        = out Bool()
    val from_ds_uop_rob_id   = in  Bits (RIDX bits)
    val from_ds_uop_fu_opcode = in Bits (4 bits)
    val from_ds_uop_rd_arch  = in  Bits (AIDX bits)
    val from_ds_uop_rd_phy   = in  Bits (PIDX bits)
    // agu_lsq_itf.lsq from_agu
    val from_agu_valid = in Bool()
    val from_agu_data  = in Bits (138 bits)
    // cdb_itf.fu cdb_out
    val cdb_rob_id        = out Bits (RIDX bits)
    val cdb_rd_phy        = out Bits (PIDX bits)
    val cdb_rd_arch       = out Bits (AIDX bits)
    val cdb_rd_value      = out Bits (32 bits)
    val cdb_rs1_value_dbg = out Bits (32 bits)
    val cdb_rs2_value_dbg = out Bits (32 bits)
    val cdb_valid         = out Bool()
    // ldq_rob_itf.ldq to_rob
    val to_rob_rob_id           = out Bits (RIDX bits)
    val to_rob_addr_dbg         = out Bits (32 bits)
    val to_rob_rmask_dbg        = out Bits (4 bits)
    val to_rob_rdata_dbg        = out Bits (32 bits)
    val to_rob_valid            = out Bool()
    val to_rob_violation        = out Bool()
    val to_rob_violation_rob_id = out Bits (RIDX bits)
    // ldq_dmem_itf.ldq dmem
    val dmem_valid = out Bool()
    val dmem_ready = in  Bool()
    val dmem_addr  = out Bits (32 bits)
    val dmem_rmask = out Bits (4 bits)
    val dmem_resp  = in  Bool()
    val dmem_rdata = in  Bits (32 bits)
    // ldq_stq_itf.ldq from_stq
    val stq_tail              = in  Bits (STW bits)
    val stq_deq               = in  Bool()
    val stq_has_conf          = in  Bits (LDQ bits)
    val stq_known_conflict    = in  Bits (LDQ bits)
    val stq_unknown_older     = in  Bits (LDQ bits)
    val stq_forward_en        = in  Bits (LDQ bits)
    val stq_forward_wdata_flat = in Bits (LDQ * 32 bits)
    val ldq_tracker_flat = out Bits (LDQ * STW bits)
    val ldq_addr_flat    = out Bits (LDQ * 32 bits)
    val ldq_rmask_flat   = out Bits (LDQ * 4 bits)
    // ldq_stb_itf.ldq from_stb
    val stb_has_conf      = in  Bits (LDQ bits)
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
  val aguRobId = io.from_agu_data(137 downto 132)
  val aguAddr  = io.from_agu_data(131 downto 100)
  val aguMask  = io.from_agu_data(67 downto 64)
  val aguRs1   = io.from_agu_data(63 downto 32)
  val aguRs2   = io.from_agu_data(31 downto 0)
  def stqFwdWdata(i: UInt) = io.stq_forward_wdata_flat.subdivideIn(LDQ slices)(i)

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

    // ---- push select (first free slot) ----
    val canPush = io.from_ds_valid && io.from_ds_ready && !io.from_ds_uop_fu_opcode(3)
    val pushEn = Bool(); pushEn := False
    val pushIdx = UInt(IDX bits); pushIdx := 0
    for (i <- LDQ - 1 downto 0) { when(canPush && !valid(i)) { pushEn := True; pushIdx := U(i, IDX bits) } }
    io.from_ds_ready := (0 until LDQ).map(i => !valid(i)).reduce(_ || _)

    // ---- AGU-address bypass ----
    val aguHit   = Vec(Bool(), LDQ)
    val effAddr  = Vec(Bits(32 bits), LDQ)
    val effMask  = Vec(Bits(4 bits), LDQ)
    val effAvalid = Vec(Bool(), LDQ)
    for (i <- 0 until LDQ) {
      aguHit(i)    := io.from_agu_valid && valid(i) && !addrValid(i) && (robId(i) === aguRobId)
      effAddr(i)   := Mux(aguHit(i), aguAddr, addr(i))
      effMask(i)   := Mux(aguHit(i), aguMask, mask(i))
      effAvalid(i) := addrValid(i) || aguHit(i)
      io.ldq_tracker_flat(i * STW, STW bits) := track(i).asBits
      io.ldq_addr_flat(i * 32, 32 bits)      := effAddr(i)
      io.ldq_rmask_flat(i * 4, 4 bits)       := effMask(i)
      io.stb_ldq_addr_flat(i * 32, 32 bits)  := effAddr(i)
      io.stb_ldq_rmask_flat(i * 4, 4 bits)   := effMask(i)
    }

    // ---- issue select (lowest disambiguated/forwardable load) ----
    val issueEn = Bool(); issueEn := False
    val issueIdx = UInt(IDX bits); issueIdx := 0
    for (i <- LDQ - 1 downto 0) {
      val ok = valid(i) && effAvalid(i) && !issued(i) &&
        ((!io.stq_known_conflict(i) && !io.stb_has_conf(i)) || io.stq_forward_en(i))
      when(ok) { issueEn := True; issueIdx := U(i, IDX bits) }
    }
    io.dmem_valid := issueEn && !io.backend_flush

    // ---- next-state (mirrors ldq_arr_nxt) ----
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
      when(io.stq_unknown_older(issueIdx)) { nIssued(issueIdx) := True; nSpec(issueIdx) := True }
        .otherwise { nValid(issueIdx) := False }
    }

    // ---- register next-state (valid cleared on rst/flush; rest hold on flush) ----
    when(io.backend_flush) {
      for (i <- 0 until LDQ) valid(i) := False
    }.otherwise {
      for (i <- 0 until LDQ) {
        valid(i) := nValid(i); addrValid(i) := nAddrValid(i); issued(i) := nIssued(i); spec(i) := nSpec(i)
        track(i) := nTrack(i); robId(i) := nRobId(i); fuOp(i) := nFuOp(i); addr(i) := nAddr(i)
        mask(i) := nMask(i); rdArch(i) := nRdArch(i); rdPhy(i) := nRdPhy(i); rs1dbg(i) := nRs1(i); rs2dbg(i) := nRs2(i)
      }
    }

    // ---- memory-ordering violation (highest matching slot wins) ----
    io.to_rob_violation := False; io.to_rob_violation_rob_id := 0
    for (i <- 0 until LDQ) {
      when(valid(i) && issued(i) && spec(i) && io.stq_known_conflict(i)) {
        io.to_rob_violation := True; io.to_rob_violation_rob_id := robId(i)
      }
    }

    // ---- D-cache request ----
    val dmemAddr = effAddr(issueIdx)(31 downto 2) ## B(0, 2 bits)
    io.dmem_addr  := dmemAddr
    io.dmem_rmask := effMask(issueIdx)

    // ---- load stage register ----
    val lsrRobId = Reg(Bits(RIDX bits)); val lsrAddr2 = Reg(UInt(2 bits)); val lsrFuOp = Reg(Bits(4 bits))
    val lsrRdArch = Reg(Bits(AIDX bits)); val lsrRdPhy = Reg(Bits(PIDX bits)); val lsrAddrDbg = Reg(Bits(32 bits))
    val lsrMaskDbg = Reg(Bits(4 bits)); val lsrRs1 = Reg(Bits(32 bits)); val lsrRs2 = Reg(Bits(32 bits))
    val lsrFwdEn = Reg(Bool()); val lsrFwdWdata = Reg(Bits(32 bits))
    when(io.dmem_valid && io.dmem_ready) {
      lsrRobId := robId(issueIdx); lsrAddr2 := effAddr(issueIdx)(1 downto 0).asUInt; lsrFuOp := fuOp(issueIdx)
      lsrRdArch := rdArch(issueIdx); lsrRdPhy := rdPhy(issueIdx); lsrAddrDbg := dmemAddr
      lsrMaskDbg := effMask(issueIdx)
      lsrRs1 := Mux(aguHit(issueIdx), aguRs1, rs1dbg(issueIdx))
      lsrRs2 := Mux(aguHit(issueIdx), aguRs2, rs2dbg(issueIdx))
      lsrFwdEn := io.stq_forward_en(issueIdx); lsrFwdWdata := stqFwdWdata(issueIdx)
    }

    // ---- load result formatting ----
    val dmemRdata = Mux(lsrFwdEn, lsrFwdWdata, io.dmem_rdata)
    val byteSel = dmemRdata.subdivideIn(8 bits)(lsrAddr2)
    val halfSel = dmemRdata.subdivideIn(16 bits)(lsrAddr2(1).asUInt)
    val rdataWb = Bits(32 bits)
    switch(lsrFuOp) {
      is(MEM_LB)  { rdataWb := byteSel.asSInt.resize(32 bits).asBits }
      is(MEM_LBU) { rdataWb := byteSel.resize(32 bits) }
      is(MEM_LH)  { rdataWb := halfSel.asSInt.resize(32 bits).asBits }
      is(MEM_LHU) { rdataWb := halfSel.resize(32 bits) }
      is(MEM_LW)  { rdataWb := dmemRdata }
      default     { rdataWb := B(0, 32 bits) }
    }

    // ---- CDB + ROB outputs (combinational pass-through on dmem.resp) ----
    io.cdb_valid         := io.dmem_resp
    io.cdb_rob_id        := lsrRobId
    io.cdb_rd_phy        := lsrRdPhy
    io.cdb_rd_arch       := lsrRdArch
    io.cdb_rd_value      := rdataWb
    io.cdb_rs1_value_dbg := lsrRs1
    io.cdb_rs2_value_dbg := lsrRs2
    io.to_rob_valid     := io.dmem_resp
    io.to_rob_rob_id    := lsrRobId
    io.to_rob_addr_dbg  := lsrAddrDbg
    io.to_rob_rmask_dbg := lsrMaskDbg
    io.to_rob_rdata_dbg := dmemRdata

    // ---- perf taps ----
    io.dbg_valid_flat      := valid.asBits
    io.dbg_addr_valid_flat := addrValid.asBits
    io.dbg_issued_flat     := issued.asBits
    io.dbg_issue_en        := issueEn
  }
}
