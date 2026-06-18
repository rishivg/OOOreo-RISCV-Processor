package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/branch_predictor/ubtb.sv` -- the micro-BTB,
  * now SET-ASSOCIATIVE (area lever A2).
  *
  * Replaces the fully-associative 64-entry CAM (which cost 4 slots x 2 banks x 64 =
  * 512 tag comparators + 64-wide priority/target muxes -> ~113k um^2) with a
  * SETS x WAYS organisation: each lookup reads only the indexed set's WAYS, so the
  * comparator count drops to 4 slots x 2 banks x WAYS = 32. Same total capacity
  * (UBTB_DEPTH entries), far less comparator/mux area, and a shorter stored tag.
  *
  * Two parallel banks (br for conditional branches gated by gshare, jm for jumps),
  * trained at commit (INSERT free way / UPDATE tag-match / per-set round-robin
  * OVERWRITE). Block-PC key (with the RVC de-alias pc[1]->LSB) split as
  * {tag = high bits, set = low SIDX bits}. SV clock-gated mems -> enabled Regs
  * (valid reset via RegInit; tag/target unreset like the SV gated arrays).
  */
class Ubtb(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ubtb_spinal")
  val IFW   = cfg.ifWidth      // 4
  val DEPTH = cfg.ubtbDepth    // 64
  val WAYS  = 4
  val SETS  = DEPTH / WAYS     // 16
  val SIDX  = log2Up(SETS)     // 4
  val WIDX  = log2Up(WAYS)     // 2
  val TAGW  = cfg.ubtbTagIdx   // 20 (full block-PC key width)
  val TTAG  = TAGW - SIDX      // 16 (stored tag width = key minus set-index bits)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // cb_bp_itf.bp from_cb (fields ubtb.sv reads)
    val from_cb_update_en      = in Bool()
    val from_cb_pc             = in Bits (32 bits)
    val from_cb_fu_opcode      = in Bits (4 bits)
    val from_cb_branch_taken   = in Bool()
    val from_cb_target_address = in Bits (32 bits)
    val predict_taken_gshare = in Bits (IFW bits)
    val inst_pc        = in Bits (IFW * 32 bits)
    val seq_next       = in Bits (IFW * 32 bits)
    val predict_target = out Bits (IFW * 32 bits)
    val predict_taken  = out Bits (IFW bits)
  }
  noIoPrefix()

  // block-PC key (RVC de-alias: pc[1] folded into the LSB), split into {tag, set}.
  def key(pc: Bits): Bits = pc(TAGW + 1 downto 3) ## (pc(2) ^ pc(1))   // TAGW bits
  def setOf(pc: Bits): UInt = key(pc)(SIDX - 1 downto 0).asUInt        // low SIDX bits
  def tagOf(pc: Bits): Bits = key(pc)(TAGW - 1 downto SIDX)            // high TTAG bits

  val instPc  = io.inst_pc.subdivideIn(IFW slices)
  val seqNext = io.seq_next.subdivideIn(IFW slices)
  val uSet = setOf(io.from_cb_pc)
  val uTag = tagOf(io.from_cb_pc)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // One set-associative bank (br or jump); isJump selects the fu_opcode[3] polarity.
    class UbtbBank(isJump: Boolean) {
      val valid  = Vec(Vec(RegInit(False), WAYS), SETS)
      val tag    = Vec(Vec(Reg(Bits(TTAG bits)), WAYS), SETS)
      val target = Vec(Vec(Reg(Bits(32 bits)), WAYS), SETS)
      val head   = Vec(RegInit(U(0, WIDX bits)), SETS)        // per-set round-robin victim

      val classMatch = if (isJump) io.from_cb_fu_opcode(3) else !io.from_cb_fu_opcode(3)

      // pick update kind within the commit set: INSERT (free way) / UPDATE (tag hit)
      // / OVERWRITE (set full, no hit). Defaults to OVERWRITE; last-writer-wins over j.
      val uValid = valid(uSet); val uTags = tag(uSet)
      val update  = Bits(3 bits); update := B"3'b100"     // OVERWRITE
      val wInsert = UInt(WIDX bits); wInsert := 0
      val wUpdate = UInt(WIDX bits); wUpdate := 0
      for (j <- 0 until WAYS) {
        when(classMatch) {
          when(!uValid(j)) { update := B"3'b001"; wInsert := U(j, WIDX bits) }            // INSERT
          .elsewhen(uTags(j) === uTag) { update := B"3'b010"; wUpdate := U(j, WIDX bits) } // UPDATE
        }
      }

      when(io.from_cb_update_en && io.from_cb_branch_taken && classMatch) {
        switch(update) {
          is(B"3'b001") {                                   // INSERT into the free way
            valid(uSet)(wInsert)  := True
            tag(uSet)(wInsert)    := uTag
            target(uSet)(wInsert) := io.from_cb_target_address
          }
          is(B"3'b010") {                                   // UPDATE the tag-matching way
            tag(uSet)(wUpdate)    := uTag
            target(uSet)(wUpdate) := io.from_cb_target_address
          }
          is(B"3'b100") {                                   // OVERWRITE the round-robin victim (set full -> already valid)
            tag(uSet)(head(uSet))    := uTag
            target(uSet)(head(uSet)) := io.from_cb_target_address
            head(uSet) := head(uSet) + 1
          }
          default {}
        }
      }
    }

    val br = new UbtbBank(isJump = false)
    val jm = new UbtbBank(isJump = true)

    // ---- prediction: per slot, read the indexed set's ways; branch (gshare-gated)
    //      over jump. Tags are unique within a (bank, set) so <=1 way hits. ----
    val ptaken  = Vec(Bool(), IFW)
    val ptarget = Vec(Bits(32 bits), IFW)
    for (w <- 0 until IFW) {
      ptaken(w)  := False
      ptarget(w) := seqNext(w)
      val sSet = setOf(instPc(w)); val sTag = tagOf(instPc(w))
      val jV = jm.valid(sSet); val jT = jm.tag(sSet); val jTgt = jm.target(sSet)
      val bV = br.valid(sSet); val bT = br.tag(sSet); val bTgt = br.target(sSet)
      for (j <- 0 until WAYS) {
        val jHit  = jV(j) && (jT(j) === sTag)
        val brHit = io.predict_taken_gshare(w) && bV(j) && (bT(j) === sTag)
        when(jHit)  { ptarget(w) := jTgt(j); ptaken(w) := True }
        when(brHit) { ptarget(w) := bTgt(j); ptaken(w) := True }
      }
    }
    io.predict_taken  := ptaken.asBits
    io.predict_target := ptarget.asBits
  }
}
