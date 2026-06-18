package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/rename/rob.sv` -- the reorder buffer (in-order
  * commit + RVFI retirement record + branch/mem-violation flush).
  *
  * ROB_DEPTH rows x ID_WIDTH slots. Since rob_id = row*ID_WIDTH + slot, the entry
  * arrays are flat Vecs of ROB_DEPTH*ID_WIDTH indexed by rob_id directly. Push at
  * tail on dispatch; CDB snoop sets ready + fills the rvfi record; slot-granular
  * commit at head with violation/branch squashing of younger slots; flush clears
  * valid/ready and the pointers.
  *
  * Named rob_spinal; sim/swap_shims/rob.sv carries the six SV interfaces, rebuilds
  * the hierarchically-tapped `rvfi_dbg_t rvfi_itf[ID_WIDTH]` from rvfi_itf_flat, and
  * surfaces the perf_monitor-tapped internals (viol_flush/pop/empty/branch_flush/
  * commit_instr/head_ptr_reg/tail_ptr_reg) from the dbg_* outputs.
  */
class Rob(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("rob_spinal")
  val IDW   = cfg.idWidth        // 2
  val CDBW  = cfg.cdbWidth       // 5
  val DEPTH = cfg.robDepth       // 32
  val PIDX  = cfg.robPtrIdx      // 5
  val RIDX  = cfg.robIdx         // 6
  val PRF   = cfg.prfIdx         // 6
  val ARF   = cfg.arfIdx         // 5
  val IIDX  = log2Up(IDW)        // 1
  val N     = DEPTH * IDW        // 64 flat entries
  val RVFIW = 1 + 64 + 32 + 5 + 5 + 32 + 32 + 5 + 32 + 5 + 32 + 32 + 32 + 32 + 4 + 4 + 32 + 32  // 413

  // rvfi_dbg_t. toBits/fromBits mirror the SV packed struct EXACTLY (first field is
  // MSB) -- SpinalHDL's auto asBits/assignFromBits order is not trusted across the
  // SV boundary (only the set fields commit/order/rd_wdata/... would scramble).
  case class RvfiDbg() extends Bundle {
    val commit = Bool(); val order = Bits(64 bits); val inst = Bits(32 bits)
    val rs1_addr = Bits(5 bits); val rs2_addr = Bits(5 bits)
    val rs1_rdata = Bits(32 bits); val rs2_rdata = Bits(32 bits)
    val rd_addr = Bits(5 bits); val rd_wdata = Bits(32 bits)
    val frd_addr = Bits(5 bits); val frd_wdata = Bits(32 bits)
    val pc_rdata = Bits(32 bits); val pc_wdata = Bits(32 bits)
    val mem_addr = Bits(32 bits); val mem_rmask = Bits(4 bits); val mem_wmask = Bits(4 bits)
    val mem_rdata = Bits(32 bits); val mem_wdata = Bits(32 bits)
    def toBits: Bits = commit.asBits ## order ## inst ## rs1_addr ## rs2_addr ##
      rs1_rdata ## rs2_rdata ## rd_addr ## rd_wdata ## frd_addr ## frd_wdata ##
      pc_rdata ## pc_wdata ## mem_addr ## mem_rmask ## mem_wmask ## mem_rdata ## mem_wdata
  }

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush       = out Bool()
    val backend_redirect_pc = out Bits (32 bits)
    // id_rob_itf.rob from_id
    val from_id_valid        = in  Bool()
    val from_id_ready        = out Bool()
    val from_id_inst_valid   = in  Bits (IDW bits)
    val from_id_rob_id_flat  = out Bits (IDW * RIDX bits)
    val from_id_rd_phy_flat  = in  Bits (IDW * PRF bits)
    val from_id_rd_arch_flat = in  Bits (IDW * ARF bits)
    val from_id_is_store     = in  Bits (IDW bits)
    val from_id_is_atomic    = in  Bits (IDW bits)   // RV32A (aExt)
    val from_id_rvfi_dbg_flat = in Bits (IDW * RVFIW bits)
    // rob_rrf_itf.rob to_rrf
    val to_rrf_valid        = out Bits (IDW bits)
    val to_rrf_rd_phy_flat  = out Bits (IDW * PRF bits)
    val to_rrf_rd_arch_flat = out Bits (IDW * ARF bits)
    // cdb_itf.rob cdb[CDB_WIDTH]
    val cdb_valid        = in Bits (CDBW bits)
    val cdb_rob_id_flat  = in Bits (CDBW * RIDX bits)
    val cdb_rd_value_flat = in Bits (CDBW * 32 bits)
    val cdb_rs1_dbg_flat = in Bits (CDBW * 32 bits)
    val cdb_rs2_dbg_flat = in Bits (CDBW * 32 bits)
    // cb_rob_itf.rob from_cb
    val from_cb_rob_id         = in  Bits (RIDX bits)
    val from_cb_miss_predict   = in  Bool()
    val from_cb_target_address = in  Bits (32 bits)
    val from_cb_ready          = in  Bool()
    val from_cb_dequeue        = out Bool()
    // stq_rob_itf.rob from_stq
    val from_stq_rob_id        = in  Bits (RIDX bits)
    val from_stq_addr_dbg      = in  Bits (32 bits)
    val from_stq_wmask_dbg     = in  Bits (4 bits)
    val from_stq_wdata_dbg     = in  Bits (32 bits)
    val from_stq_rs1_value_dbg = in  Bits (32 bits)
    val from_stq_rs2_value_dbg = in  Bits (32 bits)
    val from_stq_valid         = in  Bool()
    val from_stq_ready         = out Bool()
    // ldq_rob_itf.rob from_ldq
    val from_ldq_rob_id           = in Bits (RIDX bits)
    val from_ldq_addr_dbg         = in Bits (32 bits)
    val from_ldq_rmask_dbg        = in Bits (4 bits)
    val from_ldq_rdata_dbg        = in Bits (32 bits)
    val from_ldq_valid            = in Bool()
    val from_ldq_violation        = in Bool()
    val from_ldq_violation_rob_id = in Bits (RIDX bits)
    // RV32A: head handshake to the AtomicUnit (atomic is oldest & not yet executed)
    val atomic_go        = out Bool()
    val atomic_go_rob_id = out Bits (RIDX bits)
    // rvfi_itf[ID_WIDTH] (hierarchically tapped, rebuilt in the shim)
    val rvfi_itf_flat = out Bits (IDW * RVFIW bits)
    // perf_monitor-tapped internals
    val dbg_viol_flush   = out Bool()
    val dbg_pop          = out Bool()
    val dbg_empty        = out Bool()
    val dbg_branch_flush = out Bool()
    val dbg_commit_instr = out Bits (IDW bits)
    val dbg_head_ptr_reg = out Bits (PIDX + 1 bits)
    val dbg_tail_ptr_reg = out Bits (PIDX + 1 bits)
  }
  noIoPrefix()

  // input slice helpers
  def fromIdRdPhy(i: Int)  = io.from_id_rd_phy_flat(i * PRF, PRF bits)
  def fromIdRdArch(i: Int) = io.from_id_rd_arch_flat(i * ARF, ARF bits)
  def fromIdRvfi(i: Int)   = io.from_id_rvfi_dbg_flat(i * RVFIW, RVFIW bits)
  def cdbRobId(k: Int)     = io.cdb_rob_id_flat(k * RIDX, RIDX bits).asUInt
  def cdbRdValue(k: Int)   = io.cdb_rd_value_flat(k * 32, 32 bits)
  def cdbRs1Dbg(k: Int)    = io.cdb_rs1_dbg_flat(k * 32, 32 bits)
  def cdbRs2Dbg(k: Int)    = io.cdb_rs2_dbg_flat(k * 32, 32 bits)
  // unpack an SV-packed rvfi_dbg_t (LSB-first cumulative; mirrors toBits)
  def rvfiFromBits(b: Bits): RvfiDbg = {
    val e = RvfiDbg(); var o = 0
    def take(w: Int): Bits = { val s = b(o, w bits); o += w; s }
    e.mem_wdata := take(32); e.mem_rdata := take(32); e.mem_wmask := take(4); e.mem_rmask := take(4)
    e.mem_addr := take(32); e.pc_wdata := take(32); e.pc_rdata := take(32)
    e.frd_wdata := take(32); e.frd_addr := take(5); e.rd_wdata := take(32); e.rd_addr := take(5)
    e.rs2_rdata := take(32); e.rs1_rdata := take(32); e.rs2_addr := take(5); e.rs1_addr := take(5)
    e.inst := take(32); e.order := take(64); e.commit := take(1).asBool
    e
  }

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // ---- flat entry storage (indexed by rob_id) ----
    val robValid   = Vec(RegInit(False), N)
    val robReady   = Vec(RegInit(False), N)
    val robRdPhy   = Vec(Reg(Bits(PRF bits)), N)
    val robRdArch  = Vec(Reg(Bits(ARF bits)), N)
    val robIsStore = Vec(Reg(Bool()), N)
    val robIsAtomic = Vec(Reg(Bool()), N)   // RV32A (aExt)
    val robMemViol = Vec(Reg(Bool()), N)
    val rvfiArr    = Vec(Reg(RvfiDbg()), N)
    val headPtrReg = RegInit(U(0, PIDX + 1 bits))
    val tailPtrReg = RegInit(U(0, PIDX + 1 bits))
    val rvfiOrder  = RegInit(U(0, 64 bits))

    val headPtr  = headPtrReg(PIDX - 1 downto 0)
    val headFlag = headPtrReg(PIDX)
    val tailPtr  = tailPtrReg(PIDX - 1 downto 0)
    val tailFlag = tailPtrReg(PIDX)
    val full  = (tailPtr === headPtr) && (tailFlag =/= headFlag)
    val empty = (tailPtr === headPtr) && (tailFlag === headFlag)

    def headIdx(slot: Int): UInt = headPtr @@ U(slot, IIDX bits)
    def headIdxU(slot: UInt): UInt = headPtr @@ slot.resize(IIDX bits)
    def tailIdx(slot: Int): UInt = tailPtr @@ U(slot, IIDX bits)

    // ---- store-queue commit readiness (drives pop) ----
    val stqEntry = io.from_stq_rob_id(RIDX - 1 downto IIDX).asUInt
    var srAcc: Bool = (stqEntry === headPtr)
    for (i <- 0 until IDW) {
      srAcc = srAcc && !(robValid(headIdx(i)) && !robIsStore(headIdx(i)) && !robReady(headIdx(i)))
    }
    val stqReady = srAcc
    io.from_stq_ready := stqReady

    // ---- pop ----
    val pop = Bool()
    when(empty) { pop := False }
    .elsewhen(io.from_stq_valid && stqReady) { pop := True }
    .otherwise {
      pop := (0 until IDW).map(i => !(robValid(headIdx(i)) && !robReady(headIdx(i)))).reduce(_ && _)
    }

    // ---- memory-ordering violation (lowest/oldest slot wins) ----
    val violFlush = Bool(); violFlush := False
    val violSlot  = UInt(IIDX bits); violSlot := 0
    for (i <- IDW - 1 downto 0) {
      when(pop && robValid(headIdx(i)) && robMemViol(headIdx(i))) {
        violFlush := True; violSlot := U(i, IIDX bits)
      }
    }

    // ---- RV32A: fence-like atomic commit. An AMO/LR/SC is not in the STQ, so the
    // LDQ can't squash a younger load that read its address before the RMW. When the
    // atomic commits, flush everything younger (redirect to pc+4) so it re-executes
    // observing the atomic's memory effect. The atomic is the oldest entry when it
    // becomes ready, so it wins the redirect over any younger branch/violation.
    val atomicFlush = Bool(); atomicFlush := False
    val atomicSlot  = UInt(IIDX bits); atomicSlot := 0
    if (cfg.aExt) {
      for (i <- IDW - 1 downto 0) {
        when(pop && robValid(headIdx(i)) && robIsAtomic(headIdx(i)) && robReady(headIdx(i))) {
          atomicFlush := True; atomicSlot := U(i, IIDX bits)
        }
      }
    }

    // ---- branch resolution / flush / redirect ----
    val brSlot   = io.from_cb_rob_id(IIDX - 1 downto 0).asUInt
    val cbEntry  = io.from_cb_rob_id(RIDX - 1 downto IIDX).asUInt
    val dequeue  = Mux(io.from_cb_ready, pop && (cbEntry === headPtr), False)
    io.from_cb_dequeue := dequeue
    val branchFlush  = dequeue && io.from_cb_miss_predict
    val backendFlush = branchFlush || violFlush || atomicFlush
    io.backend_flush := backendFlush
    // Oldest flush cause wins the redirect. Previously violFlush unconditionally won,
    // which was correct only because br-older-than-violating-load never shared a row
    // (id_stage serialized br0+mem1). With br0+load1 now allowed, an older branch must
    // redirect to its target rather than the younger squashed load's PC.
    val brWins = branchFlush && (!violFlush || (brSlot < violSlot))
    io.backend_redirect_pc := Mux(atomicFlush, (rvfiArr(headIdxU(atomicSlot)).pc_rdata.asUInt + 4).asBits,
                               Mux(brWins, io.from_cb_target_address, rvfiArr(headIdxU(violSlot)).pc_rdata))

    // ---- slot-granular commit ----
    val commitInstr = Vec(Bool(), IDW)
    for (i <- 0 until IDW) {
      commitInstr(i) := pop && robValid(headIdx(i)) &&
        !(violFlush && (U(i, IIDX bits) >= violSlot)) &&
        !(branchFlush && (U(i, IIDX bits) > brSlot)) &&
        !(atomicFlush && (U(i, IIDX bits) > atomicSlot))
    }

    // ---- from_id / to_rrf ----
    io.from_id_ready := !full
    val robIdOut = Vec(Bits(RIDX bits), IDW)
    for (i <- 0 until IDW) robIdOut(i) := (tailPtr @@ U(i, IIDX bits)).resize(RIDX bits).asBits
    io.from_id_rob_id_flat := robIdOut.asBits
    val rrfPhy  = Vec(Bits(PRF bits), IDW)
    val rrfArch = Vec(Bits(ARF bits), IDW)
    for (i <- 0 until IDW) { rrfPhy(i) := robRdPhy(headIdx(i)); rrfArch(i) := robRdArch(headIdx(i)) }
    io.to_rrf_valid := commitInstr.asBits
    io.to_rrf_rd_phy_flat := rrfPhy.asBits
    io.to_rrf_rd_arch_flat := rrfArch.asBits

    // ---- RVFI order prefix + per-slot output ----
    val rvfiOut = Vec(RvfiDbg(), IDW)
    var acc: UInt = U(0, 64 bits)
    for (i <- 0 until IDW) {
      val head    = rvfiArr(headIdx(i))
      val stqSlot = io.from_stq_rob_id(IIDX - 1 downto 0).asUInt
      val stqHit  = io.from_stq_valid && stqReady && (stqSlot === U(i, IIDX bits))
      val brHit   = branchFlush && (brSlot === U(i, IIDX bits))
      val o = rvfiOut(i)
      o.commit    := commitInstr(i)
      o.order     := (rvfiOrder + acc).asBits
      o.inst      := head.inst
      o.rs1_addr  := head.rs1_addr
      o.rs2_addr  := head.rs2_addr
      o.rs1_rdata := Mux(stqHit, io.from_stq_rs1_value_dbg, head.rs1_rdata)
      o.rs2_rdata := Mux(stqHit, io.from_stq_rs2_value_dbg, head.rs2_rdata)
      o.rd_addr   := head.rd_addr
      o.rd_wdata  := head.rd_wdata
      o.frd_addr  := head.frd_addr
      o.frd_wdata := head.frd_wdata
      o.pc_rdata  := head.pc_rdata
      o.pc_wdata  := Mux(brHit, io.backend_redirect_pc, head.pc_wdata)
      o.mem_addr  := Mux(stqHit, io.from_stq_addr_dbg, head.mem_addr)
      o.mem_rmask := Mux(stqHit, B(0, 4 bits), head.mem_rmask)
      o.mem_wmask := Mux(stqHit, io.from_stq_wmask_dbg, head.mem_wmask)
      o.mem_rdata := Mux(stqHit, B(0, 32 bits), head.mem_rdata)
      o.mem_wdata := Mux(stqHit, io.from_stq_wdata_dbg, head.mem_wdata)
      acc = acc + commitInstr(i).asUInt.resize(64 bits)
    }
    val commitInstrs = acc
    val outFlat = Vec(Bits(RVFIW bits), IDW)
    for (i <- 0 until IDW) outFlat(i) := rvfiOut(i).toBits
    io.rvfi_itf_flat := outFlat.asBits

    // ---- registered state ----
    when(backendFlush) {
      for (w <- 0 until N) { robValid(w) := False; robReady(w) := False }
      headPtrReg := 0; tailPtrReg := 0
    }.otherwise {
      when(io.from_id_valid && !full) {                 // push
        tailPtrReg := tailPtrReg + 1
        for (i <- 0 until IDW) {
          robValid(tailIdx(i))   := io.from_id_inst_valid(i)
          robReady(tailIdx(i))   := False
          robRdPhy(tailIdx(i))   := fromIdRdPhy(i)
          robRdArch(tailIdx(i))  := fromIdRdArch(i)
          robIsStore(tailIdx(i)) := io.from_id_is_store(i)
          robIsAtomic(tailIdx(i)) := io.from_id_is_atomic(i)
          robMemViol(tailIdx(i)) := False
          rvfiArr(tailIdx(i))    := rvfiFromBits(fromIdRvfi(i))
        }
      }
      when(pop) { headPtrReg := headPtrReg + 1 }         // pop
      for (k <- 0 until CDBW) {                          // CDB snoop
        when(io.cdb_valid(k)) {
          robReady(cdbRobId(k))          := True
          rvfiArr(cdbRobId(k)).rd_wdata  := cdbRdValue(k)
          rvfiArr(cdbRobId(k)).rs1_rdata := cdbRs1Dbg(k)
          rvfiArr(cdbRobId(k)).rs2_rdata := cdbRs2Dbg(k)
        }
      }
      when(io.from_ldq_violation) {                      // mem violation flag
        robMemViol(io.from_ldq_violation_rob_id.asUInt) := True
      }
      when(io.from_ldq_valid) {                          // load rvfi fill
        val li = io.from_ldq_rob_id.asUInt
        rvfiArr(li).mem_addr  := io.from_ldq_addr_dbg
        rvfiArr(li).mem_rmask := io.from_ldq_rmask_dbg
        rvfiArr(li).mem_wmask := B(0, 4 bits)
        rvfiArr(li).mem_rdata := io.from_ldq_rdata_dbg
        rvfiArr(li).mem_wdata := B(0, 32 bits)
      }
    }
    // rvfi_order advances on pop (independent of flush; SV resets only on rst)
    when(pop) { rvfiOrder := rvfiOrder + commitInstrs }

    // ---- RV32A: drive the AtomicUnit when an atomic is the oldest not-yet-ready
    // entry at the head (all older head-row slots committed/ready). It executes the
    // RMW non-speculatively and broadcasts on the CDB -> robReady -> normal commit.
    val atomicGo = Bool(); atomicGo := False
    val atomicGoId = Bits(RIDX bits); atomicGoId := 0
    if (cfg.aExt) {
      for (i <- IDW - 1 downto 0) {
        val olderBusy = (0 until i).map(j => robValid(headIdx(j)) && !robReady(headIdx(j))).fold(False)(_ || _)
        when(robValid(headIdx(i)) && robIsAtomic(headIdx(i)) && !robReady(headIdx(i)) && !olderBusy) {
          atomicGo   := True
          atomicGoId := headIdx(i).resize(RIDX bits).asBits
        }
      }
    }
    io.atomic_go        := atomicGo
    io.atomic_go_rob_id := atomicGoId

    // ---- perf_monitor-tapped internals ----
    io.dbg_viol_flush   := violFlush
    io.dbg_pop          := pop
    io.dbg_empty        := empty
    io.dbg_branch_flush := branchFlush
    io.dbg_commit_instr := commitInstr.asBits
    io.dbg_head_ptr_reg := headPtrReg.asBits
    io.dbg_tail_ptr_reg := tailPtrReg.asBits
  }
}
