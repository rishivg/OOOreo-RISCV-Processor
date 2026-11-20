package ooo.memory

import spinal.core._

/** Select byte lanes directly so late load data avoids a shift-then-format mux. */
object LoadResultFormat {
  def control(op: Bits, offset: UInt): Bits = {
    val low = Bits(4 bits); val middle = Bits(4 bits); val signed = Bits(4 bits)
    val word = op === 2; val byte = op === 0 || op === 4; val half = op === 1 || op === 5
    for (i <- 0 until 4) {
      val byteLane = offset === i
      val halfLane = offset(1) === Bool(i >= 2)
      low(i) := (word && Bool(i == 0)) || (half && halfLane && Bool(i % 2 == 0)) || (byte && byteLane)
      middle(i) := (word && Bool(i == 1)) || (half && halfLane && Bool(i % 2 == 1))
      signed(i) := ((op === 0) && byteLane) || ((op === 1) && halfLane && Bool(i % 2 == 1))
    }
    (op === 0).asBits ## word.asBits ## signed ## middle ## low
  }
  def decoded(data: Bits, select: Bits): Bits = {
    val sign = (select(11 downto 8) & Vec((0 until 4).map(i => data(i*8+7))).asBits).orR
    val bytes = data.subdivideIn(8 bits).toSeq
    val lo = ooo.OhSel(select(3 downto 0),bytes)
    val mid = ooo.OhSel(select(7 downto 4),bytes) | B(8 bits, default -> (sign && select(13)))
    val hi = (data(31 downto 16) & B(16 bits, default -> select(12))) | B(16 bits, default -> sign)
    hi ## mid ## lo
  }
  def apply(data: Bits, op: Bits, offset: UInt): Bits =
    decoded(data, control(op, offset))
}
