package ooo.csr

import spinal.core._
import ooo.CpuConfig

/** Machine-mode CSR addresses. */
object CsrAddr {
  // machine information (read-only)
  def MVENDORID = 0xF11; def MARCHID = 0xF12; def MIMPID = 0xF13; def MHARTID = 0xF14
  // machine trap setup
  def MSTATUS   = 0x300; def MISA    = 0x301; def MIE    = 0x304; def MTVEC  = 0x305
  def MSTATUSH  = 0x310; def MCOUNTINHIBIT = 0x320
  // machine trap handling
  def MSCRATCH  = 0x340; def MEPC    = 0x341; def MCAUSE = 0x342; def MTVAL  = 0x343
  def MIP       = 0x344
  // counters (Zicntr): machine-mode and the read-only user-mode shadows
  def MCYCLE    = 0xB00; def MINSTRET  = 0xB02
  def MCYCLEH   = 0xB80; def MINSTRETH = 0xB82
  def CYCLE     = 0xC00; def TIME      = 0xC01; def INSTRET  = 0xC02
  def CYCLEH    = 0xC80; def TIMEH     = 0xC81; def INSTRETH = 0xC82
}

/** Machine interrupt codes; trap entry sets mcause bit 31. */
object TrapCause {
  // interrupt codes (with the msb set)
  def IRQ_M_SOFT = 3; def IRQ_M_TIMER = 7; def IRQ_M_EXT = 11
}

/** CSR read-modify-write function encoding (funct3 of the SYSTEM opcode). */
object CsrOp {
  def RW = B"3'b001"; def RS = B"3'b010"; def RC = B"3'b011"
  def RWI = B"3'b101"; def RSI = B"3'b110"; def RCI = B"3'b111"
}

/** Serialized CSR state with MPP fixed to machine mode. */
class Csr(cfg: CpuConfig) extends Component {
  setDefinitionName("csr_file_spinal")
  import CsrAddr._

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()

    // CSR instruction access (from CsrUnit, at the ROB head: non-speculative)
    val acc_en    = in  Bool()                 // perform the access this cycle
    val acc_addr  = in  Bits (12 bits)
    val acc_wdata = in  Bits (32 bits)         // rs1 value, or the zero-extended uimm
    val acc_write = in  Bool()                 // this access actually writes (see CsrUnit)
    val acc_op    = in  Bits (3 bits)          // funct3: RW/RS/RC (+immediate forms)
    /** Instructions older than the accessing op that retire in the same commit group
      * as it (the ROB pops a row at a time): minstret must already count them. */
    val acc_instret_adj = in UInt (log2Up(cfg.idWidth + 1) bits)
    val acc_rdata = out Bits (32 bits)         // OLD value -> rd
    val acc_illegal = out Bool()               // unknown addr, or a write to a read-only CSR

    // trap entry (from the ROB, at commit)
    val trap_en    = in  Bool()
    val trap_cause = in  Bits (32 bits)        // full mcause value (bit31 = interrupt)
    val trap_epc   = in  Bits (32 bits)        // pc of the faulting/interrupted instruction
    val trap_tval  = in  Bits (32 bits)
    val trap_vector = out Bits (32 bits)       // where to redirect (mtvec, vectored if MODE=1)

    // mret
    val mret_en  = in  Bool()
    val mret_pc  = out Bits (32 bits)          // mepc

    // interrupt inputs (from the CLINT / platform)
    val irq_timer = in Bool()
    val irq_soft  = in Bool()
    val irq_ext   = in Bool()
    /** An enabled+pending interrupt is waiting; the ROB samples this at a commit
      * boundary and turns it into a trap. Already gated by mstatus.MIE. */
    val wfi_wake = if (cfg.lowPower) out Bool() else null
    val irq_pending = out Bool()
    val irq_cause   = out Bits (32 bits)

    // counters
    val instret_inc = in UInt (log2Up(cfg.idWidth + 1) bits)   // instructions retired this cycle
    val mtime       = in UInt (64 bits)                         // CLINT mtime (the `time` CSR)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  val csr = new ClockingArea(domain) {
    // architectural state
    // mstatus: only MIE (3) and MPIE (7) are writable; MPP (12:11) is hardwired 11
    // because this is an M-mode-only implementation.
    val mstatusMie  = RegInit(False)
    val mstatusMpie = RegInit(False)
    val mie   = RegInit(B(0, 32 bits))
    val mip   = Bits(32 bits)                  // pending is a live input, not state
    val mtvec = RegInit(B(0, 32 bits))
    val mscratch = RegInit(B(0, 32 bits))
    val mepc  = RegInit(B(0, 32 bits))
    val mcause = RegInit(B(0, 32 bits))
    val mtval = RegInit(B(0, 32 bits))
    val mcountinhibit = RegInit(B(0, 32 bits))   // bit0 = CY, bit2 = IR
    val cycle   = RegInit(U(0, 64 bits))
    val instret = RegInit(U(0, 64 bits))

