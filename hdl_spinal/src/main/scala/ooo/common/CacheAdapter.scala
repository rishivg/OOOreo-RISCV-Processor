package ooo.common

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/common/cache_adapter.sv` -- the 256b cacheline <-> 64b
  * bmem width adapter. A write streams the 256b line as 4x64b beats (W_Idle ->
  * Issue_1..3); a read collects 4x64b beats into the 256b line (R_Idle ->
  * Collect_1..3). Named cache_adapter_spinal; sim/swap_shims/cache_adapter.sv
  * carries cacheline_itf.slave ufp + the scalar bmem dfp.
  */
class CacheAdapter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("cache_adapter_spinal")
  def W_IDLE = B"2'b00"; def ISS1 = B"2'b01"; def ISS2 = B"2'b10"; def ISS3 = B"2'b11"
  def R_IDLE = B"2'b00"; def COL1 = B"2'b01"; def COL2 = B"2'b10"; def COL3 = B"2'b11"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // cacheline_itf.slave ufp
    val ufp_addr = in Bits (32 bits); val ufp_read = in Bool(); val ufp_write = in Bool(); val ufp_wdata = in Bits (256 bits)
    val ufp_ready = out Bool(); val ufp_rdata = out Bits (256 bits); val ufp_raddr = out Bits (32 bits); val ufp_rvalid = out Bool()
    // bmem dfp
    val dfp_addr = out Bits (32 bits); val dfp_read = out Bool(); val dfp_write = out Bool(); val dfp_wdata = out Bits (64 bits)
    val dfp_ready = in Bool(); val dfp_raddr = in Bits (32 bits); val dfp_rdata = in Bits (64 bits); val dfp_rvalid = in Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val wState = RegInit(W_IDLE)
    val wn = cloneOf(wState); wn := wState
    io.dfp_wdata := B(0, 64 bits); io.ufp_ready := False
    switch(wState) {
      is(W_IDLE) {
        io.ufp_ready := io.dfp_ready
        when(io.ufp_write) {
          io.ufp_ready := False; io.dfp_wdata := io.ufp_wdata(0, 64 bits)
          when(io.dfp_ready) { wn := ISS1 }
        }
      }
      is(ISS1) { io.dfp_wdata := io.ufp_wdata(64, 64 bits);  when(io.dfp_ready) { wn := ISS2 } }
      is(ISS2) { io.dfp_wdata := io.ufp_wdata(128, 64 bits); when(io.dfp_ready) { wn := ISS3 } }
      is(ISS3) { io.dfp_wdata := io.ufp_wdata(192, 64 bits); when(io.dfp_ready) { io.ufp_ready := True; wn := W_IDLE } }
    }
    wState := wn

    val rState = RegInit(R_IDLE)
    val rn = cloneOf(rState); rn := rState
    val cached = Vec(Reg(Bits(64 bits)), 3)
    val cacheRd = Vec(Bool(), 3); for (i <- 0 until 3) cacheRd(i) := False
    io.ufp_rdata := B(0, 256 bits); io.ufp_rvalid := False
    switch(rState) {
      is(R_IDLE) { when(io.dfp_rvalid) { rn := COL1 }; cacheRd(0) := True }
      is(COL1)   { rn := COL2; cacheRd(1) := True }
      is(COL2)   { rn := COL3; cacheRd(2) := True }
      is(COL3)   { rn := R_IDLE; io.ufp_rvalid := True; io.ufp_rdata := io.dfp_rdata ## cached(2) ## cached(1) ## cached(0) }
    }
    rState := rn
    for (i <- 0 until 3) when(cacheRd(i)) { cached(i) := io.dfp_rdata }

    io.dfp_addr := io.ufp_addr; io.dfp_read := io.ufp_read; io.dfp_write := io.ufp_write; io.ufp_raddr := io.dfp_raddr
  }
}
