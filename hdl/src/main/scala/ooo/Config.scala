package ooo

import spinal.core._

/** Architectural resources and implementation options shared by all generators. */
case class CpuConfig(
  // ISA extensions (generator-time toggles; elaborate a different netlist)
  cExt: Boolean = true,
  aExt: Boolean = true, // LR/SC and AMOs
  zicsr: Boolean = false, // Machine-mode CSRs, traps, interrupts, and CLINT
  lowPower: Boolean = false, // WFI drain and retained-state clock gating; requires Zicsr
  mmio: Boolean = false, // Ordered uncached peripheral master; requires Zicsr
  mmioBase: Long = 0x10000000L,
  mmioMask: Long = 0xf0000000L,
  clintHi16: Int = 0x0200, // Uncached 64 KiB CLINT window selected by addr[31:16]
  storeAgeLookup: Boolean = false, // FPGA LUT interval for small store queues
  storeAgePrecompute: Boolean = false, // Compute next-cycle disambiguation intervals before their registers
  storePairPrecompute: Boolean = false, // Cache store/load address and byte-mask comparisons
  storeVerdictPrecompute: Boolean = false, // Retain next-cycle store-dependency decisions
  storeBufferPrecompute: Boolean = false, // Retain committed-store dependency decisions
  dcacheReadAllBanks: Boolean = false, // Trade speculative SRAM reads for shorter enable paths
  dcacheMergedTag: Boolean = false, // Resolve the tag carry before its capture register
  lsuWaySpeculation: Boolean = false, // Generate dependent addresses before the cache way resolves
  lsuCarryFreeStoreMatch: Boolean = false, // Match effective addresses without a late carry chain
  lsuWordSpeculation: Boolean = false, // Generate addresses before selecting the cache word
  distributedFlush: Boolean = false, // Replicate the final recovery decode near each consumer
  aluAguFusion: Boolean = false, // Fuse ALU fast-bypass arithmetic with per-entry address generation
  dcacheLruReadCache: Boolean = false, // Cache the PLRU read without adding latency
  bmemWriteDataBypass: Boolean = false, // Keep request control off the write-data bus
  bmemBeatSpeculation: Boolean = false, // Select memory beats before the late cache way
  bmemEarlyAddress: Boolean = false, // Select cache address candidates in the memory arbiter
  mmioIdleCapture: Boolean = false, // Capture MMIO payload while idle
  robSerialSummary: Boolean = false, // Cache head-row serial-operation presence
  robDeviceParallel: Boolean = false, // Resolve device retirement before late head selection
  robStqSummary: Boolean = false, // Cache store-retirement readiness for the ROB head
  iqParallelDecode: Boolean = false, // Decode entries before queue selection
  iqMergedDecodeSelect: Boolean = false, // Merge decoded row and slot selection
  iqOneHotHead: Boolean = false, // Retain the decoded instruction-queue read address
  mulCompactSigns: Boolean = false, // Replace repeated Booth sign bits with a correction
  mulDaddaReduction: Boolean = false, // Column-wise partial-product compression
  mulCarryTopology: String = "auto", // Dadda: Brent-Kung; other reduction: existing carry tree
  mulKeepPropagate: Boolean = false, // Preserve propagate nodes in addition to generate nodes
  mulOrCarry: Boolean = false, // Inclusive propagation in multiplier carry trees
  aguOrCarry: Boolean = false, // Use inclusive propagation in address-adder carry trees
  aguCarrySelectAt: Int = 0, // Optional lower-half carry-select split; zero uses the prefix tree
  aguSignedImmediate: Boolean = false, // Specialize address addition for signed 12-bit ISA immediates
  lsuForwardSpeculation: Boolean = false, // Keep forwarding and serial selection after address arithmetic
  lsuStoreForwardLanes: Boolean = false, // Select raw queued-store results after address arithmetic
  lsuBufferForwardLanes: Boolean = false, // Select raw committed-store results after address arithmetic
  lsuResponsePredecode: Boolean = false, // Select forwarding verdicts with a captured one-hot load index
  lsuFormatPredecode: Boolean = false, // Capture load-format controls before result data arrives
  frontendInvertedTag: Boolean = false, // Keep the I-cache tag register separate from shared address state
  frontendFastCarry: Boolean = false, // Capture the trailing parcel directly on a span
  frontendPublishedValidity: Boolean = false, // Fold pending refill publication into early validity
  frontendLaneValidity: Boolean = false, // Carry cache-validity results through predictor selection
  frontendValidSpeculation: Boolean = false, // Read initialized bits before next-PC priority selection
  frontendPcOneHot: Boolean = false, // Reuse early next-PC candidates
  frontendCacheAddressOneHot: Boolean = false, // Gate cache address candidates before selection
  frontendOutcomeOneHot: Boolean = false, // Decode the late fetch outcome once for all consumers
  tageHistoryStateCofactors: Boolean = false, // Select precomputed history next-state outcomes
  frontendHistoryCofactors: Boolean = false, // Fold history and route SRAM banks before outcome selection
  frontendPredictCofactors: Boolean = false, // Precompute fetch decisions before TAGE direction selection
  tageLateBankSelect: Boolean = false, // Compare bank tags before selecting prediction flags
  tagePcPrehash: Boolean = false, // Hash PC candidates before their one-hot selection
  tageRegisteredTags: Boolean = false, // Combine PC/history tags before the prediction register
  tageParallelPredict: Boolean = false, // Select precomputed provider/alternate predictions after tag match
  tageParallelHistory: Boolean = false, // Select among parallel folded-history updates
  keepTimingHierarchy: Boolean = false, // Keep speculative fetch and address modules separate in synthesis
  frontendLaneDecode: Boolean = false, // Decode parcel candidates before selecting slot boundaries
  frontendBankSpeculation: Boolean = false, // Select banks after parallel fetch work
  ubtbOneHotSlots: Boolean = false, // Decode slot selection once for all prediction fields
  ubtbLateCarrySelect: Boolean = false, // Decode window bases before carry selection
  ubtbParallelTagCompare: Boolean = false, // Compare bank tags before selecting hits
  frontendParallelRealign: Boolean = false, // Evaluate entry lanes before selection
  frontendLengthPredecode: Boolean = false, // Store instruction length in the existing predecode row
  lsuCachePermission: Boolean = false, // Qualify the cache port using the device-go blocking invariant
  frontendPayloadSpeculation: Boolean = false, // Align, decompress and predecode each cache way before selection
  memCdbSpeculation: Boolean = false, // Select non-memory writeback operands after address arithmetic
  storePairSplitTag: Boolean = false, // Compare both address high sums before selecting the carry
  lsuOperandSpeculation: Boolean = false, // Select forwarding eligibility after address arithmetic
  lsuSerialSpeculation: Boolean = false, // Compute CSR and atomic address candidates before their late select
  lsuWakeupPredecode: Boolean = false, // Compare CSR, atomic and load tags before selecting a broadcast
  ratParallelRead: Boolean = false, // Select precomputed row readiness and physical names
  intCsrSpeculation: Boolean = false, // Complete integer issue selection before CSR validity arrives
  intmWakeupPrecompute: Boolean = false, // Cache matches while multiplier/divider metadata is stable
  aluWakeupPrecompute: Boolean = false, // Match next ALU broadcasts before the CDB register
  lsuEntrySpeculation: Boolean = false, // Calculate per-entry addresses before the issue grant
  memPrfPredecode: Boolean = false, // Capture memory operand read selects at dispatch
  clintEarlyWrite: Boolean = false, // Select timer write payload before arbitration
  clintLateWriteGrant: Boolean = false, // Apply load priority after timer write preparation
  clintCoreRead: Boolean = false, // Clock CLINT responses with their synchronous requester
  clintRetimedRead: Boolean = false, // Capture timer banks before selecting the read result
  aguParallelAdd: Boolean = false, // Add operand alternatives before the late bypass selection
  implementation: CpuImplementation = CpuImplementation(),
  fpgaNativeAdd: Boolean = false,
  fpgaSharedShift: Boolean = false,
  prfBinaryRead: Boolean = false,
  prfLutRam: Boolean = false,
  brPrfSharedPredecode: Boolean = false, // Decode branch register rows before the late grant
  prfReadSharing: Int = 0, // Bit 0: memory; bit 1: multiply/divide; bit 2: branch

  rvfi: Boolean = true, // Retirement tracing; disable to prune monitor-only logic

  // pipeline widths
  ifWidth: Int = 4,
  idWidth: Int = 2,
  instQueueDepth: Int = 8, // Fetch packets, independent of instruction slots
  gateFetchPayload: Boolean = false, // Suppress invalid-slot and untaken-target FIFO writes

  // rename / ROB / register files
  robDepth: Int = 32,
  prfDepth: Int = 48,
  arfDepth: Int = 32,

  // reservation stations / control buffer
  intrsDepth:  Int = 12,
  intmrsDepth: Int = 3,
  brrsDepth:   Int = 3,
  memrsDepth:  Int = 6,
  cbDepth:     Int = 8,

  // LSU queue depths must be powers of two for pointer wrap.
  ldqDepth: Int = 4,
  stqDepth: Int = 4,
  stbDepth: Int = 2,
  atomicCamDepth: Int = 4, // Pending serialized atomic operands; any positive depth
  csrCamDepth: Int = 2, // Pending CSR/barrier operands
  maxReadBursts: Int = 31, // Accepted read credits tracked before sleep

  // execute
  intIssueWidth: Int = 2,
  divCycles: Int = 12, // DW_div_seq latency; physical IP must match
  cdbWidth:      Int = 4, // Multiply/divide and branch share one lane
  prfReadPorts:  Int = 5, // Two integer ports, reserved intm/branch ports, and memory rs2
  numFastBypass: Int = 2,

  // branch prediction
  phtDepth:    Int = 1024,
  ubtbRows:    Int = 32, // Logical rows; each even/odd bank holds half
  ubtbTagW:    Int = 9,
  rasDepth:    Int = 4,
  ghrLen:      Int = 63, // Must cover the longest TAGE history
  tageNum:     Int = 3,
  tageDepth:   Int = 64,
  tageTagBits: Int = 8,
  tageCtrBits: Int = 3,
  tageAltCounterBits: Int = 4, // Adaptive weak-provider/alternate hysteresis
  tageUBits:   Int = 1,
  tageHistLen: Seq[Int] = Seq(19, 39, 63), // One history length per tagged table

  // caches
  iOffsetIdx: Int = 5, iSetIdx: Int = 6, iNumWays: Int = 4, // I-cache: sets x ways x line bytes
  dOffsetIdx: Int = 5, dSetIdx: Int = 4, dNumWays: Int = 4, // D-cache: sets x ways x line bytes

  // reset
  resetPc: Long = 0xaaaaa000L
) {
  require(!mulCompactSigns || mulDaddaReduction, "MUL_COMPACT_SIGNS requires MUL_DADDA_REDUCTION")
  require(FastAdd.prefixTopologies(mulCarryTopology), s"Unsupported MUL_CARRY_TOPOLOGY: $mulCarryTopology")
  require(tageCtrBits >= 1 && tageCtrBits <= 8, "TAGE_COUNTER_BITS must be 1..8")
  require(tageAltCounterBits >= 1 && tageAltCounterBits <= 8, "TAGE_ALT_COUNTER_BITS must be 1..8")
  require(aguCarrySelectAt >= 0 && aguCarrySelectAt < 16, "AGU_CARRY_SELECT_AT must be 0..15")
  require(!intCsrSpeculation || (zicsr && lsuWakeupPredecode),
    "CSR issue precomputation requires Zicsr and predecoded LSU wakeup")
  def iFetchBanks: Int = if (frontendBankSpeculation) 2 else 1
  def iFetchWays: Int = iNumWays * iFetchBanks
  require(!iqParallelDecode || iqOneHotHead, "IQ_PARALLEL_DECODE requires IQ_ONE_HOT_HEAD")
  require(!iqMergedDecodeSelect || iqParallelDecode, "IQ_MERGED_DECODE_SELECT requires IQ_PARALLEL_DECODE")
  require(!clintLateWriteGrant || (zicsr && clintEarlyWrite),
    "Late CLINT write grant requires ZICSR and early write payloads")
  require(!lsuCarryFreeStoreMatch || (lsuEntrySpeculation && lsuWaySpeculation && storeBufferPrecompute),
    "carry-free store matching requires entry, way and store-buffer precomputation")
  require(!frontendOutcomeOneHot || frontendPredictCofactors, "one-hot fetch selection requires outcome cofactors")
  require(!tageHistoryStateCofactors || frontendHistoryCofactors, "history state cofactors require address cofactors")
  require(!frontendHistoryCofactors || frontendPredictCofactors, "history cofactors require fetch cofactors")
  require(!frontendPredictCofactors || (ifWidth == 4 && frontendLaneValidity),
    "frontend prediction cofactors require four slots and projected validity")
  require(!tageParallelPredict || tageNum <= 4,
    "Parallel prediction supports up to four tagged tables")
  require(!frontendPublishedValidity || frontendLaneValidity,
    "Published validity requires lane validity")
  require(!frontendPcOneHot || (frontendValidSpeculation && !frontendPredictCofactors),
    "One-hot next-PC selection requires early cache candidates without prediction cofactors")
  require(!robDeviceParallel || (mmio && robStqSummary),
    "Parallel device retirement requires MMIO and store retirement summaries")
  require(!frontendCacheAddressOneHot || frontendValidSpeculation,
    "One-hot cache addresses require early cache candidates")
  require(!bmemBeatSpeculation || bmemWriteDataBypass,
    "Early memory beats require direct write-data bypass")
  require(!frontendLaneValidity || (frontendValidSpeculation && ifWidth == 4),
    "Lane validity requires candidate validity and four fetch slots")
  require(!frontendBankSpeculation || (frontendPayloadSpeculation && iOffsetIdx == 5 && ifWidth == 4),
    "bank speculation requires four-wide payload speculation and 32-byte cache lines")
  // derived widths (mirror the $clog2 locals)
  def parcelCntW   = log2Up(2 * ifWidth + 1)
  // LSU (load) CDB lane index -- must match BackendTop's setLane(_, lsu...) wiring.
  // The lane whose `valid` is the late-arriving D$-hit bit (combinational from
  // dcacheTag -> hitDetect -> ldq.cdb_valid); MemRs Shannon-expands its issue
  // select on this bit so the hit doesn't precede select->PRF->AGU in one cycle.
  def cdbLsuLane   = cdbWidth - 1
  // Shared branch|intm CDB lane index -- must match BackendTop's setLane(2, br|intm)
  // wiring. Its rd_phy is a tri-mux (branch / div / mul, all from registers) whose
  // selects resolve early; MemRs entries pre-resolve their wakeup compare against
  // all three sources in parallel and mux the MATCH (RsEntry intmSplit).
  def cdbIntmLane  = cdbWidth - 2
  def robPtrIdx    = log2Up(robDepth)
  def robIdx       = log2Up(robDepth * idWidth)
  def prfIdx       = log2Up(prfDepth)
  def arfIdx       = log2Up(arfDepth)
  def ldqIdx       = log2Up(ldqDepth)
  def stqIdx       = log2Up(stqDepth)
  def stbIdx       = log2Up(stbDepth)
  def phtIdx       = log2Up(phtDepth)
  def rasIdx       = log2Up(rasDepth)
  def tageIdx      = log2Up(tageDepth)
  def iTagIdx      = 32 - iSetIdx - iOffsetIdx
  def dTagIdx      = 32 - dSetIdx - dOffsetIdx
  def ifBlkLz      = log2Up(ifWidth * 4)   // in-block byte-offset bits (the predictors' LZ)
  // Predictor PC hashes are computed before the late candidate select.
  def predCandN    = if (frontendPredictCofactors) 16 else ifWidth + 4
  // highest candidate PC bit any predictor address derivation reads: TAGE tag-fold
  // pc-part (2*TAGB+1), tagged-table block index, bimodal row, uBTB row.
  def predCandHi   = Seq(2 * tageTagBits + 1, tageIdx + ifBlkLz - 1,
                         phtIdx - log2Up(2 * ifWidth) + ifBlkLz - 1,
                         log2Up(ubtbRows) + ifBlkLz - 1).max
  def predCandW    = predCandHi - ifBlkLz + 1   // candidate bus = pc(predCandHi downto ifBlkLz)

  // Packed FU/RS widths follow the field layouts in their owning modules.
  // Derive index widths from the configured depths.
  def bypassNetW = 1 + prfIdx + 32                                       // bypass_network_t: valid rd_phy rd_value
  def rvfiDbgW   = 414                                                    // rvfi_dbg_t flattened width
  def bpProvW    = tageNum * (1 + tageCtrBits + tageUBits) + 2            // TAGE provider snapshot + bimodal counter
  def aguLsqW    = robIdx + 32 + 32 + 4 + 32 + 32                        // agu_lsq_t: rob_id addr wdata mask rs1_dbg rs2_dbg (138 @ default)
  def intmRsRegW = robIdx + arfIdx + prfIdx + 4 + 32 + 32                // intm_rs_reg_t: rob_id rd_arch rd_phy fu_opcode rs1 rs2
  def fuCdbRegW  = robIdx + arfIdx + prfIdx + 32 + 32 + 32               // fu_cdb_reg_t:  rob_id rd_arch rd_phy rd_value rs1_dbg rs2_dbg
  def fuAluRegW  = robIdx + arfIdx + prfIdx + 4 + 32 + 32 + 32 + 32       // fu_alu_reg_t: rob_id rd_arch rd_phy fu_opcode opA opB rs1 rs2 (operands PRE-SELECTED in IntRs)
  def fuBrRegW   = robIdx + arfIdx + prfIdx + 4 + 32 + 32 + 32 + 32 + 1 + 1 + 32 // fu_br_reg_t: rob_id rd_arch rd_phy fu_opcode pc imm rs1 rs2 is_compressed predict_taken predict_target
  def aguRegW    = robIdx + 4 + 32 + 32 + 32                             // agu_reg_t: rob_id fu_opcode imm rs1 rs2

  // Candidate counts are shared by address generation and result selection.
  def lsuCacheCandidates: Int = dNumWays * (if (lsuWordSpeculation) 1 << (dOffsetIdx - 2) else 1)
  def lsuSerialCandidates: Int = if (lsuSerialSpeculation && zicsr && aExt) 2 else 1
  def lsuStqForwardCandidates: Int = if (lsuStoreForwardLanes) stqDepth else ldqDepth
  def lsuStbForwardCandidates: Int = if (lsuBufferForwardLanes) stbDepth else ldqDepth
  def lsuForwardCandidates: Int = lsuStqForwardCandidates + lsuStbForwardCandidates
  def lsuBypassCandidates: Int = lsuCacheCandidates + (if (lsuForwardSpeculation) lsuForwardCandidates + lsuSerialCandidates else 0)

  /** Reject unsupported sizes and interfaces before elaboration. */
  def validate(): Unit = {
    implementation.validate()
    require(!brPrfSharedPredecode || ((prfReadSharing & 4) != 0 && !prfLutRam && !prfBinaryRead),
      "BR_PRF_SHARED_PREDECODE requires shared branch reads and the ASIC decoded PRF")
    require(prfReadSharing >= 0 && prfReadSharing <= 7, "PRF_READ_SHARING must be in 0..7")
    require(!prfLutRam || implementation.isFpga, "PRF_LUTRAM requires an FPGA target")
    require(!(lowPower || mmio) || zicsr, "LOW_POWER/MMIO require ZICSR=1")
    require(mmioBase >= 0 && mmioBase <= 0xffffffffL && mmioMask >= 0 && mmioMask <= 0xffffffffL)
    require((mmioBase & mmioMask) == mmioBase, "MMIO_BASE must be normalized by MMIO_MASK")
    require(!mmio || (mmioMask != 0 && (mmioMask & 3) == 0), "MMIO window must contain complete words")
    require(!mmio || (((clintHi16.toLong << 16) ^ mmioBase) & mmioMask & 0xffff0000L) != 0,
      "External MMIO must not overlap the 64 KiB CLINT window")
    def pow2(n: Int) = n > 0 && (n & (n - 1)) == 0
    require(pow2(instQueueDepth) && instQueueDepth >= 2,
      s"Instruction queue depth must be a power-of-two >= 2, got $instQueueDepth")
    require(atomicCamDepth > 0 && csrCamDepth > 0,
      "Atomic and CSR capture depths must be positive")
    require(atomicCamDepth <= robDepth * idWidth && csrCamDepth <= robDepth * idWidth,
      "Serial capture depths cannot exceed ROB capacity")
    require(maxReadBursts > 0 && maxReadBursts <= 255,
      "MAX_READ_BURSTS must be in 1..255")
    require(divCycles >= 3 && divCycles <= 33, "DIV_CYCLES must be in 3..33")
    require(resetPc >= 0 && resetPc <= 0xffffffffL && (resetPc & (if (cExt) 1 else 3)) == 0,
      "RESET_PC must be an aligned 32-bit instruction address")
    require(clintHi16 >= 0 && clintHi16 <= 0xffff, "CLINT_HI16 must fit 16 bits")

    // branch prediction
    require(tageNum > 0 && tageHistLen.nonEmpty && tageHistLen.forall(_ > 0),
      "TAGE requires at least one table with positive history lengths")
    require(tageHistLen.length == tageNum, s"tageHist len ${tageHistLen.length} != tageNum ${tageNum}")
    require(ghrLen >= tageHistLen.max, s"ghrLen ${ghrLen} < max hist ${tageHistLen.max}")
    // Micro-BTB rows split into even/odd banks with exact power-of-two indices.
    require(!ubtbParallelTagCompare || ubtbLateCarrySelect, "Parallel micro-BTB tag comparison requires late carry selection")
    require(pow2(ubtbRows) && ubtbRows >= 4, s"ubtbRows must be a power-of-two >= 4 (even/odd bank split), got ${ubtbRows}")
    require(pow2(phtDepth), s"phtDepth must be power-of-two, got ${phtDepth}")
    require(pow2(tageDepth), s"tageDepth must be power-of-two, got ${tageDepth}")
    require(pow2(rasDepth), s"rasDepth must be power-of-two, got ${rasDepth}")

    // Queue pointers wrap at their binary index width.
    require(pow2(ldqDepth), s"ldqDepth must be power-of-two, got ${ldqDepth}")
    require(pow2(stqDepth), s"stqDepth must be power-of-two, got ${stqDepth}")
    require(pow2(stbDepth), s"stbDepth must be power-of-two, got ${stbDepth}")

    // rename / ROB
    // FreeList holds the non-architectural pregs: FDEP = prfDepth - arfDepth must be a
    // positive power-of-two (FIDX = log2Up(FDEP) is used as an exact index width).
    require(!lsuCachePermission || mmio, "Cache permission predecode requires MMIO ordering")
    require(!memCdbSpeculation || (lsuOperandSpeculation && aluAguFusion && (prfReadSharing & 1) == 0),
      "CDB address speculation requires operand speculation, ALU fusion and unshared memory reads")
    require(!lsuOperandSpeculation || (lsuEntrySpeculation && lsuWaySpeculation),
      "Operand speculation requires per-entry and per-way address generation")
    require(!aluAguFusion || (lsuEntrySpeculation && lsuWaySpeculation),
      "ALU/address fusion requires per-entry cache-way speculation")
    require(!lsuStoreForwardLanes || (lsuForwardSpeculation && storeVerdictPrecompute),
      "Store forwarding lanes require forwarding speculation and registered store verdicts")
    require(!lsuBufferForwardLanes || (lsuForwardSpeculation && storeBufferPrecompute),
      "Committed-store lanes require forwarding speculation and registered buffer verdicts")
    require(!lsuForwardSpeculation || (lsuWaySpeculation && lsuResponsePredecode),
      "Forwarding speculation requires cache-way speculation and response predecode")
    require(!lsuEntrySpeculation || (prfReadSharing & 1) == 0,
      "Per-entry address generation requires separate memory operand reads")
    require(!memPrfPredecode || (!prfLutRam && !prfBinaryRead && (prfReadSharing & 1) == 0),
      "Memory PRF predecode requires separate one-hot flop-array reads")
    require(prfDepth > arfDepth, s"prfDepth ($prfDepth) must exceed arfDepth ($arfDepth) -- FreeList would be empty")
    require(pow2(prfDepth - arfDepth), s"prfDepth - arfDepth must be power-of-two, got ${prfDepth - arfDepth}")
    require(pow2(robDepth), s"robDepth must be power-of-two, got ${robDepth}")
    require(pow2(arfDepth), s"arfDepth must be power-of-two, got ${arfDepth}")

    // pipeline widths
    require(idWidth == 2 && idWidth <= ifWidth, "Decode/retirement width is currently fixed at 2")
    require(cdbWidth == 4 && prfReadPorts == 5 && numFastBypass == 2 && arfDepth == 32,
      "The current execution lane map requires CDB=4, PRF read ports=5, fast bypass=2 and ARF=32")
    require(pow2(ifWidth), s"ifWidth must be power-of-two, got ${ifWidth}")
    require(intIssueWidth == 2, s"Integer issue supports exactly two lanes, got $intIssueWidth")
    require(numFastBypass <= cdbWidth, s"numFastBypass ($numFastBypass) cannot exceed cdbWidth ($cdbWidth)")

    // caches
    // Icache block-banking assumes exactly 2 fetch blocks per line (Icache: PDBLKS == 2).
    require((1 << (iOffsetIdx - log2Up(ifWidth * 4))) == 2,
            s"I-cache needs exactly 2 fetch blocks/line: iOffsetIdx=$iOffsetIdx with ifWidth=$ifWidth gives ${1 << (iOffsetIdx - log2Up(ifWidth * 4))}")
    // Dcache splits the tag compare hi16/lo (Dcache: TAG == 16 + TAGLO, TAGLO > 0).
    require(dSetIdx + dOffsetIdx < 16, s"D-cache hi16 tag split needs dSetIdx + dOffsetIdx < 16, got ${dSetIdx + dOffsetIdx}")
    require(pow2(iNumWays) && pow2(dNumWays), s"cache ways must be power-of-two, got i=$iNumWays d=$dNumWays")
  }
}

