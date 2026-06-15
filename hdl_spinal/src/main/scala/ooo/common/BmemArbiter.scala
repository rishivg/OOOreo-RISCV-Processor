package ooo.common

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/common/bmem_arbiter.sv` -- arbitrates the I-cache and
  * D-cache cacheline ports onto the single bmem adapter, prioritising the D-cache
  * (and parking a write via a buffered WAIT_WRITE state). Named bmem_arbiter_spinal;
  * sim/swap_shims/bmem_arbiter.sv carries the three cacheline interfaces.
  */
class BmemArbiter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("bmem_arbiter_spinal")
  def PASS_THRU = False; def WAIT_WRITE = True

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // cacheline_itf.slave icache
    val icache_addr = in Bits (32 bits); val icache_read = in Bool(); val icache_write = in Bool(); val icache_wdata = in Bits (256 bits)
    val icache_ready = out Bool(); val icache_rdata = out Bits (256 bits); val icache_raddr = out Bits (32 bits); val icache_rvalid = out Bool()
    // cacheline_itf.slave dcache
    val dcache_addr = in Bits (32 bits); val dcache_read = in Bool(); val dcache_write = in Bool(); val dcache_wdata = in Bits (256 bits)
    val dcache_ready = out Bool(); val dcache_rdata = out Bits (256 bits); val dcache_raddr = out Bits (32 bits); val dcache_rvalid = out Bool()
    // cacheline_itf.master adapter
    val adapter_addr = out Bits (32 bits); val adapter_read = out Bool(); val adapter_write = out Bool(); val adapter_wdata = out Bits (256 bits)
    val adapter_ready = in Bool(); val adapter_raddr = in Bits (32 bits); val adapter_rdata = in Bits (256 bits); val adapter_rvalid = in Bool()
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
    io.adapter_addr := B(0, 32 bits); io.adapter_wdata := B(0, 256 bits)
    switch(state) {
      is(PASS_THRU) {
        when(io.dcache_read || io.dcache_write) {
          io.adapter_read := io.dcache_read; io.adapter_write := io.dcache_write
          io.adapter_addr := io.dcache_addr; io.adapter_wdata := io.dcache_wdata
          when(io.adapter_ready) { io.dcache_ready := True }
        }.elsewhen(io.icache_read) {
          io.adapter_read := True; io.adapter_addr := io.icache_addr; io.adapter_wdata := io.icache_wdata
          when(io.adapter_ready) { io.icache_ready := True }
        }
      }
      is(WAIT_WRITE) {
        io.adapter_write := True; io.adapter_addr := addrBuf; io.adapter_wdata := dataBuf
        when(io.adapter_ready) { io.dcache_ready := True }
      }
    }
    switch(state) {
      is(PASS_THRU)  { when(io.dcache_write)  { next := WAIT_WRITE } }
      is(WAIT_WRITE) { when(io.adapter_ready) { next := PASS_THRU } }
    }
    state := next

    // direct connect of read responses to both masters
    io.icache_rdata := io.adapter_rdata; io.dcache_rdata := io.adapter_rdata
    io.icache_rvalid := io.adapter_rvalid; io.dcache_rvalid := io.adapter_rvalid
    io.icache_raddr := io.adapter_raddr; io.dcache_raddr := io.adapter_raddr
  }
}