    // Preserve pre-increment CSR-write priority while clocking only active banks.
    for (lo <- 0 until 64 by 8) {
      val carry = if (lo == 0) True else cycle(lo - 1 downto 0).andR
      when(!mcountinhibit(0) && carry) {
        cycle(lo + 7 downto lo) := cycle(lo + 7 downto lo) + 1
      }
      val retireCarry = if (lo == 0) io.instret_inc =/= 0
        else (instret(lo - 1 downto 0) +^ io.instret_inc.resize(lo bits)).msb
      when(!mcountinhibit(2) && retireCarry) {
        val amount = if (lo == 0) io.instret_inc.resize(8 bits) else U(1,8 bits)
        instret(lo + 7 downto lo) := instret(lo + 7 downto lo) + amount
      }
    }

    val instretRd = Mux(mcountinhibit(2), instret, ooo.FastAdd.withCout(instret,io.acc_instret_adj.resize(64 bits),nativeCarry=cfg.fpgaNativeAdd)._1)

    // Pending bits are platform-owned; legal mip writes leave them unchanged.
    mip := B(0, 32 bits)
    mip(TrapCause.IRQ_M_SOFT)  := io.irq_soft
    mip(TrapCause.IRQ_M_TIMER) := io.irq_timer
    mip(TrapCause.IRQ_M_EXT)   := io.irq_ext

    def mstatusValue: Bits = {
      val v = B(0, 32 bits)
      v(3)  := mstatusMie
      v(7)  := mstatusMpie
      v(12 downto 11) := B"2'b11"              // MPP = M (hardwired)
      v
    }

    // misa: RV32 (MXL=1) with the extensions this core actually implements.
    def misaValue: Bits = {
      val ext = B(0, 26 bits)
      ext(0)  := Bool(cfg.aExt)                // A
      ext(2)  := Bool(cfg.cExt)                // C
      ext(8)  := True                          // I
      ext(12) := True                          // M
      B"2'b01" ## B(0, 4 bits) ## ext          // MXL=1, WIRI, extensions
    }

    // read
    val rdata = Bits(32 bits); rdata := 0
    val known = Bool(); known := True
    val readOnly = Bool(); readOnly := False
    switch(io.acc_addr.asUInt) {
      is(MVENDORID) { rdata := 0; readOnly := True }
      is(MARCHID)   { rdata := 0; readOnly := True }
      is(MIMPID)    { rdata := 0; readOnly := True }
      is(MHARTID)   { rdata := 0; readOnly := True }   // single hart
      is(MSTATUS)   { rdata := mstatusValue }
      is(MSTATUSH)  { rdata := 0 }                     // no endianness / SBE/MBE control
      is(MCOUNTINHIBIT) { rdata := mcountinhibit }
      is(MISA)      { rdata := misaValue }             // writable-but-ignored (WARL)
      is(MIE)       { rdata := mie }
      is(MTVEC)     { rdata := mtvec }
      is(MSCRATCH)  { rdata := mscratch }
      is(MEPC)      { rdata := mepc }
      is(MCAUSE)    { rdata := mcause }
      is(MTVAL)     { rdata := mtval }
      is(MIP)       { rdata := mip }                  // writes ignored
      is(MCYCLE, CYCLE)       { rdata := cycle(31 downto 0).asBits }
      is(MCYCLEH, CYCLEH)     { rdata := cycle(63 downto 32).asBits }
      is(MINSTRET, INSTRET)   { rdata := instretRd(31 downto 0).asBits }
      is(MINSTRETH, INSTRETH) { rdata := instretRd(63 downto 32).asBits }
      is(TIME)      { rdata := io.mtime(31 downto 0).asBits }
      is(TIMEH)     { rdata := io.mtime(63 downto 32).asBits }
      default       { known := False }
    }
    // mhpmcounter3..31(h) / mhpmevent3..31: no HPM counters -- read-only zero, writes
    // ignored (legal: the spec lets an implementation hardwire them to 0).
    val hpmRange = (io.acc_addr.asUInt >= U(0xB03) && io.acc_addr.asUInt <= U(0xB1F)) ||
                   (io.acc_addr.asUInt >= U(0xB83) && io.acc_addr.asUInt <= U(0xB9F)) ||
                   (io.acc_addr.asUInt >= U(0x323) && io.acc_addr.asUInt <= U(0x33F))
    when(hpmRange) { known := True; rdata := 0 }
    io.acc_rdata := rdata

