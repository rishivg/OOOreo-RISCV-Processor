package ooo.memory
import spinal.core._

/** Exact ALU value decomposition for fused effective-address generation. */
object AluAddressSource {
  val width = 100
  def pack(a: Bits,b: Bits,cin: Bool,other: Bits,compare: Bool,add: Bool,cmp: Bool): Bits =
    cmp.asBits ## add.asBits ## compare.asBits ## cin.asBits ## other ## b ## a
  def a(x: Bits): Bits = x(31 downto 0)
  def b(x: Bits): Bits = x(63 downto 32)
  def other(x: Bits): Bits = x(95 downto 64)
  def cin(x: Bits): Bool = x(96)
  def compare(x: Bits): Bool = x(97)
  def add(x: Bits): Bool = x(98)
  def cmp(x: Bits): Bool = x(99)
}
