package ooo.memory

import spinal.core._
import ooo.CpuConfig

// ---- external array/macro blackboxes (real SV/macro modules stay in the build) ----
class DcacheDataArray(setW: Int) extends BlackBox {
  setBlackBoxName("dcache_data_array")
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val wmask0 = in Bits(32 bits); val addr0 = in Bits(setW bits)
    val din0 = in Bits(256 bits); val dout0 = out Bits(256 bits)
  }
  noIoPrefix()
}
class DcacheTagArray(setW: Int, tagW: Int) extends BlackBox {
  setBlackBoxName("dcache_tag_array")
  val io = new Bundle {
    val clk0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(tagW bits); val dout0 = out Bits(tagW bits)
  }
  noIoPrefix()
}
class ValidArray(setW: Int) extends BlackBox {
  setBlackBoxName("valid_array")
  addGeneric("S_INDEX", setW); addGeneric("WIDTH", 1)
  val io = new Bundle {
    val clk0 = in Bool(); val rst0 = in Bool(); val csb0 = in Bool(); val web0 = in Bool()
    val addr0 = in Bits(setW bits); val din0 = in Bits(1 bits); val dout0 = out Bits(1 bits)
  }
  noIoPrefix()
}
class LruArray(setW: Int, w: Int) extends BlackBox {
  setBlackBoxName("lru_array")
  addGeneric("S_INDEX", setW); addGeneric("WIDTH", w)
  val io = new Bundle {
    val clk0 = in Bool(); val rst0 = in Bool()
    val csb0 = in Bool(); val addr0 = in Bits(setW bits); val din0 = in Bits(w bits); val dout0 = out Bits(w bits)
    val csb1 = in Bool(); val web1 = in Bool(); val addr1 = in Bits(setW bits); val din1 = in Bits(w bits)
  }
  noIoPrefix()
}
class PlruUpdate(numWays: Int, plruBits: Int, wayBits: Int) extends BlackBox {
  setBlackBoxName("plru_update")
  addGeneric("NUM_WAYS", numWays); addGeneric("PLRU_BITS", plruBits); addGeneric("WAY_BITS", wayBits)
  val io = new Bundle {
    val current_plru = in Bits(plruBits bits); val next_plru = out Bits(plruBits bits)
    val hit_way = in Bits(wayBits bits); val replace_way = out Bits(wayBits bits)
  }
  noIoPrefix()
}

/** SpinalHDL port of `hdl/memory/dcache/dcache.sv` -- the D-cache datapath.
  *
  * SpinalHDL hierarchy: per-way data/tag/valid SRAM macros + a 2-port LRU array
  * (blackboxes referencing the real SV/macro modules), the reused SpinalHDL
  * HitDetection + DcacheCtrl twins, a blackboxed plru_update, and the FETCH-stage
  * register + chip-select / write-enable / wmask-din / dfp-ufp datapath glue.
  *
  * Named dcache_spinal; sim/swap_shims/dcache.sv carries dmem_itf.cache (ufp) +
  * cacheline_itf.master (dfp). DcacheCtrl re-emits module `dcache_ctrl`, so the
  * swap EXTRA_EXCLUDEs the real dcache_ctrl.sv.
  */
