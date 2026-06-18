package ooo

import spinal.core._

/** Central configuration -- the SpinalHDL port of `pkg/types.sv` localparams.
  *
  * This is a *generator* parameter object: change a field (or pass a different
  * `CpuConfig`) to elaborate a different-width / different-capacity core. Derived
  * index widths are computed with `log2Up`, exactly like the SV `$clog2(...)`
  * locals. Defaults match the current committed SV core (post IF_WIDTH=4).
  */
case class CpuConfig(
  // ---- pipeline widths ----
  ifWidth: Int = 4,   // fetch width  [IF_WIDTH]
  idWidth: Int = 2,   // decode/issue width  [ID_WIDTH]

  // ---- rename / ROB / register files ----
  robDepth: Int = 32, // [ROB_DEPTH]
  prfDepth: Int = 64, // [PRF_DEPTH]
  arfDepth: Int = 32, // [ARF_DEPTH]

  // ---- reservation stations / control buffer ----
  intrsDepth:  Int = 16, // [INTRS_DEPTH]
  intmrsDepth: Int = 4,  // [INTMRS_DEPTH]
  brrsDepth:   Int = 4,  // [BRRS_DEPTH]
  memrsDepth:  Int = 8,  // [MEMRS_DEPTH]
  cbDepth:     Int = 8,  // [CB_DEPTH]

  // ---- LSU queues ----
  ldqDepth: Int = 8, // [LDQ_DEPTH]
  stqDepth: Int = 8, // [STQ_DEPTH]
  stbDepth: Int = 4, // [STB_DEPTH]

  // ---- execute ----
  intIssueWidth: Int = 2, // [INT_ISSUE_WIDTH]
  cdbWidth:      Int = 5, // [CDB_WIDTH]
  numFastBypass: Int = 2, // [NUM_FAST_BYPASS]

  // ---- branch prediction ----
  phtDepth:    Int = 1024, // [PHT_DEPTH]
  ubtbDepth:   Int = 64,   // [UBTB_DEPTH]
  ubtbTagIdx:  Int = 20,   // [UBTB_TAG_IDX]
  ftbDepth:    Int = 64,   // [FTB_DEPTH]
  ftbTagBits:  Int = 20,   // [FTB_TAG_BITS]
  rasDepth:    Int = 16,   // [RAS_DEPTH]
  ghrLen:      Int = 64,   // [GHR_LEN]
  tageNum:     Int = 4,    // [TAGE_NUM]
  tageDepth:   Int = 128,  // A1: 256->128 = -0.19% imc for ~-9% core area (64 cost -1.4% imc; 128 is the imc knee)
  tageTagBits: Int = 9,    // [TAGE_TAG_BITS]
  tageCtrBits: Int = 3,    // [TAGE_CTR_BITS]
  tageUBits:   Int = 2,    // [TAGE_U_BITS]
  tageHistLen: Seq[Int] = Seq(7, 15, 31, 63), // HISTLEN[] in tage.sv

  // ---- caches ----
  iOffsetIdx: Int = 5, iSetIdx: Int = 6, iNumWays: Int = 4, // I$: 64 sets x 4 way x 32B
  dOffsetIdx: Int = 5, dSetIdx: Int = 4, dNumWays: Int = 4, // D$: 16 sets x 4 way x 32B

  // ---- reset ----
  resetPc: Long = 0xaaaaa000L
) {
  // ---- derived widths (mirror the $clog2 locals) ----
  def parcelCntW   = log2Up(2 * ifWidth + 1)
  def robPtrIdx    = log2Up(robDepth)
  def robIdx       = log2Up(robDepth * idWidth)
  def prfIdx       = log2Up(prfDepth)
  def arfIdx       = log2Up(arfDepth)
  def intrsIdx     = log2Up(intrsDepth)
  def intmrsIdx    = log2Up(intmrsDepth)
  def brrsIdx      = log2Up(brrsDepth)
  def memrsIdx     = log2Up(memrsDepth)
  def ldqIdx       = log2Up(ldqDepth)
  def stqIdx       = log2Up(stqDepth)
  def stbIdx       = log2Up(stbDepth)
  def phtIdx       = log2Up(phtDepth)
  def ubtbIdx      = log2Up(ubtbDepth)
  def ftbIdx       = log2Up(ftbDepth)
  def rasIdx       = log2Up(rasDepth)
  def tageIdx      = log2Up(tageDepth)
  def iTagIdx      = 32 - iSetIdx - iOffsetIdx
  def dTagIdx      = 32 - dSetIdx - dOffsetIdx
  def ifBlkSize    = ifWidth * 4
}
