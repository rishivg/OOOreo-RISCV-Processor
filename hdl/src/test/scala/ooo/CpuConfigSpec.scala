package ooo

import org.scalatest.funsuite.AnyFunSuite

class CpuConfigSpec extends AnyFunSuite {
  test("multiplier carry layout is configurable and defaults to sparse Dadda wiring") {
    val defaults = CpuConfig()
    assert(defaults.mulCarryTopology == "auto" && !defaults.mulKeepPropagate)
    for (topology <- FastAdd.prefixTopologies) {
      val cfg = CpuConfig.fromEnvironment(defaults, Map(
        "MUL_CARRY_TOPOLOGY" -> topology.toUpperCase, "MUL_KEEP_PROPAGATE" -> "0"))
      assert(cfg.mulCarryTopology == topology && !cfg.mulKeepPropagate)
    }
    intercept[IllegalArgumentException](CpuConfig(mulCarryTopology = "unknown"))
  }
  test("compact Booth signs require column reduction") {
    intercept[IllegalArgumentException](CpuConfig(mulCompactSigns=true))
    val cfg = CpuConfig.fromEnvironment(CpuConfig(), Map(
      "MUL_DADDA_REDUCTION" -> "1", "MUL_COMPACT_SIGNS" -> "1"))
    assert(cfg.mulDaddaReduction && cfg.mulCompactSigns)
  }
  test("shared branch predecode requires shared decoded flop-array reads") {
    val cfg = CpuConfig.fromEnvironment(CpuConfig(), Map(
      "PRF_READ_SHARING" -> "4", "BR_PRF_SHARED_PREDECODE" -> "1"))
    assert(cfg.brPrfSharedPredecode)
    for (bad <- Seq(cfg.copy(prfReadSharing=0), cfg.copy(prfBinaryRead=true),
      CpuConfig.forTarget(cfg, "fpga"))) {
      intercept[IllegalArgumentException](bad.validate())
    }
  }
  test("predictor counter widths are bounded and environment configurable") {
    val cfg = CpuConfig.fromEnvironment(CpuConfig(), Map(
      "TAGE_COUNTER_BITS" -> "2", "TAGE_ALT_COUNTER_BITS" -> "1"))
    assert(cfg.tageCtrBits == 2 && cfg.tageAltCounterBits == 1)
    for (width <- Seq(0, 9)) {
      intercept[IllegalArgumentException](CpuConfig(tageCtrBits=width))
      intercept[IllegalArgumentException](CpuConfig(tageAltCounterBits=width))
    }
  }
  test("CSR issue precomputation requires predecoded CSR wakeup") {
    assert(!CpuConfig().intCsrSpeculation)
    val base = CpuConfig(zicsr=true, lsuWakeupPredecode=true)
    assert(CpuConfig.fromEnvironment(base, Map("INT_CSR_SPECULATION" -> "1")).intCsrSpeculation)
    intercept[IllegalArgumentException](base.copy(intCsrSpeculation=true, zicsr=false))
    intercept[IllegalArgumentException](base.copy(intCsrSpeculation=true, lsuWakeupPredecode=false))
  }
  test("early memory beats require direct write-data bypass") {
    intercept[IllegalArgumentException](CpuConfig(bmemBeatSpeculation=true))
    val cfg = CpuConfig.fromEnvironment(CpuConfig(bmemWriteDataBypass=true),
      Map("BMEM_BEAT_SPECULATION" -> "1"))
    assert(cfg.bmemBeatSpeculation)
    assert(CpuConfig.fromEnvironment(CpuConfig(),
      Map("BMEM_EARLY_ADDRESS" -> "1")).bmemEarlyAddress)
  }
  test("parallel queue decode requires a one-hot head and merged selection requires decode") {
    assert(!CpuConfig().iqParallelDecode && !CpuConfig().iqMergedDecodeSelect)
    val enabled = CpuConfig.fromEnvironment(CpuConfig(), Map(
      "IQ_ONE_HOT_HEAD" -> "1", "IQ_PARALLEL_DECODE" -> "1", "IQ_MERGED_DECODE_SELECT" -> "1"))
    assert(enabled.iqParallelDecode && enabled.iqMergedDecodeSelect)
    intercept[IllegalArgumentException](CpuConfig(iqParallelDecode=true))
    intercept[IllegalArgumentException](CpuConfig(iqMergedDecodeSelect=true))
  }
  test("late CLINT write grant requires early payload selection and ZICSR") {
    val base = CpuConfig(zicsr=true,clintEarlyWrite=true)
    assert(!base.clintLateWriteGrant)
    assert(CpuConfig.fromEnvironment(base,Map("CLINT_LATE_WRITE_GRANT" -> "1")).clintLateWriteGrant)
    intercept[IllegalArgumentException](base.copy(clintLateWriteGrant=true,zicsr=false))
    intercept[IllegalArgumentException](base.copy(clintLateWriteGrant=true,clintEarlyWrite=false))
  }
  test("parallel device retirement requires the store summary and MMIO") {
    val base = CpuConfig(zicsr=true,mmio=true,robStqSummary=true)
    assert(!base.robDeviceParallel)
    assert(CpuConfig.fromEnvironment(base,Map("ROB_DEVICE_PARALLEL" -> "1")).robDeviceParallel)
    intercept[IllegalArgumentException](base.copy(robDeviceParallel=true,robStqSummary=false))
    intercept[IllegalArgumentException](base.copy(robDeviceParallel=true,mmio=false))
  }
  test("fetch and load-format timing options default off and validate their dependencies") {
    val base = CpuConfig()
    assert(!base.lsuFormatPredecode && !base.frontendPcOneHot && !base.frontendCacheAddressOneHot)
    val c = CpuConfig.fromEnvironment(base, Map("LSU_FORMAT_PREDECODE" -> "1",
      "FRONTEND_VALID_SPECULATION" -> "1", "FRONTEND_PC_ONE_HOT" -> "1",
      "FRONTEND_CACHE_ADDRESS_ONE_HOT" -> "1"))
    assert(c.lsuFormatPredecode && c.frontendPcOneHot && c.frontendCacheAddressOneHot)
    assert(c.copy(frontendPcOneHot=false).frontendCacheAddressOneHot)
    intercept[IllegalArgumentException](base.copy(frontendPcOneHot=true))
    intercept[IllegalArgumentException](base.copy(frontendCacheAddressOneHot=true))
    intercept[IllegalArgumentException](c.copy(frontendPredictCofactors=true))
  }
  test("profiles resolve before per-resource overrides") {
    val c=CpuConfig.fromEnvironment(CpuConfig(),Map("CPU_PROFILE"->"mcu-efficient","IQ_DEPTH"->"2","ATOMIC_CAM_DEPTH"->"3","RVFI"->"1"))
    assert(c.zicsr && c.mmio && c.lowPower && c.rvfi)
    assert(c.instQueueDepth==2 && c.atomicCamDepth==3 && c.csrCamDepth==1 && c.maxReadBursts==7)
    assert(CpuConfig.fromEnvironment(CpuConfig(),Map.empty)==CpuConfig())
    assert(!CpuConfig().dcacheLruReadCache)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("DCACHE_LRU_READ_CACHE" -> "1")).dcacheLruReadCache)
    assert(!CpuConfig().bmemWriteDataBypass)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("BMEM_WRITE_DATA_BYPASS" -> "1")).bmemWriteDataBypass)
    assert(!CpuConfig().mmioIdleCapture)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("MMIO_IDLE_CAPTURE" -> "1")).mmioIdleCapture)
    assert(!CpuConfig().robSerialSummary)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("ROB_SERIAL_SUMMARY" -> "1")).robSerialSummary)
    assert(!CpuConfig().ubtbOneHotSlots && !CpuConfig().tagePcPrehash)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("UBTB_ONE_HOT_SLOTS" -> "1", "TAGE_PC_PREHASH" -> "1")).ubtbOneHotSlots)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("TAGE_PC_PREHASH" -> "1")).tagePcPrehash)
    assert(!CpuConfig().robStqSummary)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("ROB_STQ_SUMMARY" -> "1")).robStqSummary)
    assert(!CpuConfig().iqOneHotHead)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("IQ_ONE_HOT_HEAD" -> "1")).iqOneHotHead)
    assert(!CpuConfig().aguOrCarry)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("AGU_OR_CARRY" -> "1")).aguOrCarry)
    assert(!CpuConfig().ubtbLateCarrySelect)
    assert(CpuConfig.fromEnvironment(CpuConfig(), Map("UBTB_LATE_CARRY_SELECT" -> "1")).ubtbLateCarrySelect)
    assert(CpuConfig.fromEnvironment(CpuConfig(),Map("CLINT_HI16"->"0x0300","RESET_PC"->"0x1000")).resetPc==0x1000L)
  }
  test("invalid capacities and unsupported widths fail before elaboration") {
    for (bad <- Seq(CpuConfig(instQueueDepth=1),CpuConfig(instQueueDepth=3),CpuConfig(atomicCamDepth=0),
      CpuConfig(csrCamDepth=100),CpuConfig(maxReadBursts=0),CpuConfig(maxReadBursts=256),
      CpuConfig(divCycles=2),CpuConfig(divCycles=34),CpuConfig(idWidth=1),CpuConfig(cdbWidth=5),
      CpuConfig(resetPc=1),CpuConfig(clintHi16=0x10000),CpuConfig(memCdbSpeculation=true),
      CpuConfig(lsuOperandSpeculation=true),CpuConfig(lsuCachePermission=true))) {
      intercept[IllegalArgumentException](bad.validate())
    }
    intercept[IllegalArgumentException](CpuConfig.fromEnvironment(CpuConfig(),Map("CPU_PROFILE"->"typo")))
    for (invalid <- Seq(CpuConfig(tageNum=0,tageHistLen=Seq.empty),
                        CpuConfig(tageHistLen=Seq(0,39,63)))) {
      intercept[IllegalArgumentException](invalid.validate())
    }
  }
  test("raw forwarding lanes follow store capacities and require captured verdicts") {
    val base = CpuConfig(lsuWaySpeculation=true, lsuForwardSpeculation=true,
      lsuResponsePredecode=true, storeVerdictPrecompute=true, storeBufferPrecompute=true,
      stqDepth=8, stbDepth=2)
    val raw = CpuConfig.fromEnvironment(base, Map(
      "LSU_STORE_FORWARD_LANES" -> "1", "LSU_BUFFER_FORWARD_LANES" -> "1"))
    raw.validate()
    assert(!CpuConfig().lsuStoreForwardLanes && !CpuConfig().lsuBufferForwardLanes)
    assert(base.lsuForwardCandidates == 8 && raw.lsuForwardCandidates == 10)
    for (bad <- Seq(raw.copy(storeVerdictPrecompute=false),
      raw.copy(storeBufferPrecompute=false), raw.copy(lsuForwardSpeculation=false))) {
      intercept[IllegalArgumentException](bad.validate())
    }
  }
  test("target defaults preserve architecture and explicit overrides take precedence") {
    val base = CpuProfiles.named("mcu-efficient")
    val fpga = CpuConfig.forTarget(base, "fpga")
    val asic = CpuConfig.forTarget(base, "asic")
    assert(asic.fpgaSharedShift && asic.prfReadSharing == 6)
    assert(fpga.implementation.isFpga && fpga.prfLutRam && fpga.prfReadSharing == 7)
    assert(fpga.robDepth == base.robDepth && fpga.prfDepth == base.prfDepth)
    assert(fpga.divCycles == base.divCycles && fpga.instQueueDepth == base.instQueueDepth)
    val overridden = CpuConfig.fromEnvironment(base, Map(
      "CPU_TARGET" -> "fpga", "PRF_LUTRAM" -> "0", "PRF_READ_SHARING" -> "3"))
    assert(!overridden.prfLutRam && overridden.prfReadSharing == 3)
    val unshared = CpuConfig.fromEnvironment(base, Map(
      "CPU_TARGET" -> "asic", "FPGA_SHARED_SHIFT" -> "0", "PRF_READ_SHARING" -> "0"))
    assert(!unshared.fpgaSharedShift && unshared.prfReadSharing == 0)
    for (bad <- Seq(
      CpuConfig(prfLutRam = true), CpuConfig(prfReadSharing = 8),
      CpuConfig(implementation = CpuImplementation(multiplier = "dsp-karatsuba")),
      CpuConfig(implementation = CpuImplementation(clockGate = "bufgctrl")))) {
      intercept[IllegalArgumentException](bad.validate())
    }
  }
}
