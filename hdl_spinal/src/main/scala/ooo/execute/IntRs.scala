package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/execute/int_rs/int_rs.sv` -- the integer
  * reservation station SUBSYSTEM (ROADMAP Phase 3). Compacting RS: 16 RsEntry
  * slots + IssueArbiter + 2 FuAlu, with the shift/compaction control, push/pop
  * pointer, and ready logic. one_hot_mux is inlined as a masked-OR.
  *
  * Named int_rs_spinal; sim/swap_shims/int_rs.sv (named int_rs) carries the SV
  * interfaces (ds_rs_itf, rs_prf_itf[2], cdb_itf.rs[5], cdb_itf.fu[2], bypass[2])
  * and flattens them onto these ports. The shim also extracts the uop->entry
  * fields (pure renaming) so this module takes packed int_rs_entry_t per dispatch slot.
  */
class IntRs(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("int_rs_spinal")

  val D    = cfg.intrsDepth      // 16
  val W    = cfg.intIssueWidth   // 2
  val IDW  = cfg.idWidth         // 2
  val CDBW = cfg.cdbWidth        // 5
  val NFB  = cfg.numFastBypass   // 2
  val EW   = IntRsEntry.width     // 69
  val IDX  = log2Up(D)           // 4
  val FALU = 119                 // fu_alu_reg_t

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // ds_rs_itf.rs (entries pre-extracted by the shim) + valid/ready
    val from_ds_entry_flat = in  Bits (IDW * EW bits)
    val from_ds_valid      = in  Bits (IDW bits)
    val from_ds_ready      = out Bool()
    // rs_prf_itf.rs[W]
    val to_prf_rs1_phy_flat   = out Bits (W * 6 bits)
    val to_prf_rs2_phy_flat   = out Bits (W * 6 bits)
    val to_prf_rs_bypass_flat = out Bits (W * 14 bits)
    val to_prf_rs1_value_flat = in  Bits (W * 32 bits)
    val to_prf_rs2_value_flat = in  Bits (W * 32 bits)
    // cdb_itf.rs[CDBW] (wakeup)
    val cdb_rd_phy_flat = in Bits (CDBW * 6 bits)
    val cdb_valid       = in Bits (CDBW bits)
    // cdb_itf.fu[W] (driven by the FUs)
    val fu_cdb_rob_id_flat   = out Bits (W * 6 bits)
    val fu_cdb_rd_phy_flat    = out Bits (W * 6 bits)
    val fu_cdb_rd_arch_flat   = out Bits (W * 5 bits)
    val fu_cdb_rd_value_flat  = out Bits (W * 32 bits)
    val fu_cdb_rs1_dbg_flat   = out Bits (W * 32 bits)
    val fu_cdb_rs2_dbg_flat   = out Bits (W * 32 bits)
    val fu_cdb_valid          = out Bits (W bits)
    // bypass_network_t alu_bypass[NFB]
    val alu_bypass_flat = out Bits (NFB * 39 bits)
  }
  noIoPrefix()

  def orMux(sel: Bits, data: collection.Seq[Bits]): Bits =
    data.zipWithIndex.map { case (d, i) => Mux(sel(i), d, B(0, d.getWidth bits)) }.reduce(_ | _)

  // combinational sub-component
  val arb = new IssueArbiter(cfg)
  // FU instances (own clk/rst, same clock as the core)
  val alus = (0 until W).map { _ => val a = new FuAlu(cfg); a.io.clk := io.clk; a.io.rst := io.rst; a }

  val coreDomain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(coreDomain) {
    val entries = (0 until D).map(_ => new RsEntry(cfg, RsEntryLayout.int))

    // dispatch entries (pre-extracted, packed Bits(EW))
    val from_ds_entry = (0 until IDW).map(w => io.from_ds_entry_flat(w * EW, EW bits))

    // wakeup CDB vec (shared by all slots)
    val wcdb = Vec(CdbRs(), CDBW)
    for (k <- 0 until CDBW) { wcdb(k).rd_phy := io.cdb_rd_phy_flat(k * 6, 6 bits); wcdb(k).valid := io.cdb_valid(k) }
    // fast bypass = the two ALU bypass nets
    val fb = Vec(BypassNet(), NFB)
    for (k <- 0 until NFB) { fb(k) := BypassNet.fromBits(alus(k).io.bypass) }

    // per-slot wires (entries are opaque Bits(EW) -- generic RsEntry)
    val rs_valid     = Vec(Bool(), D)
    val rs_request   = Vec(Bool(), D)
    val rs_entry_out = Vec(Bits(EW bits), D)
    val rs_entry     = Vec(Bits(EW bits), D)
    val rs_bypass    = Vec(BypassT(), D)
    val push_en  = Vec(Bool(), D)
    val clear    = Vec(Bool(), D)
    val entry_in = Vec(Bits(EW bits), D)

    for (i <- 0 until D) {
      val e = entries(i)
      e.io.grant       := arb.io.rs_grant(i)
      e.io.push_en     := push_en(i)
      e.io.entry_in    := entry_in(i)
      e.io.clear       := clear(i)
      e.io.fast_bypass := fb
      e.io.wakeup_cdb  := wcdb
      rs_valid(i)     := e.io.valid
      rs_request(i)   := e.io.request
      rs_entry_out(i) := e.io.entry_out
      rs_entry(i)     := e.io.entry
      rs_bypass(i)    := e.io.rs_bypass
    }

    // issue arbiter
    arb.io.rs_request := rs_request.asBits
    val rs_grant   = arb.io.rs_grant
    val comp       = (0 until D).map(i => arb.io.rs_compress_flat(i * 2, 2 bits))
    val fu_issue   = (0 until W).map(k => arb.io.fu_issue_flat(k * D, D bits))

    // ready
    val n_avail = (0 until D).map(i => (!rs_valid(i)).asUInt).reduce(_ +^ _)
    io.from_ds_ready := n_avail >= IDW
    val ds_ready = io.from_ds_ready

    // push/pop pointer
    val int_rs_top = Reg(UInt(IDX bits)) init (0)
    val int_rs_valid = (0 until W).map(k => fu_issue(k).orR)         // alu_ready == 1
    val pops = (0 until W).map(k => int_rs_valid(k).asUInt).reduce(_ +^ _)
    val top_after_pop = (int_rs_top - pops).resize(IDX)
    val doPush0 = io.from_ds_valid(0) && ds_ready
    val doPush1 = io.from_ds_valid(1) && ds_ready
    val slot0 = top_after_pop
    val slot1 = (top_after_pop + doPush0.asUInt).resize(IDX)
    int_rs_top := (slot1 + doPush1.asUInt).resize(IDX)

    // one-hot push targets per slot
    val rs_push = Vec(Bits(IDW bits), D)
    for (i <- 0 until D) {
      val sel0 = doPush0 && (slot0 === i)
      val sel1 = doPush1 && (slot1 === i)
      rs_push(i) := sel1 ## sel0
    }
    // push entry per slot (one-hot mux over dispatch slots) -- from_ds_entry is Bits(EW)
    val rs_push_entry = (0 until D).map(i => orMux(rs_push(i), from_ds_entry))

    // compaction / update mux
    for (i <- 0 until D) {
      when(rs_push(i).orR) {                                   // PUSH_IN
        push_en(i) := True;  clear(i) := False; entry_in(i) := rs_push_entry(i)
      } .elsewhen(rs_valid(i) && comp(i).orR) {                // NEXT (shift down)
        when(comp(i) === B"2'b10") {                           // +2
          if (i + 2 < D) { push_en(i) := rs_valid(i + 2); clear(i) := !rs_valid(i + 2); entry_in(i) := rs_entry_out(i + 2) }
          else           { push_en(i) := False; clear(i) := True; entry_in(i) := B(0, EW bits) }
        } otherwise {                                          // +1
          if (i + 1 < D) { push_en(i) := rs_valid(i + 1); clear(i) := !rs_valid(i + 1); entry_in(i) := rs_entry_out(i + 1) }
          else           { push_en(i) := False; clear(i) := True; entry_in(i) := B(0, EW bits) }
        }
      } .otherwise {                                           // SELF
        push_en(i) := False; clear(i) := False; entry_in(i) := B(0, EW bits)
      }
    }

    // issued entry + bypass (one-hot mux over slots, per issue port)
    val issued = (0 until W).map(k => IntRsEntry.fromBits(orMux(fu_issue(k), rs_entry)))
    val rs1_value = (0 until W).map(k => io.to_prf_rs1_value_flat(k * 32, 32 bits))
    val rs2_value = (0 until W).map(k => io.to_prf_rs2_value_flat(k * 32, 32 bits))

    for (k <- 0 until W) {
      io.to_prf_rs1_phy_flat(k * 6, 6 bits) := issued(k).rs1_phy
      io.to_prf_rs2_phy_flat(k * 6, 6 bits) := issued(k).rs2_phy
      io.to_prf_rs_bypass_flat(k * 14, 14 bits) := orMux(fu_issue(k), rs_bypass.map(_.toBits))

      // fu_alu_reg_t (SV layout): rob_id rd_arch rd_phy fu_opcode op1_sel op2_sel imm rs1 rs2
      val falu = issued(k).rob_id ## issued(k).rd_arch ## issued(k).rd_phy ## issued(k).fu_opcode ##
                 issued(k).op1_sel ## issued(k).op2_sel ## issued(k).imm ## rs1_value(k) ## rs2_value(k)
      alus(k).io.int_rs_valid  := int_rs_valid(k)
      alus(k).io.fu_alu_reg_in := falu

      io.fu_cdb_rob_id_flat(k * 6, 6 bits)   := alus(k).io.cdb_rob_id
      io.fu_cdb_rd_phy_flat(k * 6, 6 bits)   := alus(k).io.cdb_rd_phy
      io.fu_cdb_rd_arch_flat(k * 5, 5 bits)  := alus(k).io.cdb_rd_arch
      io.fu_cdb_rd_value_flat(k * 32, 32 bits) := alus(k).io.cdb_rd_value
      io.fu_cdb_rs1_dbg_flat(k * 32, 32 bits)  := alus(k).io.cdb_rs1_value_dbg
      io.fu_cdb_rs2_dbg_flat(k * 32, 32 bits)  := alus(k).io.cdb_rs2_value_dbg
      io.fu_cdb_valid(k) := alus(k).io.cdb_valid

      io.alu_bypass_flat(k * 39, 39 bits) := alus(k).io.bypass
    }
  }
}
