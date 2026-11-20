package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** One outstanding 32-bit peripheral transaction. Both reads and writes require
  * a response. Address is word-aligned, strobes identify little-endian lanes.
  * The platform must hold response data/error stable for its valid cycle.
  */
case class MmioMaster() extends Bundle {
  val req_valid = out Bool(); val req_ready = in Bool()
  val addr = out Bits(32 bits); val wdata = out Bits(32 bits)
  val rmask = out Bits(4 bits); val wmask = out Bits(4 bits)
  val resp_valid = in Bool(); val resp_rdata = in Bits(32 bits); val resp_error = in Bool()
}

object DeviceRegion {
  def external(addr: Bits, cfg: CpuConfig): Bool =
    (addr & B(BigInt(cfg.mmioMask),32 bits)) === B(BigInt(cfg.mmioBase),32 bits)
  def ordered(addr: Bits, cfg: CpuConfig): Bool =
    external(addr,cfg) || (addr(31 downto 16) === B(cfg.clintHi16,16 bits))
  def orderedSplit(low: Bits, hi0: Bits, hi1: Bits, carry: Bool, cfg: CpuConfig): Bool =
    Mux(carry, ordered(hi1 ## low,cfg), ordered(hi0 ## low,cfg))
}

class MmioBridge(cfg: CpuConfig) extends Component {
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val flush = in Bool()
    val start = in Bool(); val accepted = out Bool()
    val addr = in Bits(32 bits); val wdata = in Bits(32 bits)
    val rmask = in Bits(4 bits); val wmask = in Bits(4 bits); val rob_id = in Bits(cfg.robIdx bits)
    val bus = MmioMaster()
    val busy = out Bool(); val done = out Bool(); val error = out Bool()
    val result = out Bits(32 bits); val done_addr = out Bits(32 bits)
    val done_rob_id = out Bits(cfg.robIdx bits); val is_write = out Bool()
  }
  val domain = ClockDomain(io.clk,io.rst,config=ClockDomainConfig(resetActiveLevel=HIGH,resetKind=SYNC))
  new ClockingArea(domain) {
    val idle :: request :: waitResponse :: complete :: Nil = List.tabulate(4)(i=>U(i,2 bits))
    val state = RegInit(idle)
    val addr = Reg(Bits(32 bits)); val data = Reg(Bits(32 bits))
    val rm = Reg(Bits(4 bits)); val wm = Reg(Bits(4 bits)); val rob = Reg(Bits(cfg.robIdx bits))
    val result = Reg(Bits(32 bits)); val error = RegInit(False)
    io.accepted := state === idle && io.start && !io.flush
    io.bus.req_valid := state === request && !io.flush
    io.bus.addr := addr(31 downto 2) ## B(0,2 bits); io.bus.wdata := data; io.bus.rmask := rm; io.bus.wmask := wm
    io.busy := state =/= idle
    io.done := state === complete
    io.error := error; io.result := result; io.done_addr := addr; io.done_rob_id := rob; io.is_write := wm.orR
    def captureResponse(): Unit = { result := io.bus.resp_rdata; error := io.bus.resp_error; state := complete }
    // Idle payload is unobserved. Capture before the late acceptance/flush cone;
    // the acceptance edge still supplies exactly the same transaction payload.
    if (cfg.mmioIdleCapture) when(state === idle) {
      addr := io.addr; data := io.wdata; rm := io.rmask; wm := io.wmask; rob := io.rob_id
    }
    switch(state) {
      is(idle) { when(io.accepted) {
        if (!cfg.mmioIdleCapture) {
          addr := io.addr; data := io.wdata; rm := io.rmask; wm := io.wmask; rob := io.rob_id
        }
        error := False; state := request
      } }
      is(request) {
        when(io.flush) { state := idle }
        .elsewhen(io.bus.req_ready) {
          when(io.bus.resp_valid) { captureResponse() }.otherwise { state := waitResponse }
        }
      }
      // Accepted requests are never abandoned, including a coincident flush.
      is(waitResponse) { when(io.bus.resp_valid) { captureResponse() } }
      is(complete) { state := idle }
    }
  }
}
