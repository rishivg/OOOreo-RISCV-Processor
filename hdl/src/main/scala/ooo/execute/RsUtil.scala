package ooo.execute

import spinal.core._
import ooo.{BalancedOr, CpuConfig}

object RsUtil {
  def orMux(sel: Bits, data: collection.Seq[Bits]): Bits =
    BalancedOr(data.zipWithIndex.map { case (d, i) => Mux(sel(i), d, B(0, d.getWidth bits)) })

  def exclusivePrefixOr(requests: collection.Seq[Bool]): Seq[Bool] = {
    var earlier: Bool = False
    requests.iterator.map { request =>
      val prefix = earlier
      earlier = earlier | request
      prefix
    }.toVector
  }

  def firstOneHot(requests: collection.Seq[Bool]): Vec[Bool] =
    Vec(requests.zip(exclusivePrefixOr(requests)).map {
      case (request, earlier) => request && !earlier
    })

  def wakeupVec(rdPhyFlat: Bits, valid: Bits, cfg: CpuConfig) = {
    val wcdb = Vec(CdbRs(cfg), cfg.cdbWidth)
    for (k <- 0 until cfg.cdbWidth) {
      wcdb(k).rd_phy := rdPhyFlat(k * cfg.prfIdx, cfg.prfIdx bits)
      wcdb(k).valid  := valid(k)
    }
    wcdb
  }

  def bypassVec(flat: Bits, cfg: CpuConfig) = {
    val fb = Vec(BypassNet(cfg), cfg.numFastBypass)
    for (k <- 0 until cfg.numFastBypass) {
      fb(k) := BypassNet.fromBits(flat(k * cfg.bypassNetW, cfg.bypassNetW bits), cfg)
    }
    fb
  }

  def withBypassLaneEn(payload: Bits, cfg: CpuConfig, lane: Int,
                       rs1Enabled: Bool, rs2Enabled: Bool): Bits = {
    val selectWidth = log2Up(cfg.intIssueWidth)
    val rs2EnableLsb = 2 * selectWidth
    val rs1EnableLsb = rs2EnableLsb + cfg.cdbWidth + 1
    val updated = CombInit(payload)
    updated(rs1EnableLsb + lane) := rs1Enabled
    updated(rs2EnableLsb + lane) := rs2Enabled
    updated
  }
}
