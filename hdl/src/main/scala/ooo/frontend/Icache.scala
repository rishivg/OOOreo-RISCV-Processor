package ooo.frontend

import spinal.core._
import ooo.CpuConfig
import ooo.memory.{LruArray, PlruUpdate}

// ---- I-cache SRAM macro blackboxes (real macros stay in the build) ----
class IcacheDataArray(setW: Int) extends BlackBox {
  setBlackBoxName("icache_data_array"); addGeneric("ADDR_WIDTH", setW)
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val wmask0 = in Bits(32 bits); val addr0 = in Bits(setW bits)
    val din0 = in Bits(256 bits); val dout0 = out Bits(256 bits)
  }
  noIoPrefix()
}
class IcacheTagArray(setW: Int) extends BlackBox {
  setBlackBoxName("icache_tag_array"); addGeneric("ADDR_WIDTH", setW)
  val io = new Bundle {     // macro DATA_WIDTH defaults to 24 (SV does not override it)
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(24 bits); val dout0 = out Bits(24 bits)
  }
  noIoPrefix()
}

/** SpinalHDL port of `hdl/frontend/icache/icache.sv` -- the I-cache datapath.
  *
  * Read-only cache: per-way data/tag SRAM macros (BlackBoxes) + 2-port LRU array,
  * the reused IcacheCtrl miss-FSM twin, a blackboxed plru_update, and the FETCH-
  * stage register + chip-select / din / IF_WIDTH-wide rdata glue. Line validity is
  * a GENERATION (epoch) bit in the tag SRAM MSB: valid iff line_epoch==global_epoch;
  * reset flips global_epoch to invalidate all lines at once.
  *
  * Named icache_spinal; sim/swap_shims/icache.sv is the parameterized shim
  * (absorbs the if1_stage `#(.IF_WIDTH(..))` override + packed-2D ufp_rdata).
  */
