package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Combinational D-cache hit detection; the highest matching way wins. */
class HitDetection(cfg: CpuConfig = CpuConfig(), splitHigh: Boolean = false) extends Component {
  setDefinitionName("hit_detection_spinal")
  val TAG  = cfg.dTagIdx
  val WAYS = cfg.dNumWays
  val WAYB = log2Up(WAYS)
  val TAW  = TAG + 2 // Epoch and dirty bits accompany each tag; validity is separate.

  val io = new Bundle {
    val tag            = in  Bits (TAG bits)
    val tag_arr_flat   = in  Bits (WAYS * TAW bits)
    val valid_arr_flat = in  Bits (WAYS bits)
    val hi0 = if (splitHigh) in Bits(16 bits) else null
    val hi1 = if (splitHigh) in Bits(16 bits) else null
    val carry = if (splitHigh) in Bool() else null
    val hit            = out Bool()
    val hit_way        = out Bits (WAYB bits)
    val selected_way   = out Bits(WAYS bits)
  }
  noIoPrefix()

  io.hit := False
  io.hit_way := B(0, WAYB bits)
  val matches = Bits(WAYS bits)
  for (i <- 0 until WAYS) {
    val tg = io.tag_arr_flat(i * TAW, TAW bits)(TAG - 1 downto 0)
    val equal = if (splitHigh) {
      require(TAG > 16)
      val high = tg(TAG - 1 downto TAG - 16)
      Mux(io.carry, high === io.hi1, high === io.hi0) &&
        (tg(TAG - 17 downto 0) === io.tag(TAG - 17 downto 0))
    } else tg === io.tag
    matches(i) := equal && io.valid_arr_flat(i)
    when(matches(i)) { io.hit := True; io.hit_way := B(i, WAYB bits) }
  }
  for (i <- 0 until WAYS) {
    val higher = if (i == WAYS - 1) False else matches(WAYS - 1 downto i + 1).orR
    // Preserve way zero's data on a miss, including arbitrary duplicate tags.
    io.selected_way(i) := !higher && (if (i == 0) True else matches(i))
  }
}
