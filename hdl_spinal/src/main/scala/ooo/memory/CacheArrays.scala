package ooo.memory

import spinal.core._

/** SpinalHDL ports of the cache helper arrays (hdl/common/cache). These were
  * BlackBoxes during co-validation; now real Components so the core is standalone.
  * io matches the SV modules exactly (clk0/rst0/csb.. ports) so Dcache/Icache wire
  * them unchanged.
  */

/** lru_array.sv -- 2-port PLRU store: registered read (port0) with write-forwarding
  * from the 1-cycle-delayed write (port1). */
class LruArray(setW: Int, w: Int) extends Component {
  setDefinitionName(s"lru_array_spinal_s${setW}_w${w}")
  val io = new Bundle {
    val clk0 = in Bool(); val rst0 = in Bool()
    val csb0 = in Bool(); val addr0 = in Bits(setW bits); val din0 = in Bits(w bits); val dout0 = out Bits(w bits)
    val csb1 = in Bool(); val web1 = in Bool(); val addr1 = in Bits(setW bits); val din1 = in Bits(w bits)
  }
  noIoPrefix()
  val domain = ClockDomain(clock = io.clk0, reset = io.rst0,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))
  new ClockingArea(domain) {
    val addr0Reg = Reg(Bits(setW bits)); val din0Reg = Reg(Bits(w bits))
    val web1Reg = RegInit(True); val addr1Reg = Reg(Bits(setW bits)); val din1Reg = Reg(Bits(w bits))
    val array = Vec(RegInit(B(0, w bits)), 1 << setW)
    when(!io.csb0) { addr0Reg := io.addr0; din0Reg := io.din0 }
    when(!io.csb1) { web1Reg := io.web1; addr1Reg := io.addr1; din1Reg := io.din1 }
    when(!web1Reg) { array(addr1Reg.asUInt) := din1Reg }
    io.dout0 := Mux((addr0Reg === addr1Reg) && !web1Reg, din1Reg, array(addr0Reg.asUInt))
  }
}

/** valid_array.sv -- single-port valid-bit store with a 1-cycle registered read. */
class ValidArray(setW: Int) extends Component {
  setDefinitionName(s"valid_array_spinal_s${setW}")
  val io = new Bundle {
    val clk0 = in Bool(); val rst0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(1 bits); val dout0 = out Bits(1 bits)
  }
  noIoPrefix()
  val domain = ClockDomain(clock = io.clk0, reset = io.rst0,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))
  new ClockingArea(domain) {
    val web0Reg = RegInit(True); val addr0Reg = Reg(Bits(setW bits)); val din0Reg = Reg(Bits(1 bits))
    val array = Vec(RegInit(B(0, 1 bits)), 1 << setW)
    when(!io.csb0) { web0Reg := io.web0; addr0Reg := io.addr0; din0Reg := io.din0 }
    when(!web0Reg) { array(addr0Reg.asUInt) := din0Reg }
    io.dout0 := array(addr0Reg.asUInt)
  }
}

/** plru_update.sv -- combinational PLRU tree walk: pick the victim way + the
  * next tree state on a hit. */
class PlruUpdate(numWays: Int, plruBits: Int, wayBits: Int) extends Component {
  setDefinitionName(s"plru_update_spinal_${numWays}_${plruBits}_${wayBits}")
  val io = new Bundle {
    val current_plru = in Bits(plruBits bits); val next_plru = out Bits(plruBits bits)
    val hit_way = in Bits(wayBits bits); val replace_way = out Bits(wayBits bits)
  }
  noIoPrefix()

  // victim way: walk the tree from the root following current_plru, then +1
  var rw: UInt = U(0, wayBits bits)
  for (_ <- 0 until wayBits) {
    val sel = io.current_plru(rw.resize(log2Up(plruBits) bits))
    rw = Mux(sel, (rw * 2 + 1).resize(wayBits bits), (rw * 2 + 2).resize(wayBits bits))
  }
  io.replace_way := (rw + 1).resize(wayBits bits).asBits

  // next state: flip the nodes on the path to hit_way
  val np = Vec(Bool(), plruBits)
  for (i <- 0 until plruBits) np(i) := io.current_plru(i)
  var vb: UInt = (io.hit_way.asUInt.resize(wayBits + 1) + (numWays - 1)).resize(wayBits + 1)
  for (_ <- 0 until wayBits) {
    val bit0 = vb(0)
    vb = ((vb - 1) >> 1).resize(wayBits + 1)
    val idx = vb(wayBits - 1 downto 0)
    for (k <- 0 until plruBits) when(idx === k) { np(k) := !bit0 }
  }
  io.next_plru := np.asBits
}
