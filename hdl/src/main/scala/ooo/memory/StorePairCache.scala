package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** Maintain disambiguation comparisons as either queue captures an address. */
class StorePairCache(cfg: CpuConfig, sharedWrite: Boolean = true) extends Component {
  setDefinitionName(if (sharedWrite) "store_pair_cache" else "store_buffer_pair_cache")
  val pairs = cfg.ldqDepth * cfg.stqDepth
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val store_addr_flat = in Bits(cfg.stqDepth * 32 bits)
    val store_mask_flat = in Bits(cfg.stqDepth * 4 bits)
    val load_addr_flat = in Bits(cfg.ldqDepth * 32 bits)
    val load_mask_flat = in Bits(cfg.ldqDepth * 4 bits)
    val store_write = in Bits(cfg.stqDepth bits)
    val load_write = in Bits(cfg.ldqDepth bits)
    val agu_addr = in Bits(32 bits); val agu_mask = in Bits(4 bits)
    val agu_word_matches = if (cfg.lsuCarryFreeStoreMatch && !sharedWrite) in Bits(cfg.stqDepth+1 bits) else null
    val agu_hi0 = if (cfg.storePairSplitTag) in Bits(16 bits) else null
    val agu_hi1 = if (cfg.storePairSplitTag) in Bits(16 bits) else null
    val agu_c16 = if (cfg.storePairSplitTag) in Bool() else null
    val store_write_addr = if (!sharedWrite) in Bits(32 bits) else null
    val store_write_mask = if (!sharedWrite) in Bits(4 bits) else null
    val tag_match = out Bits(pairs bits)
    val overlap = out Bits(pairs bits); val cover = out Bits(pairs bits)
    val next_tag = if (cfg.storeVerdictPrecompute) out Bits(pairs bits) else null
    val next_overlap = if (cfg.storeVerdictPrecompute) out Bits(pairs bits) else null
    val next_cover = if (cfg.storeVerdictPrecompute) out Bits(pairs bits) else null
  }
  noIoPrefix()
  val domain = ClockDomain(io.clk, io.rst,
    config=ClockDomainConfig(resetActiveLevel=HIGH, resetKind=SYNC))
  new ClockingArea(domain) {
    val storeInput = if (sharedWrite) io.agu_addr else io.store_write_addr
    val storeMaskInput = if (sharedWrite) io.agu_mask else io.store_write_mask
    def matchesAgu(address: Bits): Bool = if (cfg.storePairSplitTag)
      (address(15 downto 2) === io.agu_addr(15 downto 2)) &&
        Mux(io.agu_c16,address(31 downto 16) === io.agu_hi1,address(31 downto 16) === io.agu_hi0)
    else address(31 downto 2) === io.agu_addr(31 downto 2)
    for (i <- 0 until cfg.ldqDepth; j <- 0 until cfg.stqDepth) {
      val index = i * cfg.stqDepth + j
      val storeAddr = io.store_addr_flat(j * 32, 32 bits)
      val storeMask = io.store_mask_flat(j * 4, 4 bits)
      val loadAddr = io.load_addr_flat(i * 32, 32 bits)
      val loadMask = io.load_mask_flat(i * 4, 4 bits)
      val storeHit = io.store_write(j); val loadHit = io.load_write(i)
      val tag = Reg(Bool()).setName(s"pairTag_${i}_$j")
      val overlap = Reg(Bool()).setName(s"pairOverlap_${i}_$j")
      val cover = Reg(Bool()).setName(s"pairCover_${i}_$j")
      // Decode capture cases before late address comparisons. Reset alone refreshes the pair.
      val untouched = !storeHit && !loadHit
      val select = Vec(untouched && !io.rst, storeHit && loadHit,
        storeHit && !loadHit, !storeHit && loadHit, untouched && io.rst).asBits
      select.addAttribute("keep")
      def choose(held: Bool, both: Bool, store: Bool, load: Bool, refresh: Bool): Bool =
        ooo.OhSel.bool(select, Seq(held, both, store, load, refresh))
      val nextTag = choose(tag,
        if (sharedWrite) True else if (cfg.lsuCarryFreeStoreMatch) io.agu_word_matches(cfg.stqDepth) else matchesAgu(storeInput),
        if (sharedWrite) matchesAgu(loadAddr) else storeInput(31 downto 2) === loadAddr(31 downto 2),
        if (cfg.lsuCarryFreeStoreMatch && !sharedWrite) io.agu_word_matches(j) else matchesAgu(storeAddr),
        storeAddr(31 downto 2) === loadAddr(31 downto 2))
      val nextOverlap = choose(overlap, (io.agu_mask & storeMaskInput).orR,
        (loadMask & storeMaskInput).orR, (io.agu_mask & storeMask).orR, (loadMask & storeMask).orR)
      val nextCover = choose(cover, (io.agu_mask & ~storeMaskInput) === 0,
        (loadMask & ~storeMaskInput) === 0, (io.agu_mask & ~storeMask) === 0, (loadMask & ~storeMask) === 0)
      tag := nextTag; overlap := nextOverlap; cover := nextCover
      if (cfg.storeVerdictPrecompute) {
        io.next_tag(index) := nextTag
        io.next_overlap(index) := nextOverlap; io.next_cover(index) := nextCover
      }
      io.tag_match(index) := tag
      io.overlap(index) := overlap; io.cover(index) := cover
    }
  }
}
