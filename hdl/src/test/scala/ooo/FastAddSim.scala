package ooo

import spinal.core._
import spinal.core.sim._
import org.scalatest.funsuite.AnyFunSuite
import scala.util.Random

/** Check ALU/address arithmetic against fixed-width integer references. */
class FastAddSim extends AnyFunSuite {

  /** DUT: exposes withCout for a given width. */
  class AddDut(w: Int) extends Component {
    val io = new Bundle {
      val a    = in  UInt (w bits)
      val b    = in  UInt (w bits)
      val cin  = in  Bool()
      val sum  = out UInt (w bits)
      val cout = out Bool()
    }
    val (s, c) = FastAdd.withCout(io.a, io.b, carryIn = io.cin)
    io.sum := s
    io.cout := c
  }

  // Elaborate the width sweep together; each lane retains its original vectors.
  class AddMatrixDut(widths: Seq[Int]) extends Component {
    val io = new Bundle {
      val a = in UInt(widths.max bits)
      val b = in UInt(widths.max bits)
      val cin = in Bool()
      val sums = out Vec(UInt(widths.max bits), widths.size)
      val carries = out Bits(widths.size bits)
    }
    for ((width, lane) <- widths.zipWithIndex) {
      val (sum, carry) = FastAdd.withCout(io.a.resize(width), io.b.resize(width), carryIn=io.cin)
      io.sums(lane) := sum.resize(widths.max)
      io.carries(lane) := carry
    }
  }

  private lazy val compiledAdd32 = TestSimulation.config.compile(new AddDut(32))

  /** DUT: exposes the dedicated incrementer. */
  class IncDut(w: Int) extends Component {
    val io = new Bundle { val x = in UInt (w bits); val y = out UInt (w bits) }
    io.y := FastAdd.inc(io.x)
  }

  /** DUT: exposes withHiSplit's four outputs. */
  class SplitDut(w: Int, splitAt: Int, native: Boolean = false, inclusive: Boolean = false) extends Component {
    val io = new Bundle {
      val a      = in  UInt (w bits)
      val b      = in  UInt (w bits)
      val lo     = out UInt (splitAt bits)
      val cSplit = out Bool()
      val hi0    = out UInt (w - splitAt bits)
      val hi1    = out UInt (w - splitAt bits)
    }
    val (lo, cs, h0, h1) = FastAdd.withHiSplit(io.a, io.b, splitAt,
      nativeCarry=native, orPropagate=inclusive)
    io.lo := lo; io.cSplit := cs; io.hi0 := h0; io.hi1 := h1
  }

  private def mask(w: Int): BigInt = (BigInt(1) << w) - 1

  /** Reference: truncated sum + true carry-out of a + b + cin at width w. */
  private def ref(a: BigInt, b: BigInt, cin: Boolean, w: Int): (BigInt, Boolean) = {
    val full = a + b + (if (cin) 1 else 0)
    (full & mask(w), (full >> w) != 0)
  }

  private def checkVec(dut: AddDut, w: Int, a: BigInt, b: BigInt, cin: Boolean): Unit = {
    dut.io.a #= a; dut.io.b #= b; dut.io.cin #= cin
    sleep(1)
    val (es, ec) = ref(a, b, cin, w)
    assert(dut.io.sum.toBigInt == es,
      f"w=$w sum mismatch: a=0x$a%x b=0x$b%x cin=$cin got=0x${dut.io.sum.toBigInt}%x exp=0x$es%x")
    assert(dut.io.cout.toBoolean == ec,
      f"w=$w cout mismatch: a=0x$a%x b=0x$b%x cin=$cin got=${dut.io.cout.toBoolean} exp=$ec")
  }

  test("FastAdd exhaustive at w=8 (both carry-ins)") {
    TestSimulation.config.compile(new AddDut(8)).doSim { dut =>
      for (a <- 0 until 256; b <- 0 until 256; cin <- Seq(false, true))
        checkVec(dut, 8, BigInt(a), BigInt(b), cin)
    }
  }

  test("FastAdd randomized + corners at w=32") {
    compiledAdd32.doSim { dut =>
      val m = mask(32)
      val corners = Seq[BigInt](0, 1, 2, m, m - 1, BigInt("80000000", 16),
                                BigInt("7fffffff", 16), BigInt("ffff", 16),
                                BigInt("10000", 16), BigInt("aaaaaaaa", 16),
                                BigInt("55555555", 16))
      for (a <- corners; b <- corners; cin <- Seq(false, true)) checkVec(dut, 32, a, b, cin)
      val rnd = new Random(1234)
      for (_ <- 0 until 4000) {
        val a = BigInt(32, rnd); val b = BigInt(32, rnd)
        checkVec(dut, 32, a, b, rnd.nextBoolean())
      }
      // carry-propagate stress: a + ~a + 1 must be exactly 2^32 (sum 0, cout 1)
      for (_ <- 0 until 500) {
        val a = BigInt(32, rnd)
        checkVec(dut, 32, a, m - a, true)
      }
    }
  }

