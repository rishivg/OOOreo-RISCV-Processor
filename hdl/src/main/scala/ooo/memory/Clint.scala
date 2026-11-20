package ooo.memory

import spinal.core._
import ooo.CpuConfig

object Clint {
  val offsets = Seq(0x0000, 0x4000, 0x4004, 0xbff8, 0xbffc)

  def registerSelect(addr: Bits): Bits = {
    val select = Bits(offsets.size bits)
    for ((offset, i) <- offsets.zipWithIndex)
      select(i) := addr(15 downto 2) === B(offset >> 2, 14 bits)
    select
  }

  /** Decode word offsets from sum operands without waiting for address carries. */
  def registerAddSelect(a: Bits, b: Bits, cin: Bool = False): Bits = {
    val select = Bits(offsets.size bits)
    for ((offset, i) <- offsets.zipWithIndex)
      select(i) := AguWordMatch.carryFreeWithCarry(a(15 downto 0), b(15 downto 0), B(offset, 16 bits), cin)
    select
  }

  def writeSelect(addr: Bits, cfg: CpuConfig): Bits =
    registerSelect(addr) & B(offsets.size bits, default -> (addr(31 downto 16) === B(cfg.clintHi16, 16 bits)))
}

/** Uncached CLINT register window: software interrupts, mtime, and mtimecmp.
  * Timer state remains on the always-on clock when core sleep is enabled.
  */
class Clint(cfg: CpuConfig, predecodedWrites: Boolean = false, predecodedReads: Boolean = false, retimedRead: Boolean = false, clientClockedRead: Boolean = false) extends Component {
  setDefinitionName("clint_spinal")
  val lateWriteGrant = cfg.clintLateWriteGrant && predecodedWrites
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val read_clk = if (clientClockedRead) in Bool() else null
    val req_valid = in Bool()                // this cycle's dmem request targets the CLINT
    val req_addr  = in Bits (16 bits)        // offset inside the window
    val req_rmask = in Bits (4 bits)
    val req_wmask = in Bits (4 bits)
    val req_wdata = in Bits (32 bits)
    val write_sel = if (predecodedWrites) in Bits(Clint.offsets.size bits) else null
    val write_block = if (lateWriteGrant) in Bool() else null
    val read_sel = if (predecodedReads) in Bits(Clint.offsets.size bits) else null
    val read_fire = if (predecodedReads) in Bool() else null
    val request_fire = if (predecodedReads) in Bool() else null
    val resp      = out Bool()               // one cycle after req_valid
    val rdata     = out Bits (32 bits)
    val irq_timer = out Bool()
    val irq_soft  = out Bool()
    val mtime     = out UInt (64 bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  val readDomain = if (clientClockedRead) ClockDomain(clock=io.read_clk,reset=io.rst,
    config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC)) else domain
  if (clientClockedRead) readDomain.setSynchronousWith(domain)

  val clint = new ClockingArea(domain) {
    val mtime    = RegInit(U(0, 64 bits))
    val mtimecmp = RegInit(U("64'hFFFFFFFFFFFFFFFF"))   // no spurious timer irq out of reset
    val msip     = RegInit(False)
    // Banks above bit zero advance only when the lower bits carry.
    for (lo <- 0 until 64 by 8) {
      val carry = if (lo == 0) True else mtime(lo - 1 downto 0).andR
      when(carry) { mtime(lo + 7 downto lo) := mtime(lo + 7 downto lo) + 1 }
    }

    val off = io.req_addr(15 downto 2) ## B"2'b00"
    val selMsip  = off === B"16'h0000"
    val selCmpLo = off === B"16'h4000"
    val selCmpHi = off === B"16'h4004"
    val selTimLo = off === B"16'hBFF8"
    val selTimHi = off === B"16'hBFFC"

    val readSelect = if (predecodedReads) io.read_sel else
      selTimHi ## selTimLo ## selCmpHi ## selCmpLo ## selMsip
    val rd = ooo.OhSel(readSelect, Seq(B(0, 31 bits) ## msip, mtimecmp(31 downto 0).asBits,
      mtimecmp(63 downto 32).asBits, mtime(31 downto 0).asBits, mtime(63 downto 32).asBits))

    def merge(old: Bits, wm: Bits, wd: Bits): Bits =
      Cat((0 until 4).map(b => Mux(wm(b), wd(b * 8, 8 bits), old(b * 8, 8 bits))))
    val writeSel = if (predecodedWrites) io.write_sel else
      (selTimHi ## selTimLo ## selCmpHi ## selCmpLo ## selMsip) &
        B(Clint.offsets.size bits, default -> (io.req_valid && io.req_wmask.orR))
    when(writeSel(0)) { msip := merge(B(0, 31 bits) ## msip, io.req_wmask, io.req_wdata)(0) }
    when(writeSel(1)) { mtimecmp(31 downto 0) := merge(mtimecmp(31 downto 0).asBits, io.req_wmask, io.req_wdata).asUInt }
    when(writeSel(2)) { mtimecmp(63 downto 32) := merge(mtimecmp(63 downto 32).asBits, io.req_wmask, io.req_wdata).asUInt }
    when(writeSel(3)) { mtime(31 downto 0) := merge(mtime(31 downto 0).asBits, io.req_wmask, io.req_wdata).asUInt }
    when(writeSel(4)) { mtime(63 downto 32) := merge(mtime(63 downto 32).asBits, io.req_wmask, io.req_wdata).asUInt }

    if (lateWriteGrant) when(io.write_block) {
      msip := msip
      mtimecmp := mtimecmp
      for (lo <- 0 until 64 by 8) {
        val carry = if (lo == 0) True else mtime(lo - 1 downto 0).andR
        mtime(lo + 7 downto lo) := mtime(lo + 7 downto lo)
        when(carry) { mtime(lo + 7 downto lo) := mtime(lo + 7 downto lo) + 1 }
      }
    }

    val requestFire = if (predecodedReads) io.request_fire else io.req_valid && (io.req_rmask.orR || io.req_wmask.orR)
    val readFire = if (predecodedReads) io.read_fire else io.req_valid && io.req_rmask.orR
    // The requester drains responses before gating this related clock.
    new ClockingArea(readDomain) {
      io.resp := RegNext(requestFire) init(False)
      if (retimedRead) {
        // Capture the timer bank before selecting read data. Keep the last read
        // through idle/write cycles with a delayed hold register, without adding latency.
        val values = Seq(B(0,31 bits) ## msip,mtimecmp(31 downto 0).asBits,
          mtimecmp(63 downto 32).asBits,mtime(31 downto 0).asBits,mtime(63 downto 32).asBits)
        val snapshot = values.map(v => RegNext(v))
        val selection = Reg(Bits(Clint.offsets.size bits))
        when(readFire) { selection := readSelect }
        val readLast = RegNext(readFire)
        val current = ooo.OhSel(selection,snapshot)
        val held = Reg(Bits(32 bits))
        when(readLast) { held := current }
        io.rdata := Mux(readLast,current,held)
      } else {
        val readData = Reg(Bits(32 bits))
        when(readFire) { readData := rd }
        io.rdata := readData
      }
    }
    io.irq_timer := RegNext(!ooo.FastAdd.lessThan(mtime,mtimecmp,cfg.fpgaNativeAdd)) init(False)
    io.irq_soft  := msip
    io.mtime     := mtime
  }
}
