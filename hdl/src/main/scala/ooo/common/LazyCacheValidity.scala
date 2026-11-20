package ooo.common

import spinal.core._
import ooo.{CpuConfig,OhSel}

/** Reset-safe lazy tag-row initialization. One resettable bit per set masks
  * arbitrary SRAM contents. The first refill clears the other ways' tag-valid
  * bits; the row is published when that registered SRAM write completes.
  */
class LazyCacheValidity(setWidth: Int, requestSet: UInt, stageSet: UInt,
                        captureAddress: Bool, allocateDone: Bool, invalidate: Bool = False,
                        requestCandidates: Option[(Bits,Bits)] = None,
                        requestValue: Option[Bool] = None,
                        requestIncludesPublication: Boolean = false) extends Area {
  val initialized = Vec(RegInit(False),1 << setWidth)
  val rowInitialized = RegInit(False)
  val initializeOnAllocate = allocateDone && !rowInitialized
  val publishRow = RegNext(initializeOnAllocate) init(False)
  require(!requestIncludesPublication || requestValue.nonEmpty)
  val lookupBitmap=if(requestIncludesPublication) {
    Vec((0 until (1 << setWidth)).map(i => initialized(i) ||
      (publishRow && stageSet === i))).asBits
  } else initialized.asBits
  val requestInitialized=requestValue.getOrElse(requestCandidates.map { case (sets,select) =>
    require(sets.getWidth == select.getWidth * setWidth)
    val values=sets.subdivideIn(select.getWidth slices).map { set =>
      val value=Bool();value:=initialized(set.asUInt);value.addAttribute("keep")
      value.asBits
    }
    OhSel(select,values)(0)
  }.getOrElse(initialized(requestSet)))
  when(captureAddress) { rowInitialized := requestInitialized }
  when(publishRow) {
    initialized(stageSet) := True
    // A redirect may capture a different set on the publication edge.
    if(requestIncludesPublication) {
      when(!captureAddress) {rowInitialized:=True}
    } else when(!captureAddress || requestSet === stageSet) { rowInitialized := True }
  }
  // Invalidation wins over a pending refill publication, even on the same edge.
  when(invalidate) {
    initialized.foreach(_ := False)
    rowInitialized := False
    publishRow := False
  }
}

object CacheValidityLookup {
  def apply(bitmap: Bits,address: Bits,cfg: CpuConfig): Bool = {
    val value=Bool()
    value:=bitmap(address(cfg.iOffsetIdx,cfg.iSetIdx bits).asUInt)
    value.addAttribute("keep")
    value
  }
}
