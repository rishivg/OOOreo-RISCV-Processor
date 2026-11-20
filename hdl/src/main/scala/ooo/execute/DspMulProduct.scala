package ooo.execute

import spinal.core._

/** One registered Karatsuba product stage; 16/17-bit factors fit three DSP48s. */
class DspMulProduct extends Component {
  val io = new Bundle {
    val clk = in Bool()
    val capture = in Bool()
    val a = in Bits(33 bits)
    val b = in Bits(33 bits)
    val product = out Bits(64 bits)
  }
  val domain = ClockDomain(io.clk)
  new ClockingArea(domain) {
    val al = io.a(15 downto 0).asUInt; val ah = io.a(31 downto 16).asUInt
    val bl = io.b(15 downto 0).asUInt; val bh = io.b(31 downto 16).asUInt
    val lo = al * bl; val hi = ah * bh; val middle = (al +^ ah) * (bl +^ bh)
    for (signal <- Seq(lo, hi, middle)) signal.addAttribute("use_dsp", "yes")
    val loReg = Reg(UInt(32 bits)); val hiReg = Reg(UInt(32 bits))
    val middleReg = Reg(UInt(34 bits)); val correction = Reg(UInt(32 bits))
    when(io.capture) {
      loReg := lo; hiReg := hi; middleReg := middle
      correction := (Mux(io.a(32), io.b(31 downto 0).asUInt, U(0, 32 bits)) +
        Mux(io.b(32), io.a(31 downto 0).asUInt, U(0, 32 bits))).resize(32)
    }
    val cross = middleReg - loReg.resize(34) - hiReg.resize(34)
    val unsigned = loReg.resize(64) + (cross.resize(64) |<< 16) + (hiReg.resize(64) |<< 32)
    io.product := (unsigned - (correction.resize(64) |<< 32)).asBits
  }
}