  test("FastAdd subtract form: a + ~b + 1 == a - b, cout == (a >=u b)") {
    compiledAdd32.doSim { dut =>
      val m = mask(32)
      val rnd = new Random(99)
      def sub(a: BigInt, b: BigInt): Unit = {
        dut.io.a #= a; dut.io.b #= (~b) & m; dut.io.cin #= true
        sleep(1)
        val expDiff = (a - b) & m
        assert(dut.io.sum.toBigInt == expDiff,
          f"sub mismatch a=0x$a%x b=0x$b%x got=0x${dut.io.sum.toBigInt}%x exp=0x$expDiff%x")
        // cout of (a + ~b + 1) is the NOT-borrow, i.e. unsigned a >= b
        assert(dut.io.cout.toBoolean == (a >= b),
          f"sltu mismatch a=0x$a%x b=0x$b%x got=${dut.io.cout.toBoolean} exp=${a >= b}")
      }
      for (v <- Seq[BigInt](0, 1, m, m - 1, BigInt("80000000", 16))) { sub(v, v); sub(v, 0); sub(0, v) }
      for (_ <- 0 until 4000) sub(BigInt(32, rnd), BigInt(32, rnd))
    }
  }

  test("FastAdd.inc == x + 1 (exhaustive w=8, randomized w=32)") {
    TestSimulation.config.compile(new IncDut(8)).doSim { dut =>
      for (x <- 0 until 256) {
        dut.io.x #= x; sleep(1)
        val exp = (BigInt(x) + 1) & mask(8)
        assert(dut.io.y.toBigInt == exp, s"inc8 x=$x got=${dut.io.y.toBigInt} exp=$exp")
      }
    }
    TestSimulation.config.compile(new IncDut(32)).doSim { dut =>
      val m = mask(32); val rnd = new Random(31337)
      def chk(x: BigInt): Unit = {
        dut.io.x #= x; sleep(1)
        val exp = (x + 1) & m
        assert(dut.io.y.toBigInt == exp, f"inc32 x=0x$x%x got=0x${dut.io.y.toBigInt}%x exp=0x$exp%x")
      }
      // all-ones is the full carry-propagate case (wraps to 0)
      for (v <- Seq[BigInt](0, 1, m, m - 1, BigInt("7fffffff",16), BigInt("80000000",16),
                            BigInt("ffff",16), BigInt("ffffff",16))) chk(v)
      for (_ <- 0 until 4000) chk(BigInt(32, rnd))
    }
  }

  test("FastAdd withHiSplit carry decomposition == a + b (w=32, split 16)") {
    TestSimulation.config.compile(new SplitDut(32, 16)).doSim { dut =>
      val rnd = new Random(7)
      def chk(a: BigInt, b: BigInt): Unit = {
        dut.io.a #= a; dut.io.b #= b
        sleep(1)
        val hi = if (dut.io.cSplit.toBoolean) dut.io.hi1.toBigInt else dut.io.hi0.toBigInt
        val got = (hi << 16) | dut.io.lo.toBigInt
        val exp = (a + b) & mask(32)
        assert(got == exp, f"hiSplit mismatch a=0x$a%x b=0x$b%x got=0x$got%x exp=0x$exp%x")
      }
      val m = mask(32)
      for (v <- Seq[BigInt](0, 1, m, BigInt("ffff", 16), BigInt("10000", 16))) { chk(v, v); chk(v, 1) }
      for (_ <- 0 until 4000) chk(BigInt(32, rnd), BigInt(32, rnd))
    }
  }

  test("FastAdd non-power-of-two and odd widths") {
    val widths = Seq(1, 7, 9, 17, 35)
    TestSimulation.config.compile(new AddMatrixDut(widths)).doSim { dut =>
      for ((w, lane) <- widths.zipWithIndex) {
        val m = mask(w); val random = new Random(1900+w)
        def check(a: BigInt, b: BigInt, carryIn: Boolean): Unit = {
          dut.io.a #= a; dut.io.b #= b; dut.io.cin #= carryIn
          sleep(1)
          val (sum, carry) = ref(a,b,carryIn,w)
          assert(dut.io.sums(lane).toBigInt == sum, s"width=$w a=$a b=$b carry=$carryIn")
          assert(dut.io.carries.toBigInt.testBit(lane) == carry, s"width=$w carry-out")
        }
        for(a <- Seq[BigInt](0,1,m,m-1); b <- Seq[BigInt](0,1,m,m-1); cin <- Seq(false,true))
          check(a,b,cin)
        for(_ <- 0 until 1000) check(BigInt(w,random),BigInt(w,random),random.nextBoolean())
      }
    }
  }

  test("FastAdd arbitrary split positions preserve both conditional upper sums") {
    for ((width, split, native, inclusive) <- Seq(
      (9,3,false,false), (17,5,false,true), (35,13,true,false), (32,7,true,true))) {
      TestSimulation.config.compile(new SplitDut(width,split,native,inclusive)).doSim { dut =>
        val random = new Random(8723 + width)
        val lowMask = mask(split)
        val highMask = mask(width-split)
        val corners = Seq[BigInt](0,1,lowMask,lowMask+1,mask(width))
        val vectors = (for (a <- corners; b <- corners) yield (a,b)) ++
          (0 until 1000).map(_ => (BigInt(width,random),BigInt(width,random)))
        for ((a,b) <- vectors) {
          dut.io.a #= a; dut.io.b #= b; sleep(1)
          val low = (a & lowMask) + (b & lowMask)
          val upper = (a >> split) + (b >> split)
          assert(dut.io.lo.toBigInt == (low & lowMask))
          assert(dut.io.cSplit.toBoolean == (low > lowMask))
          assert(dut.io.hi0.toBigInt == (upper & highMask))
          assert(dut.io.hi1.toBigInt == ((upper+1) & highMask))
        }
      }
    }
  }
}
