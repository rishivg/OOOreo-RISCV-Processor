package ooo.common

import spinal.core._
import ooo.CpuConfig

/** Transfer 256-bit cache lines as four 64-bit external-memory beats. */
class CacheAdapter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("cache_adapter_spinal")
  def W_IDLE = B"2'b00"; def ISS1 = B"2'b01"; def ISS2 = B"2'b10"; def ISS3 = B"2'b11"
  def R_IDLE = B"2'b00"; def COL1 = B"2'b01"; def COL2 = B"2'b10"; def COL3 = B"2'b11"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val idle = if (cfg.lowPower) out Bool() else null
    val ufp_addr = in Bits (32 bits); val ufp_read = in Bool(); val ufp_write = in Bool(); val ufp_wdata = in Bits (256 bits)
    val ufp_ready = out Bool(); val ufp_rdata = out Bits (256 bits); val ufp_raddr = out Bits (32 bits); val ufp_rvalid = out Bool()
    val dfp_addr = out Bits (32 bits); val dfp_read = out Bool(); val dfp_write = out Bool(); val dfp_wdata = out Bits (64 bits)
    val dfp_ready = in Bool(); val dfp_raddr = in Bits (32 bits); val dfp_rdata = in Bits (64 bits); val dfp_rvalid = in Bool()
    val write_beat = if (cfg.bmemBeatSpeculation) out Bits(2 bits) else null
    val ufp_wdata_beat = if (cfg.bmemBeatSpeculation) in Bits(64 bits) else null
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val wState = RegInit(W_IDLE)
    val wn = cloneOf(wState); wn := wState
    if (cfg.bmemBeatSpeculation) io.write_beat := wState
    io.dfp_wdata := (if (cfg.bmemBeatSpeculation) io.ufp_wdata_beat
      else if (cfg.bmemWriteDataBypass) io.ufp_wdata(0, 64 bits) else B(0, 64 bits))
    io.ufp_ready := False
    switch(wState) {
      is(W_IDLE) {
        io.ufp_ready := io.dfp_ready
        when(io.ufp_write) {
          io.ufp_ready := False
          if (!cfg.bmemWriteDataBypass) io.dfp_wdata := io.ufp_wdata(0, 64 bits)
          when(io.dfp_ready) { wn := ISS1 }
        }
      }
      is(ISS1) {
        if (!cfg.bmemBeatSpeculation) io.dfp_wdata := io.ufp_wdata(64, 64 bits)
        when(io.dfp_ready) { wn := ISS2 }
      }
      is(ISS2) {
        if (!cfg.bmemBeatSpeculation) io.dfp_wdata := io.ufp_wdata(128, 64 bits)
        when(io.dfp_ready) { wn := ISS3 }
      }
      is(ISS3) {
        if (!cfg.bmemBeatSpeculation) io.dfp_wdata := io.ufp_wdata(192, 64 bits)
        when(io.dfp_ready) { io.ufp_ready := True; wn := W_IDLE }
      }
    }
    wState := wn

    val rState = RegInit(R_IDLE)
    val rn = cloneOf(rState); rn := rState
    val cached = Vec(Reg(Bits(64 bits)), 3)
    val cacheRd = Vec(Bool(), 3); for (i <- 0 until 3) cacheRd(i) := False
    io.ufp_rdata := B(0, 256 bits); io.ufp_rvalid := False
    switch(rState) {
      // Only the first valid beat starts a burst. The remaining three beats
      // follow consecutively under the existing bmem contract.
      is(R_IDLE) { when(io.dfp_rvalid) { rn := COL1; cacheRd(0) := True } }
      is(COL1)   { rn := COL2; cacheRd(1) := True }
      is(COL2)   { rn := COL3; cacheRd(2) := True }
      is(COL3)   { rn := R_IDLE; io.ufp_rvalid := True; io.ufp_rdata := io.dfp_rdata ## cached(2) ## cached(1) ## cached(0) }
    }
    rState := rn
    val readCreditsFull = Bool()
    if (!cfg.lowPower) readCreditsFull := False
    if (cfg.lowPower) {
      // I/D misses and killed speculative fetches can overlap. Account for
      // every accepted burst, rather than treating the adapter as one request.
      val pending = RegInit(U(0,log2Up(cfg.maxReadBursts + 1) bits))
      val full = pending === cfg.maxReadBursts
      readCreditsFull := full
      val accepted = io.dfp_read && io.dfp_ready
      when(accepted =/= io.ufp_rvalid) {
        when(accepted) { pending := pending + 1 }.otherwise { pending := pending - 1 }
      }
      when(full && io.ufp_read) { io.ufp_ready := False }
      io.idle := pending === 0 && wState === W_IDLE && rState === R_IDLE && !io.ufp_read && !io.ufp_write
    }
    for (i <- 0 until 3) when(cacheRd(i)) { cached(i) := io.dfp_rdata }

    io.dfp_addr := io.ufp_addr
    // Backpressure must reach the physical request pin as well as its ready.
    io.dfp_read := io.ufp_read && !readCreditsFull
    io.dfp_write := io.ufp_write; io.ufp_raddr := io.dfp_raddr
  }
}
