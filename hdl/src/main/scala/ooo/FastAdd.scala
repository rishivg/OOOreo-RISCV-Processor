package ooo

import spinal.core._

/** Carry arithmetic with an ASIC prefix network or FPGA native carry inference. */
object FastAdd {
  val prefixTopologies: Set[String] =
    Set("auto", "kogge-stone", "sklansky", "brent-kung", "han-carlson")

  /** Return the fixed-width sum and carry-out. */
  def withCout(a: UInt, b: UInt, carryIn: Bool = False,
               keepPrefix: Boolean = true, nativeCarry: Boolean = false, orPropagate: Boolean = false,
               prefixTopology: String = "auto", keepPropagate: Boolean = true): (UInt, Bool) = {
    val w = a.getWidth
    require(w > 0 && b.getWidth == w, s"FastAdd operands need equal positive widths ($w vs ${b.getWidth})")
    require(prefixTopologies(prefixTopology), s"Unsupported prefix topology: $prefixTopology")
    if (nativeCarry) {
      val result = a.resize(w + 1) + b.resize(w + 1) + carryIn.asUInt.resize(w + 1)
      return (result.resize(w), result(w))
    }
    // Pair wider kept trees; short adders retain minimum prefix depth.
    def K(x: Bool): Bool = if (!keepPrefix) x else {
      val s = Bool(); s := x; s.addAttribute("keep"); s
    }
    def P(x: Bool): Bool = if (keepPropagate) K(x) else x
    val pOrig = (0 until w).map(i => a(i) ^ b(i))     // propagate (also the sum term)
    val carryProp = if (orPropagate) (0 until w).map(i => a(i) | b(i)) else pOrig
    val gOrig = (0 until w).map(i => a(i) & b(i))
    val stride = if (keepPrefix && w >= 16) 2 else 1
    val groups = (w + stride - 1) / stride
    var prefixGenerate = Array.tabulate(groups) { j =>
      val i = j * stride
      if (stride == 2 && i + 1 < w) K(gOrig(i + 1) | (carryProp(i + 1) & gOrig(i))) else gOrig(i)
    }
    var prefixPropagate = Array.tabulate(groups) { j =>
      val i = j * stride
      if (stride == 2 && i + 1 < w) P(carryProp(i + 1) & carryProp(i)) else carryProp(i)
    }
    // Build one immutable level at a time so every merge reads the prior level.
    def level(active: Int => Boolean, root: Int => Int): Unit = {
      val nextGenerate = Array.tabulate(groups) { i =>
        if (active(i)) K(prefixGenerate(i) | (prefixPropagate(i) & prefixGenerate(root(i))))
        else prefixGenerate(i)
      }
      val nextPropagate = Array.tabulate(groups) { i =>
        if (active(i)) P(prefixPropagate(i) & prefixPropagate(root(i)))
        else prefixPropagate(i)
      }
      prefixGenerate = nextGenerate
      prefixPropagate = nextPropagate
    }
    val topology = if (prefixTopology == "auto") {
      if (groups <= 8) "sklansky" else "kogge-stone"
    } else prefixTopology
    topology match {
      case "brent-kung" =>
        var distance = 1
        while (distance < groups) {
          val step = distance
          level(i => (i + 1) % (2 * step) == 0, i => i - step)
          distance *= 2
        }
        distance /= 4
        while (distance >= 1) {
          val step = distance
          level(i => i >= 3 * step - 1 && (i + 1) % (2 * step) == step, i => i - step)
          distance /= 2
        }
      case "han-carlson" =>
        level(i => i % 2 == 1, i => i - 1)
        var distance = 2
        while (distance < groups) {
          val step = distance
          level(i => i % 2 == 1 && i >= step, i => i - step)
          distance *= 2
        }
        level(i => i > 0 && i % 2 == 0, i => i - 1)
      case _ =>
        var distance = 1
        while (distance < groups) {
          val step = distance
          if (topology == "sklansky")
            level(i => (i & step) != 0, i => (i / step) * step - 1)
          else
            level(i => i >= step, i => i - step)
          distance *= 2
        }
    }
    def carryAfter(i: Int): Bool = {
      val j = i / stride
      if (stride == 1 || i % 2 == 1 || i == w - 1) prefixGenerate(j) | (prefixPropagate(j) & carryIn)
      else {
        val previous = if (i == 0) carryIn else prefixGenerate(j - 1) | (prefixPropagate(j - 1) & carryIn)
        gOrig(i) | (carryProp(i) & previous)
      }
    }
    val s = Bits(w bits)
    for (i <- 0 until w) {
      val ci = if (i == 0) carryIn else carryAfter(i - 1)
      s(i) := pOrig(i) ^ ci
    }
    (s.asUInt, carryAfter(w - 1))
  }

  /** Return the low sum, split carry, and both conditional upper sums. */
  def withHiSplit(a: UInt, b: UInt, splitAt: Int,
                  keepPrefix: Boolean = true, nativeCarry: Boolean = false, orPropagate: Boolean = false): (UInt, Bool, UInt, UInt) = {
    val w = a.getWidth
    require(b.getWidth == w, s"FastAdd operands must match width ($w vs ${b.getWidth})")
    require(splitAt > 0 && splitAt < w, s"splitAt $splitAt must be inside width $w")
    val (lo, cSplit) = withCout(a(splitAt - 1 downto 0), b(splitAt - 1 downto 0), False, keepPrefix, nativeCarry, orPropagate)
    val (hi0, _) = withCout(a(w - 1 downto splitAt), b(w - 1 downto splitAt), False, keepPrefix, nativeCarry, orPropagate)
    val (hi1, _) = withCout(a(w - 1 downto splitAt), b(w - 1 downto splitAt), True, keepPrefix, nativeCarry, orPropagate)
    (lo, cSplit, hi0, hi1)
  }

