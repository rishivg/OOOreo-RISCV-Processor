package ooo.frontend

import spinal.core._
import ooo.{CpuConfig,OhSel}

/** Complete alignment and dispatch predecode before the cache-way selection. */
class FetchPayload(cfg: CpuConfig) extends Component {
  setDefinitionName("fetch_payload_spinal")
  val IFW=cfg.ifWidth;val PMAX=2 * IFW;val LZ=log2Up(IFW * 4)
  val io=new Bundle {
    val inst_arms=in Bits((cfg.iFetchWays + 1) * IFW * 32 bits)
    val arm_select=in Bits(cfg.iFetchWays + 1 bits)
    val pc=in Bits(32 bits);val carry_valid=in Bool()
    val carry_lo=in Bits(16 bits);val carry_pc=in Bits(32 bits)
    val inst=out Bits(IFW * 32 bits);val raw=out Bits(IFW * 32 bits)
    val inst_pc=out Bits(IFW * 32 bits);val comp=out Bits(IFW bits)
    val span_lo=out Bits(16 bits);val pre=out Bits(IFW * DispatchPredecode.width bits)
  }
  noIoPrefix()
  val po=io.pc(LZ - 1 downto 1).asUInt
  val fetchPc=Mux(io.carry_valid,io.carry_pc,io.pc)
  val nValid=Mux(io.carry_valid,U(PMAX,cfg.parcelCntW bits),
    (U(PMAX,cfg.parcelCntW bits)-po).resize(cfg.parcelCntW bits))
  def windowOf(block: Bits): Vec[Bits] = {
    val raw=block.subdivideIn(PMAX slices);val window=Vec(Bits(16 bits),PMAX)
    when(io.carry_valid) {
      window(0):=io.carry_lo
      for(k <- 1 until PMAX)window(k):=raw(k - 1)
    }.otherwise {
      for(k <- 0 until PMAX) {
        window(k):=0
        when((po +^ k)<PMAX) {window(k):=raw((po+k).resize(log2Up(PMAX) bits))}
      }
    }
    window
  }
  def align(block: Bits): FetchAlign = {
    val u=new FetchAlign(cfg,flowOutputs=false,indicesOnly=cfg.frontendLaneDecode)
    val window=windowOf(block)
    u.io.pc:=(if (cfg.frontendLaneDecode) B(0,32 bits) else fetchPc)
    u.io.parcels:=(if (cfg.frontendLaneDecode) Vec(window.map(_(1 downto 0))).asBits else window.asBits)
    u.io.n_valid:=nValid.asBits
    u
  }
  val blocks=io.inst_arms.subdivideIn(cfg.iFetchWays + 1 slices).toSeq
  val aligners=blocks.map(align)
  def selected(field: FetchAlign => Bits): Bits = OhSel(io.arm_select,aligners.map(field))
  val early = if (cfg.frontendLaneDecode) blocks.zip(aligners).map { case (block,u) =>
    val parcels=block.subdivideIn(PMAX slices)
    def pair(low: Bits,high: Bits): Bits = Mux(
      if (cfg.cExt) low(1 downto 0) =/= B"2'b11" else False,
      B(0,16 bits) ## low,high ## low)
    // Slot starts are at most 2*(IFW-1), so window wrap cannot affect a slot payload.
    val rawCases=(0 until PMAX).map(p => pair(parcels(p),
      if (p + 1 < PMAX) parcels(p + 1) else B(0,16 bits))) ++
      Seq(B(0,32 bits),pair(io.carry_lo,parcels(0)))
    val expanded=Vec(Bits(32 bits),PMAX + 2)
    val controls=Vec(Bits(DispatchPredecode.width bits),PMAX + 2)
    for (p <- rawCases.indices) {
      if (cfg.cExt) {
        val d=new Decompressor
        d.io.inst_in:=rawCases(p);expanded(p):=d.io.inst_out
      } else expanded(p):=rawCases(p)
      controls(p):=DispatchPredecode.decodeParcel(rawCases(p),cfg)
      expanded(p).addAttribute("keep");controls(p).addAttribute("keep")
    }
    val inst=Vec(Bits(32 bits),IFW)
    val pre=Vec(Bits(DispatchPredecode.width bits),IFW)
    val indices=u.io.parcel_index.subdivideIn(IFW slices)
    val selectWidth=log2Up(PMAX + 2)
    for (s <- 0 until IFW) {
      val index=indices(s).asUInt
      val absolute=po +^ index
      val fromBlock=Mux(absolute < PMAX,absolute.resize(selectWidth bits),U(PMAX,selectWidth bits))
      val fromCarry=Mux(index===0,U(PMAX + 1,selectWidth bits),(index - 1).resize(selectWidth bits))
      val selected=Mux(io.carry_valid,fromCarry,fromBlock)
      inst(s):=expanded(selected);pre(s):=controls(selected)
    }
    (inst.asBits,pre.asBits)
  } else Seq.empty[(Bits,Bits)]
  io.inst:=(if (cfg.frontendLaneDecode) OhSel(io.arm_select,early.map(_._1)) else selected(_.io.inst))
  if (cfg.frontendLaneDecode) {
    val window=windowOf(OhSel(io.arm_select,blocks))
    val indices=OhSel(io.arm_select,aligners.map(_.io.parcel_index)).subdivideIn(IFW slices)
    val raw=Vec(Bits(32 bits),IFW);val pcs=Vec(Bits(32 bits),IFW)
    for (s <- 0 until IFW) {
      val index=indices(s).asUInt
      val low=window(index);val high=window((index + 1).resize(log2Up(PMAX) bits))
      val compressed=if (cfg.cExt) low(1 downto 0) =/= B"2'b11" else False
      raw(s):=Mux(compressed,B(0,16 bits) ## low,high ## low)
      pcs(s):=ooo.FastAdd.bits(fetchPc.asUInt,(index << 1).resize(32 bits),keepPrefix= !cfg.fpgaNativeAdd)
    }
    io.raw:=raw.asBits;io.inst_pc:=pcs.asBits
    io.span_lo:=window(OhSel(io.arm_select,aligners.map(_.io.span_index)).asUInt)
  } else {
    io.raw:=selected(_.io.inst_raw);io.inst_pc:=selected(_.io.inst_pc)
    io.span_lo:=selected(_.io.span_lo)
  }
  io.comp:=selected(_.io.inst_comp)
  val pre=aligners.zipWithIndex.map { case (u,index) =>
    if (cfg.frontendLaneDecode) early(index)._2
    else Vec((0 until IFW).map(i => DispatchPredecode.decode(u.io.inst(i * 32,32 bits),cfg))).asBits
  }
  io.pre:=OhSel(io.arm_select,pre)
}
