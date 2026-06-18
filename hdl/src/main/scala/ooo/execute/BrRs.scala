package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/branch/br_rs/br_rs.sv` -- the branch RS subsystem.
  * Simple (non-compacting): push to the first free slot, issue the first requesting
  * slot. BRRS_DEPTH RsEntry slots + the reused FuBr. Single dispatch (ds_rs_mono_itf).
  *
  * Named br_rs_spinal; sim/swap_shims/br_rs.sv carries the SV interfaces. FuBr's
  * debug taps are surfaced as top outputs so the shim can recreate the
  * perf_monitor-tapped `fu_br_i` scope.
  */
class BrRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("br_rs_spinal")
  val D    = cfg.brrsDepth     // 4
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val EW   = RsEntryLayout.br.width   // 133
  val FBRW = 183                      // fu_br_reg_t

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_entry_flat = in Bits (EW bits)
    val from_ds_valid      = in Bool()
    val from_ds_ready      = out Bool()
    val branch_ready       = in Bool()
    val to_prf_rs1_phy   = out Bits (6 bits)
    val to_prf_rs2_phy   = out Bits (6 bits)
    val to_prf_rs_bypass = out Bits (14 bits)
    val to_prf_rs1_value = in  Bits (32 bits)
    val to_prf_rs2_value = in  Bits (32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * 6 bits)
    val cdb_valid       = in Bits (CDBW bits)
    val alu_bypass_flat = in Bits (NFB * 39 bits)
    // cdb_itf.fu
    val fu_cdb_rob_id = out Bits (6 bits);  val fu_cdb_rd_phy = out Bits (6 bits)
    val fu_cdb_rd_arch = out Bits (5 bits); val fu_cdb_rd_value = out Bits (32 bits)
    val fu_cdb_rs1_dbg = out Bits (32 bits); val fu_cdb_rs2_dbg = out Bits (32 bits)
    val fu_cdb_valid = out Bool()
    // br_cdb_itf.fu
    val br_cdb_rob_id = out Bits (6 bits); val br_cdb_miss_predict = out Bool()
    val br_cdb_target_address = out Bits (32 bits); val br_cdb_valid = out Bool()
    val br_cdb_branch_taken = out Bool()
    // debug taps for perf_monitor (br_rs_i.fu_br_i.*)
    val dbg_fu_br_valid = out Bool(); val dbg_miss_predict = out Bool(); val dbg_reg_out = out Bits (FBRW bits)
  }
  noIoPrefix()

  def orMux(sel: Bits, data: collection.Seq[Bits]): Bits =
    data.zipWithIndex.map { case (d, i) => Mux(sel(i), d, B(0, d.getWidth bits)) }.reduce(_ | _)

  val fubr = new FuBr(cfg); fubr.io.clk := io.clk; fubr.io.rst := io.rst

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.br))

    val wcdb = Vec(CdbRs(), CDBW)
    for (k <- 0 until CDBW) { wcdb(k).rd_phy := io.cdb_rd_phy_flat(k * 6, 6 bits); wcdb(k).valid := io.cdb_valid(k) }
    val fb = Vec(BypassNet(), NFB)
    for (k <- 0 until NFB) { fb(k) := BypassNet.fromBits(io.alu_bypass_flat(k * 39, 39 bits)) }

    val rs_valid   = Vec(Bool(), D)
    val rs_request = Vec(Bool(), D)
    val rs_entry   = Vec(Bits(EW bits), D)
    val rs_bypass  = Vec(BypassT(), D)
    val push_en    = Vec(Bool(), D)

    // push: first free slot (lowest i with !rs_valid)
    val notValid = (0 until D).map(i => !rs_valid(i))
    val doPush = io.from_ds_valid && io.branch_ready
    for (i <- 0 until D) {
      val freeBelow = (0 until i).map(j => notValid(j)).fold(False)(_ || _)
      push_en(i) := doPush && notValid(i) && !freeBelow
    }

    // issue: first requesting slot
    val rs_grant = Vec(Bool(), D)
    for (i <- 0 until D) {
      val reqBelow = (0 until i).map(j => rs_request(j)).fold(False)(_ || _)
      rs_grant(i) := rs_request(i) && !reqBelow
    }

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := io.from_ds_entry_flat   // all slots get from_ds_entry; push_en selects
      e.io.clear       := False
      e.io.fast_bypass := fb
      e.io.wakeup_cdb  := wcdb
      rs_valid(i)   := e.io.valid
      rs_request(i) := e.io.request
      rs_entry(i)   := e.io.entry
      rs_bypass(i)  := e.io.rs_bypass
    }

    io.from_ds_ready := notValid.reduce(_ || _)

    val grantBits = rs_grant.asBits
    val issued = orMux(grantBits, rs_entry)              // br_rs_entry_t Bits(133)
    io.to_prf_rs_bypass := orMux(grantBits, rs_bypass.map(_.toBits))

    // br entry field slices (LSB-first)
    val i_predict_target = issued(31 downto 0)
    val i_predict_taken  = issued(32)
    val i_is_compressed  = issued(33)
    val i_fu_opcode      = issued(37 downto 34)
    val i_pc             = issued(69 downto 38)
    val i_imm            = issued(101 downto 70)
    val i_rd_arch        = issued(106 downto 102)
    val i_rd_phy         = issued(112 downto 107)
    val i_rs2_phy        = issued(119 downto 114)
    val i_rs1_phy        = issued(126 downto 121)
    val i_rob_id         = issued(132 downto 127)

    io.to_prf_rs1_phy := i_rs1_phy
    io.to_prf_rs2_phy := i_rs2_phy

    // fu_br_reg_t (SV layout): rob_id rd_arch rd_phy fu_opcode pc imm rs1 rs2 is_compressed predict_taken predict_target
    val fbr = i_rob_id ## i_rd_arch ## i_rd_phy ## i_fu_opcode ## i_pc ## i_imm ##
              io.to_prf_rs1_value ## io.to_prf_rs2_value ## i_is_compressed ## i_predict_taken ## i_predict_target
    fubr.io.br_rs_valid  := rs_request.reduce(_ || _)
    fubr.io.fu_br_reg_in := fbr
  }

  // FuBr outputs -> top
  io.fu_cdb_rob_id := fubr.io.cdb_rob_id; io.fu_cdb_rd_phy := fubr.io.cdb_rd_phy
  io.fu_cdb_rd_arch := fubr.io.cdb_rd_arch; io.fu_cdb_rd_value := fubr.io.cdb_rd_value
  io.fu_cdb_rs1_dbg := fubr.io.cdb_rs1_value_dbg; io.fu_cdb_rs2_dbg := fubr.io.cdb_rs2_value_dbg
  io.fu_cdb_valid := fubr.io.cdb_valid
  io.br_cdb_rob_id := fubr.io.br_cdb_rob_id; io.br_cdb_miss_predict := fubr.io.br_cdb_miss_predict
  io.br_cdb_target_address := fubr.io.br_cdb_target_address; io.br_cdb_valid := fubr.io.br_cdb_valid
  io.br_cdb_branch_taken := fubr.io.br_cdb_branch_taken
  io.dbg_fu_br_valid := fubr.io.dbg_fu_br_valid
  io.dbg_miss_predict := fubr.io.dbg_miss_predict
  io.dbg_reg_out := fubr.io.dbg_reg_out
}
