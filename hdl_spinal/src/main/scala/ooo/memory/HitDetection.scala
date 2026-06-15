package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/memory/dcache/hit_detection.sv` -- D-cache hit/way
  * detection (combinational, last-matching-way wins). The SV module is
  * parameterized + has unpacked-array inputs; this is fixed to the D-cache config
  * with FLAT array ports. sim/swap_shims/hit_detection.sv is a parameterized shim
  * that un-flattens (and absorbs the `#(...)` override).
  */
class HitDetection(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("hit_detection_spinal")
  val TAG  = cfg.dTagIdx      // 23
  val WAYS = cfg.dNumWays     // 4
  val WAYB = log2Up(WAYS)     // 2
  val TAW  = TAG + 1          // tag_arr element width (24)

  val io = new Bundle {
    val tag            = in  Bits (TAG bits)
    val tag_arr_flat   = in  Bits (WAYS * TAW bits)
    val valid_arr_flat = in  Bits (WAYS bits)
    val hit            = out Bool()
    val hit_way        = out Bits (WAYB bits)
  }
  noIoPrefix()

  io.hit := False
  io.hit_way := B(0, WAYB bits)
  for (i <- 0 until WAYS) {
    val tg = io.tag_arr_flat(i * TAW, TAW bits)(TAG - 1 downto 0)
    when(tg === io.tag && io.valid_arr_flat(i)) { io.hit := True; io.hit_way := B(i, WAYB bits) }
  }
}
