package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** Decode a complete window base before the late carry-state selection. */
class UbtbBaseDecode(cfg: CpuConfig) extends Component {
  setDefinitionName("ubtb_base_decode")
  addAttribute("keep_hierarchy", "yes")
  val LZ = log2Up(cfg.ifWidth * 4)
  val LANES = 2 * cfg.ifWidth
  val RIDXW = log2Up(cfg.ubtbRows)
  val TTAG = cfg.ubtbTagW
  val OFFW = 18
  val EW = 1 + TTAG + 2 + OFFW
  val DW = LANES * EW
  val io = new Bundle {
    val base = in Bits(32 - LZ bits)
    val br_a, br_b, jm_a, jm_b = in Bits(DW bits)
    val bank_select = if (cfg.ubtbParallelTagCompare) in Bool() else null
    val j_hit, b_hit = out Bits(2 * LANES bits)
    val j_target, b_target = out Bits(64 * LANES bits)
  }
  noIoPrefix()
  val baseB = ooo.FastAdd.addPow2(io.base(RIDXW + TTAG - 1 downto 0).asUInt,0,cfg.fpgaNativeAdd).asBits
  def tagOfBase(b: Bits): Bits = b(RIDXW + TTAG - 1 downto RIDXW)
  def hi3(b: Bits): Vec[Bits] = {                            // pc[31:OFFW] and +/-1 (adj 00 / 01 / 1x)
    val h = b(31 - LZ downto OFFW - LZ)
    Vec(h,ooo.FastAdd.addPow2(h.asUInt,0,cfg.fpgaNativeAdd).asBits,
      ooo.FastAdd.dec(h.asUInt,cfg.fpgaNativeAdd).asBits)
  }
  val tagA = tagOfBase(io.base); val tagB = tagOfBase(baseB)
  val hiA = hi3(io.base)
  val carryHi = io.base(OFFW - LZ - 1 downto 0).andR
  val hiPlus2 = ooo.FastAdd.addPow2(hiA(0).asUInt,1,cfg.fpgaNativeAdd).asBits
  val hiB = Vec(Mux(carryHi,hiA(1),hiA(0)),
    Mux(carryHi,hiPlus2,hiA(1)),Mux(carryHi,hiA(0),hiA(2)))
  // per-(block, lane) hit + reconstructed target: [0..LANES) = block A, [LANES..) = B
  val jHitL = Vec(Bool(), 2 * LANES); val jTgtL = Vec(Bits(32 bits), 2 * LANES)
  val bHitL = Vec(Bool(), 2 * LANES); val bTgtL = Vec(Bits(32 bits), 2 * LANES)
  def rowA(a: Bits, b: Bits): Bits = if (cfg.ubtbParallelTagCompare) Mux(io.bank_select, b, a) else a
  def rowB(a: Bits, b: Bits): Bits = if (cfg.ubtbParallelTagCompare) Mux(io.bank_select, a, b) else b
  val jmA = rowA(io.jm_a, io.jm_b); val jmB = rowB(io.jm_a, io.jm_b)
  val brA = rowA(io.br_a, io.br_b); val brB = rowB(io.br_a, io.br_b)
  for (l <- 0 until LANES) {
    def unpack(row: Bits): (Bool, Bits, Bits, Bits) = {      // (valid, tag, hi_adj, target_lo)
      val s = row.subdivideIn(LANES slices)(l)
      (s(EW - 1), s(EW - 2 downto OFFW + 2), s(OFFW + 1 downto OFFW), s(OFFW - 1 downto 0))
    }
    def tgt(hi: Vec[Bits], adj: Bits, lo: Bits): Bits = Mux(adj(1), hi(2), Mux(adj(0), hi(1), hi(0))) ## lo
    def hit(row: Bits, expected: Bits): Bool = {
      val (valid, tag, _, _) = unpack(row)
      if (cfg.ubtbParallelTagCompare) {
        val compare = new UbtbTagMatch(TTAG)
        compare.io.valid := valid; compare.io.tag := tag; compare.io.expected := expected
        compare.io.hit
      } else valid && (tag === expected)
    }
    def selectedHit(a: Bits, b: Bits, expected: Bits, blockB: Boolean): Bool = {
      if (cfg.ubtbParallelTagCompare) {
        val first = hit(a, expected); val second = hit(b, expected)
        if (blockB) Mux(io.bank_select, first, second) else Mux(io.bank_select, second, first)
      } else hit(if (blockB) b else a, expected)
    }
    val (_, _, jaa, jla) = unpack(jmA); jTgtL(l) := tgt(hiA, jaa, jla)
    val (_, _, baa, bla) = unpack(brA); bTgtL(l) := tgt(hiA, baa, bla)
    val (_, _, jab, jlb) = unpack(jmB); jTgtL(LANES + l) := tgt(hiB, jab, jlb)
    val (_, _, bab, blb) = unpack(brB); bTgtL(LANES + l) := tgt(hiB, bab, blb)
    jHitL(l) := selectedHit(io.jm_a, io.jm_b, tagA, blockB = false)
    bHitL(l) := selectedHit(io.br_a, io.br_b, tagA, blockB = false)
    jHitL(LANES + l) := selectedHit(io.jm_a, io.jm_b, tagB, blockB = true)
    bHitL(LANES + l) := selectedHit(io.br_a, io.br_b, tagB, blockB = true)
  }
  io.j_hit := jHitL.asBits; io.b_hit := bHitL.asBits
  io.j_target := jTgtL.asBits; io.b_target := bTgtL.asBits
}
