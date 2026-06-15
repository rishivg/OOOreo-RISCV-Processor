package ooo.frontend

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/if1_stage.sv` -- the IF1 fetch stage: block-PC
  * generation, the I-cache request/response handshake (prv/nxt valid-ready), and a
  * one-deep output hold (temp_icache_rdata) so a stalled consumer keeps the fetched
  * block. Instantiates the SpinalHDL Icache (icache_spinal).
  *
  * Named if1_stage_spinal; sim/swap_shims/if1_stage.sv carries the cacheline_itf.
  * master + packed-2D insts and surfaces the perf-tapped icache_unresponsive.
  */
class If1Stage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("if1_stage_spinal")
  val IFW = cfg.ifWidth        // 4
  val LZ  = log2Up(IFW * 4)    // block byte-offset bits (4 for IF_BLK_SIZE=16)

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val flush     = in Bool()
    val prv_valid = in  Bool(); val prv_ready = out Bool()
    val nxt_valid = out Bool(); val nxt_ready = in Bool()
    val pc_next   = in  Bits (32 bits)
    val pc        = out Bits (32 bits)
    val insts     = out Bits (IFW * 32 bits)
    // cacheline_itf.master icache_itf
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

    val icacheResp  = Bool()
    val icacheRdata = Bits(IFW * 32 bits)
    val nxtValid    = icacheValid && !(icachePending && !icacheResp)
    val prvReady    = !icacheValid || (nxtValid && io.nxt_ready) || io.flush
    val icacheUnresp = icachePending && !icacheResp

    val blkPcNext = io.pc_next(31 downto LZ) ## B(0, LZ bits)

    when(prvReady && io.prv_valid) { pcReg := io.pc_next }
    when(prvReady && io.prv_valid) { icachePending := True }.elsewhen(icacheResp) { icachePending := False }
    when(prvReady) { icacheValid := io.prv_valid }
    when(icacheResp) { tempRdata := icacheRdata }

    // I-cache
    val ic = new Icache(cfg)
    ic.io.clk := io.clk; ic.io.rst := io.rst
    ic.io.ufp_addr := blkPcNext
    ic.io.ufp_read := prvReady && io.prv_valid
    ic.io.kill := io.flush
    icacheRdata := ic.io.ufp_rdata
    icacheResp  := ic.io.ufp_resp
    io.icache_addr  := ic.io.dfp_addr;  io.icache_read := ic.io.dfp_read; io.icache_write := ic.io.dfp_write
    io.icache_wdata := ic.io.dfp_wdata
    ic.io.dfp_ready := io.icache_ready; ic.io.dfp_raddr := io.icache_raddr
    ic.io.dfp_rdata := io.icache_rdata; ic.io.dfp_rvalid := io.icache_rvalid

    io.prv_ready := prvReady
    io.nxt_valid := nxtValid
    io.pc        := pcReg
    io.insts     := Mux(icacheResp, icacheRdata, tempRdata)
    io.dbg_icache_unresponsive := icacheUnresp
  }
}
