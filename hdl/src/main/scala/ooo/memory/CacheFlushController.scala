package ooo.memory

import spinal.core._

/** Walk every D$ way, writing dirty lines back before invalidating their tags.
  * Request is level-held; done stays high until the requester releases it.
  * The caller starts only after normal cache traffic and committed stores drain.
  */
class CacheFlushController(setWidth: Int, wayWidth: Int) extends Component {
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val request = in Bool(); val can_start = in Bool()
    val dirty = in Bool(); val write_ready = in Bool()
    val busy = out Bool(); val done = out Bool()
    val set = out UInt(setWidth bits); val way = out UInt(wayWidth bits)
    val read_row = out Bool(); val writeback = out Bool(); val invalidate = out Bool()
  }
  val domain = ClockDomain(io.clk,io.rst,config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC))
  new ClockingArea(domain) {
    val idle :: read :: check :: write :: clear :: next :: done :: Nil = List.tabulate(7)(i => U(i,3 bits))
    val state = RegInit(idle)
    val set = RegInit(U(0,setWidth bits)); val way = RegInit(U(0,wayWidth bits))
    io.set := set; io.way := way
    io.busy := state =/= idle; io.done := state === done
    io.read_row := state === read; io.writeback := state === write
    io.invalidate := state === clear
    switch(state) {
      is(idle) { when(io.request && io.can_start) { set := 0; way := 0; state := read } }
      is(read) { state := check }
      is(check) { state := Mux(io.dirty,write,clear) }
      is(write) { when(io.write_ready) { state := clear } }
      is(clear) { state := next }
      is(next) {
        when(way.andR) {
          way := 0
          when(set.andR) { state := done }.otherwise { set := set + 1; state := read }
        }.otherwise { way := way + 1; state := read }
      }
      is(done) { when(!io.request) { state := idle } }
    }
  }
}
