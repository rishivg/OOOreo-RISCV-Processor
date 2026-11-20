package ooo.frontend

import spinal.core._
import ooo.{CpuConfig, FastAdd}

/** Align compressed and 32-bit instructions across fetch boundaries. */
class FetchAlign(cfg: CpuConfig = CpuConfig(), flowOutputs: Boolean = true, indicesOnly: Boolean = false) extends Component {
  setDefinitionName(if (indicesOnly) "fetch_align_indices" else if (flowOutputs) "fetch_align" else "fetch_align_payload")
  if (cfg.keepTimingHierarchy) addAttribute("keep_hierarchy", "yes")
  require(!indicesOnly || !flowOutputs)
  val IFW  = cfg.ifWidth
  val PMAX = 2 * IFW
  val PIDX = log2Up(PMAX + 1)
  val PCW  = cfg.parcelCntW
  val io = new Bundle {
    val pc         = in  Bits (32 bits)
    val parcels    = in  Bits (PMAX * (if (indicesOnly) 2 else 16) bits)
    val n_valid    = in  Bits (PCW bits)
    val inst       = out Bits (IFW * 32 bits)
    val inst_raw   = out Bits (IFW * 32 bits)
    val inst_pc    = out Bits (IFW * 32 bits)
    val inst_comp  = out Bits (IFW bits)
    val inst_valid = out Bits (IFW bits)
    val inst_pre = if (cfg.frontendLaneDecode && !indicesOnly) out Bits(IFW * DispatchPredecode.width bits) else null
    val parcel_index = if (indicesOnly) out Bits(IFW * log2Up(PMAX) bits) else null
    val span_index = if (indicesOnly) out Bits(log2Up(PMAX) bits) else null
    val seq_next   = out Bits (IFW * 32 bits)
    val consumed   = out Bits (PCW bits)
    val span       = out Bool ()
    val span_lo    = out Bits (16 bits)
    val span_pc    = out Bits (32 bits)
    val next_pc    = out Bits (32 bits)
  }
  noIoPrefix()

  val parcelsVec = io.parcels.subdivideIn(PMAX slices)   // parcel(0) at LSB == pc
  def par(i: UInt): Bits = {
    val value = parcelsVec(i.resize(log2Up(PMAX) bits))
    if (indicesOnly) B(0,14 bits) ## value else value
  }   // reads only hit 0..PMAX-1

  val nValid = io.n_valid.asUInt
  val pcU    = io.pc.asUInt

  // Compute instruction boundaries with a prefix network.
  val comp32 = Vec(Bool(), PMAX)                         // parcel p begins a 16-bit op
  val nxtPos = Vec(UInt(PIDX bits), PMAX)               // j1: unstopped next start from p
  for (p <- 0 until PMAX) {
    // cExt off -> every op is 32-bit (2 parcels), so the walk uses a fixed +2 stride.
    comp32(p) := (if (cfg.cExt) (parcelsVec(p)(1 downto 0) =/= B"2'b11") else False)
    nxtPos(p) := (U(p, PIDX bits) + Mux(comp32(p), U(1, PIDX bits), U(2, PIDX bits))).resize(PIDX bits)
  }
  def comp(i: UInt): Bool = comp32(i.resize(log2Up(PMAX) bits))
  def balancedOr(xs: Seq[UInt]): UInt =
    if (xs.length == 1) xs.head else { val (l, r) = xs.splitAt(xs.length / 2); balancedOr(l) | balancedOr(r) }

  // jump(k)(p) is the parcel 2^k instructions ahead of p. Compose the levels
  // selected by s's set bits to find start(s) in at most LOGW+1 lookups.
  val LOGW = log2Up(IFW)
  val jump = Array.tabulate(LOGW + 1)(_ => Vec(UInt(PIDX bits), PMAX))
  for (p <- 0 until PMAX) jump(0)(p) := nxtPos(p)
  for (k <- 1 to LOGW; p <- 0 until PMAX)
    jump(k)(p) := jump(k - 1)(jump(k - 1)(p).resize(log2Up(PMAX) bits))

  val start = Vec(UInt(PIDX bits), IFW + 1)              // slot start parcel indices
  for (s <- 0 to IFW) {
    var cur: UInt = U(0, PIDX bits)
    for (k <- 0 to LOGW if (s & (1 << k)) != 0) cur = jump(k)(cur.resize(log2Up(PMAX) bits))
    start(s) := cur
  }

  // per-slot validity condition (parallel), then monotone inclusive prefix-AND
  // (Hillis-Steele, depth ceil(log2 IFW)): instValid(s) == AND(cond(0..s)).
  val cond = (0 until IFW).map { s =>
    val idx = start(s); val hi = (idx + 1).resize(PIDX bits)
    (idx < nValid) && (comp(idx) || (hi < nValid))
  }.toArray
  var pv = cond.clone()
  var dd = 1
  while (dd < IFW) { pv = Array.tabulate(IFW)(s => if (s >= dd) pv(s) && pv(s - dd) else pv(s)); dd *= 2 }
  val instValid = Vec(Bool(), IFW)
  for (s <- 0 until IFW) instValid(s) := pv(s)

