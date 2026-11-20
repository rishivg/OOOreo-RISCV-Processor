package ooo.common

import spinal.core._
import ooo.CpuConfig

/** Share the memory adapter between caches; prioritize data and buffer stalled writes. */
class BmemArbiter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("bmem_arbiter_spinal")
  def PASS_THRU = False; def WAIT_WRITE = True

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val icache_addr = in Bits (32 bits); val icache_read = in Bool(); val icache_write = in Bool(); val icache_wdata = in Bits (256 bits)
    val icache_ready = out Bool(); val icache_rdata = out Bits (256 bits); val icache_raddr = out Bits (32 bits); val icache_rvalid = out Bool()
    val dcache_addr = in Bits (32 bits); val dcache_read = in Bool(); val dcache_write = in Bool(); val dcache_wdata = in Bits (256 bits)
    val dcache_ready = out Bool(); val dcache_rdata = out Bits (256 bits); val dcache_raddr = out Bits (32 bits); val dcache_rvalid = out Bool()
    val adapter_addr = out Bits (32 bits); val adapter_read = out Bool(); val adapter_write = out Bool(); val adapter_wdata = out Bits (256 bits)
    val adapter_ready = in Bool(); val adapter_raddr = in Bits (32 bits); val adapter_rdata = in Bits (256 bits); val adapter_rvalid = in Bool()
    val write_beat = if (cfg.bmemBeatSpeculation) in Bits(2 bits) else null
    val dcache_wdata_beat = if (cfg.bmemBeatSpeculation) in Bits(64 bits) else null
    val adapter_wdata_beat = if (cfg.bmemBeatSpeculation) out Bits(64 bits) else null
    val dcache_read_addr = if (cfg.bmemEarlyAddress) in Bits(32 bits) else null
    val dcache_write_addr = if (cfg.bmemEarlyAddress) in Bits(32 bits) else null
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val addrBuf = RegInit(B(0, 32 bits)); val dataBuf = RegInit(B(0, 256 bits))
    when(io.dcache_write) { addrBuf := io.dcache_addr; dataBuf := io.dcache_wdata }

    val state = RegInit(PASS_THRU)
    val next = cloneOf(state); next := state

    io.icache_ready := False; io.dcache_ready := False
    io.adapter_read := False; io.adapter_write := False
    // Idle address follows I-cache; only asserted requests consume it.
    if (cfg.bmemEarlyAddress) {
      val select = Vec(state, !state && io.dcache_write,
        !state && !io.dcache_write && io.dcache_read,
        !state && !io.dcache_write && !io.dcache_read).asBits
      select.addAttribute("keep")
      io.adapter_addr := ooo.OhSel(select,
        Seq(addrBuf, io.dcache_write_addr, io.dcache_read_addr, io.icache_addr))
    } else io.adapter_addr := Mux(state,addrBuf,
      Mux(io.dcache_read || io.dcache_write,io.dcache_addr,io.icache_addr))
    // Payload is observed only on writes. Keep late request qualifiers off it.
    io.adapter_wdata := (if (cfg.bmemWriteDataBypass) Mux(state, dataBuf, io.dcache_wdata) else B(0, 256 bits))
    if (cfg.bmemBeatSpeculation)
      io.adapter_wdata_beat := Mux(state,
        dataBuf.subdivideIn(64 bits)(io.write_beat.asUInt), io.dcache_wdata_beat)
    switch(state) {
      is(PASS_THRU) {
        when(io.dcache_read || io.dcache_write) {
          io.adapter_read := io.dcache_read; io.adapter_write := io.dcache_write
          if (!cfg.bmemWriteDataBypass) io.adapter_wdata := io.dcache_wdata
          when(io.adapter_ready) { io.dcache_ready := True }
        }.elsewhen(io.icache_read) {
          io.adapter_read := True
          if (!cfg.bmemWriteDataBypass) io.adapter_wdata := io.icache_wdata
          when(io.adapter_ready) { io.icache_ready := True }
        }
      }
      is(WAIT_WRITE) {
        io.adapter_write := True
        if (!cfg.bmemWriteDataBypass) io.adapter_wdata := dataBuf
        when(io.adapter_ready) { io.dcache_ready := True }
      }
    }
    switch(state) {
      is(PASS_THRU)  { when(io.dcache_write)  { next := WAIT_WRITE } }
      is(WAIT_WRITE) { when(io.adapter_ready) { next := PASS_THRU } }
    }
    state := next

    io.icache_rdata := io.adapter_rdata; io.dcache_rdata := io.adapter_rdata
    io.icache_rvalid := io.adapter_rvalid; io.dcache_rvalid := io.adapter_rvalid
    io.icache_raddr := io.adapter_raddr; io.dcache_raddr := io.adapter_raddr
  }
}
