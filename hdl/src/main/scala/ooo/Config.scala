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
  // ---- ISA extensions (generator-time toggles; elaborate a different netlist) ----
  cExt: Boolean = true,   // RV32C compressed (off -> leaner/faster RV32I-aligned front-end)
  aExt: Boolean = true,   // RV32A atomics (RTL WIP)

  // ---- pipeline widths ----
  ifWidth: Int = 4,   // fetch width  [IF_WIDTH]
  idWidth: Int = 2,   // decode/issue width  [ID_WIDTH]

  // ---- rename / ROB / register files ----
  robDepth: Int = 32, // [ROB_DEPTH]
  prfDepth: Int = 48, // [PRF_DEPTH] lever #3: 64->48 (imc-neutral, validated)
  arfDepth: Int = 32, // [ARF_DEPTH]

  // ---- reservation stations / control buffer ----
  intrsDepth:  Int = 12, // right-sized 16->12 (knee: imc -0.012%; 10=-0.069%, 8=-0.11%)
  intmrsDepth: Int = 3,  // [INTMRS_DEPTH] lever #4: 4->3 (imc-neutral, validated)
  brrsDepth:   Int = 3,  // [BRRS_DEPTH] lever #4: 4->3 (imc-neutral, validated)
  memrsDepth:  Int = 8,  // [MEMRS_DEPTH]
  cbDepth:     Int = 8,  // [CB_DEPTH]

  // ---- LSU queues (must be power-of-2: pointer wrap assumes 2^idx; 6 hangs) ----
  ldqDepth: Int = 4, // right-sized 8->4 (imc -0.023%, CoreMark MLP-bound <4; shrinks 8x8->4x4 disambig)
  stqDepth: Int = 4, // right-sized 8->4 (pairs with ldq; same disambig-matrix shrink)
  stbDepth: Int = 2, // [STB_DEPTH] lever #9: 4->2 (imc-neutral, validated)

  // ---- execute ----
  intIssueWidth: Int = 2, // [INT_ISSUE_WIDTH]
  cdbWidth:      Int = 4, // [CDB_WIDTH] lever #2: 5->4 (intm+branch share one writeback/wakeup lane; IPC-neutral)
  prfReadPorts:  Int = 5, // PRF read fabric ports (int x2, intm, branch, lsu issue independently of writeback)
  numFastBypass: Int = 2, // [NUM_FAST_BYPASS]

  // ---- branch prediction ----
  phtDepth:    Int = 1024, // TAGE bimodal base (512 measured -0.13% imc -> past the knee; kept at 1024)
  ubtbDepth:   Int = 64,   // [UBTB_DEPTH]
  ubtbTagIdx:  Int = 20,   // [UBTB_TAG_IDX]
  ftbDepth:    Int = 64,   // [FTB_DEPTH]
  ftbTagBits:  Int = 20,   // [FTB_TAG_BITS]
  rasDepth:    Int = 8,    // right-sized 16->8 (bit-identical; CoreMark call nesting <8; 4 also bit-identical)
  ghrLen:      Int = 63,   // [GHR_LEN] 64->63: bit63 dead (longest TAGE hist L=63 reads h[0..62]); bit-identical, trims per-instr GHR carry
  tageNum:     Int = 4,    // [TAGE_NUM] (4->3 measured -1.99% imc at tageDepth=128 -- below baseline, NOT worth -16k; reverted)
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

  // ---- packed FU/RS struct widths (single source of truth; mirror the SV *_reg_t,
  //      field order/widths in the owning module's header comment). Derived from the
  //      index widths above so depth/width retunes propagate instead of going stale. ----
  def bypassNetW = 1 + prfIdx + 32                                       // bypass_network_t: valid rd_phy rd_value
  def intmRsRegW = robIdx + arfIdx + prfIdx + 4 + 32 + 32                // intm_rs_reg_t: rob_id rd_arch rd_phy fu_opcode rs1 rs2
  def fuCdbRegW  = robIdx + arfIdx + prfIdx + 32 + 32 + 32               // fu_cdb_reg_t:  rob_id rd_arch rd_phy rd_value rs1_dbg rs2_dbg
  def fuAluRegW  = robIdx + arfIdx + prfIdx + 4 + 1 + 1 + 32 + 32 + 32   // fu_alu_reg_t:  +op1_sel op2_sel imm
  def fuBrRegW   = robIdx + arfIdx + prfIdx + 4 + 32 + 32 + 32 + 32 + 1 + 1 + 32 // fu_br_reg_t: rob_id rd_arch rd_phy fu_opcode pc imm rs1 rs2 is_compressed predict_taken predict_target
  def aguRegW    = robIdx + 4 + 32 + 32 + 32                             // agu_reg_t: rob_id fu_opcode imm rs1 rs2
}
