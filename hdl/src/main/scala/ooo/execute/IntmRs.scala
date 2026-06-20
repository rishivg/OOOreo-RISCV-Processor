package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/execute/intm_rs/intm_rs.sv` -- the mul/div RS
  * subsystem. INTMRS_DEPTH RsEntry slots (non-compacting, dual dispatch) + the
  * reused FuMul + the CDB arbiter (div priority, pass-through). fu_div stays SV
  * (DesignWare DW_div_seq blackbox) -- its interface is EXPOSED and the shim
  * instantiates the real SV fu_div_i (so the perf tap fu_div_i.div_start resolves).
  *
  * Named intm_rs_spinal. ds_rs_itf (2 uops), to_prf single, fu_cdb_out single.
  */
class IntmRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("intm_rs_spinal")
  val D    = cfg.intmrsDepth   // 4
  val IDW  = cfg.idWidth       // 2
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val EW   = RsEntryLayout.intm.width   // 35
  val REGW = 85                         // intm_rs_reg_t
  val CDBR = 113                        // fu_cdb_reg_t

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_entry_flat = in Bits (IDW * EW bits)
    val from_ds_valid      = in Bits (IDW bits)
    val from_ds_ready      = out Bool()
    val to_prf_rs1_phy   = out Bits (6 bits)
    val to_prf_rs2_phy   = out Bits (6 bits)
    val to_prf_rs_bypass = out Bits (14 bits)
    val to_prf_rs1_value = in  Bits (32 bits)
    val to_prf_rs2_value = in  Bits (32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * 6 bits)
    val cdb_valid       = in Bits (CDBW bits)
    val alu_bypass_flat = in Bits (NFB * 39 bits)
    // fu_cdb_itf.fu (single)
    val fu_cdb_rob_id = out Bits (6 bits);  val fu_cdb_rd_phy = out Bits (6 bits)
    val fu_cdb_rd_arch = out Bits (5 bits); val fu_cdb_rd_value = out Bits (32 bits)
    val fu_cdb_rs1_dbg = out Bits (32 bits); val fu_cdb_rs2_dbg = out Bits (32 bits)
    val fu_cdb_valid = out Bool()
    // externalized fu_div interface (shim instantiates the SV fu_div)
    val div_prv_valid = out Bool(); val div_prv_ready = in Bool()
    val div_nxt_valid = in Bool();  val div_nxt_ready = out Bool()
    val div_iss_in  = out Bits (REGW bits)
    val div_cdb_out = in  Bits (CDBR bits)
    // debug tap for perf_monitor (intm_rs_i.fu_mul_i.mul_start)
    val dbg_mul_start = out Bool()
  }
  noIoPrefix()

  def orMux(sel: Bits, data: collection.Seq[Bits]): Bits =
    data.zipWithIndex.map { case (d, i) => Mux(sel(i), d, B(0, d.getWidth bits)) }.reduce(_ | _)
  def firstOH(req: collection.Seq[Bool]): Vec[Bool] = {
    val g = Vec(Bool(), req.length)              // first-requester one-hot
    var acc: Bool = False                        // shared prefix-OR (O(D) vs O(D^2))
    for (i <- req.indices) { g(i) := req(i) && !acc; acc = acc | req(i) }
    g
  }

  val fumul = new FuMul(cfg); fumul.io.clk := io.clk; fumul.io.rst := io.rst
  io.dbg_mul_start := fumul.io.mul_start

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.intm))
    val from_ds_entry = (0 until IDW).map(w => io.from_ds_entry_flat(w * EW, EW bits))

    val wcdb = Vec(CdbRs(), CDBW)
    for (k <- 0 until CDBW) { wcdb(k).rd_phy := io.cdb_rd_phy_flat(k * 6, 6 bits); wcdb(k).valid := io.cdb_valid(k) }
    val fb = Vec(BypassNet(), NFB)
    for (k <- 0 until NFB) { fb(k) := BypassNet.fromBits(io.alu_bypass_flat(k * 39, 39 bits)) }

    val rs_valid   = Vec(Bool(), D)
    val rs_request = Vec(Bool(), D)
    val rs_entry   = Vec(Bits(EW bits), D)
    val rs_bypass  = Vec(BypassT(), D)
    val push_en    = Vec(Bool(), D)
    val entry_in   = Vec(Bits(EW bits), D)

    // ready
    val n_avail = (0 until D).map(i => (!rs_valid(i)).asUInt).reduce(_ +^ _)
    io.from_ds_ready := n_avail >= IDW
    val ds_ready = io.from_ds_ready

    // push: first/second free slot (dual dispatch)
    val notValid = (0 until D).map(i => !rs_valid(i))
    val firstFree  = firstOH(notValid)
    val notValid2  = (0 until D).map(i => notValid(i) && !firstFree(i))
    val secondFree = firstOH(notValid2)
    val p0 = io.from_ds_valid(0) && ds_ready
    val p1 = io.from_ds_valid(1) && ds_ready
    for (i <- 0 until D) {
      val en0 = p0 && firstFree(i)
      val en1 = p1 && secondFree(i)
      push_en(i) := en0 || en1
      entry_in(i) := orMux(en1 ## en0, from_ds_entry)
    }

    // issue: split mul/div by fu_opcode[2], first requesting each, div priority
    val mulReq = (0 until D).map(i => rs_request(i) && !rs_entry(i)(2))
    val divReq = (0 until D).map(i => rs_request(i) &&  rs_entry(i)(2))
    val fu_mul_ready = fumul.io.prv_ready
    val fu_div_ready = io.div_prv_ready
    val mulG = Vec(Bool(), D); val divG = Vec(Bool(), D)
    val mulFirst = firstOH(mulReq); val divFirst = firstOH(divReq)
    for (i <- 0 until D) { mulG(i) := fu_mul_ready && mulFirst(i); divG(i) := fu_div_ready && divFirst(i) }
    val rs_grant = Mux(divG.reduce(_ || _), divG.asBits, mulG.asBits)

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := entry_in(i)
      e.io.clear       := False
      e.io.fast_bypass := fb
      e.io.wakeup_cdb  := wcdb
      rs_valid(i)   := e.io.valid
      rs_request(i) := e.io.request
      rs_entry(i)   := e.io.entry
      rs_bypass(i)  := e.io.rs_bypass
    }

    // issued entry -> intm_rs_in + prf
    val issued = orMux(rs_grant, rs_entry)        // intm_rs_entry_t Bits(35)
    val i_fu_opcode = issued(3 downto 0)
    val i_rd_arch   = issued(8 downto 4)
    val i_rd_phy    = issued(14 downto 9)
    val i_rs2_phy   = issued(21 downto 16)
    val i_rs1_phy   = issued(28 downto 23)
    val i_rob_id    = issued(34 downto 29)
    io.to_prf_rs1_phy := i_rs1_phy
    io.to_prf_rs2_phy := i_rs2_phy
    io.to_prf_rs_bypass := orMux(rs_grant, rs_bypass.map(_.toBits))

    // intm_rs_reg_t (SV layout): rob_id rd_arch rd_phy fu_opcode rs1_value rs2_value
    val intm_rs_in = i_rob_id ## i_rd_arch ## i_rd_phy ## i_fu_opcode ## io.to_prf_rs1_value ## io.to_prf_rs2_value

    // FuMul (internal) handshake
    val mulReqAny = mulReq.reduce(_ || _)
    val divGrantAny = divG.reduce(_ || _)
    fumul.io.prv_valid := Mux(divGrantAny, False, mulReqAny)
    fumul.io.iss_in    := intm_rs_in
    val fu_mul_valid = fumul.io.nxt_valid
    val fu_mul_cdb   = fumul.io.cdb_out

    // fu_div (external) handshake
    io.div_prv_valid := divReq.reduce(_ || _)
    io.div_iss_in    := intm_rs_in
    val fu_div_valid = io.div_nxt_valid
    val fu_div_cdb   = io.div_cdb_out

    // CDB arbiter (div priority, pass-through)
    val cdb_valid     = fu_mul_valid || fu_div_valid
    fumul.io.nxt_ready := !fu_div_valid          // cdb_mul_ready
    io.div_nxt_ready   := True                   // cdb_div_ready
    val cdb_reg_in = Mux(fu_div_valid, fu_div_cdb, fu_mul_cdb)
    io.fu_cdb_valid   := cdb_valid
    io.fu_cdb_rob_id  := cdb_reg_in(112 downto 107)
    io.fu_cdb_rd_arch := cdb_reg_in(106 downto 102)
    io.fu_cdb_rd_phy  := cdb_reg_in(101 downto 96)
    io.fu_cdb_rd_value := cdb_reg_in(95 downto 64)
    io.fu_cdb_rs1_dbg := cdb_reg_in(63 downto 32)
    io.fu_cdb_rs2_dbg := cdb_reg_in(31 downto 0)
  }
}
