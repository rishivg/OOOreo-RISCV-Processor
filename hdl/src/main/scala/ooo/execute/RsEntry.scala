package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Compacting reservation slot with enabled storage, CDB wakeup, and fast bypass.
  * CDB wakeup accepts physical register zero; fast bypass excludes it.
  */
class RsEntry(cfg: CpuConfig, lay: RsEntryLayout, wkPreResolve: Boolean = false,
              csrPreResolve: Boolean = false) extends Component {
  require(!csrPreResolve || (wkPreResolve && cfg.zicsr && cfg.lsuWakeupPredecode))
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val W    = lay.width

  val io = new Bundle {
    // Use pre-resolved producer comparisons for the late shared INTM/LSU lanes,
    // so the late lane selector does not precede the physical-register comparator.
    val wk_intm_phy_br  = wkPreResolve generate (in Bits(cfg.prfIdx bits))
    val wk_intm_phy_div = wkPreResolve generate (in Bits(cfg.prfIdx bits))
    val wk_intm_phy_mul = wkPreResolve generate (in Bits(cfg.prfIdx bits))
    val wk_intm_sel_br  = wkPreResolve generate (in Bool())
    val wk_intm_sel_div = wkPreResolve generate (in Bool())
    // Compare each LSU producer tag before selecting its late valid signal.
    val wk_lsu_phy_c = if (wkPreResolve && cfg.lsuWakeupPredecode && cfg.zicsr) in Bits(cfg.prfIdx bits) else null
    val wk_lsu_sel_c = if (wkPreResolve && cfg.lsuWakeupPredecode && cfg.zicsr) in Bool() else null
    val wk_lsu_phy_a  = wkPreResolve generate (in Bits(cfg.prfIdx bits))
    val wk_lsu_phy_l  = wkPreResolve generate (in Bits(cfg.prfIdx bits))
    val wk_lsu_sel_a  = wkPreResolve generate (in Bool())
    val request_csr = csrPreResolve generate (out Bool())
    val request_load, request_atomic = csrPreResolve generate (out Bool())
    val m1_csr, m2_csr = csrPreResolve generate (out Bool())
    val m1_load, m2_load, m1_atomic, m2_atomic = csrPreResolve generate (out Bool())
    val valid       = out Bool()
    val request     = out Bool()
    // request = Mux(lsuValid, request_v1, request_v0). Issue arbiters select
    // between these cofactors after priority selection, keeping the late cache
    // hit out of the select/PRF/AGU path.
    val request_v0  = out Bool()
    val request_v1  = out Bool()
    // wkPreResolve: the (early) lane-L match bits behind rs{1,2}_en(L) = vLsu && m --
    // MemRs builds per-cofactor BYPASS fields from them (en(L)=0 for hit=0, =m for
    // hit=1) so the late D$-hit bit also leaves the PRF read's one-hot select.
    val m1_lsu      = out Bool()
    val m2_lsu      = out Bool()
    val grant       = in  Bool()
    val push_en     = in  Bool()
    val entry_in    = in  Bits(W bits)
    val entry_out   = out Bits(W bits)
    val entry       = out Bits(W bits)
    val clear       = in  Bool()
    val fast_bypass = in  Vec(BypassNet(cfg), NFB)
    val rs_bypass   = out (BypassT(cfg))
    val wakeup_cdb  = in  Vec(CdbRs(cfg), CDBW)
  }

  val PIDX = cfg.prfIdx
  def rs1Phy(b: Bits) = b(lay.rs1PhyLsb + PIDX - 1 downto lay.rs1PhyLsb)
  def rs2Phy(b: Bits) = b(lay.rs2PhyLsb + PIDX - 1 downto lay.rs2PhyLsb)

  val entry_valid = RegInit(False)
  val entry_reg   = Reg(Bits(W bits))   // no reset (gated flop, don't-care until valid)

  val next_valid = CombInit(entry_valid)
  when(io.push_en) { next_valid := True } .elsewhen(io.grant) { next_valid := False }
  when(io.clear) { entry_valid := False } otherwise { entry_valid := next_valid }

  val rawFast1 = (0 until NFB).map(i =>
    io.fast_bypass(i).valid && rs1Phy(entry_reg) === io.fast_bypass(i).rd_phy)
  val rawFast2 = (0 until NFB).map(i =>
    io.fast_bypass(i).valid && rs2Phy(entry_reg) === io.fast_bypass(i).rd_phy)
  // A valid ALU CDB result carries the preceding cycle's fast-bypass tag.
  // Include a simultaneous push so the cached match follows the new entry.
  val aluWake1 = if (cfg.aluWakeupPrecompute) (0 until NFB).map { i =>
    val hit = RegNext(Mux(io.push_en,
      io.fast_bypass(i).valid && rs1Phy(io.entry_in) === io.fast_bypass(i).rd_phy,
      rawFast1(i))) init(False)
    hit.setName(s"aluWakeMatch1_$i"); hit
  } else Seq.empty[Bool]
  val aluWake2 = if (cfg.aluWakeupPrecompute) (0 until NFB).map { i =>
    val hit = RegNext(Mux(io.push_en,
      io.fast_bypass(i).valid && rs2Phy(io.entry_in) === io.fast_bypass(i).rd_phy,
      rawFast2(i))) init(False)
    hit.setName(s"aluWakeMatch2_$i"); hit
  } else Seq.empty[Bool]
  val intmWake = if (cfg.intmWakeupPrecompute && wkPreResolve) {
    Seq(io.wk_intm_phy_div,io.wk_intm_phy_mul).zipWithIndex.map { case (tag,unit) =>
      Seq(rs1Phy _,rs2Phy _).zipWithIndex.map { case (physical,operand) =>
        val hit = RegNext(Mux(io.push_en,physical(io.entry_in) === tag,
          physical(entry_reg) === tag)) init(False)
        hit.setName(s"intmWakeMatch${operand + 1}_$unit"); hit
      }
    }
  } else Seq.empty[Seq[Bool]]
  def rawIntmMatch(phy: Bits, operand: Int): Bool = {
    val branch = phy === io.wk_intm_phy_br
    val div = if (cfg.intmWakeupPrecompute && wkPreResolve) intmWake(0)(operand - 1)
      else phy === io.wk_intm_phy_div
    val mul = if (cfg.intmWakeupPrecompute && wkPreResolve) intmWake(1)(operand - 1)
      else phy === io.wk_intm_phy_mul
    Mux(io.wk_intm_sel_br,branch,Mux(io.wk_intm_sel_div,div,mul))
  }
  def rawLsuMatch(phy: Bits): Bool = {
    val atomic = phy === io.wk_lsu_phy_a
    val load = phy === io.wk_lsu_phy_l
    val serial = if (cfg.lsuWakeupPredecode && cfg.zicsr)
      Mux(io.wk_lsu_sel_c, phy === io.wk_lsu_phy_c, atomic) else atomic
    Mux(io.wk_lsu_sel_a, serial, load)
  }
  def cdbMatch1(k: Int): Bool = io.wakeup_cdb(k).valid &&
    (if (cfg.aluWakeupPrecompute && k < NFB) aluWake1(k)
     else if (cfg.intmWakeupPrecompute && wkPreResolve && k == cfg.cdbIntmLane)
       rawIntmMatch(rs1Phy(entry_reg),1)
     else if (cfg.lsuWakeupPredecode && wkPreResolve && k == cfg.cdbLsuLane)
       rawLsuMatch(rs1Phy(entry_reg))
     else rs1Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)
  def cdbMatch2(k: Int): Bool = io.wakeup_cdb(k).valid &&
    (if (cfg.aluWakeupPrecompute && k < NFB) aluWake2(k)
     else if (cfg.intmWakeupPrecompute && wkPreResolve && k == cfg.cdbIntmLane)
       rawIntmMatch(rs2Phy(entry_reg),2)
     else if (cfg.lsuWakeupPredecode && wkPreResolve && k == cfg.cdbLsuLane)
       rawLsuMatch(rs2Phy(entry_reg))
     else rs2Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)
  val m1 = (0 until CDBW).map(cdbMatch1).reduce(_ || _)
  val m2 = (0 until CDBW).map(cdbMatch2).reduce(_ || _)

  val next_entry = Bits(W bits)
  when(io.push_en) {
    next_entry := io.entry_in
  } otherwise {
    next_entry := entry_reg
    when(m1) { next_entry(lay.rs1ValidLsb) := True }
    when(m2) { next_entry(lay.rs2ValidLsb) := True }
  }
  when(io.push_en || m1 || m2) { entry_reg := next_entry }

  val eo = CombInit(entry_reg)
  when(m1) { eo(lay.rs1ValidLsb) := True }
  when(m2) { eo(lay.rs2ValidLsb) := True }
  io.entry_out := eo

  // wkPreResolve compares (see io): guard-and-compare per source off the
  // registered phys, muxed on the early selects. === the guarded compare
  // against the muxed lane bus.
  def cmpIntm(phy: Bits, operand: Int): Bool =
    phy.asUInt =/= 0 && rawIntmMatch(phy,operand)
  def cmpLsu(phy: Bits): Bool = {
    if (cfg.lsuWakeupPredecode) phy =/= 0 && rawLsuMatch(phy)
    else {
      val mA = (io.wk_lsu_phy_a =/= 0) && (phy === io.wk_lsu_phy_a)
      val mL = (io.wk_lsu_phy_l =/= 0) && (phy === io.wk_lsu_phy_l)
      Mux(io.wk_lsu_sel_a, mA, mL)
    }
  }
  val rs1_en = Bits(CDBW + 1 bits)
  val rs2_en = Bits(CDBW + 1 bits)
  for (k <- 0 until CDBW) {
    if (cfg.aluWakeupPrecompute && k < NFB) {
      rs1_en(k) := cdbMatch1(k) && rs1Phy(entry_reg).asUInt =/= 0
      rs2_en(k) := cdbMatch2(k) && rs2Phy(entry_reg).asUInt =/= 0
    } else if (wkPreResolve && k == cfg.cdbIntmLane) {
      rs1_en(k) := io.wakeup_cdb(k).valid && cmpIntm(rs1Phy(entry_reg),1)
      rs2_en(k) := io.wakeup_cdb(k).valid && cmpIntm(rs2Phy(entry_reg),2)
    } else if (wkPreResolve && k == cfg.cdbLsuLane) {
      rs1_en(k) := io.wakeup_cdb(k).valid && cmpLsu(rs1Phy(entry_reg))
      rs2_en(k) := io.wakeup_cdb(k).valid && cmpLsu(rs2Phy(entry_reg))
    } else {
      rs1_en(k) := io.wakeup_cdb(k).valid && (io.wakeup_cdb(k).rd_phy =/= 0) && (rs1Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)
      rs2_en(k) := io.wakeup_cdb(k).valid && (io.wakeup_cdb(k).rd_phy =/= 0) && (rs2Phy(entry_reg) === io.wakeup_cdb(k).rd_phy)
    }
  }
  val fm1 = (0 until NFB).map(i => rawFast1(i) && io.fast_bypass(i).rd_phy =/= 0)
  val fm2 = (0 until NFB).map(i => rawFast2(i) && io.fast_bypass(i).rd_phy =/= 0)
  rs1_en(CDBW) := fm1.reduce(_ || _)
  rs2_en(CDBW) := fm2.reduce(_ || _)
  io.rs_bypass.rs1_bypass_sel := Mux(fm1(0), B(0, 1 bits), B(1, 1 bits))
  io.rs_bypass.rs2_bypass_sel := Mux(fm2(0), B(0, 1 bits), B(1, 1 bits))
  io.rs_bypass.rs1_bypass_en  := rs1_en
  io.rs_bypass.rs2_bypass_en  := rs2_en

  val src1_ready = entry_reg(lay.rs1ValidLsb) || rs1_en.orR
  val src2_ready = entry_reg(lay.rs2ValidLsb) || rs2_en.orR
  io.request := entry_valid && src1_ready && src2_ready

  // request cofactors (see io declaration). rs{1,2}_en(L) = v && m{1,2}Lsu with all
  // other terms registered/early, so substituting v=0/v=1 only drops/forces lane L.
  // With wkPreResolve the lane-L compare itself is also pre-resolved (the phy bus
  // muxes atomic-vs-load on a late select; see cmpLsu).
  val L = cfg.cdbLsuLane
  val m1Lsu = if (wkPreResolve) cmpLsu(rs1Phy(entry_reg))
              else (io.wakeup_cdb(L).rd_phy =/= 0) && (rs1Phy(entry_reg) === io.wakeup_cdb(L).rd_phy)
  val m2Lsu = if (wkPreResolve) cmpLsu(rs2Phy(entry_reg))
              else (io.wakeup_cdb(L).rd_phy =/= 0) && (rs2Phy(entry_reg) === io.wakeup_cdb(L).rd_phy)
  val src1_v0 = entry_reg(lay.rs1ValidLsb) || (0 until CDBW + 1).filter(_ != L).map(rs1_en(_)).reduce(_ || _)
  val src2_v0 = entry_reg(lay.rs2ValidLsb) || (0 until CDBW + 1).filter(_ != L).map(rs2_en(_)).reduce(_ || _)
  io.request_v0 := entry_valid && src1_v0 && src2_v0
  io.request_v1 := entry_valid && (src1_v0 || m1Lsu) && (src2_v0 || m2Lsu)
  io.m1_lsu := m1Lsu
  io.m2_lsu := m2Lsu
  if (csrPreResolve) {
    def producerMatch(phy: Bits, producer: Bits): Bool = phy =/= 0 && phy === producer
    io.m1_csr := producerMatch(rs1Phy(entry_reg), io.wk_lsu_phy_c)
    io.m2_csr := producerMatch(rs2Phy(entry_reg), io.wk_lsu_phy_c)
    io.m1_load := producerMatch(rs1Phy(entry_reg), io.wk_lsu_phy_l)
    io.m2_load := producerMatch(rs2Phy(entry_reg), io.wk_lsu_phy_l)
    io.m1_atomic := producerMatch(rs1Phy(entry_reg), io.wk_lsu_phy_a)
    io.m2_atomic := producerMatch(rs2Phy(entry_reg), io.wk_lsu_phy_a)
    io.request_csr := entry_valid && (src1_v0 || io.m1_csr) && (src2_v0 || io.m2_csr)
    io.request_load := entry_valid && (src1_v0 || io.m1_load) && (src2_v0 || io.m2_load)
    io.request_atomic := entry_valid && (src1_v0 || io.m1_atomic) && (src2_v0 || io.m2_atomic)
  }
  io.valid   := entry_valid
  io.entry   := entry_reg
}
