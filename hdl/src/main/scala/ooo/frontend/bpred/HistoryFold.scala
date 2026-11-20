package ooo.frontend.bpred

import spinal.core._
import ooo.OhSel

object HistoryFold {
  case class ShiftPlan(count: Bits, inserted: Bits, select: Bits, taken: Bits)

  private def xor(terms: Seq[Bool]): Bool = {
    if (terms.isEmpty) False
    else if (terms.length == 1) terms.head
    else xor(terms.grouped(2).map(pair => pair.reduce(_ ^ _)).toSeq)
  }

  /** Decode once; bit zero holds the newest valid branch outcome. */
  def plan(valid: Bits, taken: Bits): ShiftPlan = {
    val n = valid.getWidth
    require(n > 0 && n <= 4 && taken.getWidth == n)
    val masks = 0 until (1 << n)
    val select = Vec(masks.map(mask => valid === B(mask, n bits))).asBits
    val count = Vec((0 to n).map(k =>
      masks.filter(Integer.bitCount(_) == k).map(select(_)).reduce(_ | _))).asBits
    val inserted = Vec((0 until n).map { bit =>
      masks.flatMap { mask =>
        val slots = (0 until n).filter(i => (mask & (1 << i)) != 0).reverse
        if (bit < slots.length) Some(select(mask) && taken(slots(bit))) else None
      }.reduce(_ | _)
    }).asBits
    ShiftPlan(count, inserted, select, taken)
  }

  /** Two-slot stages avoid a high-fanout four-slot count decode on the GHR. */
  def shiftPairs(history: Bits, valid: Bits, taken: Bits): Bits = {
    require(valid.getWidth == taken.getWidth && history.getWidth >= valid.getWidth)
    var h = history
    for (first <- 0 until valid.getWidth by 2) {
      def shifted(k: Int): Bits = (h.asUInt << k).resize(h.getWidth).asBits
      if (first + 1 == valid.getWidth) {
        h = Mux(valid(first), shifted(1) | taken(first).asBits.resize(h.getWidth), h)
      } else {
        val a = valid(first)
        val b = valid(first + 1)
        val select = Vec(!(a | b), a ^ b, a & b).asBits
        val newest = Mux(b, taken(first + 1), a & taken(first))
        val inserted = (a & b & taken(first)).asBits ## newest.asBits
        h = OhSel(select, Seq(h, shifted(1), shifted(2))) | inserted.resize(h.getWidth)
      }
    }
    h
  }

  /** Rotation and outgoing-history corrections depend only on the shift count. */
  def update(ch: Bits, history: Bits, length: Int, plan: ShiftPlan): Bits = {
    val w = ch.getWidth
    val n = plan.inserted.getWidth
    require(w > 0 && length > 0 && length <= history.getWidth)
    if (length < n) return parallel(ch, history, length, plan.taken, plan.select)
    val bases = (0 to n).map { k =>
      Vec((0 until w).map { bit =>
        val outgoing = (0 until k).filter(j => (length + k - 1 - j) % w == bit)
          .map(j => history(length - 1 - j))
        xor(Seq(ch((bit - k % w + w) % w)) ++ outgoing)
      }).asBits
    }
    val incoming = Vec((0 until w).map(bit =>
      xor((bit until n by w).map(plan.inserted(_))))).asBits
    OhSel(plan.count, bases) ^ incoming
  }

  def step(ch: Bits, length: Int, incoming: Bool, outgoing: Bool): Bits = {
    val w=ch.getWidth
    val injection=Vec(Bool(),w)
    for (i <- 0 until w) {
      val a=if (i == 0) incoming else False
      val b=if (i == length % w) outgoing else False
      injection(i):=a ^ b
    }
    (ch(w-2 downto 0) ## ch(w-1)) ^ injection.asBits
  }

  def parallel(ch: Bits, history: Bits, length: Int, taken: Bits, select: Bits): Bits = {
    require(select.getWidth == (1 << taken.getWidth))
    val candidates=(0 until select.getWidth).map { mask =>
      var fold=ch;var h=history
      for (i <- 0 until taken.getWidth if (mask & (1 << i)) != 0) {
        fold=step(fold,length,taken(i),h(length-1))
        h=h(h.getWidth-2 downto 0) ## taken(i)
      }
      val value=Bits(ch.getWidth bits);value:=fold;value.addAttribute("keep")
      value
    }
    OhSel(select,candidates)
  }
}
