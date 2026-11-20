package ooo.frontend.bpred

import spinal.core._
import ooo.{CpuConfig, OhSel}

/** Select Boolean predictions without putting counter muxes after tag matching. */
class TagePriorityPrediction(cfg: CpuConfig, decoded: Boolean = false) extends Component {
  setDefinitionName(if (decoded) "tage_decoded_prediction" else "tage_priority_prediction")
  addAttribute("keep_hierarchy", "yes")
  val n = cfg.tageNum
  val io = new Bundle {
    val hits = in Bits(n bits)
    val counters = if (!decoded) in Bits(n * cfg.tageCtrBits bits) else null
    val usefulness = if (!decoded) in Bits(n * cfg.tageUBits bits) else null
    val directions = if (decoded) in Bits(n bits) else null
    val weak_flags = if (decoded) in Bits(n bits) else null
    val base, use_alt = in Bool()
    val prediction = out Bool()
  }
  noIoPrefix()
  val counters = if (!decoded) io.counters.subdivideIn(n slices) else null
  val usefulness = if (!decoded) io.usefulness.subdivideIn(n slices) else null
  def direction(t: Int): Bool = if (decoded) io.directions(t) else !counters(t).msb
  def higherHit(t: Int, limit: Int): Bool =
    if (t + 1 == limit) False else io.hits(limit - 1 downto t + 1).orR
  if (decoded && n == 3 && !cfg.implementation.isFpga) {
    val low = new TagePriorityPrediction(
      cfg.copy(tageNum = 2, tageHistLen = cfg.tageHistLen.take(2)), decoded = true)
    low.setDefinitionName("tage_low_prediction")
    low.io.hits := io.hits(1 downto 0)
    low.io.directions := io.directions(1 downto 0)
    low.io.weak_flags := io.weak_flags(1 downto 0)
    low.io.base := io.base
    low.io.use_alt := io.use_alt
    val alternate = Mux(io.hits(1), io.directions(1), Mux(io.hits(0), io.directions(0), io.base))
    val high = Mux(io.use_alt && io.weak_flags(2), alternate, io.directions(2))
    // Keep the late highest-table hit on a single final selector input.
    val choice = new TageFinalChoice
    choice.io.hit := io.hits(2)
    choice.io.without := low.io.prediction
    choice.io.withHit := high
    io.prediction := choice.io.prediction
  } else if (decoded && n <= 2 && !cfg.implementation.isFpga) {
    def none(tables: Seq[Int]): Bool = !tables.map(io.hits(_)).foldLeft(False)(_ || _)
    val useAlternate = (0 until n).map(t => io.weak_flags(t) && io.use_alt)
    // A direction wins as a strong provider or the alternate of one higher hit.
    val selected = (0 until n).map { t =>
      val higher = t + 1 until n
      val alternate = higher.map { provider =>
        io.hits(provider) && useAlternate(provider) && none(higher.filter(_ != provider))
      }.foldLeft(False)(_ || _)
      io.hits(t) && ((none(higher) && !useAlternate(t)) || alternate)
    }
    val base = !io.hits.orR || (0 until n).map { t =>
      io.hits(t) && useAlternate(t) && none((0 until n).filter(_ != t))
    }.foldLeft(False)(_ || _)
    io.prediction := OhSel.bool(Vec(selected :+ base).asBits, (0 until n).map(direction) :+ io.base)
  } else {
    val provider = Vec((0 until n).map(t => io.hits(t) && !higherHit(t, n))).asBits
    val independent, baseChoice = Vec(Bool(), n)
    for (t <- 0 until n) {
      val lower = if (t == 0) False else io.hits(t - 1 downto 0).orR
      val alternate = if (t == 0) False else {
        val selected = Vec((0 until t).map(j => io.hits(j) && !higherHit(j, t))).asBits
        OhSel.bool(selected, (0 until t).map(direction))
      }
      val weak = if (decoded) io.weak_flags(t) else (usefulness(t) === 0) &&
        ((counters(t) === 0) || (counters(t).asSInt === S(-1, cfg.tageCtrBits bits)))
      val useAlternate = weak && io.use_alt
      independent(t) := Mux(useAlternate, alternate, direction(t))
      baseChoice(t) := useAlternate && !lower
    }
    // Keep the late bimodal decision out of provider and alternate selection.
    val prediction = OhSel.bool(provider, independent.toSeq)
    val needsBase = !io.hits.orR || OhSel.bool(provider, baseChoice.toSeq)
    io.prediction := prediction || (io.base && needsBase)
  }
}

/** Preserve the final late-hit mux when mapping the earlier prediction logic. */
class TageFinalChoice extends Component {
  setDefinitionName("tage_final_choice")
  addAttribute("keep_hierarchy", "yes")
  val io = new Bundle {
    val hit, without, withHit = in Bool()
    val prediction = out Bool()
  }
  noIoPrefix()
  io.prediction := Mux(io.hit, io.withHit, io.without)
}
