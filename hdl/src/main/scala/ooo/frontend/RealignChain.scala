package ooo.frontend

import spinal.core._
import ooo.{CpuConfig, OhSel}

/** Per-way compressed-instruction realignment. Select the small results after tag matching. */
class RealignChain(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("realign_chain_spinal")
  if (cfg.keepTimingHierarchy) addAttribute("keep_hierarchy", "yes")
  val IFW  = cfg.ifWidth
  val PMAX = 2 * IFW

  val io = new Bundle {
    val pd          = in  Bits (PMAX * 4 bits)   // per-lane {off3,off2} predecode row
    val comp        = in  Bits (PMAX bits)       // per-lane "compressed instruction starts here"
    val entry_lane  = in  UInt (3 bits)          // way-independent (pc / carry regs)
    val carry_valid = in  Bool()
    val lane_s      = out Bits (IFW * 4 bits)    // slot start lanes (block coords)
    val sn_s        = out Bits (IFW * 4 bits)    // slot seq-next lanes
    val valid_s     = out Bits (IFW bits)        // slot complete-in-window (thermometer)
    val ch_p        = out UInt (4 bits)          // consumed pointer
    val span_r      = out Bool()                 // 32b op straddling the window boundary
  }
  noIoPrefix()

  val compV = Vec(Bool(), PMAX)
  for (p <- 0 until PMAX) compV(p) := io.comp(p)
  val pdRow = io.pd.subdivideIn(PMAX slices)

  def chain(entryLane: UInt, fixedEntry: Option[Int] = None): Bits = {
    val eNib = pdRow(entryLane)
    val e4   = entryLane.resize(4 bits)
    val ch0  = e4
    val ch1  = e4 + Mux(compV(entryLane), U(1, 4 bits), U(2, 4 bits))
    val ch2  = e4 + (U(2, 3 bits) +^ eNib(1 downto 0).asUInt).resize(4 bits)
    val ch3  = e4 + (U(3, 3 bits) +^ eNib(3 downto 2).asUInt).resize(4 bits)
    val ch4 = fixedEntry match {
      case Some(e) =>
        val ends = Vec((0 until 4).map { offset =>
          val start = e + 3 + offset
          Mux(compV(start & 7), U(start + 1, 4 bits), U(start + 2, 4 bits))
        })
        ends(eNib(3 downto 2).asUInt)
      case None => ch3 + Mux(compV(ch3(2 downto 0)), U(1, 4 bits), U(2, 4 bits))
    }
    val chNC = Seq(ch0, ch1, ch2, ch3, ch4)

    val laneS = Vec(UInt(4 bits), IFW)
    val snS   = Vec(UInt(4 bits), IFW)
    for (s <- 0 until IFW) {
      laneS(s) := (if (s == 0) Mux(io.carry_valid, U(7, 4 bits), ch0) else Mux(io.carry_valid, chNC(s - 1), chNC(s)))
      snS(s)   := Mux(io.carry_valid, chNC(s), chNC(s + 1))
  }
  val lim   = Mux(io.carry_valid, U(6, 4 bits), U(7, 4 bits))
  val limM1 = Mux(io.carry_valid, U(5, 4 bits), U(6, 4 bits))
  def condAt(c: UInt): Bool = (c <= lim) && (compV(c(2 downto 0)) || (c <= limM1))
  val fixedValidity = fixedEntry.map { e =>
    def validAt(n: Int): Bool = {
      if (n <= 5) True
      else if (n == 6) !io.carry_valid || compV(6)
      else if (n == 7) !io.carry_valid && compV(7)
      else False
    }
    Seq(validAt(e), Mux(compV(e), validAt(e + 1), validAt(e + 2)),
      Vec((0 until 4).map(o => validAt(e + 2 + o)))(eNib(1 downto 0).asUInt),
      Vec((0 until 4).map(o => validAt(e + 3 + o)))(eNib(3 downto 2).asUInt))
  }
  val validS = Vec(Bool(), IFW)
  var vAcc: Bool = True
  for (s <- 0 until IFW) {
    val vc = fixedValidity match {
      case Some(v) => if (s == 0) io.carry_valid || v(0) else Mux(io.carry_valid, v(s - 1), v(s))
      case None => if (s == 0) Mux(io.carry_valid, True, condAt(ch0)) else condAt(laneS(s))
    }
    vAcc = vAcc && vc
    validS(s) := vAcc
  }
  val nSel = Vec(Bool(), IFW + 1)
  nSel(0) := !validS(0)
  for (n <- 1 until IFW) nSel(n) := validS(n - 1) && !validS(n)
  nSel(IFW) := validS(IFW - 1)
  val chCons = (0 to IFW).map(n => (if (n == 0) ch0 else Mux(io.carry_valid, chNC(n - 1), chNC(n))))
  val chP = OhSel(nSel.asBits, chCons.map(_.asBits)).asUInt

  val span = if (cfg.cExt) !validS(IFW - 1) && (chP === lim) && !compV(lim(2 downto 0)) else False
  span.asBits ## chP.asBits ## validS.asBits ## snS.asBits ## laneS.asBits
  }
  val result = if (cfg.frontendParallelRealign) {
    val candidates = Vec((0 until PMAX).map(p => chain(U(p,3 bits), if (PMAX == 8) Some(p) else None)))
    if (cfg.keepTimingHierarchy) candidates.foreach(_.addAttribute("keep"))
    candidates(io.entry_lane)
  } else chain(io.entry_lane)
  io.lane_s := result(0,IFW * 4 bits)
  io.sn_s := result(IFW * 4,IFW * 4 bits)
  io.valid_s := result(IFW * 8,IFW bits)
  io.ch_p := result(IFW * 9,4 bits).asUInt
  io.span_r := result.msb
}