    // The user-mode counter shadows (0xC0x) and machine IDs are read-only; a write
    // to any of them is an illegal instruction, as is any unknown address.
    val userCounter = io.acc_addr.asUInt >= U(0xC00) && io.acc_addr.asUInt <= U(0xC82)
    io.acc_illegal := io.acc_en && (!known || (io.acc_write && (readOnly || userCounter)))

    // write (read-modify-write per funct3)
    val wval = Bits(32 bits)
    switch(io.acc_op) {
      is(CsrOp.RS, CsrOp.RSI) { wval := rdata | io.acc_wdata }
      is(CsrOp.RC, CsrOp.RCI) { wval := rdata & ~io.acc_wdata }
      default                 { wval := io.acc_wdata }      // RW / RWI
    }
    val doWrite = io.acc_en && io.acc_write && !io.acc_illegal
    when(doWrite) {
      switch(io.acc_addr.asUInt) {
        is(MSTATUS)  { mstatusMie := wval(3); mstatusMpie := wval(7) }
        is(MIE)      { mie := wval }
        // mtvec MODE: only direct (0) and vectored (1) are legal; anything else is
        // reserved, and WARL lets us fold it to direct rather than fault.
        is(MTVEC)    { mtvec := wval(31 downto 2) ## Mux(wval(1), B"2'b00", wval(1 downto 0)) }
        is(MSCRATCH) { mscratch := wval }
        is(MEPC)     { mepc := wval(31 downto 1) ## False }  // IALIGN: bit0 always 0
        is(MCAUSE)   { mcause := wval }
        is(MTVAL)    { mtval := wval }
        is(MCOUNTINHIBIT) { mcountinhibit := B(0, 29 bits) ## wval(2) ## False ## wval(0) }   // CY, IR only
        is(MCYCLE)   { cycle := cycle(63 downto 32) @@ wval.asUInt }
        is(MCYCLEH)  { cycle := wval.asUInt @@ cycle(31 downto 0) }
        is(MINSTRET) { instret := instret(63 downto 32) @@ wval.asUInt }
        is(MINSTRETH){ instret := wval.asUInt @@ instret(31 downto 0) }
        default      { /* Hardwired fields ignore legal writes. */ }
      }
    }

    // trap entry
    // Takes priority over a CSR write in the same cycle: the ROB only raises trap_en
    // for an instruction it is NOT committing, so the two cannot both be architectural.
    when(io.trap_en) {
      mepc   := io.trap_epc(31 downto 1) ## False
      mcause := io.trap_cause
      mtval  := io.trap_tval
      mstatusMpie := mstatusMie
      mstatusMie  := False                     // interrupts off on trap entry
    }
    // Vectored mode (mtvec[1:0] == 1) sends interrupts to BASE + 4*cause; synchronous
    // exceptions always go to BASE.
    val vectored = mtvec(0) && io.trap_cause(31)
    val causeIdx = io.trap_cause(4 downto 0).asUInt
    io.trap_vector := Mux(vectored,
      ooo.FastAdd.withCout((mtvec(31 downto 2) ## B"2'b00").asUInt,
        (causeIdx << 2).resize(32 bits),nativeCarry=cfg.fpgaNativeAdd)._1.asBits,
      mtvec(31 downto 2) ## B"2'b00")

    // mret
    when(io.mret_en) {
      mstatusMie  := mstatusMpie
      mstatusMpie := True                      // spec: MPIE set to 1 on mret
    }
    io.mret_pc := mepc

    // interrupt request
    // Priority per the spec: external > software > timer.
    val enabled = mip & mie
    val extReq  = enabled(TrapCause.IRQ_M_EXT)
    val softReq = enabled(TrapCause.IRQ_M_SOFT)
    val timeReq = enabled(TrapCause.IRQ_M_TIMER)
    io.irq_pending := mstatusMie && (extReq || softReq || timeReq)
    if (cfg.lowPower) io.wfi_wake := extReq || softReq || timeReq
    val code = UInt(5 bits)
    when(extReq)      { code := U(TrapCause.IRQ_M_EXT,   5 bits) }
      .elsewhen(softReq) { code := U(TrapCause.IRQ_M_SOFT,  5 bits) }
      .otherwise      { code := U(TrapCause.IRQ_M_TIMER, 5 bits) }
    io.irq_cause := True ## B(0, 26 bits) ## code.asBits
  }
}
