package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/execute/int_rs/issue_arbiter.sv` -- the INT-RS
  * oldest-first 2-wide issue selector + compaction control. First int_rs subsystem
  * component (single instance in int_rs).
  *
  * The SV outputs are UNPACKED arrays (rs_compress [INTRS_DEPTH] of [1:0],
  * fu_issue [INT_ISSUE_WIDTH] of [INTRS_DEPTH]); SpinalHDL can't emit an unpacked-array
  * port, so this module (named issue_arbiter_spinal) outputs them FLATTENED and
  * sim/swap_shims/issue_arbiter.sv un-flattens into the unpacked-array ports.
  *   rs_compress_flat[2i+1:2i] = rs_compress[i]
  *   fu_issue_flat[16w+15:16w]  = fu_issue[w]
  *
  * Hardcoded 2-wide (matches the SV: fu_issue[0]/[1], prev_assigned 2-bit).
  */
class IssueArbiter(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("issue_arbiter_spinal")
  val D = cfg.intrsDepth         // INTRS_DEPTH = 16
  val W = cfg.intIssueWidth      // INT_ISSUE_WIDTH = 2
  require(W == 2, "issue_arbiter port is hardcoded 2-wide")

  val io = new Bundle {
    val rs_request       = in  Bits (D bits)
    val rs_grant         = out Bits (D bits)
    val rs_compress_flat = out Bits (2 * D bits)
    val fu_issue_flat    = out Bits (W * D bits)
  }
  noIoPrefix()

  val req = io.rs_request

  // Shared exclusive prefix-OR: out(i) = OR(in(0..i-1)). One running accumulator
  // instead of D independent `.orR` slices (O(D) gates vs O(D^2)). Bit-identical.
  def exPrefixOr(in: collection.Seq[Bool]): Seq[Bool] = {
    val out = Array.fill(in.length)(False: Bool)
    var acc: Bool = False
    for (i <- in.indices) { out(i) = acc; acc = acc | in(i) }
    out.toSeq
  }

  // ge1(j) = any request strictly below j ; second(j) = j is a 2nd-or-later requester
  val ge1    = Vec(Bool(), D)
  val second = Vec(Bool(), D)
  val ge1Pre = exPrefixOr((0 until D).map(j => req(j)))
  for (j <- 0 until D) {
    ge1(j)    := ge1Pre(j)
    second(j) := req(j) && ge1(j)
  }
  val secondBits = second.asBits

  val grant = Vec(Bool(), D)
  val fu0   = Vec(Bool(), D)
  val fu1   = Vec(Bool(), D)
  val pa0   = Vec(Bool(), D)
  val pa1   = Vec(Bool(), D)
  val pa1Pre = exPrefixOr((0 until D).map(i => second(i)))
  for (i <- 0 until D) {
    pa0(i) := ge1(i)
    pa1(i) := pa1Pre(i)
    grant(i) := False; fu0(i) := False; fu1(i) := False
    when(!pa0(i) && req(i))      { grant(i) := True; fu0(i) := True }
    .elsewhen(!pa1(i) && req(i)) { grant(i) := True; fu1(i) := True }
  }

  // rs_compress[i] from prev_assigned[i] = {pa1, pa0}
  val comp_init = Vec(Bits(2 bits), D)
  for (i <- 0 until D) {
    switch(pa1(i) ## pa0(i)) {
      is(B"2'b00") { comp_init(i) := Mux(grant(i), B"2'b01", B"2'b00") }
      is(B"2'b01") { comp_init(i) := Mux(grant(i), B"2'b10", B"2'b01") }
      is(B"2'b11") { comp_init(i) := B"2'b10" }
      default      { comp_init(i) := B"2'b00" }  // {pa1=1,pa0=0} impossible; SV had 'x
    }
  }
  // consecutive-pop corner case (read comp_init, not comp -> no comb loop)
  val comp = Vec(Bits(2 bits), D)
  for (i <- 0 until D) {
    if (i < D - 1)
      comp(i) := Mux(comp_init(i) =/= B"2'b00" && grant(i + 1), B"2'b10", comp_init(i))
    else
      comp(i) := comp_init(i)
  }

  io.rs_grant         := grant.asBits
  io.rs_compress_flat := comp.asBits                 // element i at [2i+1:2i]
  io.fu_issue_flat    := fu1.asBits ## fu0.asBits    // [2D-1:D]=fu1, [D-1:0]=fu0
}