  // Derive each slot's outputs in parallel from start(s).
  val instComp = Vec(Bool(), IFW)
  val instPc   = Vec(Bits(32 bits), IFW)
  val seqNext  = if (flowOutputs) Vec(Bits(32 bits), IFW) else null
  val raw      = Vec(Bits(32 bits), IFW)
  for (s <- 0 until IFW) {
    val idx = start(s); val hi = (idx + 1).resize(PIDX bits); val compS = comp(idx)
    instComp(s) := compS
    raw(s)      := Mux(compS, B(0, 16 bits) ## par(idx), par(hi) ## par(idx))
    val ipc = if (indicesOnly) B(0,32 bits) else FastAdd.bits(pcU, (idx << 1).resize(32 bits), keepPrefix = !cfg.fpgaNativeAdd)
    instPc(s)   := ipc
    if (flowOutputs) seqNext(s) := FastAdd.bits(ipc.asUInt, Mux(compS, U(2, 32 bits), U(4, 32 bits)), keepPrefix = !cfg.fpgaNativeAdd)
  }

  // instValid is a monotone prefix: select start(numValid) with a balanced OR.
  val csel = (0 to IFW).map { s =>
    val pick = if (s == 0) !instValid(0)
               else if (s == IFW) instValid(IFW - 1)
               else instValid(s - 1) && !instValid(s)
    Mux(pick, start(s), U(0, PIDX bits))
  }
  val consumedU = balancedOr(csel)                       // start_idx[IF_WIDTH]

  // span: trailing 32-bit op whose high parcel lies past the valid window
  val bIdx     = Mux(consumedU < U(PMAX, PIDX bits), consumedU, U(0, PIDX bits))
  val boundary = par(bIdx)
  io.span := (if (cfg.cExt)
                (!instValid(IFW - 1) && (consumedU < nValid) &&
                 (boundary(1 downto 0) === B"2'b11") &&
                 ((consumedU.resize(PIDX + 1 bits) + 1) >= nValid.resize(PIDX + 1 bits)))
              else False)
  io.span_lo := (if (indicesOnly) B(0,16 bits) else boundary)
  if (indicesOnly) io.span_index := bIdx.resize(log2Up(PMAX) bits).asBits
  io.span_pc := (if (flowOutputs) FastAdd.bits(pcU, (consumedU << 1).resize(32 bits), keepPrefix = !cfg.fpgaNativeAdd) else B(0,32 bits))

  val instVec = Vec(Bits(32 bits), IFW)
  if (indicesOnly) {
    instVec.foreach(_ := 0)
    io.parcel_index := Vec((0 until IFW).map(s => start(s).resize(log2Up(PMAX) bits).asBits)).asBits
  } else if (cfg.frontendLaneDecode) {
    // Length-dependent slot selection follows decompression and dispatch decode.
    val expanded = Vec(Bits(32 bits), PMAX)
    val pre = Vec(Bits(DispatchPredecode.width bits), PMAX)
    for (p <- 0 until PMAX) {
      val pair = Mux(comp32(p), B(0,16 bits) ## parcelsVec(p),
        parcelsVec((p + 1) % PMAX) ## parcelsVec(p))
      if (cfg.cExt) {
        val d = new Decompressor
        d.io.inst_in := pair
        expanded(p) := d.io.inst_out
      } else expanded(p) := pair
      pre(p) := DispatchPredecode.decodeParcel(pair,cfg)
      if (cfg.keepTimingHierarchy) {
        expanded(p).addAttribute("keep")
        pre(p).addAttribute("keep")
      }
    }
    val selectedPre = Vec(Bits(DispatchPredecode.width bits),IFW)
    for (s <- 0 until IFW) {
      val index = start(s).resize(log2Up(PMAX) bits)
      instVec(s) := expanded(index)
      selectedPre(s) := pre(index)
    }
    io.inst_pre := selectedPre.asBits
  } else if (cfg.cExt) {
    for (gi <- 0 until IFW) {
      val d = new Decompressor
      d.io.inst_in := raw(gi)
      instVec(gi) := d.io.inst_out
    }
  } else {
    for (gi <- 0 until IFW) instVec(gi) := raw(gi)
  }

  io.inst       := instVec.asBits
  io.inst_raw   := (if (indicesOnly) B(0,IFW * 32 bits) else raw.asBits)
  io.inst_pc    := instPc.asBits
  io.inst_comp  := instComp.asBits
  io.inst_valid := instValid.asBits
  io.seq_next   := (if (flowOutputs) seqNext.asBits else B(0,IFW * 32 bits))
  io.consumed   := consumedU.asBits
  io.next_pc    := (if (flowOutputs) FastAdd.bits(pcU, (consumedU << 1).resize(32 bits), keepPrefix = !cfg.fpgaNativeAdd) else B(0,32 bits))
}