  /** Carry-save reduction followed by one split carry-propagate addition. */
  def withCsaHiSplit(a: UInt,b: UInt,c: UInt,cin: Bool,splitAt: Int,
                     nativeCarry: Boolean = false, orPropagate: Boolean = false): (UInt,Bool,UInt,UInt) = {
    require(a.getWidth == b.getWidth && a.getWidth == c.getWidth)
    require(splitAt > 0 && splitAt < a.getWidth, "Carry-save split must be inside the operand")
    val sum = a ^ b ^ c
    val carry = ((a & b) | (a & c) | (b & c)) |<< 1
    val (lo,lowCarry) = withCout(sum(splitAt-1 downto 0),carry(splitAt-1 downto 0),
      carryIn=cin,nativeCarry=nativeCarry,orPropagate=orPropagate)
    val upper = sum(a.getWidth-1 downto splitAt)
    val upperCarry = carry(a.getWidth-1 downto splitAt)
    val (hi0,_) = withCout(upper,upperCarry,nativeCarry=nativeCarry,orPropagate=orPropagate)
    val (hi1,_) = withCout(upper,upperCarry,carryIn=True,nativeCarry=nativeCarry,orPropagate=orPropagate)
    (lo,lowCarry,hi0,hi1)
  }

  /** Split sum for a sign-extended immediate; the upper add reduces to ±1. */
  def withSignedHiSplit(a: UInt, immediate: SInt, splitAt: Int,
                        nativeCarry: Boolean = false, orPropagate: Boolean = false,
                        carrySelectAt: Int = 0): (UInt, Bool, UInt, UInt) = {
    require(immediate.getWidth <= splitAt && splitAt < a.getWidth)
    require(carrySelectAt >= 0 && carrySelectAt < splitAt)
    val b = immediate.resize(a.getWidth).asUInt
    if (nativeCarry) return withHiSplit(a,b,splitAt,nativeCarry=true)
    val (lo,carry) = if (carrySelectAt == 0)
      withCout(a(splitAt - 1 downto 0),b(splitAt - 1 downto 0),orPropagate=orPropagate)
    else {
      val cut = carrySelectAt
      val (low,c) = withCout(a(cut - 1 downto 0),b(cut - 1 downto 0),orPropagate=orPropagate)
      val (mid0,c0) = withCout(a(splitAt - 1 downto cut),b(splitAt - 1 downto cut),orPropagate=orPropagate)
      val (mid1,c1) = withCout(a(splitAt - 1 downto cut),b(splitAt - 1 downto cut),carryIn=True,orPropagate=orPropagate)
      ((Mux(c,mid1,mid0).asBits ## low.asBits).asUInt,Mux(c,c1,c0))
    }
    val upper = a(a.getWidth - 1 downto splitAt)
    val negative = immediate.msb
    val hi0 = Mux(negative,dec(upper),upper)
    val hi1 = Mux(negative,upper,inc(upper,keepPrefix=true))
    (lo,carry,hi0,hi1)
  }

  /** Truncating increment with optional prefix preservation. */
  def inc(x: UInt, keepPrefix: Boolean = false): UInt = {
    val w = x.getWidth
    // Preserve prefix boundaries so synthesis cannot rebuild a ripple rooted at a late enable.
    def K(b: Bool): Bool = if (!keepPrefix) b else {
      val s = Bool(); s := b; s.addAttribute("keep"); s
    }
    var acc: Array[Bool] = (0 until w).map(i => x(i)).toArray   // prefix AND
    var d = 1
    while (d < w) {
      val na = Array.tabulate(w)(i => if ((i & d) != 0) K(acc(i) & acc((i / d) * d - 1)) else acc(i))
      acc = na; d *= 2
    }
    val o = Bits(w bits)
    for (i <- 0 until w) o(i) := (if (i == 0) !x(0) else x(i) ^ acc(i - 1))
    o.asUInt
  }

  def lessThan(a: UInt, b: UInt, nativeCarry: Boolean = false): Bool =
    if (nativeCarry) a < b else !withCout(a,~b,carryIn=True)._2

  def incBits(x: UInt, keepPrefix: Boolean = false): Bits = inc(x, keepPrefix).asBits

  /** Fixed-width addition of 2^bit, preserving the ASIC carry prefix. */
  def addPow2(x: UInt, bit: Int, nativeCarry: Boolean = false): UInt = {
    require(bit >= 0 && bit < x.getWidth)
    if (nativeCarry) x + U(BigInt(1) << bit,x.getWidth bits)
    else if (bit == 0) inc(x,keepPrefix=true)
    else (inc(x(x.getWidth - 1 downto bit),keepPrefix=true).asBits ##
      x(bit - 1 downto 0).asBits).asUInt
  }

  def pcNext(pc: Bits, compressed: Bool, nativeCarry: Boolean = false): Bits =
    if (nativeCarry) (pc.asUInt + Mux(compressed,U(2,pc.getWidth bits),U(4,pc.getWidth bits))).asBits
    else Mux(compressed,addPow2(pc.asUInt,1).asBits,addPow2(pc.asUInt,2).asBits)

  def dec(x: UInt, nativeCarry: Boolean = false): UInt =
    if (nativeCarry) x - 1 else ~inc(~x,keepPrefix=true)

  def bits(a: UInt, b: UInt, keepPrefix: Boolean = true,
           prefixTopology: String = "auto", keepPropagate: Boolean = true,
           orPropagate: Boolean = false): Bits =
    withCout(a, b, keepPrefix = keepPrefix,
      prefixTopology = prefixTopology, keepPropagate = keepPropagate,
      orPropagate = orPropagate)._1.asBits
}
