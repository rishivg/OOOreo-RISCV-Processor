package ooo.memory

import spinal.core._
import ooo.CpuConfig
import ooo.backend.decode.DecodeConsts

/** RV32A atomic execution unit (instantiated only when cfg.aExt).
  *
  * Atomics (LR/SC/AMO*) do NOT flow through the load/store queues -- they would
  * need a register result AND a memory write from one ROB entry, which the
  * speculative LSU datapath can't express cleanly. Instead this unit performs the
  * read-modify-write NON-SPECULATIVELY when the instruction is the oldest in the
  * machine (ROB head, all older committed). That keeps the validated load/store/
  * forwarding paths untouched and makes the RMW trivially atomic on a single hart.
  *
  * Capture is two-phase, keyed by rob_id (atomics issue out-of-order vs. the head):
  *   - dispatch  : {amo_op, rd_phy, rd_arch} written when the AMO enters mem_rs
  *   - AGU issue : {addr, rs2} latched from the agu_lsq packet
  * When the ROB asserts `go` for an atomic rob_id, an FSM drives a private D-cache
  * port (DmemArbiter atomic port, highest priority): read -> compute -> write, then
  * injects `old` (AMO/LR) or the SC success code on the LSU CDB lane. A reservation
  * register tracks LR/SC; it is cleared by SC, by a committed store to the reserved
  * word (stq->stb handoff), or by flush.
  */
class AtomicUnit(cfg: CpuConfig) extends Component {
  setDefinitionName("atomic_unit_spinal")
  import DecodeConsts._
  val RIDX = cfg.robIdx          // 6
  val PIDX = cfg.prfIdx          // 6
  val AIDX = cfg.arfIdx          // 5
  val N    = cfg.robDepth * cfg.idWidth   // 64

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    // dispatch capture (mem_rs accept of an atomic uop)
    val disp_valid     = in Bool()
    val disp_rob_id    = in Bits (RIDX bits)
    val disp_amo_op    = in Bits (4 bits)
    val disp_rd_phy    = in Bits (PIDX bits)
    val disp_rd_arch   = in Bits (AIDX bits)
    // AGU issue capture (agu_lsq packet: rob_id addr wdata mask rs1 rs2)
    val agu_valid      = in Bool()
    val agu_data       = in Bits (138 bits)
    // committed-store snoop (stq->stb handoff) -> clears matching reservation
    val st_commit_valid = in Bool()
    val st_commit_addr  = in Bits (32 bits)
    // ROB head handshake
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
    val r = Bits(32 bits); r := b
    switch(op) {
      is(B(AMO_SWAP, 4 bits)) { r := b }
      is(B(AMO_ADD,  4 bits)) { r := (oldv.asUInt + b.asUInt).asBits }
      is(B(AMO_XOR,  4 bits)) { r := oldv ^ b }
      is(B(AMO_AND,  4 bits)) { r := oldv & b }
      is(B(AMO_OR,   4 bits)) { r := oldv | b }
      is(B(AMO_MIN,  4 bits)) { r := Mux(oldv.asSInt < b.asSInt, oldv, b) }
      is(B(AMO_MAX,  4 bits)) { r := Mux(oldv.asSInt > b.asSInt, oldv, b) }
      is(B(AMO_MINU, 4 bits)) { r := Mux(oldv.asUInt < b.asUInt, oldv, b) }
      is(B(AMO_MAXU, 4 bits)) { r := Mux(oldv.asUInt > b.asUInt, oldv, b) }
    }
    r
  }

  new ClockingArea(domain) {
    // ---- per-rob-id capture table ----
    val tAtomic   = Vec(RegInit(False), N)
    val tCaptured = Vec(RegInit(False), N)
    val tAmo   = Vec(Reg(Bits(4 bits)), N)
    val tRdPhy = Vec(Reg(Bits(PIDX bits)), N)
    val tRdArch= Vec(Reg(Bits(AIDX bits)), N)
    val tAddr  = Vec(Reg(Bits(32 bits)), N)
    val tRs2   = Vec(Reg(Bits(32 bits)), N)

    val dispI = io.disp_rob_id.asUInt
    when(io.disp_valid) {
      tAtomic(dispI)   := True
      tCaptured(dispI) := False
      tAmo(dispI)      := io.disp_amo_op
      tRdPhy(dispI)    := io.disp_rd_phy
      tRdArch(dispI)   := io.disp_rd_arch
    }
    // AGU issue: latch addr+rs2 if this rob_id is a (dispatched) atomic
    val aguRob  = io.agu_data(137 downto 132).asUInt
    val aguAddr = io.agu_data(131 downto 100)
    val aguRs2  = io.agu_data(31 downto 0)
    when(io.agu_valid && tAtomic(aguRob)) {
      tAddr(aguRob)     := aguAddr
      tRs2(aguRob)      := aguRs2
      tCaptured(aguRob) := True
    }

    // ---- reservation (LR/SC), word granularity ----
    val resValid = RegInit(False)
    val resAddr  = Reg(Bits(30 bits))

    // ---- FSM ----
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
        when(io.go && tAtomic(goI) && tCaptured(goI) && io.stb_empty) {
          cur      := io.go_rob_id
          curAmo   := tAmo(goI)
          curRdPhy := tRdPhy(goI)
          curRdArch:= tRdArch(goI)
          curAddr  := tAddr(goI)
          curRs2   := tRs2(goI)
          val amo = tAmo(goI)
          val a   = tAddr(goI)
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
    // abort cleanly on flush
    when(io.backend_flush) { state := sIdle }
  }
}
