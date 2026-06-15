package ooo.frontend

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/frontend/fetch_align.sv` -- the C-extension fetch
  * realignment core (combinational). Walks up to 2*IF_WIDTH 16-bit parcels in
  * program order, extracting up to IF_WIDTH instructions (32-bit when parcel[1:0]==
  * 2'b11 else compressed), expands each through a `decompressor`, tags it with its
  * PC, and reports consumed/next_pc plus the block-boundary "span" carry.
  *
  * Combinational-only (no clk/reset). All ports are packed/scalar, so it is named
  * `fetch_align` and drops in by-name (Verilator connects the SV packed-2D nets to
  * the flat Bits ports). It instantiates the SpinalHDL `Decompressor` (emitted as
  * module `decompressor`), so the swap build EXTRA_EXCLUDEs the real decompressor.sv.
  */
class FetchAlign(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fetch_align")
  val IFW  = cfg.ifWidth        // 4
  val PMAX = 2 * IFW            // 8
  val PIDX = log2Up(PMAX + 1)   // 4
  val PCW  = cfg.parcelCntW     // 4

  val io = new Bundle {
    val pc         = in  Bits (32 bits)
    val parcels    = in  Bits (PMAX * 16 bits)
    val n_valid    = in  Bits (PCW bits)
    val inst       = out Bits (IFW * 32 bits)
    val inst_raw   = out Bits (IFW * 32 bits)
    val inst_pc    = out Bits (IFW * 32 bits)
    val inst_comp  = out Bits (IFW bits)
    val inst_valid = out Bits (IFW bits)
    val seq_next   = out Bits (IFW * 32 bits)
    val consumed   = out Bits (PCW bits)
    val span       = out Bool ()
    val span_lo    = out Bits (16 bits)
    val span_pc    = out Bits (32 bits)
    val next_pc    = out Bits (32 bits)
  }
  noIoPrefix()

  val parcelsVec = io.parcels.subdivideIn(PMAX slices)   // parcel(0) at LSB == pc
  def par(i: UInt): Bits = parcelsVec(i.resize(log2Up(PMAX) bits))   // reads only hit 0..PMAX-1

  val nValid = io.n_valid.asUInt
  val pcU    = io.pc.asUInt

  val instComp  = Vec(Bool(), IFW)
  val instValid = Vec(Bool(), IFW)
  val instPc    = Vec(Bits(32 bits), IFW)
  val seqNext   = Vec(Bits(32 bits), IFW)
  val raw       = Vec(Bits(32 bits), IFW)

  // sequential walk over the parcels (Scala fold carries start index + still-valid)
  var idx: UInt = U(0, PIDX bits)
  var stillValid: Bool = True
  for (s <- 0 until IFW) {
    val hi    = (idx + 1).resize(PIDX bits)
    val p     = par(idx)
    val compS = p(1 downto 0) =/= B"2'b11"
    val loOk  = idx < nValid
    val hiOk  = hi  < nValid
    val thisValid = stillValid && loOk && (compS || hiOk)
    instComp(s)  := compS
    instValid(s) := thisValid
    raw(s)       := Mux(compS, B(0, 16 bits) ## p, par(hi) ## p)
    val ipc = (pcU + (idx << 1).resize(32 bits)).asBits
    instPc(s)    := ipc
    seqNext(s)   := (ipc.asUInt + Mux(compS, U(2, 32 bits), U(4, 32 bits))).asBits
    val nextIdx = Mux(thisValid, (idx + Mux(compS, U(1, PIDX bits), U(2, PIDX bits))).resize(PIDX bits), idx)
    stillValid = stillValid && thisValid
    idx = nextIdx
  }
  val consumedU = idx                                    // start_idx[IF_WIDTH]

  // span: trailing 32-bit op whose high parcel lies past the valid window
  val bIdx     = Mux(consumedU < U(PMAX, PIDX bits), consumedU, U(0, PIDX bits))
  val boundary = par(bIdx)
  io.span := !instValid(IFW - 1) && (consumedU < nValid) &&
             (boundary(1 downto 0) === B"2'b11") &&
             ((consumedU.resize(PIDX + 1 bits) + 1) >= nValid.resize(PIDX + 1 bits))
  io.span_lo := boundary
  io.span_pc := (pcU + (consumedU << 1).resize(32 bits)).asBits

  // expand each extracted instruction
  val instVec = Vec(Bits(32 bits), IFW)
  for (gi <- 0 until IFW) {
    val d = new Decompressor
    d.io.inst_in := raw(gi)
    instVec(gi) := d.io.inst_out      // d.io.is_compressed unused (inst_comp comes from compS)
  }

  io.inst       := instVec.asBits
  io.inst_raw   := raw.asBits
  io.inst_pc    := instPc.asBits
  io.inst_comp  := instComp.asBits
  io.inst_valid := instValid.asBits
  io.seq_next   := seqNext.asBits
  io.consumed   := consumedU.asBits
  io.next_pc    := (pcU + (consumedU << 1).resize(32 bits)).asBits
}
