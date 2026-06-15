package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/branch_predictor/ubtb.sv` -- the micro-BTB.
  *
  * Two parallel fully-associative uBTBs (br_ubtb for conditional branches, j_ubtb
  * for jumps), each UBTB_DEPTH entries {valid, target, tag}. Trained at commit
  * (INSERT into a free slot / UPDATE a tag-match / round-robin OVERWRITE). Predicts
  * per fetch slot: branch (gated by gshare) prioritised over jump, lowest-index hit.
  *
  * Named ubtb_spinal; sim/swap_shims/ubtb.sv carries the `cb_bp_itf.bp from_cb` SV
  * interface and passes packed-2D array ports straight through. SV clock-gated
  * memories -> plain enabled Regs (rst folded into RegInit, matching the gated rst).
  */
class Ubtb(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ubtb_spinal")
  val IFW   = cfg.ifWidth      // 4
  val DEPTH = cfg.ubtbDepth    // 64
  val IDX   = cfg.ubtbIdx      // 6
  val TAGW  = cfg.ubtbTagIdx   // 20

  def INSERT    = B"3'b001"
  def UPDATE    = B"3'b010"
  def OVERWRITE = B"3'b100"

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

  // uBTB tag with the RVC de-alias fold: pc[1] XORed into the LSB.
  def btag(pc: Bits): Bits = pc(TAGW + 1 downto 3) ## (pc(2) ^ pc(1))

  val instPc  = io.inst_pc.subdivideIn(IFW slices)
  val seqNext = io.seq_next.subdivideIn(IFW slices)
  val btagPc  = btag(io.from_cb_pc)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // One associative uBTB (br or jump). `isJump` selects the fu_opcode[3] polarity.
    class UbtbBank(isJump: Boolean) {
      val valid  = Vec(RegInit(False), DEPTH)
      val tag    = Vec(Reg(Bits(TAGW bits)), DEPTH)
      val target = Vec(Reg(Bits(32 bits)), DEPTH)
      val head   = RegInit(U(0, IDX bits))

      // matches this bank's instruction class
      val classMatch = if (isJump) io.from_cb_fu_opcode(3) else !io.from_cb_fu_opcode(3)

      // combinational update-type + index selection (last-writer-wins over i)
      val update    = Bits(3 bits); update    := OVERWRITE
      val insertIdx = UInt(IDX bits); insertIdx := 0
      val updateIdx = UInt(IDX bits); updateIdx := 0
      for (i <- 0 until DEPTH) {
        when(classMatch) {
          when(!valid(i)) { update := INSERT; insertIdx := U(i, IDX bits) }
          .elsewhen(tag(i) === btagPc) { update := UPDATE; updateIdx := U(i, IDX bits) }
        }
      }

      // gated write (rst handled by RegInit; gate enable == this when condition)
      when(io.from_cb_update_en && io.from_cb_branch_taken && classMatch) {
        switch(update) {
          is(INSERT) {
            valid(insertIdx)  := True
            tag(insertIdx)    := btagPc
            target(insertIdx) := io.from_cb_target_address
          }
          is(UPDATE) {
            tag(updateIdx)    := btagPc
            target(updateIdx) := io.from_cb_target_address
          }
          is(OVERWRITE) {
            tag(head)    := btagPc
            target(head) := io.from_cb_target_address
            head := head + 1
          }
          default {}
        }
      }
    }

    val br = new UbtbBank(isJump = false)
    val jm = new UbtbBank(isJump = true)

    // ---- prediction: per slot, lowest-index hit; branch (gshare-gated) over jump ----
    val ptaken  = Vec(Bool(), IFW)
    val ptarget = Vec(Bits(32 bits), IFW)
    for (w <- 0 until IFW) {
      ptaken(w)  := False
      ptarget(w) := seqNext(w)
      val tagW = btag(instPc(w))
      // iterate high->low so the lowest-index hit wins (last assignment); within an
      // index the branch write follows the jump write so branch wins (SV br checked
      // first then `break`).
      for (i <- DEPTH - 1 downto 0) {
        val jHit  = jm.valid(i) && (jm.tag(i) === tagW)
        val brHit = io.predict_taken_gshare(w) && br.valid(i) && (br.tag(i) === tagW)
        when(jHit)  { ptarget(w) := jm.target(i); ptaken(w) := True }
        when(brHit) { ptarget(w) := br.target(i); ptaken(w) := True }
      }
    }
    io.predict_taken  := ptaken.asBits
    io.predict_target := ptarget.asBits
  }
}
