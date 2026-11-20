package ooo.csr

import spinal.core._
import ooo.{CpuConfig, OhSel}
import ooo.memory.AguLsq
import ooo.common.TaggedSlots

/** Head-serialized CSR read/modify/write, traps, returns, WFI, and barriers.
  * Capture operands by ROB ID; complete the operation before releasing retirement.
  */
class CsrUnit(cfg: CpuConfig) extends Component {
  setDefinitionName("csr_unit_spinal")
  val RIDX = cfg.robIdx; val PIDX = cfg.prfIdx; val AIDX = cfg.arfIdx

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val backend_flush = in Bool()
    // dispatch capture
    val disp_valid   = in Bool()
    val disp_ready   = out Bool()
    val disp_rob_id  = in Bits (RIDX bits)
    val disp_ctrl    = in Bits (20 bits)     // inst[31:12]: {csr_addr[11:0], rs1/uimm[4:0], funct3[2:0]}
    val disp_rd_phy  = in Bits (PIDX bits)
    val disp_rd_arch = in Bits (AIDX bits)
    // AGU issue capture
    val agu_valid    = in Bool()
    val agu_data     = in Bits (AguLsq.width(cfg) bits)
    // ROB head handshake (shared with the AtomicUnit: the CAM decides who owns the id)
    val go           = in Bool()
    val go_rob_id    = in Bits (RIDX bits)
    val go_older     = in UInt (log2Up(cfg.idWidth + 1) bits)   // see Rob.go_older
    // CSR file access
    val acc_en    = out Bool()
    val acc_addr  = out Bits (12 bits)
    val acc_wdata = out Bits (32 bits)
    val acc_write = out Bool()
    val acc_op    = out Bits (3 bits)
    val acc_instret_adj = out UInt (log2Up(cfg.idWidth + 1) bits)
    val acc_rdata = in  Bits (32 bits)
    val acc_illegal = in Bool()
    val mret_en   = out Bool()
    /** The op most recently executed here was an mret: the ROB's serial-commit flush
      * redirects to mepc instead of pc+4. Cleared by the retirement flush. */
    val mret_held = out Bool()
    val wfi_held = if (cfg.lowPower) out Bool() else null
    val memory_idle = in Bool()
    val drain_request = out Bool()
    val fence_i_request = out Bool()
    val fence_i_done = in Bool()
    // CDB result (muxed onto the LSU CDB lane, above the AtomicUnit)
    val cdb_valid    = out Bool()
    val cdb_rob_id   = out Bits (RIDX bits)
    val cdb_rd_phy   = out Bits (PIDX bits)
    val cdb_rd_arch  = out Bits (AIDX bits)
    val cdb_rd_value = out Bits (32 bits)
    val cdb_rs1_dbg  = out Bits (32 bits)
    // illegal CSR -> exception on the owning ROB entry
    val exc_valid  = out Bool()
    val exc_rob_id = out Bits (RIDX bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  val unit = new ClockingArea(domain) {
    val CAMN = cfg.csrCamDepth
    val slots = new TaggedSlots(CAMN,RIDX)
    slots.dispatch := io.disp_valid; slots.dispatchKey := io.disp_rob_id
    slots.flush := io.backend_flush
    io.disp_ready := slots.ready
    val eCaptured = slots.captured
    val eCtrl   = Vec(Reg(Bits(20 bits)), CAMN)
    val eRdPhy  = Vec(Reg(Bits(PIDX bits)), CAMN)
    val eRdArch = Vec(Reg(Bits(AIDX bits)), CAMN)
    val eRs1    = Vec(Reg(Bits(32 bits)), CAMN)
    when(slots.allocateFire) {
      for (e <- 0 until CAMN) when(slots.allocation(e)) {
        eCtrl(e) := io.disp_ctrl; eRdPhy(e) := io.disp_rd_phy; eRdArch(e) := io.disp_rd_arch
      }
    }
    val aguRob = AguLsq.robId(io.agu_data, cfg)
    val aguRs1 = AguLsq.addr(io.agu_data)       // rs1 + 0
    val aguMatch = slots.matching(aguRob)
    when(io.agu_valid && !io.backend_flush) {
      slots.capture := aguMatch
      for (e <- 0 until CAMN) when(aguMatch(e)) { eRs1(e) := aguRs1 }
    }

    val goMatch = slots.matching(io.go_rob_id)
    val goHit    = goMatch.asBits.orR
    val goCap    = OhSel.bool(goMatch.asBits, eCaptured)
    val goCtrl   = OhSel(goMatch.asBits, eCtrl)
    val goRdPhy  = OhSel(goMatch.asBits, eRdPhy)
    val goRdArch = OhSel(goMatch.asBits, eRdArch)
    val goRs1    = OhSel(goMatch.asBits, eRs1)

    // FSM: idle -> access (one cycle, CSR file RMW) -> cdb -> wait-for-pop
    val oneHot = !cfg.implementation.isFpga
    val stateWidth = if (oneHot) 4 else 2
    val sIdle :: sAcc :: sCdb :: sWait :: Nil =
      List.tabulate(4)(i => U(if (oneHot) 1 << i else i, stateWidth bits))
    val state = RegInit(sIdle).setName("csrState")
    val stateIdle = if (oneHot) state(0) else state === sIdle
    val stateAcc = if (oneHot) state(1) else state === sAcc
    val stateCdb = if (oneHot) state(2) else state === sCdb
    val stateWait = if (oneHot) state(3) else state === sWait
    val curBarrier = Reg(Bool()).setName("csrBarrier")
    val cur      = Reg(Bits(RIDX bits))
    val curCtrl  = Reg(Bits(20 bits))
    val curRdPhy = Reg(Bits(PIDX bits))
    val curRdArch= Reg(Bits(AIDX bits))
    val curRs1   = Reg(Bits(32 bits))
    val result   = Reg(Bits(32 bits))
    val curAdj   = Reg(UInt(log2Up(cfg.idWidth + 1) bits))
    val mretHeld = RegInit(False)
    val wfiHeld = if (cfg.lowPower) RegInit(False) else null

    val funct3 = curCtrl(2 downto 0)
    val field  = curCtrl(7 downto 3)             // rs1 index (register forms) / uimm5
    val isMret = (funct3 === 0) && (curCtrl(19 downto 8) === B"12'h302")
    val isBarrier = curBarrier
    def barrier(ctrl: Bits): Bool = ctrl(2 downto 0) === 0
    val needsDrain = io.go && goHit && goCap && barrier(goCtrl)
    io.drain_request := needsDrain || (!stateIdle && isBarrier)
    val isFenceI = curCtrl === B(0x100,20 bits)
    io.fence_i_request := stateAcc && isFenceI && !io.backend_flush
    if (cfg.lowPower) io.wfi_held := wfiHeld
    val immForm = funct3(2)
    // csrrw/csrrwi always write; csrrs/c(i) write only when the source is not x0 / uimm != 0
    val writes = (funct3(1 downto 0) === B"2'b01") || (field =/= 0)

    io.acc_en    := False
    io.acc_addr  := curCtrl(19 downto 8)
    io.acc_wdata := Mux(immForm, B(0, 27 bits) ## field, curRs1)
    io.acc_write := writes
    io.acc_op    := funct3
    io.acc_instret_adj := curAdj
    io.mret_en   := False
    io.mret_held := mretHeld
    io.exc_valid := False
    io.exc_rob_id := cur
    io.cdb_valid    := False
    io.cdb_rob_id   := cur
    io.cdb_rd_phy   := curRdPhy
    io.cdb_rd_arch  := curRdArch
    io.cdb_rd_value := result
    io.cdb_rs1_dbg  := curRs1

    when(stateIdle) {
      when(io.go && goHit && goCap && (!barrier(goCtrl) || io.memory_idle)) {
        cur := io.go_rob_id; curCtrl := goCtrl; curRdPhy := goRdPhy; curRdArch := goRdArch; curRs1 := goRs1
        curAdj := io.go_older
        curBarrier := barrier(goCtrl)
        slots.release := goMatch
        state := sAcc
      }
    }.elsewhen(stateAcc) {
      // The ROB only asserts go when every older instruction is ready and none is an
      // exception, and interrupts are not taken on a row holding a serial op, so no
      // flush can arrive here -- acc_en is still qualified on !flush for safety.
      when(isBarrier) {
        io.mret_en := isMret && !io.backend_flush
        mretHeld := isMret
        if (cfg.lowPower) wfiHeld := curCtrl(19 downto 8) === B"12'h105"
        result := 0
        when(!isFenceI || io.fence_i_done) { state := sCdb }
      } otherwise {
        if (cfg.lowPower) wfiHeld := False
        io.acc_en := !io.backend_flush
        mretHeld := False
        result := io.acc_rdata
        when(io.acc_illegal) { io.exc_valid := True; state := sIdle }
        .otherwise { state := sCdb }
      }
    }.elsewhen(stateCdb) { io.cdb_valid := True; state := sWait }
      .elsewhen(stateWait) { when(!(io.go && (io.go_rob_id === cur))) { state := sIdle } }

    when(io.backend_flush) {
      state := sIdle
      mretHeld := False
      if (cfg.lowPower) wfiHeld := False
    }
  }
}
