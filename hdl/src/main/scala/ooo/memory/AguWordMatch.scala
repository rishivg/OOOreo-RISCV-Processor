package ooo.memory

import spinal.core._

/** Word equality for base + displacement, checked through local carry constraints. */
object AguWordMatch {
  def carryFreeWithCarry(value: Bits, offset: Bits, target: Bits, cin: Bool): Bool = {
    val width = value.getWidth
    require(width >= 4 && offset.getWidth == width && target.getWidth == width)
    val low = value(1 downto 0).asUInt.resize(3) + offset(1 downto 0).asUInt.resize(3) + cin.asUInt.resize(3)
    val a = value(width - 1 downto 2); val b = offset(width - 1 downto 2)
    val t = target(width - 1 downto 2)
    val propagate = a ^ b
    val required = propagate ^ t
    val generated = (a & b) | (propagate & ~t)
    (required(0) === low(2)) &&
      (required(width - 3 downto 1) === generated(width - 4 downto 0))
  }

  def carryFree(value:Bits,offset:Bits,target:Bits):Bool={
    val lowCarry=(value(1 downto 0).asUInt +^ offset(1 downto 0).asUInt)(2)
    val a=value(31 downto 2);val b=offset(31 downto 2);val t=target(31 downto 2)
    val propagate=a ^ b
    val required=propagate ^ t
    val generated=(a & b) | (propagate & ~t)
    (required(0)===lowCarry) && (required(29 downto 1)===generated(28 downto 0))
  }
}