object CpuConfig {
  def forTarget(base: CpuConfig, target: String): CpuConfig = {
    val implementation = CpuImplementation.named(target)
    base.copy(implementation = implementation, fpgaNativeAdd = implementation.isFpga,
      fpgaSharedShift = base.fpgaSharedShift || implementation.isFpga, prfBinaryRead = implementation.isFpga,
      prfLutRam = implementation.isFpga,
      prfReadSharing = (if (implementation.isFpga) 7 else base.prfReadSharing),
      storeAgeLookup = implementation.isFpga)
  }
  def fromEnv(base: CpuConfig = CpuConfig()): CpuConfig = fromEnvironment(base,sys.env)

  /** Apply profile, target defaults, then explicit environment overrides. */
  def fromEnvironment(fallback: CpuConfig, env: collection.Map[String,String]): CpuConfig = {
    val profile = env.get("CPU_PROFILE").map(CpuProfiles.named).getOrElse(fallback)
    val base = env.get("CPU_TARGET").map(forTarget(profile, _)).getOrElse(profile)
    def envI(name: String, dflt: Int): Int = env.get(name).map(_.trim.toInt).getOrElse(dflt)
    def envB(name: String, dflt: Boolean): Boolean = env.get(name).map(_.trim.toLowerCase).map {
      case "1" | "true" | "yes" | "on" => true
      case "0" | "false" | "no" | "off" => false
      case v => throw new IllegalArgumentException(s"$name must be boolean, got '$v'")
    }.getOrElse(dflt)
    val cfg = base.copy(
      implementation = base.implementation.copy(
        multiplier = env.getOrElse("CPU_MULTIPLIER", base.implementation.multiplier),
        divider = env.getOrElse("CPU_DIVIDER", base.implementation.divider),
        memory = env.getOrElse("CPU_MEMORY", base.implementation.memory),
        clockGate = env.getOrElse("CPU_CLOCK_GATE", base.implementation.clockGate)),
      fpgaNativeAdd = envB("FPGA_NATIVE_ADD", base.fpgaNativeAdd),
      fpgaSharedShift = envB("FPGA_SHARED_SHIFT", base.fpgaSharedShift),
      prfBinaryRead = envB("PRF_BINARY_READ", base.prfBinaryRead),
      prfLutRam = envB("PRF_LUTRAM", base.prfLutRam),
      brPrfSharedPredecode = envB("BR_PRF_SHARED_PREDECODE", base.brPrfSharedPredecode),
      prfReadSharing = envI("PRF_READ_SHARING", base.prfReadSharing),
      cExt        = envB("C_EXT",        base.cExt),
      aExt        = envB("A_EXT",        base.aExt),
      zicsr       = envB("ZICSR",        base.zicsr),
      lowPower    = envB("LOW_POWER",    base.lowPower),
      mmio        = envB("MMIO",         base.mmio),
      storeAgeLookup = envB("STQ_AGE_LUT", base.storeAgeLookup),
      storeAgePrecompute = envB("STQ_AGE_PRECOMPUTE", base.storeAgePrecompute),
      storePairPrecompute = envB("STQ_PAIR_PRECOMPUTE", base.storePairPrecompute),
      storeVerdictPrecompute = envB("STQ_VERDICT_PRECOMPUTE", base.storeVerdictPrecompute),
      storeBufferPrecompute = envB("STB_PRECOMPUTE", base.storeBufferPrecompute),
      dcacheReadAllBanks = envB("DCACHE_READ_ALL_BANKS", base.dcacheReadAllBanks),
      dcacheMergedTag = envB("DCACHE_MERGED_TAG", base.dcacheMergedTag),
      lsuWaySpeculation = envB("LSU_WAY_SPECULATION", base.lsuWaySpeculation),
      lsuCarryFreeStoreMatch = envB("LSU_CARRY_FREE_STORE_MATCH", base.lsuCarryFreeStoreMatch),
      lsuWordSpeculation = envB("LSU_WORD_SPECULATION", base.lsuWordSpeculation),
      distributedFlush = envB("DISTRIBUTED_FLUSH", base.distributedFlush),
      aluAguFusion = envB("ALU_AGU_FUSION", base.aluAguFusion),
      dcacheLruReadCache = envB("DCACHE_LRU_READ_CACHE", base.dcacheLruReadCache),
      bmemWriteDataBypass = envB("BMEM_WRITE_DATA_BYPASS", base.bmemWriteDataBypass),
      bmemBeatSpeculation = envB("BMEM_BEAT_SPECULATION", base.bmemBeatSpeculation),
      bmemEarlyAddress = envB("BMEM_EARLY_ADDRESS", base.bmemEarlyAddress),
      mmioIdleCapture = envB("MMIO_IDLE_CAPTURE", base.mmioIdleCapture),
      robSerialSummary = envB("ROB_SERIAL_SUMMARY", base.robSerialSummary),
      robDeviceParallel = envB("ROB_DEVICE_PARALLEL", base.robDeviceParallel),
      robStqSummary = envB("ROB_STQ_SUMMARY", base.robStqSummary),
      iqParallelDecode = envB("IQ_PARALLEL_DECODE", base.iqParallelDecode),
      iqMergedDecodeSelect = envB("IQ_MERGED_DECODE_SELECT", base.iqMergedDecodeSelect),
      iqOneHotHead = envB("IQ_ONE_HOT_HEAD", base.iqOneHotHead),
      mulCompactSigns = envB("MUL_COMPACT_SIGNS", base.mulCompactSigns),
      mulDaddaReduction = envB("MUL_DADDA_REDUCTION", base.mulDaddaReduction),
      mulCarryTopology = env.get("MUL_CARRY_TOPOLOGY").map(_.trim.toLowerCase).getOrElse(base.mulCarryTopology),
      mulKeepPropagate = envB("MUL_KEEP_PROPAGATE", base.mulKeepPropagate),
      mulOrCarry = envB("MUL_OR_CARRY", base.mulOrCarry),
      aguOrCarry = envB("AGU_OR_CARRY", base.aguOrCarry),
      aguCarrySelectAt = envI("AGU_CARRY_SELECT_AT", base.aguCarrySelectAt),
      aguSignedImmediate = envB("AGU_SIGNED_IMMEDIATE", base.aguSignedImmediate),
      lsuForwardSpeculation = envB("LSU_FORWARD_SPECULATION", base.lsuForwardSpeculation),
      lsuStoreForwardLanes = envB("LSU_STORE_FORWARD_LANES", base.lsuStoreForwardLanes),
      lsuBufferForwardLanes = envB("LSU_BUFFER_FORWARD_LANES", base.lsuBufferForwardLanes),
      lsuResponsePredecode = envB("LSU_RESPONSE_PREDECODE", base.lsuResponsePredecode),
      lsuFormatPredecode = envB("LSU_FORMAT_PREDECODE", base.lsuFormatPredecode),
      frontendInvertedTag = envB("FRONTEND_INVERTED_TAG", base.frontendInvertedTag),
      frontendFastCarry = envB("FRONTEND_FAST_CARRY", base.frontendFastCarry),
      frontendPublishedValidity = envB("FRONTEND_PUBLISHED_VALIDITY", base.frontendPublishedValidity),
      frontendLaneValidity = envB("FRONTEND_LANE_VALIDITY", base.frontendLaneValidity),
      frontendValidSpeculation = envB("FRONTEND_VALID_SPECULATION", base.frontendValidSpeculation),
      frontendPcOneHot = envB("FRONTEND_PC_ONE_HOT", base.frontendPcOneHot),
      frontendCacheAddressOneHot = envB("FRONTEND_CACHE_ADDRESS_ONE_HOT", base.frontendCacheAddressOneHot),
      frontendOutcomeOneHot = envB("FRONTEND_OUTCOME_ONE_HOT", base.frontendOutcomeOneHot),
      tageHistoryStateCofactors = envB("TAGE_HISTORY_STATE_COFACTORS", base.tageHistoryStateCofactors),
      frontendHistoryCofactors = envB("FRONTEND_HISTORY_COFACTORS", base.frontendHistoryCofactors),
      frontendPredictCofactors = envB("FRONTEND_PREDICT_COFACTORS", base.frontendPredictCofactors),
      tageLateBankSelect = envB("TAGE_LATE_BANK_SELECT", base.tageLateBankSelect),
      tagePcPrehash = envB("TAGE_PC_PREHASH", base.tagePcPrehash),
      tageRegisteredTags = envB("TAGE_REGISTERED_TAGS", base.tageRegisteredTags),
      tageParallelPredict = envB("TAGE_PARALLEL_PREDICT", base.tageParallelPredict),
      tageParallelHistory = envB("TAGE_PARALLEL_HISTORY", base.tageParallelHistory),
      keepTimingHierarchy = envB("KEEP_TIMING_HIERARCHY", base.keepTimingHierarchy),
      frontendLaneDecode = envB("FRONTEND_LANE_DECODE", base.frontendLaneDecode),
      frontendBankSpeculation = envB("FRONTEND_BANK_SPECULATION", base.frontendBankSpeculation),
      ubtbOneHotSlots = envB("UBTB_ONE_HOT_SLOTS", base.ubtbOneHotSlots),
      ubtbLateCarrySelect = envB("UBTB_LATE_CARRY_SELECT", base.ubtbLateCarrySelect),
      ubtbParallelTagCompare = envB("UBTB_PARALLEL_TAG_COMPARE", base.ubtbParallelTagCompare),
      frontendParallelRealign = envB("FRONTEND_PARALLEL_REALIGN", base.frontendParallelRealign),
      frontendLengthPredecode = envB("FRONTEND_LENGTH_PREDECODE", base.frontendLengthPredecode),
      lsuCachePermission = envB("LSU_CACHE_PERMISSION", base.lsuCachePermission),
      frontendPayloadSpeculation = envB("FRONTEND_PAYLOAD_SPECULATION", base.frontendPayloadSpeculation),
      memCdbSpeculation = envB("MEM_CDB_SPECULATION", base.memCdbSpeculation),
      storePairSplitTag = envB("STQ_PAIR_SPLIT_TAG", base.storePairSplitTag),
      lsuOperandSpeculation = envB("LSU_OPERAND_SPECULATION", base.lsuOperandSpeculation),
      lsuSerialSpeculation = envB("LSU_SERIAL_SPECULATION", base.lsuSerialSpeculation),
      lsuWakeupPredecode = envB("LSU_WAKEUP_PREDECODE", base.lsuWakeupPredecode),
      ratParallelRead = envB("RAT_PARALLEL_READ", base.ratParallelRead),
      intCsrSpeculation = envB("INT_CSR_SPECULATION", base.intCsrSpeculation),
      intmWakeupPrecompute = envB("INTM_WAKEUP_PRECOMPUTE", base.intmWakeupPrecompute),
      aluWakeupPrecompute = envB("ALU_WAKEUP_PRECOMPUTE", base.aluWakeupPrecompute),
      lsuEntrySpeculation = envB("LSU_ENTRY_SPECULATION", base.lsuEntrySpeculation),
      memPrfPredecode = envB("MEM_PRF_PREDECODE", base.memPrfPredecode),
      clintEarlyWrite = envB("CLINT_EARLY_WRITE", base.clintEarlyWrite),
      clintLateWriteGrant = envB("CLINT_LATE_WRITE_GRANT", base.clintLateWriteGrant),
      clintCoreRead = envB("CLINT_CORE_READ", base.clintCoreRead),
      clintRetimedRead = envB("CLINT_RETIMED_READ", base.clintRetimedRead),
      aguParallelAdd = envB("AGU_PARALLEL_ADD", base.aguParallelAdd),
      mmioBase    = env.get("MMIO_BASE").map(java.lang.Long.decode(_).longValue).getOrElse(base.mmioBase),
      mmioMask    = env.get("MMIO_MASK").map(java.lang.Long.decode(_).longValue).getOrElse(base.mmioMask),
      clintHi16   = env.get("CLINT_HI16").map(java.lang.Integer.decode(_).intValue).getOrElse(base.clintHi16),
      resetPc     = env.get("RESET_PC").map(java.lang.Long.decode(_).longValue).getOrElse(base.resetPc),
      rvfi        = envB("RVFI",         base.rvfi),
      ifWidth     = envI("IF_WIDTH",     base.ifWidth),
      idWidth     = envI("ID_WIDTH",     base.idWidth),
      instQueueDepth = envI("IQ_DEPTH", base.instQueueDepth),
      gateFetchPayload = envB("FETCH_PAYLOAD_GATING", base.gateFetchPayload),
      atomicCamDepth = envI("ATOMIC_CAM_DEPTH", base.atomicCamDepth),
      csrCamDepth = envI("CSR_CAM_DEPTH", base.csrCamDepth),
      maxReadBursts = envI("MAX_READ_BURSTS", base.maxReadBursts),
      divCycles   = envI("DIV_CYCLES", base.divCycles),
      robDepth    = envI("ROB_DEPTH",    base.robDepth),
      prfDepth    = envI("PRF_DEPTH",    base.prfDepth),
      intrsDepth  = envI("INTRS_DEPTH",  base.intrsDepth),
      intmrsDepth = envI("INTMRS_DEPTH", base.intmrsDepth),
      brrsDepth   = envI("BRRS_DEPTH",   base.brrsDepth),
      memrsDepth  = envI("MEMRS_DEPTH",  base.memrsDepth),
      cbDepth     = envI("CB_DEPTH",     base.cbDepth),
      ldqDepth    = envI("LDQ_DEPTH",    base.ldqDepth),
      stqDepth    = envI("STQ_DEPTH",    base.stqDepth),
      stbDepth    = envI("STB_DEPTH",    base.stbDepth),
      phtDepth    = envI("PHT_DEPTH",    base.phtDepth),
      ubtbRows    = envI("UBTB_ROWS",    base.ubtbRows),
      ubtbTagW    = envI("UBTB_TAG",     base.ubtbTagW),
      rasDepth    = envI("RAS_DEPTH",    base.rasDepth),
      ghrLen      = envI("GHR_LEN",      base.ghrLen),
      tageNum     = envI("TAGE_NUM",     base.tageNum),
      tageDepth   = envI("TAGE_DEPTH",   base.tageDepth),
      tageCtrBits = envI("TAGE_COUNTER_BITS", base.tageCtrBits),
      tageTagBits = envI("TAGE_TAG",     base.tageTagBits),
      tageAltCounterBits = envI("TAGE_ALT_COUNTER_BITS", base.tageAltCounterBits),
      tageUBits   = envI("TAGE_U",       base.tageUBits),
      tageHistLen = env.get("TAGE_HIST").map(_.split(",").map(_.trim.toInt).toSeq).getOrElse(base.tageHistLen)
    )
    cfg.validate()
    cfg
  }
}
