package ooo.execute

import spinal.core._
import ooo.CpuConfig
import ooo.memory.FuAgu

/** SpinalHDL port of `hdl/memory/mem_rs/mem_rs.sv` -- the memory RS subsystem.
  * Simple non-compacting RS (push first-free, issue first-requesting) feeding the
  * reused FuAgu, whose output drives the agu_lsq_itf (valid + agu_lsq_t data).
  * Single dispatch (ds_rs_mono_itf). fu_agu re-emitted -> shim drops the real one.
  *
  * mem_rs_entry_t (56b): rob_id rs1_phy rs1_valid rs2_phy rs2_valid imm fu_opcode.
  */
class MemRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("mem_rs_spinal")
  val D    = cfg.memrsDepth     // 8
  val CDBW = cfg.cdbWidth
  val NFB  = cfg.numFastBypass
  val EW   = RsEntryLayout.mem.width   // 56
  val AGUREG = 106                     // agu_reg_t
  val AGULSQ = 138                     // agu_lsq_t

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_entry_flat = in Bits (EW bits)
    val from_ds_valid      = in Bool()
    val from_ds_ready      = out Bool()
    val to_prf_rs1_phy   = out Bits (6 bits)
    val to_prf_rs2_phy   = out Bits (6 bits)
    val to_prf_rs_bypass = out Bits (14 bits)
    val to_prf_rs1_value = in  Bits (32 bits)
    val to_prf_rs2_value = in  Bits (32 bits)
    val cdb_rd_phy_flat = in Bits (CDBW * 6 bits)
    val cdb_valid       = in Bits (CDBW bits)
    val alu_bypass_flat = in Bits (NFB * 39 bits)
    val to_lsq_valid = out Bool()
    val to_lsq_data  = out Bits (AGULSQ bits)
  }
  noIoPrefix()

  // Balanced OR-reduce (log-depth tree) instead of the linear left-fold `.reduce`,
  // so the one-hot issue mux feeding the AGU is a depth-ceil(log2 D) tree, not a
  // depth-(D-1) ripple. Logically identical (OR is associative) -> bit-exact.
  def balancedOr(terms: collection.Seq[Bits]): Bits =
    if (terms.length == 1) terms.head
    else { val (a, b) = terms.splitAt(terms.length / 2); balancedOr(a) | balancedOr(b) }
  def orMux(sel: Bits, data: collection.Seq[Bits]): Bits =
    balancedOr(data.zipWithIndex.map { case (d, i) => Mux(sel(i), d, B(0, d.getWidth bits)) })

  // Shared exclusive prefix-OR: out(i) = OR(in(0..i-1)). Computes all D prefixes in
  // O(D) gates with one running accumulator instead of the original O(D^2) per-index
  // linear folds (`(0 until i).fold`). Bit-exact (same priority semantics).
  def exPrefixOr(in: collection.Seq[Bool]): Seq[Bool] = {
    val out = Array.fill(in.length)(False: Bool)
    var acc: Bool = False
    for (i <- in.indices) { out(i) = acc; acc = acc | in(i) }
    out.toSeq
  }

  val agu = new FuAgu(cfg); agu.io.clk := io.clk; agu.io.rst := io.rst

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.mem))

    val wcdb = Vec(CdbRs(), CDBW)
    for (k <- 0 until CDBW) { wcdb(k).rd_phy := io.cdb_rd_phy_flat(k * 6, 6 bits); wcdb(k).valid := io.cdb_valid(k) }
    val fb = Vec(BypassNet(), NFB)
    for (k <- 0 until NFB) { fb(k) := BypassNet.fromBits(io.alu_bypass_flat(k * 39, 39 bits)) }

    val rs_valid   = Vec(Bool(), D)
    val rs_request = Vec(Bool(), D)
    val rs_entry   = Vec(Bits(EW bits), D)
    val rs_bypass  = Vec(BypassT(), D)
    val push_en    = Vec(Bool(), D)

    val notValid = (0 until D).map(i => !rs_valid(i))
    val doPush = io.from_ds_valid && io.from_ds_ready
    val freeBelow = exPrefixOr(notValid)                 // push to first free slot
    for (i <- 0 until D) push_en(i) := doPush && notValid(i) && !freeBelow(i)
    val rs_grant = Vec(Bool(), D)
    val reqBelow = exPrefixOr((0 until D).map(i => rs_request(i)))   // issue first requester
    for (i <- 0 until D) rs_grant(i) := rs_request(i) && !reqBelow(i)

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := io.from_ds_entry_flat
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
    val issued = orMux(grantBits, rs_entry)        // mem_rs_entry_t Bits(56)
    io.to_prf_rs_bypass := orMux(grantBits, rs_bypass.map(_.toBits))

    val i_fu_opcode = issued(3 downto 0)
    val i_imm       = issued(35 downto 4)
    val i_rs2_phy   = issued(42 downto 37)
    val i_rs1_phy   = issued(49 downto 44)
    val i_rob_id    = issued(55 downto 50)
    io.to_prf_rs1_phy := i_rs1_phy
    io.to_prf_rs2_phy := i_rs2_phy

    // agu_reg_t (SV layout): rob_id fu_opcode imm rs1_value rs2_value
    val agu_reg = i_rob_id ## i_fu_opcode ## i_imm ## io.to_prf_rs1_value ## io.to_prf_rs2_value
    agu.io.prv_valid  := rs_request.reduce(_ || _)
    agu.io.agu_reg_in := agu_reg
    io.to_lsq_valid := agu.io.nxt_valid
    io.to_lsq_data  := agu.io.to_lsq
  }
}
