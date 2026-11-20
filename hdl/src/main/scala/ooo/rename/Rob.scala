package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** Two-wide reorder buffer with ordered retirement and recovery. */
class Rob(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("rob_spinal")
  val IDW   = cfg.idWidth
  val CDBW  = cfg.cdbWidth       // [CDB_WIDTH]
  val DEPTH = cfg.robDepth
  val PIDX  = cfg.robPtrIdx
  val RIDX  = cfg.robIdx
  val PRF   = cfg.prfIdx
  val ARF   = cfg.arfIdx
  val IIDX  = log2Up(IDW)
  val N     = DEPTH * IDW        // 64 flat entries
  val RVFIW = cfg.rvfiDbgW

  // Explicit packing matches pkg/types.sv: commit is the MSB, intr the LSB.
  case class RvfiDbg() extends Bundle {
    val commit = Bool(); val order = Bits(64 bits); val inst = Bits(32 bits)
    val rs1_addr = Bits(5 bits); val rs2_addr = Bits(5 bits)
    val rs1_rdata = Bits(32 bits); val rs2_rdata = Bits(32 bits)
    val rd_addr = Bits(5 bits); val rd_wdata = Bits(32 bits)
    val frd_addr = Bits(5 bits); val frd_wdata = Bits(32 bits)
    val pc_rdata = Bits(32 bits); val pc_wdata = Bits(32 bits)
    val mem_addr = Bits(32 bits); val mem_rmask = Bits(4 bits); val mem_wmask = Bits(4 bits)
    val mem_rdata = Bits(32 bits); val mem_wdata = Bits(32 bits)
    val intr = Bool()   // first instruction retired after a trap (LSB of the SV struct)
    def toBits: Bits = commit.asBits ## order ## inst ## rs1_addr ## rs2_addr ##
      rs1_rdata ## rs2_rdata ## rd_addr ## rd_wdata ## frd_addr ## frd_wdata ##
      pc_rdata ## pc_wdata ## mem_addr ## mem_rmask ## mem_wmask ## mem_rdata ## mem_wdata ## intr.asBits
  }

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush       = out Bool()
    val flush_causes = if (cfg.distributedFlush) out Bits(6 bits) else null
    val backend_redirect_pc = out Bits (32 bits)
    val from_id_valid        = in  Bool()
    val from_id_ready        = out Bool()
    val from_id_inst_valid   = in  Bits (IDW bits)
    val from_id_rob_id_flat  = out Bits (IDW * RIDX bits)
    val from_id_rd_phy_flat  = in  Bits (IDW * PRF bits)
    val from_id_rd_arch_flat = in  Bits (IDW * ARF bits)
    val from_id_is_store     = in  Bits (IDW bits)
    val from_id_memory = if (cfg.mmio) in Bits(IDW bits) else null
    val from_id_compressed = if (cfg.mmio) in Bits(IDW bits) else null
    val device_mark = if (cfg.mmio) in Bool() else null
    val device_mark_id = if (cfg.mmio) in Bits(RIDX bits) else null
    val device_go = if (cfg.mmio) out Bool() else null
    val device_go_id = if (cfg.mmio) out Bits(RIDX bits) else null
    val wfi_held = if (cfg.lowPower) in Bool() else null
    val sleep_request = if (cfg.lowPower) out Bool() else null
    val from_id_is_atomic    = in  Bits (IDW bits)   // RV32A (aExt)
    val from_id_rvfi_dbg_flat = in Bits (IDW * RVFIW bits)
    val to_rrf_valid        = out Bits (IDW bits)
    val to_rrf_rd_phy_flat  = out Bits (IDW * PRF bits)
    val to_rrf_rd_arch_flat = out Bits (IDW * ARF bits)
    val cdb_valid        = in Bits (CDBW bits)
    val cdb_rob_id_flat  = in Bits (CDBW * RIDX bits)
    val cdb_rd_value_flat = in Bits (CDBW * 32 bits)
    val cdb_rs1_dbg_flat = in Bits (CDBW * 32 bits)
    val cdb_rs2_dbg_flat = in Bits (CDBW * 32 bits)
    val from_cb_rob_id         = in  Bits (RIDX bits)
    val from_cb_miss_predict   = in  Bool()
    val from_cb_target_address = in  Bits (32 bits)
    val from_cb_ready          = in  Bool()
    val from_cb_dequeue        = out Bool()
    val from_stq_rob_id        = in  Bits (RIDX bits)
    val from_stq_addr_dbg      = in  Bits (32 bits)
    val from_stq_wmask_dbg     = in  Bits (4 bits)
    val from_stq_wdata_dbg     = in  Bits (32 bits)
    val from_stq_rs1_value_dbg = in  Bits (32 bits)
    val from_stq_rs2_value_dbg = in  Bits (32 bits)
    val from_stq_valid         = in  Bool()
    val from_stq_ready         = out Bool()
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
    // Zicsr (ports exist only when cfg.zicsr)
    // decode-time exceptions ride in with the dispatch group
    val from_id_exc_valid      = if (cfg.zicsr) in Bits (IDW bits) else null
    val from_id_exc_cause_flat = if (cfg.zicsr) in Bits (IDW * 4 bits) else null
    val from_id_exc_tval_flat  = if (cfg.zicsr) in Bits (IDW * 32 bits) else null
    // late exceptions: (a) AGU misaligned load/store, (c) illegal CSR access (CsrUnit)
    val exc_a_valid  = if (cfg.zicsr) in Bool() else null
    val exc_a_rob_id = if (cfg.zicsr) in Bits (RIDX bits) else null
    val exc_a_cause  = if (cfg.zicsr) in Bits (4 bits) else null
    val exc_a_tval   = if (cfg.zicsr) in Bits (32 bits) else null
    val exc_c_valid  = if (cfg.zicsr) in Bool() else null
    val exc_c_rob_id = if (cfg.zicsr) in Bits (RIDX bits) else null
    // interrupt request (Csr.irq_pending, already gated by mstatus.MIE)
    val irq_pending = if (cfg.zicsr) in Bool() else null
    val irq_cause   = if (cfg.zicsr) in Bits (32 bits) else null
    // trap entry -> Csr, and the redirect targets it hands back
    val trap_en     = if (cfg.zicsr) out Bool() else null
    val trap_cause  = if (cfg.zicsr) out Bits (32 bits) else null
    val trap_epc    = if (cfg.zicsr) out Bits (32 bits) else null
    val trap_tval   = if (cfg.zicsr) out Bits (32 bits) else null
    val trap_vector = if (cfg.zicsr) in Bits (32 bits) else null
    val mret_pc     = if (cfg.zicsr) in Bits (32 bits) else null
    val mret_held   = if (cfg.zicsr) in Bool() else null     // CsrUnit: last serial op was mret
    val instret_inc = if (cfg.zicsr) out UInt (log2Up(IDW + 1) bits) else null
    // valid entries OLDER than the serial op being handed `go` in its own head row:
    // they retire in the same pop as the CSR op, so minstret as observed by the op
    // must already include them (CsrUnit carries this into the counter read)
    val go_older    = if (cfg.zicsr) out UInt (log2Up(IDW + 1) bits) else null
    // Packed per-retirement RVFI records
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
  // Decode the LSB-first retirement debug payload.
  def rvfiFromBits(b: Bits): RvfiDbg = {
    val e = RvfiDbg(); var o = 0
    def take(w: Int): Bits = { val s = b(o, w bits); o += w; s }
    e.intr := take(1).asBool
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
    // flat entry storage (indexed by rob_id)
    val robValid   = Vec(RegInit(False), N)
    val robReady   = Vec(RegInit(False), N)
    val robRdPhy   = Vec(Reg(Bits(PRF bits)), N)
    val robRdArch  = Vec(Reg(Bits(ARF bits)), N)
    val robIsStore = Vec(Reg(Bool()), N)
    val headSummary = cfg.robStqSummary || cfg.robSerialSummary
    val validNext = if (headSummary) Vec(Bool(), N) else robValid
    val readyNext = if (cfg.robStqSummary) Vec(Bool(), N) else robReady
    val storeNext = if (cfg.robStqSummary) Vec(Bool(), N) else robIsStore
    val robIsAtomic = Vec(Reg(Bool()), N)   // RV32A (aExt); with Zicsr also CSR/mret ("serial at head")
    val robMemViol = Vec(Reg(Bool()), N)
    val robDevice = if (cfg.mmio) Vec(Reg(Bool()),N) else null
    val atomicNext = if (cfg.robSerialSummary) Vec(Bool(),N) else robIsAtomic
    val deviceNext = if (cfg.mmio && cfg.robSerialSummary) Vec(Bool(),N) else robDevice
    val robMemory = if (cfg.mmio) Vec(Reg(Bool()),N) else null
    val robCompressed = if (cfg.mmio) Vec(Reg(Bool()),N) else null
    // Zicsr: exception pending on this entry (+ its mcause code). An exception entry
    // is READY from the moment it is marked -- nothing will execute for it; it exists
    // to reach the head in order and trap there.
    val robExc   = if (cfg.zicsr) Vec(Reg(Bool()), N) else null
    val robCause = if (cfg.zicsr) Vec(Reg(Bits(4 bits)), N) else null
    // NoRvfi product config: only the per-entry PC survives (it sources the
    // violation/atomic redirect); the full record + order counter elaborate
    // only when cfg.rvfi -- constant-tying at ports cannot sweep across the
    // hierarchy-preserving synthesis flow, so the logic must not exist.
    val rvfiArr = if (cfg.rvfi) Vec(Reg(RvfiDbg()), N) else null
    val pcArr   = if (cfg.rvfi) null else Vec(Reg(Bits(32 bits)), N)
    def entryPc(idx: UInt): Bits = if (cfg.rvfi) rvfiArr(idx).pc_rdata else pcArr(idx)
    val headPtrReg = RegInit(U(0, PIDX + 1 bits))
    val headRowSelect = Reg(Bits(DEPTH bits)) init(B(1, DEPTH bits))
    headRowSelect.setName("headRowSelect")
    val tailPtrReg = RegInit(U(0, PIDX + 1 bits))
    val rvfiOrder  = if (cfg.rvfi) RegInit(U(0, 64 bits)) else null

    val headSelectNext = if (headSummary) Bits(DEPTH bits) else headRowSelect
    val stqHeadReady = if (cfg.robStqSummary) RegInit(True) else null
    if (headSummary) {
      headSelectNext := headRowSelect
      headRowSelect := headSelectNext
      for (i <- 0 until N) { validNext(i) := robValid(i); robValid(i) := validNext(i) }
    }
    if (cfg.robStqSummary) {
      stqHeadReady.setName("stqHeadReady")
      for (i <- 0 until N) {
        readyNext(i) := robReady(i); storeNext(i) := robIsStore(i)
        robReady(i) := readyNext(i); robIsStore(i) := storeNext(i)
      }
      // Summarize the next head and next entry state on the same clock edge.
      stqHeadReady := ooo.OhSel.bool(headSelectNext, (0 until DEPTH).map { row =>
        (0 until IDW).map { slot =>
          val i = row * IDW + slot
          !validNext(i) || storeNext(i) || readyNext(i)
        }.reduce(_ && _)
      })
    }

    val serialHead = if (cfg.robSerialSummary) RegInit(False).setName("serialHead") else null
    if (cfg.robSerialSummary) {
      for (i <- 0 until N) {
        atomicNext(i) := robIsAtomic(i); robIsAtomic(i) := atomicNext(i)
        if (cfg.mmio) { deviceNext(i) := robDevice(i); robDevice(i) := deviceNext(i) }
      }
      serialHead := ooo.OhSel.bool(headSelectNext, (0 until DEPTH).map { row =>
        (0 until IDW).map { slot =>
          val i = row * IDW + slot
          validNext(i) && (atomicNext(i) || (if (cfg.mmio) deviceNext(i) else False))
        }.reduce(_ || _)
      })
    }

    val headPtr  = headPtrReg(PIDX - 1 downto 0)
    val headFlag = headPtrReg(PIDX)
    val tailPtr  = tailPtrReg(PIDX - 1 downto 0)
    val tailFlag = tailPtrReg(PIDX)
    val full  = (tailPtr === headPtr) && (tailFlag =/= headFlag)
    val empty = (tailPtr === headPtr) && (tailFlag === headFlag)

    def headIdx(slot: Int): UInt = headPtr @@ U(slot, IIDX bits)
    def headIdxU(slot: UInt): UInt = headPtr @@ slot.resize(IIDX bits)
    def tailIdx(slot: Int): UInt = tailPtr @@ U(slot, IIDX bits)
    // Resolve row predicates before selecting the head; keep the pointer off their logic chains.
    def headRow(predicate: Int => Bool): Bool =
      ooo.OhSel.bool(headRowSelect, (0 until DEPTH).map(predicate))

    // store-queue commit readiness (drives pop)
    val stqEntry = io.from_stq_rob_id(RIDX - 1 downto IIDX).asUInt
    val srAcc = (stqEntry === headPtr) && (if (cfg.robStqSummary) stqHeadReady else
      headRow(row => (0 until IDW).map { i =>
        val idx = row * IDW + i
        !(robValid(idx) && !robIsStore(idx) && !robReady(idx))
      }.reduce(_ && _)))
    // Zicsr: head-row exception / interrupt view (all off registered state)
    val stqSlot0 = io.from_stq_rob_id(IIDX - 1 downto 0).asUInt
    val excHit = (0 until IDW).map(i => if (cfg.zicsr)
      headRow(row => robValid(row * IDW + i) && robExc(row * IDW + i)) else False)
    val excAny  = if (cfg.zicsr) excHit.reduce(_ || _) else False
    val excSlot = UInt(IIDX bits); excSlot := 0
    if (cfg.zicsr) for (i <- IDW - 1 downto 0) { when(excHit(i)) { excSlot := U(i, IIDX bits) } }
    // an exception at or before the STQ head's slot: that store must never hand off
    val excBlocksStq = if (cfg.zicsr) (0 until IDW).map(i => excHit(i) && (U(i, IIDX bits) <= stqSlot0)).reduce(_ || _) else False
    // Interrupt: taken on the first valid head slot, but NEVER while the head row holds
    // a serial op (atomic / CSR). A ready one has already done its irreversible RMW /
    // CSR write and must commit; an unready one is executing or about to. Either way
    // the interrupt waits one row -- it is taken on the next instruction instead.
    val serialInRow = if (cfg.zicsr && cfg.robSerialSummary) serialHead
    else if (cfg.zicsr) headRow(row => (0 until IDW).map { i =>
      val idx = row * IDW + i
      robValid(idx) && (robIsAtomic(idx) || (if (cfg.mmio) robDevice(idx) else False))
    }.reduce(_ || _)) else False
    val irqTake = if (cfg.zicsr) io.irq_pending && !empty && !serialInRow else False
    val irqSlot = UInt(IIDX bits); irqSlot := 0
    if (cfg.zicsr) for (i <- IDW - 1 downto 0) { when(robValid(headIdx(i))) { irqSlot := U(i, IIDX bits) } }

    val stqReady = if (cfg.zicsr) srAcc && !excBlocksStq && !irqTake else srAcc
    io.from_stq_ready := stqReady

    // pop
    // Zicsr adds: a trap pops the row (nothing younger than the trapping slot commits)
    // needed because a store slot younger than an exception never becomes ready.
    val excPop = if (cfg.zicsr) headRow(row => (0 until IDW).map(i =>
      robValid(row * IDW + i) && robExc(row * IDW + i) &&
      (0 until i).map(j => !(robValid(row * IDW + j) && !robReady(row * IDW + j))).fold(True)(_ && _)
    ).reduce(_ || _)) else False
    // Resolve an older head-row misprediction before issuing a younger device
    // load. Waiting for the whole row would otherwise expose wrong-path MMIO.
    val earlyBranchSlotReady = if (cfg.mmio && cfg.robStqSummary) {
      val slot = io.from_cb_rob_id(IIDX-1 downto 0).asUInt
      val eligible = Vec((0 until IDW).map { i =>
        robValid(headIdx(i)) && robReady(headIdx(i)) && (0 until i).map { j =>
          !robValid(headIdx(j)) || robReady(headIdx(j))
        }.fold(True)(_ && _)
      })
      eligible(slot)
    } else False
    val earlyBranch = if (cfg.mmio && cfg.robStqSummary)
      io.from_cb_ready && io.from_cb_miss_predict &&
        (io.from_cb_rob_id(RIDX-1 downto IIDX).asUInt === headPtr) && earlyBranchSlotReady
    else if (cfg.mmio) io.from_cb_ready && io.from_cb_miss_predict &&
      (io.from_cb_rob_id(RIDX-1 downto IIDX).asUInt === headPtr) &&
      robValid(headIdxU(io.from_cb_rob_id(IIDX-1 downto 0).asUInt)) &&
      robReady(headIdxU(io.from_cb_rob_id(IIDX-1 downto 0).asUInt)) &&
      (0 until IDW).map(i => (U(i,IIDX bits) >= io.from_cb_rob_id(IIDX-1 downto 0).asUInt) ||
        !robValid(headIdx(i)) || robReady(headIdx(i))).reduce(_ && _) else False
    val basePopReady = if (cfg.robStqSummary) {
      val ready = headRow(row => (0 until IDW).map(i =>
        !(robValid(row * IDW + i) && !robReady(row * IDW + i))).reduce(_ && _))
      (io.from_stq_valid && stqReady) || (if (cfg.zicsr) ready || excPop || irqTake else ready)
    } else False
    val pop = Bool()
    if (cfg.robStqSummary) pop := !empty && (basePopReady || (if (cfg.zicsr) earlyBranch else False))
    else {
      when(empty) { pop := False }
      .elsewhen(io.from_stq_valid && stqReady) { pop := True }
      .otherwise {
        val allReady = headRow(row => (0 until IDW).map(i =>
          !(robValid(row * IDW + i) && !robReady(row * IDW + i))).reduce(_ && _))
        pop := (if (cfg.zicsr) allReady || excPop || irqTake || earlyBranch else allReady)
      }

    }

    // Choose the oldest violating ROB slot for memory-order recovery.
    val violHit = (0 until IDW).map(i => headRow(row =>
      robValid(row * IDW + i) && robMemViol(row * IDW + i)))
    val violFlush = pop && violHit.reduce(_ || _)
    val violSlot  = UInt(IIDX bits); violSlot := 0
    for (i <- IDW - 1 downto 0) { when(violHit(i)) { violSlot := U(i, IIDX bits) } }

    // RV32A: fence-like atomic commit. An AMO/LR/SC is not in the STQ, so the
    // LDQ can't squash a younger load that read its address before the RMW. When the
    // atomic commits, flush everything younger (redirect to pc+4) so it re-executes
    // observing the atomic's memory effect. The atomic is the oldest entry when it
    // becomes ready, so it wins the redirect over any younger branch/violation.
    val atomicSlot = UInt(IIDX bits); atomicSlot := 0
    val atomicFlush = if (cfg.aExt || cfg.zicsr) {
      val atomicHit = (0 until IDW).map(i => headRow(row =>
        robValid(row * IDW + i) && robIsAtomic(row * IDW + i) && robReady(row * IDW + i)))
      for (i <- IDW - 1 downto 0) { when(atomicHit(i)) { atomicSlot := U(i, IIDX bits) } }
      pop && atomicHit.reduce(_ || _)
    } else False

    val deviceSlot = UInt(IIDX bits); deviceSlot := 0
    val deviceFlush = if (cfg.mmio && cfg.robDeviceParallel) {
      def selected(predicate: Int => Bool): Bool = Vec((0 until DEPTH).map(predicate))(headPtr)
      val ready = (0 until IDW).map(i => selected { row =>
        val idx = row * IDW + i
        robValid(idx) && robDevice(idx) && robReady(idx)
      })
      val stores = (0 until IDW).map(i => selected { row =>
        val idx = row * IDW + i
        robValid(idx) && robDevice(idx) && robIsStore(idx) &&
          io.from_stq_rob_id === B(idx,RIDX bits)
      })
      val commitStore = io.from_stq_valid && stqReady
      for (i <- IDW-1 downto 0) when(ready(i) || (commitStore && stores(i))) {
        deviceSlot := U(i,IIDX bits)
      }
      // A store handshake already satisfies basePopReady.
      (pop && ready.reduce(_ || _)) || (!empty && commitStore && stores.reduce(_ || _))
    } else if (cfg.mmio) {
      val hits = (0 until IDW).map(i => robValid(headIdx(i)) && robDevice(headIdx(i)) &&
        (robReady(headIdx(i)) || (robIsStore(headIdx(i)) && io.from_stq_valid && stqReady &&
          (io.from_stq_rob_id === headIdx(i).asBits))))
      for (i <- IDW-1 downto 0) when(hits(i)) { deviceSlot := U(i,IIDX bits) }
      pop && hits.reduce(_ || _)
    } else False

    // branch resolution / flush / redirect
    val brSlot   = io.from_cb_rob_id(IIDX - 1 downto 0).asUInt
    val cbEntry  = io.from_cb_rob_id(RIDX - 1 downto IIDX).asUInt
    val dequeue  = Mux(io.from_cb_ready, pop && (cbEntry === headPtr), False)
    io.from_cb_dequeue := dequeue
    // Absorb the early-branch term before pop feeds back into branch recovery.
    val branchFlush = if (cfg.robStqSummary)
      !empty && io.from_cb_ready && (cbEntry === headPtr) && io.from_cb_miss_predict &&
        (basePopReady || (if (cfg.zicsr) earlyBranchSlotReady else False))
      else dequeue && io.from_cb_miss_predict
    // Zicsr: trap = a fourth flush source. Oldest wins: an exception at slot e
    // yields to a violation / mispredict / serial commit at a STRICTLY older slot
    // (those squash it; it re-executes and re-traps if real). An interrupt is taken
    // on the first valid slot, so nothing is older than it.
    val trapExc = if (cfg.zicsr) pop && excAny &&
      !(violFlush && (violSlot < excSlot)) && !(branchFlush && (brSlot < excSlot)) &&
      !(atomicFlush && (atomicSlot < excSlot)) && !(deviceFlush && (deviceSlot < excSlot)) else False
    val trapTake = if (cfg.zicsr) irqTake || trapExc else False
    // Exception priority selects the redirect; an older flush already requests recovery.
    val backendFlush = if (cfg.zicsr) branchFlush || violFlush || atomicFlush || deviceFlush || irqTake || (pop && excAny)
                       else branchFlush || violFlush || atomicFlush
    io.backend_flush := backendFlush
    if (cfg.distributedFlush) io.flush_causes :=
      (if (cfg.zicsr) (pop && excAny).asBits ## irqTake.asBits ## deviceFlush.asBits
       else B(0,3 bits)) ## atomicFlush.asBits ## violFlush.asBits ## branchFlush.asBits
    // Oldest flush cause wins: a younger violating load cannot override a branch redirect.
    val brWins = branchFlush && (!violFlush || (brSlot < violSlot))
    // Increment each head slot before the late recovery-slot mux. Keep the
    // carry prefix so mapping cannot rebuild a serial chain across the PC.
    val headPc = Vec((0 until IDW).map(i => ooo.OhSel(headRowSelect,
      (0 until DEPTH).map(row => entryPc(U(row * IDW + i,RIDX bits))))))
    val headPc4 = Vec(headPc.map(pc => ooo.FastAdd.addPow2(pc.asUInt,2,cfg.fpgaNativeAdd).asBits))
    val deviceNextPc = if (cfg.mmio) Vec((0 until IDW).map(i =>
      ooo.FastAdd.pcNext(headPc(i),robCompressed(headIdx(i)),cfg.fpgaNativeAdd))) else headPc4
    if (cfg.zicsr) {
      // serial commit: pc+4, or mepc when the op was an mret; trap: the vector
      val serialPc = Mux(io.mret_held, io.mret_pc, headPc4(atomicSlot))
      io.backend_redirect_pc := Mux(trapTake, io.trap_vector,
                                 Mux(deviceFlush && !(branchFlush && brSlot < deviceSlot) && !(violFlush && violSlot <= deviceSlot), deviceNextPc(deviceSlot),
                                 Mux(atomicFlush, serialPc,
                                 Mux(brWins, io.from_cb_target_address, headPc(violSlot)))))
      val trapSlot = Mux(irqTake, irqSlot, excSlot)
      io.trap_en    := trapTake
      io.trap_cause := Mux(irqTake, io.irq_cause, B(0, 28 bits) ## robCause(headIdxU(excSlot)))
      io.trap_epc   := headPc(trapSlot)
    } else {
      io.backend_redirect_pc := Mux(atomicFlush, headPc4(atomicSlot),
                                 Mux(brWins, io.from_cb_target_address, headPc(violSlot)))
    }

    // slot-granular commit
    val commitInstr = Vec(Bool(), IDW)
    for (i <- 0 until IDW) {
      val base = pop && robValid(headIdx(i)) &&
        !(violFlush && (U(i, IIDX bits) >= violSlot)) &&
        !(branchFlush && (U(i, IIDX bits) > brSlot)) &&
        !(atomicFlush && (U(i, IIDX bits) > atomicSlot)) &&
        !(deviceFlush && (U(i,IIDX bits) > deviceSlot))
      commitInstr(i) := (if (cfg.zicsr) base && !irqTake && !(trapExc && (U(i, IIDX bits) >= excSlot)) else base)
    }

    if (cfg.lowPower) io.sleep_request := atomicFlush &&
      commitInstr.asBits(atomicSlot) && io.wfi_held && !trapTake

    // from_id / to_rrf
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

    // RVFI order prefix + per-slot output
    val rvfiOut = Vec(RvfiDbg(), IDW)
    var acc: UInt = U(0, 64 bits)
    // Zicsr: rvfi_intr on the first retirement after a trap (the monitor's shadow-pc
    // chain is broken there by design). Sticky from the trap until the next commit.
    val intrPending = if (cfg.zicsr && cfg.rvfi) RegInit(False) else null
    if (cfg.zicsr && cfg.rvfi) {
      when(commitInstr.asBits.orR) { intrPending := False }
      when(trapTake) { intrPending := True }
    }
    var olderCommit: Bool = False
    if (cfg.rvfi) for (i <- 0 until IDW) {
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
      // Zicsr: a serial op (mret) may redirect somewhere other than pc+4
      val serHit  = if (cfg.zicsr) (atomicFlush && (atomicSlot === U(i,IIDX bits))) || (deviceFlush && (deviceSlot === U(i,IIDX bits))) else False
      o.pc_wdata  := Mux(if (cfg.zicsr) brHit || serHit else brHit, io.backend_redirect_pc, head.pc_wdata)
      o.mem_addr  := Mux(stqHit, io.from_stq_addr_dbg, head.mem_addr)
      o.mem_rmask := Mux(stqHit, B(0, 4 bits), head.mem_rmask)
      o.mem_wmask := Mux(stqHit, io.from_stq_wmask_dbg, head.mem_wmask)
      o.mem_rdata := Mux(stqHit, B(0, 32 bits), head.mem_rdata)
      o.mem_wdata := Mux(stqHit, io.from_stq_wdata_dbg, head.mem_wdata)
      o.intr      := (if (cfg.zicsr) intrPending && !olderCommit else False)
      olderCommit = olderCommit || commitInstr(i)
      acc = acc + commitInstr(i).asUInt.resize(64 bits)
    }
    val commitInstrs = acc
    if (cfg.zicsr) io.instret_inc := (0 until IDW).map(i => commitInstr(i).asUInt.resize(log2Up(IDW + 1) bits)).reduce(_ + _)
    if (cfg.rvfi) {
      val outFlat = Vec(Bits(RVFIW bits), IDW)
      for (i <- 0 until IDW) outFlat(i) := rvfiOut(i).toBits
      io.rvfi_itf_flat := outFlat.asBits
    } else {
      for (i <- 0 until IDW) rvfiOut(i).assignFromBits(B(0, RVFIW bits))   // keep the Vec legal
      io.rvfi_itf_flat := B(0, IDW * RVFIW bits)
    }

    // registered state
    when(backendFlush) {
      for (w <- 0 until N) { validNext(w) := False; readyNext(w) := False }
      headPtrReg := 0; headSelectNext := B(1, DEPTH bits); tailPtrReg := 0
    }.otherwise {
      when(io.from_id_valid && !full) {                 // push
        tailPtrReg := tailPtrReg + 1
        for (i <- 0 until IDW) {
          validNext(tailIdx(i))   := io.from_id_inst_valid(i)
          readyNext(tailIdx(i))   := False
          robRdPhy(tailIdx(i))   := fromIdRdPhy(i)
          robRdArch(tailIdx(i))  := fromIdRdArch(i)
          storeNext(tailIdx(i)) := io.from_id_is_store(i)
          atomicNext(tailIdx(i)) := io.from_id_is_atomic(i)
          robMemViol(tailIdx(i)) := False
          if (cfg.mmio) {
            deviceNext(tailIdx(i)) := False
            robMemory(tailIdx(i)) := io.from_id_memory(i)
            robCompressed(tailIdx(i)) := io.from_id_compressed(i)
          }
          if (cfg.zicsr) {
            robExc(tailIdx(i))   := io.from_id_exc_valid(i) && io.from_id_inst_valid(i)
            robCause(tailIdx(i)) := io.from_id_exc_cause_flat(i * 4, 4 bits)
            when(io.from_id_exc_valid(i)) { readyNext(tailIdx(i)) := True }
          }
          if (cfg.rvfi) rvfiArr(tailIdx(i)) := rvfiFromBits(fromIdRvfi(i))
          else pcArr(tailIdx(i)) := rvfiFromBits(fromIdRvfi(i)).pc_rdata
        }
      }
      if (cfg.mmio) when(io.device_mark && robValid(io.device_mark_id.asUInt) && robMemory(io.device_mark_id.asUInt)) {
        deviceNext(io.device_mark_id.asUInt) := True
      }
      when(pop) {
        headPtrReg := headPtrReg + 1
        headSelectNext := headRowSelect(DEPTH - 2 downto 0) ## headRowSelect(DEPTH - 1)
      }
      for (k <- 0 until CDBW) {                          // CDB snoop
        when(io.cdb_valid(k)) {
          readyNext(cdbRobId(k))          := True
          if (cfg.rvfi) {
            rvfiArr(cdbRobId(k)).rd_wdata  := cdbRdValue(k)
            rvfiArr(cdbRobId(k)).rs1_rdata := cdbRs1Dbg(k)
            rvfiArr(cdbRobId(k)).rs2_rdata := cdbRs2Dbg(k)
          }
        }
      }
      when(io.from_ldq_violation) {                      // mem violation flag
        robMemViol(io.from_ldq_violation_rob_id.asUInt) := True
      }
      if (cfg.zicsr) {                                   // late exceptions: mark + ready
        when(io.exc_a_valid) {
          robExc(io.exc_a_rob_id.asUInt) := True; readyNext(io.exc_a_rob_id.asUInt) := True
          robCause(io.exc_a_rob_id.asUInt) := io.exc_a_cause
        }
        when(io.exc_c_valid) {
          robExc(io.exc_c_rob_id.asUInt) := True; readyNext(io.exc_c_rob_id.asUInt) := True
          robCause(io.exc_c_rob_id.asUInt) := B(2, 4 bits)   // illegal instruction
        }
      }
      if (cfg.rvfi) when(io.from_ldq_valid) {           // load rvfi fill
        val li = io.from_ldq_rob_id.asUInt
        rvfiArr(li).mem_addr  := io.from_ldq_addr_dbg
        rvfiArr(li).mem_rmask := io.from_ldq_rmask_dbg
        rvfiArr(li).mem_wmask := B(0, 4 bits)
        rvfiArr(li).mem_rdata := io.from_ldq_rdata_dbg
        rvfiArr(li).mem_wdata := B(0, 32 bits)
      }
    }
    // Retirement order advances on pop and resets only on rst.
    if (cfg.rvfi) when(pop) { rvfiOrder := rvfiOrder + commitInstrs }

    // RV32A: drive the AtomicUnit when an atomic is the oldest not-yet-ready
    // entry at the head (all older head-row slots committed/ready). It executes the
    // RMW non-speculatively and broadcasts on the CDB -> robReady -> normal commit.
    val atomicGo = Bool(); atomicGo := False
    val atomicGoId = Bits(RIDX bits); atomicGoId := 0
    val goOlder = UInt(log2Up(IDW + 1) bits); goOlder := 0
    if (cfg.aExt || cfg.zicsr) {
      for (i <- IDW - 1 downto 0) {
        val eligible = headRow { row =>
          val idx = row * IDW + i
          val olderBusy = (0 until i).map { j =>
            val older = row * IDW + j
            robValid(older) && (!robReady(older) || (if (cfg.zicsr) robExc(older) else False))
          }.fold(False)(_ || _)
          robValid(idx) && robIsAtomic(idx) && !robReady(idx) && !olderBusy
        }
        when(eligible) {
          atomicGo   := True
          atomicGoId := headIdx(i).resize(RIDX bits).asBits
          goOlder    := (0 until i).map(j => robValid(headIdx(j)).asUInt.resize(log2Up(IDW + 1) bits)).fold(U(0, log2Up(IDW + 1) bits))(_ + _)
        }
      }
    }
    if (cfg.mmio) {
      io.device_go := False; io.device_go_id := 0
      for (i <- IDW-1 downto 0) {
        val eligible = headRow { row =>
          val idx = row * IDW + i
          val olderBlocked = (0 until i).map { j =>
            val older = row * IDW + j
            robValid(older) && (!robReady(older) || robExc(older) || robMemViol(older))
          }.fold(False)(_ || _)
          robValid(idx) && robDevice(idx) && !robReady(idx) && !olderBlocked
        }
        when(eligible && !backendFlush) {
          io.device_go := True; io.device_go_id := headIdx(i).asBits
        }
      }
    }
    io.atomic_go        := atomicGo
    io.atomic_go_rob_id := atomicGoId
    if (cfg.zicsr) io.go_older := goOlder

    // Zicsr: mtval for the OLDEST pending exception (one register, not 32b/entry)
    // Every exception source writes it if it is older than the current holder (age =
    // distance from the head). Because a trap flushes everything younger, the holder
    // at trap time is always the trapping entry -- or nobody, which reads as 0.
    if (cfg.zicsr) {
      val tvalValid = RegInit(False)
      val tvalRob   = Reg(UInt(RIDX bits))
      val tvalReg   = Reg(Bits(32 bits))
      def age(id: UInt): UInt = (id - headIdx(0)).resize(RIDX bits)
      def record(id: UInt, v: Bits): Unit = { tvalValid := True; tvalRob := id; tvalReg := v }
      when(backendFlush) { tvalValid := False }
      .otherwise {
        when(io.from_id_valid && !full) {            // dispatch: youngest; slot 0 beats slot 1
          for (i <- IDW - 1 downto 0) {
            // only VALID slots: an invalid slot carries stale decode (its exc bit is garbage)
            when(io.from_id_inst_valid(i) && io.from_id_exc_valid(i) && !tvalValid) { record(tailIdx(i), io.from_id_exc_tval_flat(i * 32, 32 bits)) }
          }
        }
        when(io.exc_a_valid && (!tvalValid || (age(io.exc_a_rob_id.asUInt) < age(tvalRob)))) {
          record(io.exc_a_rob_id.asUInt, io.exc_a_tval)
        }
      }
      io.trap_tval := Mux(!irqTake && tvalValid && (tvalRob === headIdxU(excSlot)), tvalReg, B(0, 32 bits))
    }

    // perf_monitor-tapped internals
    io.dbg_viol_flush   := violFlush
    io.dbg_pop          := pop
    io.dbg_empty        := empty
    io.dbg_branch_flush := branchFlush
    io.dbg_commit_instr := commitInstr.asBits
    io.dbg_head_ptr_reg := headPtrReg.asBits
    io.dbg_tail_ptr_reg := tailPtrReg.asBits
  }
}
