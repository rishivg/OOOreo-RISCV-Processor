package ooo.memory

import spinal.core._
import ooo.{CpuConfig, OhSel}
import ooo.backend.decode.DecodeConsts
import ooo.common.TaggedSlots

/** Head-serialized RV32A LR/SC and AMO execution through a private D-cache port.
  * Capture metadata at dispatch and operands at AGU issue, keyed by ROB ID.
  * SC, a committed store to the reserved word, or flush clears the LR reservation.
  */
class AtomicUnit(cfg: CpuConfig) extends Component {
  setDefinitionName("atomic_unit_spinal")
  import DecodeConsts._
  val RIDX = cfg.robIdx
  val PIDX = cfg.prfIdx
  val AIDX = cfg.arfIdx
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    // dispatch capture (mem_rs accept of an atomic uop)
    val disp_valid     = in Bool()
    val disp_ready     = out Bool()   // CAM has a free entry (LsuTop backpressures an atomic when low)
    val disp_rob_id    = in Bits (RIDX bits)
    val disp_amo_op    = in Bits (4 bits)
    val disp_rd_phy    = in Bits (PIDX bits)
    val disp_rd_arch   = in Bits (AIDX bits)
    // AGU issue capture (agu_lsq packet: rob_id addr wdata mask rs1 rs2)
    val agu_valid      = in Bool()
    val agu_data       = in Bits (AguLsq.width(cfg) bits)
    // AGU hi16 split: addr(31:16) arrives as conditional sums + c16 (the merged
    // agu_data addr hi is NOT consumed -- it's the late block-carry-merge tail).
    // The lo half captures at AGU issue; the hi half is composed off these,
    // REGISTERED, and written one cycle later; tCaptured also moves one cycle
    // later (+1 cycle atomic AGU-to-ready latency, invisible to the RMW protocol).
    val agu_hi0        = in Bits (16 bits)
    val agu_hi1        = in Bits (16 bits)
    val agu_c16        = in Bool()
    // committed-store snoop (stq->stb handoff) -> clears matching reservation
    val st_commit_valid = in Bool()
    val st_commit_addr  = in Bits (32 bits)
    // ROB head handshake
    val device_fault = if (cfg.mmio) out Bool() else null
    val device_fault_id = if (cfg.mmio) out Bits(RIDX bits) else null
    val device_fault_addr = if (cfg.mmio) out Bits(32 bits) else null
    val device_fault_cause = if (cfg.mmio) out Bits(4 bits) else null
    val go        = in Bool()
    val go_rob_id = in Bits (RIDX bits)
    val stb_empty = in Bool()       // all older committed stores drained to cache
    val busy      = out Bool()
    // private D-cache port (DmemArbiter atomic port)
    val cache_valid = out Bool()
    val cache_addr  = out Bits (32 bits)
    val cache_rmask = out Bits (4 bits)
    val cache_wmask = out Bits (4 bits)
    val cache_wdata = out Bits (32 bits)
    val cache_ready = in  Bool()
    val cache_resp  = in  Bool()
    val cache_rdata = in  Bits (32 bits)
    // CDB result (muxed onto the LSU CDB lane)
    val cdb_valid    = out Bool()
    val cdb_rob_id   = out Bits (RIDX bits)
    val cdb_rd_phy   = out Bits (PIDX bits)
    val cdb_rd_arch  = out Bits (AIDX bits)
    val cdb_rd_value = out Bits (32 bits)
    val cdb_rs1_dbg  = out Bits (32 bits)
    val cdb_rs2_dbg  = out Bits (32 bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  def computeF(op: Bits, oldv: Bits, b: Bits): Bits = {
    val unsignedLess = ooo.FastAdd.lessThan(oldv.asUInt,b.asUInt,cfg.fpgaNativeAdd)
    val signedLess = Mux(oldv(31) =/= b(31), oldv(31), unsignedLess)
    val less = Mux(op === B(AMO_MINU, 4 bits) || op === B(AMO_MAXU, 4 bits),
      unsignedLess, signedLess)
    val minimum = Mux(less, oldv, b)
    val maximum = Mux(less, b, oldv)
    val r = Bits(32 bits); r := b
    switch(op) {
      is(B(AMO_SWAP, 4 bits)) { r := b }
      is(B(AMO_ADD,  4 bits)) { r := ooo.FastAdd.withCout(oldv.asUInt,b.asUInt,nativeCarry=cfg.fpgaNativeAdd)._1.asBits }
      is(B(AMO_XOR,  4 bits)) { r := oldv ^ b }
      is(B(AMO_AND,  4 bits)) { r := oldv & b }
      is(B(AMO_OR,   4 bits)) { r := oldv | b }
      is(B(AMO_MIN, 4 bits), B(AMO_MINU, 4 bits)) { r := minimum }
      is(B(AMO_MAX, 4 bits), B(AMO_MAXU, 4 bits)) { r := maximum }
    }
    r
  }

  new ClockingArea(domain) {
    // Capture dispatch metadata and AGU operands in slots keyed by ROB ID.
    // Dispatch stalls if no free slot exists; flush clears all slots.
    val CAMN = cfg.atomicCamDepth
    val slots = new TaggedSlots(CAMN,RIDX)
    slots.dispatch := io.disp_valid; slots.dispatchKey := io.disp_rob_id
    slots.flush := io.backend_flush
    io.disp_ready := slots.ready
    val eCaptured = slots.captured
    val eAmo    = Vec(Reg(Bits(4 bits)), CAMN)
    val eRdPhy  = Vec(Reg(Bits(PIDX bits)), CAMN)
    val eRdArch = Vec(Reg(Bits(AIDX bits)), CAMN)
    val eAddrLo = Vec(Reg(Bits(16 bits)), CAMN)
    val eAddrHi = Vec(Reg(Bits(16 bits)), CAMN)
    val eRs2    = Vec(Reg(Bits(32 bits)), CAMN)
    when(slots.allocateFire) {
      for (e <- 0 until CAMN) when(slots.allocation(e)) {
        eAmo(e) := io.disp_amo_op; eRdPhy(e) := io.disp_rd_phy; eRdArch(e) := io.disp_rd_arch
      }
    }
    // AGU issue: latch addr+rs2 into the matching in-flight entry
    val aguRob  = AguLsq.robId(io.agu_data, cfg)
    val aguAddr = AguLsq.addr(io.agu_data)
    val aguRs2  = AguLsq.rs2Dbg(io.agu_data)
    val aguMatch = slots.matching(aguRob)
    when(io.agu_valid && !io.backend_flush) {
      for (e <- 0 until CAMN) when(aguMatch(e)) {
        eAddrLo(e) := aguAddr(15 downto 0)
        eRs2(e)    := aguRs2
      }
    }
    // Only matching atomics capture the split sums; ordinary AGU traffic holds them.
    // (the compose is a 16b 2:1 at ~t0 -- the point of the AGU hi16 split). The
    // pending write is killed by a same-cycle flush so it can never collide with
    // a post-flush reallocation of the slot; the FSM can't have freed the entry
    // meanwhile (it only starts on captured, which this write sets).
    val captureHi = io.agu_valid && aguMatch.asBits.orR && !io.backend_flush
    val hiPendV  = RegNext(captureHi) init(False)
    val hiPendOh = RegNext(aguMatch)
    val hiPend0  = Reg(Bits(16 bits)); val hiPend1 = Reg(Bits(16 bits))
    val hiPendC  = Reg(Bool())
    when(captureHi) {
      hiPend0 := io.agu_hi0; hiPend1 := io.agu_hi1; hiPendC := io.agu_c16
    }
    when(hiPendV && !io.backend_flush) {
      slots.capture := hiPendOh
      for (e <- 0 until CAMN) when(hiPendOh(e)) {
        eAddrHi(e)   := Mux(hiPendC, hiPend1, hiPend0)
      }
    }

    // reservation (LR/SC), word granularity
    val resValid = RegInit(False)
    val resAddr  = Reg(Bits(30 bits))

    // FSM
    val sIdle :: sRead :: sWrite :: sCdb :: sWait :: Nil = List.tabulate(5)(i => U(i, 3 bits))
    val state = RegInit(sIdle)
    val cur     = Reg(Bits(RIDX bits))
    val curAmo  = Reg(Bits(4 bits))
    val curRdPhy= Reg(Bits(PIDX bits))
    val curRdArch=Reg(Bits(AIDX bits))
    val curAddr = Reg(Bits(32 bits))
    val curRs2  = Reg(Bits(32 bits))
    val oldVal  = Reg(Bits(32 bits))
    val result  = Reg(Bits(32 bits))    // CDB rd value
    val doWrite = Reg(Bool())           // sc-success / amo -> a write phase follows

    val goI    = io.go_rob_id.asUInt
    val wordAddr = curAddr(31 downto 2) ## B"2'b00"

    // CAM lookup for the ROB-head handshake (reads are OhSel over CAMN entries;
    // goMatch is one-hot among valid entries -- rob ids are unique in flight)
    val goMatch = slots.matching(io.go_rob_id)
    val goHit    = goMatch.asBits.orR
    val goCap    = OhSel.bool(goMatch.asBits, eCaptured)
    val goAmo    = OhSel(goMatch.asBits, eAmo)
    val goRdPhy  = OhSel(goMatch.asBits, eRdPhy)
    val goRdArch = OhSel(goMatch.asBits, eRdArch)
    val goAddr   = OhSel(goMatch.asBits, (0 until CAMN).map(e => eAddrHi(e) ## eAddrLo(e)))
    val goRs2    = OhSel(goMatch.asBits, eRs2)

    val badDevice = if (cfg.mmio) DeviceRegion.ordered(goAddr,cfg) else False
    if (cfg.mmio) {
      io.device_fault := state === sIdle && io.go && goHit && goCap && badDevice && !io.backend_flush
      io.device_fault_id := io.go_rob_id; io.device_fault_addr := goAddr
      io.device_fault_cause := Mux(goAmo === B(AMO_LR,4 bits),B(5,4 bits),B(7,4 bits))
    }
    // defaults
    io.cache_valid := False
    io.cache_addr  := wordAddr
    io.cache_rmask := B(0, 4 bits)
    io.cache_wmask := B(0, 4 bits)
    io.cache_wdata := B(0, 32 bits)
    io.cdb_valid    := False
    io.cdb_rob_id   := cur
    io.cdb_rd_phy   := curRdPhy
    io.cdb_rd_arch  := curRdArch
    io.cdb_rd_value := result
    io.cdb_rs1_dbg  := curAddr
    io.cdb_rs2_dbg  := curRs2
    io.busy := state =/= sIdle

    switch(state) {
      is(sIdle) {
        // start only once older committed stores are in the cache (stb drained), so
        // the RMW read sees them -- atomic holds off the cache port until then.
        when(io.go && goHit && goCap && io.stb_empty && !badDevice && !io.backend_flush) {
          cur      := io.go_rob_id
          curAmo   := goAmo
          curRdPhy := goRdPhy
          curRdArch:= goRdArch
          curAddr  := goAddr
          curRs2   := goRs2
          // free the CAM entry -- every field just copied into the cur* regs
          slots.release := goMatch
          val amo = goAmo
          val a   = goAddr
          when(amo === B(AMO_SC, 4 bits)) {
            val succ = resValid && (resAddr === a(31 downto 2))
            resValid := False                         // SC always clears reservation
            when(succ) { doWrite := True;  result := B(0, 32 bits); state := sWrite }
            .otherwise { doWrite := False; result := B(1, 32 bits); state := sCdb }
          } otherwise {                               // LR or AMO* -> read first
            doWrite := amo =/= B(AMO_LR, 4 bits)      // LR has no write
            state   := sRead
          }
        }
      }
      is(sRead) {
        io.cache_valid := True
        io.cache_rmask := B"4'b1111"
        when(io.cache_resp) {
          oldVal := io.cache_rdata
          result := io.cache_rdata                    // rd = old (AMO) / loaded (LR)
          when(curAmo === B(AMO_LR, 4 bits)) {        // set reservation, no write
            resValid := True
            resAddr  := curAddr(31 downto 2)
            state    := sCdb
          } otherwise {
            state := sWrite
          }
        }
      }
      is(sWrite) {
        io.cache_valid := True
        io.cache_wmask := B"4'b1111"
        io.cache_wdata := Mux(curAmo === B(AMO_SC, 4 bits), curRs2, computeF(curAmo, oldVal, curRs2))
        when(io.cache_resp) { state := sCdb }
      }
      is(sCdb) {
        io.cdb_valid := True
        state := sWait
      }
      is(sWait) {                                     // wait for the ROB to pop `cur`
        when(!(io.go && (goI === cur.asUInt))) { state := sIdle }
      }
    }

    // reservation clear on committed store to the reserved word
    when(io.st_commit_valid && resValid && (io.st_commit_addr(31 downto 2) === resAddr)) {
      resValid := False
    }
    // abort cleanly on flush; reclaim every CAM slot (all in-flight atomics are
    // squashed -- placed last so it beats a same-cycle allocation)
    when(io.backend_flush) {
      state := sIdle
    }
  }
}