class Dcache(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("dcache_spinal")
  val WAYS = cfg.dNumWays      // 4
  val WAYB = log2Up(WAYS)      // 2
  val SETW = cfg.dSetIdx       // 4
  val OFFW = cfg.dOffsetIdx    // 5
  val TAG  = cfg.dTagIdx       // 23
  val TAW  = TAG + 1           // 24
  val PLRU = WAYS - 1          // 3

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // dmem_itf.cache ufp
    val ufp_addr  = in  Bits (32 bits)
    val ufp_rmask = in  Bits (4 bits)
    val ufp_wmask = in  Bits (4 bits)
    val ufp_rdata = out Bits (32 bits)
    val ufp_wdata = in  Bits (32 bits)
    val ufp_resp  = out Bool()
    // cacheline_itf.master dfp
    val dfp_addr   = out Bits (32 bits)
    val dfp_read   = out Bool()
    val dfp_write  = out Bool()
    val dfp_wdata  = out Bits (256 bits)
    val dfp_ready  = in  Bool()
    val dfp_raddr  = in  Bits (32 bits)
    val dfp_rdata  = in  Bits (256 bits)
    val dfp_rvalid = in  Bool()
    // perf_monitor taps dcache_i.dcache_ctrl_i.{stall,hit,rmask,wmask}
    val dbg_stall = out Bool()
    val dbg_hit   = out Bool()
    val dbg_rmask = out Bits (4 bits)
    val dbg_wmask = out Bits (4 bits)
  }
  noIoPrefix()

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val ufpOffset = io.ufp_addr(OFFW - 1 downto 0)
    val ufpSet    = io.ufp_addr(SETW + OFFW - 1 downto OFFW)
    val ufpTag    = io.ufp_addr(TAG + SETW + OFFW - 1 downto SETW + OFFW)

    // FETCH-stage register (dcache_stage_reg_t)
    val srRmask  = RegInit(B(0, 4 bits)); val srWmask = RegInit(B(0, 4 bits))
    val srWdata  = Reg(Bits(32 bits)); val srOffset = Reg(UInt(OFFW bits))
    val srSet    = Reg(UInt(SETW bits)); val srTag = Reg(Bits(TAG bits))

    // datapath signals (declared up front; driven below)
    val hit = Bool(); val hitWay = UInt(WAYB bits); val replaceWay = UInt(WAYB bits)
    val stall = Bool(); val allocateDone = Bool(); val writeHitRec = Bool(); val writeHit = Bool()
    val plruDin1 = Bits(PLRU bits)

    val sramSet = Mux(writeHit || stall, srSet.asBits, ufpSet)

    val dataCsb = Vec(Bool(), WAYS); val tagCsb = Vec(Bool(), WAYS); val validCsb = Vec(Bool(), WAYS)
    val dataWeb = Vec(Bool(), WAYS); val tagWeb = Vec(Bool(), WAYS); val validWeb = Vec(Bool(), WAYS)
    val dataWmask = Bits(32 bits); val dataDin = Bits(256 bits); val tagDin = Bits(TAW bits); val validDin = True
    val dataDout = Vec(Bits(256 bits), WAYS); val tagDout = Vec(Bits(TAW bits), WAYS); val validDout = Vec(Bool(), WAYS)

    // per-way arrays
    for (i <- 0 until WAYS) {
      val da = new DcacheDataArray(SETW)
      da.io.clk0 := io.clk; da.io.csb0 := dataCsb(i); da.io.web0 := dataWeb(i)
      da.io.wmask0 := dataWmask; da.io.addr0 := sramSet; da.io.din0 := dataDin
      dataDout(i) := da.io.dout0
      val ta = new DcacheTagArray(SETW, TAW)
      ta.io.clk0 := io.clk; ta.io.csb0 := tagCsb(i); ta.io.web0 := tagWeb(i)
      ta.io.addr0 := sramSet; ta.io.din0 := tagDin
      tagDout(i) := ta.io.dout0
      val va = new ValidArray(SETW)
      va.io.clk0 := io.clk; va.io.rst0 := io.rst; va.io.csb0 := validCsb(i); va.io.web0 := validWeb(i)
      va.io.addr0 := sramSet; va.io.din0 := validDin.asBits
      validDout(i) := va.io.dout0(0)
    }

    // LRU array (read port0 on ufp_set, write port1 on srSet)
    val plruCsb0 = stall
    val plruCsb1 = !io.ufp_resp
    val plruWeb1 = plruCsb1
    val lru = new LruArray(SETW, PLRU)
    lru.io.clk0 := io.clk; lru.io.rst0 := io.rst
    lru.io.csb0 := plruCsb0; lru.io.addr0 := ufpSet.asBits; lru.io.din0 := B(0, PLRU bits)
    lru.io.csb1 := plruCsb1; lru.io.web1 := plruWeb1; lru.io.addr1 := srSet.asBits; lru.io.din1 := plruDin1
    val plruDout0 = lru.io.dout0

    // hit detection (reused twin, flat arrays)
    val hd = new ooo.memory.HitDetection(cfg)
    hd.io.tag := srTag
    hd.io.tag_arr_flat := Cat((0 until WAYS).map(i => tagDout(i)))   // way0 at LSB
    hd.io.valid_arr_flat := validDout.asBits
    hit := hd.io.hit; hitWay := hd.io.hit_way.asUInt

    val replaceWayDirty = tagDout(replaceWay)(TAG) && validDout(replaceWay)
    val hitWayDirty     = tagDout(hitWay)(TAG) && validDout(hitWay)

    // control FSM (reused twin)
    val ctrl = new ooo.memory.DcacheCtrl
    ctrl.io.clk := io.clk; ctrl.io.rst := io.rst
    ctrl.io.hit := hit; ctrl.io.dirty := replaceWayDirty
    ctrl.io.rmask := srRmask; ctrl.io.wmask := srWmask
    stall := ctrl.io.stall; allocateDone := ctrl.io.allocate_done
    writeHitRec := ctrl.io.write_hit_rec; writeHit := ctrl.io.write_hit
    ctrl.io.dfp_addr := io.dfp_addr
    io.dfp_read := ctrl.io.dfp_read; io.dfp_write := ctrl.io.dfp_write
    ctrl.io.dfp_ready := io.dfp_ready; ctrl.io.dfp_raddr := io.dfp_raddr; ctrl.io.dfp_rvalid := io.dfp_rvalid

    // plru update (blackbox)
    val pu = new PlruUpdate(WAYS, PLRU, WAYB)
    pu.io.current_plru := plruDout0; plruDin1 := pu.io.next_plru
    pu.io.hit_way := hitWay.asBits; replaceWay := pu.io.replace_way.asUInt

    // FETCH-stage register update
    when(!stall) {
      srRmask := io.ufp_rmask; srWmask := io.ufp_wmask; srWdata := io.ufp_wdata
      srOffset := ufpOffset.asUInt; srSet := ufpSet.asUInt; srTag := ufpTag
    }

    // chip-select
    for (i <- 0 until WAYS) { dataCsb(i) := True; tagCsb(i) := True; validCsb(i) := True }
    when(!stall || writeHitRec) {
      for (i <- 0 until WAYS) { dataCsb(i) := False; tagCsb(i) := False; validCsb(i) := False }
    }
    when(allocateDone) { dataCsb(replaceWay) := False; tagCsb(replaceWay) := False; validCsb(replaceWay) := False }

    // write-enable
    for (i <- 0 until WAYS) { dataWeb(i) := True; tagWeb(i) := True; validWeb(i) := True }
    when(allocateDone) { dataWeb(replaceWay) := False; tagWeb(replaceWay) := False; validWeb(replaceWay) := False }
    when(writeHit) { dataWeb(hitWay) := False; tagWeb(hitWay) := hitWayDirty }

    // SRAM wmask + din
    dataWmask := B(0, 32 bits); dataDin := B(0, 256 bits)
    when(writeHit) {
      for (i <- 0 until 4) when(srWmask(i)) { dataWmask((srOffset + U(i, OFFW bits)).resize(OFFW bits)) := True }
      dataDin := Cat(Seq.fill(8)(srWdata))
    }.elsewhen(allocateDone) {
      dataWmask := B(32 bits, default -> True)
      dataDin := io.dfp_rdata
    }
    tagDin := srWmask.orR ## srTag

    // PROCESS stage / dfp + ufp
    io.dfp_addr := Mux(io.dfp_write,
      tagDout(replaceWay)(TAG - 1 downto 0) ## srSet.asBits ## B(0, OFFW bits),
      srTag ## srSet.asBits ## B(0, OFFW bits))
    io.dfp_wdata := dataDout(replaceWay)
    io.ufp_rdata := dataDout(hitWay)(srOffset * 8, 32 bits)
    io.ufp_resp  := (srRmask.orR || srWmask.orR) && !stall

    // perf taps
    io.dbg_stall := stall; io.dbg_hit := hit; io.dbg_rmask := srRmask; io.dbg_wmask := srWmask
  }
}