class Icache(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("icache_spinal")
  val IFW  = cfg.ifWidth       // 4
  val WAYS = cfg.iNumWays      // 4
  val WAYB = log2Up(WAYS)      // 2
  val SETW = cfg.iSetIdx       // 6
  val OFFW = cfg.iOffsetIdx    // 5
  val TAG  = cfg.iTagIdx       // 21
  val TAW  = TAG + 1           // 22 ({epoch, tag})
  val PLRU = WAYS - 1          // 3

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val ufp_addr  = in  Bits (32 bits)
    val ufp_read  = in  Bool()
    val ufp_rdata = out Bits (IFW * 32 bits)
    val ufp_resp  = out Bool()
    val kill      = in  Bool()
    val dfp_addr   = out Bits (32 bits)
    val dfp_read   = out Bool()
    val dfp_write  = out Bool()
    val dfp_wdata  = out Bits (256 bits)
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rdata  = in  Bits (256 bits)
    val dfp_rvalid = in  Bool()
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val globalEpoch = Reg(Bool())                      // no reset: toggles on rst
    when(io.rst) { globalEpoch := !globalEpoch }

    val ufpOffset = io.ufp_addr(OFFW - 1 downto 0)
    val ufpSet    = io.ufp_addr(SETW + OFFW - 1 downto OFFW)
    val ufpTag    = io.ufp_addr(TAG + SETW + OFFW - 1 downto SETW + OFFW)

    val srRead   = RegInit(False)
    val srOffset = Reg(UInt(OFFW bits)); val srSet = Reg(UInt(SETW bits)); val srTag = Reg(Bits(TAG bits))

    val hit = Bool(); val hitWay = UInt(WAYB bits); val replaceWay = UInt(WAYB bits)
    val stall = Bool(); val allocateDone = Bool(); val plruDin1 = Bits(PLRU bits)

    val sramSet = Mux(!stall || io.kill, ufpSet.asBits, srSet.asBits)
    val dataCsb = Vec(Bool(), WAYS); val tagCsb = Vec(Bool(), WAYS)
    val dataWeb = Vec(Bool(), WAYS); val tagWeb = Vec(Bool(), WAYS)
    val dataWmask = Bits(32 bits); val dataDin = Bits(256 bits)
    val dataDout = Vec(Bits(256 bits), WAYS); val tagDout = Vec(Bits(TAW bits), WAYS); val validDout = Vec(Bool(), WAYS)

    // refill stamps {global_epoch, tag}; macro is 24b wide (upper 2 unused)
    val tagDin = (B(0, 24 - TAW bits) ## globalEpoch ## srTag)

    for (i <- 0 until WAYS) {
      val da = new IcacheDataArray(SETW)
      da.io.clk0 := io.clk; da.io.csb0 := dataCsb(i); da.io.web0 := dataWeb(i)
      da.io.wmask0 := dataWmask; da.io.addr0 := sramSet; da.io.din0 := dataDin
      dataDout(i) := da.io.dout0
      val ta = new IcacheTagArray(SETW)
      ta.io.clk0 := io.clk; ta.io.csb0 := tagCsb(i); ta.io.web0 := tagWeb(i)
      ta.io.addr0 := sramSet; ta.io.din0 := tagDin
      tagDout(i) := ta.io.dout0(TAW - 1 downto 0)
      validDout(i) := tagDout(i)(TAG) === globalEpoch
    }

    val plruCsb0 = stall
    val plruCsb1 = !io.ufp_resp
    val plruWeb1 = plruCsb1
    val lru = new LruArray(SETW, PLRU)
    lru.io.clk0 := io.clk; lru.io.rst0 := io.rst
    lru.io.csb0 := plruCsb0; lru.io.addr0 := ufpSet.asBits; lru.io.din0 := B(0, PLRU bits)
    lru.io.csb1 := plruCsb1; lru.io.web1 := plruWeb1; lru.io.addr1 := srSet.asBits; lru.io.din1 := plruDin1

    // miss FSM (reused twin)
    val ctrl = new IcacheCtrl(cfg)
    ctrl.io.clk := io.clk; ctrl.io.rst := io.rst
    ctrl.io.kill := io.kill; ctrl.io.read := srRead
    ctrl.io.tag := srTag; ctrl.io.set := srSet.asBits
    ctrl.io.tag_arr_flat := Cat((0 until WAYS).map(i => tagDout(i)))   // way0 at LSB
    ctrl.io.valid_arr_flat := validDout.asBits
    stall := ctrl.io.stall; allocateDone := ctrl.io.allocate_done; hitWay := ctrl.io.hit_way.asUInt
    hit := False
    io.dfp_addr := ctrl.io.dfp_addr; io.dfp_read := ctrl.io.dfp_read; io.dfp_write := ctrl.io.dfp_write
    ctrl.io.dfp_ready := io.dfp_ready; ctrl.io.dfp_raddr := io.dfp_raddr; ctrl.io.dfp_rvalid := io.dfp_rvalid

    val pu = new PlruUpdate(WAYS, PLRU, WAYB)
    pu.io.current_plru := lru.io.dout0; plruDin1 := pu.io.next_plru
    pu.io.hit_way := hitWay.asBits; replaceWay := pu.io.replace_way.asUInt

    // FETCH-stage register
    when(io.rst) { srRead := False }
      .elsewhen(!stall || io.kill) { srRead := io.ufp_read; srOffset := ufpOffset.asUInt; srSet := ufpSet.asUInt; srTag := ufpTag }

    // chip-select / write-enable
    for (i <- 0 until WAYS) { dataCsb(i) := True; tagCsb(i) := True; dataWeb(i) := True; tagWeb(i) := True }
    when(!stall || io.kill) { for (i <- 0 until WAYS) { dataCsb(i) := False; tagCsb(i) := False } }
    when(allocateDone) {
      dataCsb(replaceWay) := False; tagCsb(replaceWay) := False
      dataWeb(replaceWay) := False; tagWeb(replaceWay) := False
    }

    // SRAM din
    dataWmask := B(0, 32 bits); dataDin := B(0, 256 bits)
    when(allocateDone) { dataWmask := B(32 bits, default -> True); dataDin := io.dfp_rdata }

    // PROCESS stage / ufp
    io.dfp_wdata := B(0, 256 bits)
    val rd = Vec(Bits(32 bits), IFW)
    for (i <- 0 until IFW) { rd(i) := dataDout(hitWay)((srOffset * 8 + U(32 * i, 9 bits)).resize(9 bits), 32 bits) }
    io.ufp_rdata := rd.asBits
    io.ufp_resp  := srRead && !stall
  }
}
