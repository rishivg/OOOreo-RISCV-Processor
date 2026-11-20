package ooo.frontend

import spinal.core._
import ooo.{CpuConfig, OhSel}

/** Fetch-stage state and late instruction-cache way selection. */
class If1Stage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("if1_stage_spinal")
  val IFW = cfg.ifWidth
  val LZ  = log2Up(IFW * 4)    // block byte-offset bits (4 for IF_BLK_SIZE=16)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val invalidate = if (cfg.zicsr) in Bool() else null
    val flush     = in Bool()
    val prv_valid = in  Bool(); val prv_ready = out Bool()
    val nxt_valid = out Bool(); val nxt_ready = in Bool()
    val pc_next   = in  Bits (32 bits)
    val set_candidates = if (cfg.frontendValidSpeculation) in Bits(cfg.predCandN * cfg.iSetIdx bits) else null
    val set_select = if (cfg.frontendValidSpeculation) in Bits(cfg.predCandN bits) else null
    val initialized_bitmap = if (cfg.frontendLaneValidity) out Bits((1 << cfg.iSetIdx) bits) else null
    val request_initialized = if (cfg.frontendLaneValidity) in Bool() else null
    val pc        = out Bits (32 bits)
    val insts     = out Bits (IFW * 32 bits)
    val inst_arms = if (cfg.frontendPayloadSpeculation) out Bits((cfg.iFetchWays + 1) * IFW * 32 bits) else null
    val data_arm_select = if (cfg.frontendPayloadSpeculation) out Bits(cfg.iFetchWays + 1 bits) else null
    val flags     = out Bits (2 * IFW * 3 bits)   // per-lane {ret,call,ctrl}, decoded per way in
                                                  // Keep per-way predecode available before the late tag-match/way selection.
    val pd_arms   = out Bits ((cfg.iFetchWays + 1) * 2 * IFW * 4 bits)
    val comp_arms = out Bits ((cfg.iFetchWays + 1) * 2 * IFW bits)
    val arm_sel   = out Bits (cfg.iFetchWays + 1 bits)
    val icache_addr   = out Bits (32 bits)
    val icache_read   = out Bool()
    val icache_write  = out Bool()
    val icache_wdata  = out Bits (256 bits)
    val icache_ready  = in  Bool()
    val icache_raddr  = in  Bits (32 bits)
    val icache_rdata  = in  Bits (256 bits)
    val icache_rvalid = in  Bool()
    // perf tap
    val dbg_icache_unresponsive = out Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val icacheValid   = RegInit(False)
    val icachePending = RegInit(False)
    val pcReg         = RegInit(B(0, 32 bits))
    val tempRdata     = Reg(Bits(IFW * 32 bits))
    val tempPd        = Reg(Bits(2 * IFW * 4 bits))   // held predecode row (mirrors tempRdata)
    val tempComp      = Reg(Bits(2 * IFW bits))        // held comp bits (mirrors tempPd)
    val tempFlags     = Reg(Bits(2 * IFW * 3 bits))    // held per-lane flags (mirrors tempPd)

    val icacheResp  = Bool()
    val icacheRdata = Bits(IFW * 32 bits)
    val icachePdWays = Bits(cfg.iFetchWays * 2 * IFW * 4 bits)
    val icachePdSel  = Bits(cfg.iFetchWays bits)
    val icacheCompWays = Bits(cfg.iFetchWays * 2 * IFW bits)
    val icacheFlagWays = Bits(cfg.iFetchWays * 2 * IFW * 3 bits)
    val nxtValid    = icacheValid && !(icachePending && !icacheResp)
    val prvReady    = !icacheValid || (nxtValid && io.nxt_ready) || io.flush
    val icacheUnresp = icachePending && !icacheResp

    val blkPcNext = io.pc_next(31 downto LZ) ## B(0, LZ bits)

    when(prvReady && io.prv_valid) { pcReg := io.pc_next }
    when(prvReady && io.prv_valid) { icachePending := True }.elsewhen(icacheResp) { icachePending := False }
    when(prvReady) { icacheValid := io.prv_valid }
    // Select the registered hold arm or matching way with a one-hot mux after per-way work completes.
    val pdSel  = icachePdSel ## !(icachePdSel.orR)   // bit 0 = hold, bits 1.. = ways
    val pdData = tempPd +: icachePdWays.subdivideIn(cfg.iFetchWays slices)
    val compData = tempComp +: icacheCompWays.subdivideIn(cfg.iFetchWays slices)
    val pdOut  = OhSel(pdSel, pdData)
    val compOut = OhSel(pdSel, compData)
    // taps: same arms, same one-hot, exported unreduced (see the io note).
    io.pd_arms   := Vec(pdData).asBits
    io.comp_arms := Vec(compData).asBits
    io.arm_sel   := pdSel
    val flagsOut = OhSel(pdSel, tempFlags +: icacheFlagWays.subdivideIn(cfg.iFetchWays slices))

    when(icacheResp) { tempRdata := icacheRdata; tempPd := pdOut; tempComp := compOut; tempFlags := flagsOut }

    // I-cache
    val ic = new Icache(cfg)
    ic.io.clk := io.clk; ic.io.rst := io.rst
    ic.io.ufp_addr := blkPcNext
    if (cfg.frontendValidSpeculation) {
      ic.io.set_candidates:=io.set_candidates;ic.io.set_select:=io.set_select
    }
    if (cfg.frontendLaneValidity) {
      io.initialized_bitmap:=ic.io.initialized_bitmap
      ic.io.request_initialized:=io.request_initialized
    }
    ic.io.ufp_read := prvReady && io.prv_valid
    // early csb superset: prvReady without the live-resp term (see the Icache port note)
    ic.io.ufp_read_early := io.prv_valid && (!icacheValid || io.nxt_ready || io.flush)
    ic.io.kill := io.flush
    if (cfg.zicsr) {
      ic.io.invalidate := io.invalidate
      when(io.invalidate) { ic.io.kill := True; icacheValid := False; icachePending := False }
    }
    icacheRdata := ic.io.ufp_rdata
    icachePdWays := ic.io.ufp_pd_ways
    icachePdSel  := ic.io.ufp_pd_sel
    icacheCompWays := ic.io.ufp_comp_ways
    icacheFlagWays := ic.io.ufp_flag_ways
    icacheResp  := ic.io.ufp_resp
    io.icache_addr  := ic.io.dfp_addr;  io.icache_read := ic.io.dfp_read; io.icache_write := ic.io.dfp_write
    io.icache_wdata := ic.io.dfp_wdata
    ic.io.dfp_ready := io.icache_ready; ic.io.dfp_raddr := io.icache_raddr
    ic.io.dfp_rdata := io.icache_rdata; ic.io.dfp_rvalid := io.icache_rvalid

    io.prv_ready := prvReady
    io.nxt_valid := nxtValid
    io.pc        := pcReg
    io.insts     := Mux(icacheResp, icacheRdata, tempRdata)
    if (cfg.frontendPayloadSpeculation) {
      io.inst_arms := ic.io.ufp_data_ways ## tempRdata
      io.data_arm_select := (ic.io.ufp_data_select & B(cfg.iFetchWays bits,default -> icacheResp)) ## !icacheResp
    }
    io.flags     := flagsOut
    io.dbg_icache_unresponsive := icacheUnresp
  }
}
