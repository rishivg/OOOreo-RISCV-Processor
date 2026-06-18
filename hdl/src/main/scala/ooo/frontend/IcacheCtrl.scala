package ooo.frontend

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/icache/icache_ctrl.sv` (I-cache config).
  *
  * I-cache miss FSM (PASS_THRU -> ALLOCATE -> ALLOCATE_STALL) + hit detection.
  * The SV module is parameterized + has unpacked-array inputs (tag_arr_out,
  * valid_arr_out); this module is fixed to the I-cache config and presents those
  * arrays FLATTENED. sim/swap_shims/icache_ctrl.sv is a parameterized shim that
  * un-flattens (and absorbs the `#(...)` override).
  *
  * icache_ctrl_fsm_state_t: PASS_THRU 00 / ALLOCATE 01 / ALLOCATE_STALL 10.
  */
class IcacheCtrl(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("icache_ctrl_spinal")
  val TAG  = cfg.iTagIdx      // 21
  val SETW = cfg.iSetIdx      // 6
  val OFFW = cfg.iOffsetIdx   // 5
  val WAYS = cfg.iNumWays     // 4
  val WAYB = log2Up(WAYS)     // 2
  val TAW  = TAG + 1          // tag_arr element width (22)

  def PASS_THRU = B"2'b00"; def ALLOCATE = B"2'b01"; def ALLOCATE_STALL = B"2'b10"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val kill = in Bool(); val read = in Bool()
    val tag  = in Bits (TAG bits)
    val set  = in Bits (SETW bits)
    val tag_arr_flat   = in Bits (WAYS * TAW bits)
    val valid_arr_flat = in Bits (WAYS bits)
    val stall         = out Bool()
    val allocate_done = out Bool()
    val hit_way       = out Bits (WAYB bits)
    val dfp_addr   = out Bits (32 bits)
    val dfp_read   = out Bool()
    val dfp_write  = out Bool()
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rvalid = in  Bool()
  }
  noIoPrefix()

  io.dfp_write := False
  io.dfp_addr  := io.tag ## io.set ## B(0, OFFW bits)

  // hit detection (last matching way wins, per the SV for-loop)
  val hit = Bool(); hit := False
  io.hit_way := B(0, WAYB bits)
  for (i <- 0 until WAYS) {
    val tg = io.tag_arr_flat(i * TAW, TAW bits)(TAG - 1 downto 0)
    when(tg === io.tag && io.valid_arr_flat(i)) { hit := True; io.hit_way := B(i, WAYB bits) }
  }
  io.stall := io.read && !hit

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val state = RegInit(PASS_THRU)
    val next_state = cloneOf(state); next_state := state
    io.dfp_read := False
    io.allocate_done := False
    switch(state) {
      is(PASS_THRU) {
        when(!io.kill) {
          when(io.read && !hit) {
            io.dfp_read := True
            when(io.dfp_ready) { next_state := ALLOCATE }
          }
        }
      }
      is(ALLOCATE) {
        when(io.kill) { next_state := PASS_THRU }
        .elsewhen(io.dfp_rvalid && io.dfp_addr === io.dfp_raddr) {
          next_state := ALLOCATE_STALL; io.allocate_done := True
        }
      }
      is(ALLOCATE_STALL) { next_state := PASS_THRU }
      default { }
    }
    state := next_state
  }
}
