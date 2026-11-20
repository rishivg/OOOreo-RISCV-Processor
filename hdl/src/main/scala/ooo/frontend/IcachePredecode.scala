package ooo.frontend

import spinal.core._

/** Store the first quadrant and the next two lengths in four bits. */
object IcachePredecode {
    def encode(par: collection.Seq[Bits], cExt: Boolean, packed: Boolean): Bits = {
      val PDLANES = par.size      // 8 parcels -> 32b {off3,off2}/lane
      val cmp = Vec((0 until PDLANES).map(p =>
        if (cExt) par(p)(1 downto 0) =/= B"2'b11" else False))
      def cAt(x: UInt): Bool = cmp(x(2 downto 0))         // mod-8; callers guard by ok bits
      val nib = Vec(Bits(4 bits), PDLANES)
      for (p <- 0 until PDLANES) {
        val c1   = U(p, 4 bits) + Mux(cmp(p), U(1, 4 bits), U(2, 4 bits))
        val c1ok = c1 < U(PDLANES, 4 bits)
        val c2   = c1 + Mux(cAt(c1), U(1, 4 bits), U(2, 4 bits))
        val c2ok = c1ok && (c2 < U(PDLANES, 4 bits))
        val c3   = c2 + Mux(cAt(c2), U(1, 4 bits), U(2, 4 bits))
        val off2 = Mux(c1ok, (c2 - U(p + 2, 4 bits))(1 downto 0).asBits, B(0, 2 bits))
        val off3 = Mux(c2ok, (c3 - U(p + 3, 4 bits))(1 downto 0).asBits, B(0, 2 bits))
        nib(p) := (if (packed) (c2ok && cAt(c2)).asBits ## (c1ok && cAt(c1)).asBits ## par(p)(1 downto 0) else off3 ## off2)
      }
      nib.asBits
    }
  def decode(encoded: Bits, cExt: Boolean = true): (Bits, Bits) = {
    val lanes = encoded.getWidth / 4
    val fields = encoded.subdivideIn(lanes slices)
    val offsets = Vec(Bits(4 bits),lanes)
    val compressed = Bits(lanes bits)
    for (p <- 0 until lanes) {
      val first = if (cExt) fields(p)(1 downto 0) =/= B"2'b11" else False
      val second = fields(p)(2)
      val third = fields(p)(3)
      val firstTwo = Bits(2 bits)
      firstTwo(0) := first ^ second
      firstTwo(1) := !first && !second
      val firstThree = Bits(2 bits)
      firstThree(0) := !(first ^ second ^ third)
      firstThree(1) := (!first && !second) || (!first && !third) || (!second && !third)
      val secondValid = if (p + 2 < lanes) True else if (p + 1 < lanes) first else False
      val thirdValid = if (p + 4 < lanes) True else if (p + 3 < lanes) first || second
        else if (p + 2 < lanes) first && second else False
      val off2 = Mux(secondValid,firstTwo,B(0,2 bits))
      val off3 = Mux(thirdValid,firstThree,B(0,2 bits))
      offsets(p) := off3 ## off2
      compressed(p) := first
    }
    (offsets.asBits,compressed)
  }
}
