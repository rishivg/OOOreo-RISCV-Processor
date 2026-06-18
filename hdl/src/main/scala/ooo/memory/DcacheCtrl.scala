package ooo.memory

import spinal.core._

/** Port-compatible SpinalHDL twin of `hdl/memory/dcache/dcache_ctrl.sv`.
  *
  * The D-cache miss FSM (PASS_THRU -> WB/ALLOCATE -> ALLOCATE_STALL). All-scalar
  * ports, clocked. Drops into dcache.sv by-name. `write_hit_rec` is a registered
  * output read internally.
  *
  * dcache_ctrl_fsm_state_t: PASS_THRU 00 / ALLOCATE 01 / ALLOCATE_STALL 10 / WB 11.
  */
class DcacheCtrl extends Component {
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
