package ooo.memory

import spinal.core._

/** Data-cache hit, miss, refill, and writeback control. */
class DcacheCtrl(cfg: ooo.CpuConfig = ooo.CpuConfig()) extends Component {
  setDefinitionName("dcache_ctrl")

  def PASS_THRU      = B"2'b00"
  def ALLOCATE       = B"2'b01"
  def ALLOCATE_STALL = B"2'b10"
  def WB             = B"2'b11"

  val io = new Bundle {
    val clk           = in  Bool()
    val rst           = in  Bool()
    val hit           = in  Bool()
    val dirty         = in  Bool()
    val rmask         = in  Bits (4 bits)
    val wmask         = in  Bits (4 bits)
    val idle = if (cfg.zicsr || cfg.mmio || cfg.lowPower) out Bool() else null
    val stall         = out Bool()
    val allocate_done = out Bool()
    val write_hit     = out Bool()
    val write_hit_rec = out Bool()
    val dfp_addr      = in  Bits (32 bits)
    val dfp_read      = out Bool()
    val dfp_write     = out Bool()
    val dfp_ready     = in  Bool()
    val dfp_raddr     = in  Bits (32 bits)
    val dfp_rvalid    = in  Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(
    clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  new ClockingArea(domain) {
    val state   = RegInit(PASS_THRU)
    val whRec   = RegInit(False)                 // write_hit_rec
    io.write_hit_rec := whRec

    val anyReq = io.rmask.orR || io.wmask.orR
    if (cfg.zicsr || cfg.mmio || cfg.lowPower) io.idle := state === PASS_THRU && !whRec && !anyReq

    val next_state = cloneOf(state); next_state := state
    io.allocate_done := False
    io.write_hit     := False
    io.dfp_read      := False
    io.dfp_write     := False

    switch(state) {
      is(PASS_THRU) {
        when(anyReq && !whRec) {
          when(!io.hit) {
            when(io.dirty) {
              io.dfp_write := True
              when(io.dfp_ready) { next_state := WB }
            } otherwise {
              io.dfp_read := True
              when(io.dfp_ready) { next_state := ALLOCATE }
            }
          }
          io.write_hit := io.wmask.orR && io.hit
        }
      }
      is(ALLOCATE) {
        when(io.dfp_rvalid && io.dfp_addr === io.dfp_raddr) {
          next_state := ALLOCATE_STALL
          io.allocate_done := True
        }
      }
      is(ALLOCATE_STALL) {
        next_state := PASS_THRU
      }
      is(WB) {
        io.dfp_read := True
        when(io.dfp_ready) { next_state := ALLOCATE }
      }
    }
    state := next_state

    io.stall := anyReq && (whRec || !io.hit)

    // write_hit_rec: set the cycle after a write-hit, clears itself next cycle
    when(whRec)            { whRec := False }
    .elsewhen(io.write_hit){ whRec := True }
  }
}
