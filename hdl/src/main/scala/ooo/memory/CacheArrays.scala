package ooo.memory

import spinal.core._

/** PLRU store with a read port and a delayed, forwarding write port. */
class LruArray(setW: Int, w: Int, readCache: Boolean = false) extends Component {
  setDefinitionName(s"lru_array_spinal_s${setW}_w${w}" + (if (readCache) "_cached" else ""))
  val io = new Bundle {
    val clk0 = in Bool(); val rst0 = in Bool()
    val csb0 = in Bool(); val addr0 = in Bits(setW bits); val dout0 = out Bits(w bits)
    val csb1 = in Bool(); val web1 = in Bool(); val addr1 = in Bits(setW bits); val din1 = in Bits(w bits)
  }
  noIoPrefix()
  val domain = ClockDomain(clock = io.clk0, reset = io.rst0,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))
  new ClockingArea(domain) {
    val addr0Reg = Reg(Bits(setW bits))
    val web1Reg = RegInit(True); val addr1Reg = Reg(Bits(setW bits)); val din1Reg = Reg(Bits(w bits))
    val array = Vec(Reg(Bits(w bits)), 1 << setW) // Replacement hints need no reset.
    when(!io.csb0) { addr0Reg := io.addr0 }
    when(!io.csb1) { web1Reg := io.web1; addr1Reg := io.addr1; din1Reg := io.din1 }
    when(!web1Reg) { array(addr1Reg.asUInt) := din1Reg }
    if (readCache) {
      // Compute the read after this edge, including both delayed writes
      // and the newly captured forwarding port. No extra read cycle is added.
      def readAfterEdge(address: Bits): Bits = {
        val updated = Mux(!web1Reg && address === addr1Reg, din1Reg, array(address.asUInt))
        Mux(!io.rst0 && !io.csb1 && !io.web1 && address === io.addr1, io.din1, updated)
      }
      val cachedRead = Reg(Bits(w bits)).setName("cachedRead")
      // Select the completed reads after the late read-enable, rather than
      // putting that enable before the row mux and forwarding comparisons.
      cachedRead := Mux(!io.csb0, readAfterEdge(io.addr0), readAfterEdge(addr0Reg))
      io.dout0 := cachedRead
    } else {
      io.dout0 := Mux((addr0Reg === addr1Reg) && !web1Reg, din1Reg, array(addr0Reg.asUInt))
    }
  }
}

/** Select four-way victims directly from the tree, without encoding then decoding a way. */
object PlruSelect {
  def apply[T <: Data](plru: Bits, ways: Seq[T], binaryWay: UInt): T = {
    if (ways.size == 4 && plru.getWidth == 3) {
      val root = plru(0)
      val select = Vec(root && plru(1), root && !plru(1),
        !root && plru(2), !root && !plru(2)).asBits
      select.addAttribute("keep")
      val selected = cloneOf(ways.head)
      selected.assignFromBits(ooo.OhSel(select, ways.map(_.asBits)))
      selected
    } else Vec(ways)(binaryWay)
  }
}

/** Choose a victim and update the tree along the accessed way's path. */
class PlruUpdate(numWays: Int, plruBits: Int, wayBits: Int) extends Component {
  setDefinitionName(s"plru_update_spinal_${numWays}_${plruBits}_${wayBits}")
  val io = new Bundle {
    val current_plru = in Bits(plruBits bits); val next_plru = out Bits(plruBits bits)
    val hit_way = in Bits(wayBits bits); val replace_way = out Bits(wayBits bits)
  }
  noIoPrefix()

  if (numWays == 4 && plruBits == 3 && wayBits == 2) {
    val root = io.current_plru(0)
    io.replace_way := (!root).asBits ## (!Mux(root,io.current_plru(1),io.current_plru(2))).asBits
    io.next_plru := Mux(io.hit_way(1),io.hit_way(0),io.current_plru(2)).asBits ##
      Mux(io.hit_way(1),io.current_plru(1),io.hit_way(0)).asBits ## io.hit_way(1).asBits
  } else {
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
}
