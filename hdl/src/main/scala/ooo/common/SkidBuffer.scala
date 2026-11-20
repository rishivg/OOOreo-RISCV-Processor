package ooo.common

import spinal.core._

/** Valid/ready skid buffer with registered handshake signals and configurable payload width. */
class SkidBuffer(width: Int) extends Component {
  setDefinitionName(s"skid_buffer_spinal_${width}")
  def EMPTY = B"3'b001"; def BUSY = B"3'b010"; def FULL = B"3'b100"
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val prv_valid = in Bool(); val prv_ready = out Bool()
    val nxt_valid = out Bool(); val nxt_ready = in Bool()
    val prv_data = in Bits(width bits); val nxt_data = out Bits(width bits)
  }
  noIoPrefix()
  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))
  new ClockingArea(domain) {
    val state = RegInit(EMPTY)
    val prvReadyR = RegInit(False); val nxtValidR = RegInit(False)
    io.prv_ready := prvReadyR; io.nxt_valid := nxtValidR
    val accept = io.prv_valid && prvReadyR
    val transmit = nxtValidR && io.nxt_ready

    val stateNxt = cloneOf(state)
    switch(state) {
      is(EMPTY) { stateNxt := Mux(accept, BUSY, EMPTY) }
      is(BUSY)  { stateNxt := BUSY; when(accept && !transmit) { stateNxt := FULL }.elsewhen(!accept && transmit) { stateNxt := EMPTY } }
      is(FULL)  { stateNxt := Mux(transmit, BUSY, FULL) }
      default   { stateNxt := EMPTY }
    }
    state := stateNxt
    prvReadyR := stateNxt =/= FULL
    nxtValidR := stateNxt =/= EMPTY

    val buffer = Reg(Bits(width bits)); val nxtData = Reg(Bits(width bits))
    io.nxt_data := nxtData
    val bufWe  = (state === BUSY) && accept && !transmit
    val dataWe = ((state === EMPTY) && accept && !transmit) ||
                 ((state === BUSY) && accept && transmit) ||
                 ((state === FULL) && !accept && transmit)
    when(dataWe) { nxtData := Mux(state === FULL, buffer, io.prv_data) }
    when(bufWe)  { buffer := io.prv_data }
  }
}
