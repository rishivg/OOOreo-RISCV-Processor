package ooo.common

import spinal.core._

/** Always-on controller. Stop new work, drain accepted transactions, then gate.
  * Wake wins over entry; require two consecutive quiet cycles before closing.
  */
class SleepController extends Component {
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val sleep_request = in Bool(); val wake = in Bool(); val quiescent = in Bool()
    val halt = out Bool(); val clock_enable = out Bool()
  }
  val domain = ClockDomain(io.clk, io.rst, config=ClockDomainConfig(resetActiveLevel=HIGH, resetKind=SYNC))
  new ClockingArea(domain) {
    val drain = RegInit(False)
    val asleep = RegInit(False)
    val quiet = RegInit(False)
    when(io.wake) { drain := False; asleep := False; quiet := False }
    .elsewhen(io.sleep_request) { drain := True; quiet := False }
    .elsewhen(drain && !asleep) {
      quiet := io.quiescent
      when(quiet && io.quiescent) { asleep := True }
    }
    io.halt := drain
    io.clock_enable := !asleep || io.rst
  }
}

/** Dedicated Xilinx global clock gate primitive. */
class XilinxBufgCtrl extends BlackBox {
  setBlackBoxName("BUFGCTRL")
  addGeneric("INIT_OUT", 0)
  addGeneric("PRESELECT_I0", "FALSE")
  addGeneric("PRESELECT_I1", "FALSE")
  val io = new Bundle {
    val I0 = in Bool(); val I1 = in Bool()
    val S0 = in Bool(); val S1 = in Bool()
    val CE0 = in Bool(); val CE1 = in Bool()
    val IGNORE0 = in Bool(); val IGNORE1 = in Bool()
    val O = out Bool()
  }
  noIoPrefix()
}

/** Gate the clock during sleep while retaining downstream state.
  * ASIC integration may replace the inferred falling-edge gate with an ICG cell.
  * FPGA builds use BUFGCTRL; the falling-edge register also tracks gate status.
  */
class SafeClockGate(fpga: Boolean = false) extends Component {
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val enable = in Bool(); val scan_enable = in Bool()
    val gated_clk = out Bool(); val closed = out Bool()
  }
  val lowPhase = ClockDomain(io.clk, io.rst,
    config=ClockDomainConfig(clockEdge=FALLING, resetActiveLevel=HIGH, resetKind=SYNC))
  new ClockingArea(lowPhase) {
    val enabled = RegInit(True)
    enabled := io.enable || io.scan_enable || io.rst
    if (fpga) {
      val gate = new XilinxBufgCtrl
      gate.io.I0 := io.clk; gate.io.I1 := False
      gate.io.S0 := True; gate.io.S1 := False
      gate.io.CE0 := io.enable || io.scan_enable || io.rst; gate.io.CE1 := False
      gate.io.IGNORE0 := False; gate.io.IGNORE1 := False
      io.gated_clk := gate.io.O
    } else io.gated_clk := io.clk && enabled
    io.closed := !enabled
  }
}
