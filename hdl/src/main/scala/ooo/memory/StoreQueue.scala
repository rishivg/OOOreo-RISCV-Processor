package ooo.memory

import spinal.core._
import spinal.lib._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/memory/store_queue.sv` -- the store queue: in-order FIFO
  * of in-flight stores (enqueued at dispatch, address filled by the AGU, dequeued
  * to the ROB + store-buffer at commit) plus speculative-load disambiguation and
  * store-to-load forwarding against the load queue.
  *
  * Named store_queue_spinal; sim/swap_shims/store_queue.sv carries the five SV
  * interfaces and surfaces the perf_monitor-tapped want_dequeue/counter/
  * rd_ptr_actual + a per-entry addr_valid (the tap reads fifo[rd_ptr_actual]).
  */
class StoreQueue(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("store_queue_spinal")
  val DEPTH = cfg.stqDepth     // 8
  val IDX   = cfg.stqIdx       // 3
  val LDQ   = cfg.ldqDepth     // 8
  val RIDX  = cfg.robIdx       // 6
  val TW    = IDX + 1          // pointer/tracker width (4)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    // ds_rs_mono_itf.rs from_ds
    val from_ds_valid       = in  Bool()
    val from_ds_ready       = out Bool()
    val from_ds_uop_rob_id  = in  Bits (RIDX bits)
    val from_ds_uop_fu_opcode = in Bits (4 bits)
    // agu_lsq_itf.lsq from_agu
    val from_agu_valid = in Bool()
    val from_agu_data  = in Bits (RIDX + 32 + 32 + 4 + 32 + 32 bits)  // agu_lsq_t = 138
    // stq_rob_itf.stq to_rob
    val to_rob_ready         = in  Bool()
    val to_rob_valid         = out Bool()
    val to_rob_rob_id        = out Bits (RIDX bits)
    val to_rob_addr_dbg      = out Bits (32 bits)
    val to_rob_wmask_dbg     = out Bits (4 bits)
    val to_rob_wdata_dbg     = out Bits (32 bits)
    val to_rob_rs1_value_dbg = out Bits (32 bits)
    val to_rob_rs2_value_dbg = out Bits (32 bits)
    // stq_stb_itf.stq to_stb
    val to_stb_ready = in  Bool()
    val to_stb_valid = out Bool()
    val to_stb_wmask = out Bits (4 bits)
    val to_stb_addr  = out Bits (32 bits)
    val to_stb_wdata = out Bits (32 bits)
    // ldq_stq_itf.stq from_ldq
    val ldq_tracker_flat = in  Bits (LDQ * TW bits)
    val ldq_addr_flat    = in  Bits (LDQ * 32 bits)
    val ldq_rmask_flat   = in  Bits (LDQ * 4 bits)
    val stq_tail         = out Bits (TW bits)
    val stq_deq          = out Bool()
    val has_conflicting_store = out Bits (LDQ bits)
    val known_conflict        = out Bits (LDQ bits)
    val unknown_older         = out Bits (LDQ bits)
    val forward_en            = out Bits (LDQ bits)
    val forward_wdata_flat    = out Bits (LDQ * 32 bits)
    // perf_monitor taps
    val dbg_want_dequeue   = out Bool()
    val dbg_counter        = out Bits (TW bits)
    val dbg_rd_ptr_actual  = out Bits (IDX bits)
    val dbg_addr_valid_flat = out Bits (DEPTH bits)
  }
  noIoPrefix()

  // agu_lsq_t slices (MSB->LSB: rob_id, addr, wdata, mask, rs1_dbg, rs2_dbg)
  val aguRobId = io.from_agu_data(137 downto 132)
  val aguAddr  = io.from_agu_data(131 downto 100)
  val aguWdata = io.from_agu_data(99 downto 68)
  val aguMask  = io.from_agu_data(67 downto 64)
  val aguRs1   = io.from_agu_data(63 downto 32)
  val aguRs2   = io.from_agu_data(31 downto 0)
  def ldqTracker(i: Int) = io.ldq_tracker_flat(i * TW, TW bits).asUInt
  def ldqAddr(i: Int)    = io.ldq_addr_flat(i * 32, 32 bits)
  def ldqRmask(i: Int)   = io.ldq_rmask_flat(i * 4, 4 bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // FIFO storage (data fields unreset, mirroring SV; addr_valid set on enqueue)
    val robId     = Vec(Reg(Bits(RIDX bits)), DEPTH)
    val addrValid = Vec(Reg(Bool()), DEPTH)
    val addr      = Vec(Reg(Bits(32 bits)), DEPTH)
    val mask      = Vec(Reg(Bits(4 bits)), DEPTH)
    val wdata     = Vec(Reg(Bits(32 bits)), DEPTH)
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

    // ---- pointers / counter (reset & flush clear) ----
    when(io.backend_flush) {
      wrPtr := 0; rdPtr := 0; counter := 0
    }.otherwise {
      when(enqueue) { wrPtr := wrPtr + 1 }
      when(dequeue) { rdPtr := rdPtr + 1 }
      counter := (counter + Mux(enqueue, U(1, TW bits), U(0, TW bits)) - Mux(dequeue, U(1, TW bits), U(0, TW bits))).resize(TW bits)
    }

    // ---- FIFO writes (no reset, like SV; runs regardless of flush) ----
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

    // ---- drain to STB / ROB ----
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

    // ---- speculative-load disambiguation + store-to-load forwarding ----
    val hasConf = Vec(Bool(), LDQ); val known = Vec(Bool(), LDQ)
    val unknown = Vec(Bool(), LDQ); val fwdEn = Vec(Bool(), LDQ)
    val fwdData = Vec(Bits(32 bits), LDQ)
    for (i <- 0 until LDQ) {
      val tracker = ldqTracker(i)
      val trackedTail = (rdPtr + tracker - 1).resize(TW bits)
      val ttActual = trackedTail(IDX - 1 downto 0); val ttFlag = trackedTail(IDX)
      val sameAddr = Vec(Bool(), DEPTH); val potConf = Vec(Bool(), DEPTH)
      val unkOld   = Vec(Bool(), DEPTH); val ovlOld  = Vec(Bool(), DEPTH); val covOld = Vec(Bool(), DEPTH)
      for (j <- 0 until DEPTH) {
        val addrMatch = addr(j)(31 downto 2) === ldqAddr(i)(31 downto 2)
        val rmaskOvl  = (ldqRmask(i) & ~mask(j)) =/= ldqRmask(i)
        val rmaskCov  = (ldqRmask(i) & ~mask(j)) === 0
        sameAddr(j) := !addrValid(j) || (addrMatch && rmaskOvl)
        potConf(j) := Mux(ttFlag === rdFlag,
          (rdActual <= U(j, IDX bits)) && (U(j, IDX bits) <= ttActual),
          (rdActual <= U(j, IDX bits)) || (U(j, IDX bits) <= ttActual))
        unkOld(j) := potConf(j) && !addrValid(j)
        ovlOld(j) := potConf(j) && addrValid(j) && addrMatch && rmaskOvl
        covOld(j) := potConf(j) && addrValid(j) && addrMatch && rmaskCov
      }
      hasConf(i) := (sameAddr.asBits & potConf.asBits).orR
      known(i)   := (tracker =/= 0) && ovlOld.asBits.orR
      unknown(i) := (tracker =/= 0) && unkOld.asBits.orR
      fwdEn(i)   := False
      fwdData(i) := B(0, 32 bits)
      when((tracker =/= 0) && !unkOld.asBits.orR && (CountOne(ovlOld) === 1)) {
        for (j <- 0 until DEPTH) {
          when(ovlOld(j) && covOld(j)) { fwdEn(i) := True; fwdData(i) := wdata(j) }
        }
      }
    }
    io.has_conflicting_store := hasConf.asBits
    io.known_conflict        := known.asBits
    io.unknown_older         := unknown.asBits
    io.forward_en            := fwdEn.asBits
    io.forward_wdata_flat    := fwdData.asBits

    // ---- perf taps ----
    io.dbg_want_dequeue  := wantDequeue
    io.dbg_counter       := counter.asBits
    io.dbg_rd_ptr_actual := rdActual.asBits
    io.dbg_addr_valid_flat := addrValid.asBits
  }
}
