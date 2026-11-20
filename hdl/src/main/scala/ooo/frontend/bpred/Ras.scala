package ooo.frontend.bpred

import spinal.core._
import ooo.{CpuConfig, OhSel}

/** Speculative and committed return-address stacks with recovery. */
class Ras(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ras_spinal")
  val IFW   = cfg.ifWidth
  val DEPTH = cfg.rasDepth
  val IDX   = cfg.rasIdx
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val flush      = in Bool()
    val fetch_fire = in Bool()
    val seq_next   = in Bits (IFW * 32 bits)
    // inst_valid must be a thermometer prefix. Higher-slot predictor/state reads are
    // only observable for those valid slots.
    val inst_valid = in Bits (IFW bits)
    // Raw call/return predecode keeps decompression off the prediction path.
    val is_call    = in Bits (IFW bits)
    val is_ret     = in Bits (IFW bits)
    val predict_taken_in   = in Bits (IFW bits)
    val predict_target_in  = in Bits (IFW * 32 bits)
    val case_taken_in = if (cfg.frontendPredictCofactors) Vec(in Bits(IFW bits),2) else null
    val case_target_in = if (cfg.frontendPredictCofactors) Vec(in Bits(IFW*32 bits),2) else null
    val case_initialized_in = if (cfg.frontendPredictCofactors) Vec(in Bits(IFW bits),2) else null
    val case_taken_out = if (cfg.frontendPredictCofactors) Vec(out Bits(IFW bits),2) else null
    val case_target_out = if (cfg.frontendPredictCofactors) Vec(out Bits(IFW*32 bits),2) else null
    val case_initialized_out = if (cfg.frontendPredictCofactors) Vec(out Bits(IFW bits),2) else null
    val predict_taken_out  = out Bits (IFW bits)
    val predict_target_out = out Bits (IFW * 32 bits)
    val initialized_bitmap = if (cfg.frontendLaneValidity) in Bits((1 << cfg.iSetIdx) bits) else null
    val predict_initialized_in = if (cfg.frontendLaneValidity) in Bits(IFW bits) else null
    val predict_initialized_out = if (cfg.frontendLaneValidity) out Bits(IFW bits) else null
    val from_cb_update_en     = in Bool()
    val from_cb_pc            = in Bits (32 bits)
    val from_cb_is_call       = in Bool()
    val from_cb_is_ret        = in Bool()
    val from_cb_is_compressed = in Bool()
  }
  noIoPrefix()

  val seqNext   = io.seq_next.subdivideIn(IFW slices)
  val ptgtIn    = io.predict_target_in.subdivideIn(IFW slices)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val rasSpecMem   = Vec(Reg(Bits(32 bits)), DEPTH)
    val rasCommitMem = Vec(Reg(Bits(32 bits)), DEPTH)
    val tosSpec   = RegInit(U(0, IDX bits))
    val tosCommit = RegInit(U(0, IDX bits))

    // speculative stack update across the fetched slots, in program order
    val ptOut   = Vec(Bool(), IFW)
    val ptgtOut = Vec(Bits(32 bits), IFW)
    val pushEn  = Vec(Bool(), IFW)
    val pushIdx = Vec(UInt(IDX bits), IFW)
    val pushVal = Vec(Bits(32 bits), IFW)

    // Decode the early pointer once; rotate narrow selectors instead of stack data.
    val offsets = (-(IFW - 1) until IFW).map(k => (k % DEPTH + DEPTH) % DEPTH).distinct.sorted
    val pointerOh = Vec((0 until DEPTH).map(p => tosSpec === p)).asBits
    val stackAt = rasSpecMem.toSeq

    val initializedAt=if (cfg.frontendLaneValidity) {
      rasSpecMem.map(pc => ooo.common.CacheValidityLookup(io.initialized_bitmap,pc,cfg).asBits).toSeq
    } else Seq.empty[Bits]

    // Compute stack deltas for every valid slot. The first taken branch gates speculative
    // state writes, while the read walk remains independent of that late decision.
    def sum(values: Seq[UInt]): UInt = {
      if (values.isEmpty) U(0, IDX bits)
      else if (values.length == 1) values.head
      else {
        val (a, b) = values.splitAt(values.length / 2)
        (sum(a) + sum(b)).resize(IDX bits)
      }
    }
    val deltas = (0 until IFW).map(i =>
      (io.is_call(i).asUInt.resize(IDX) - io.is_ret(i).asUInt.resize(IDX)).resize(IDX))
    val prefOh = (0 until IFW).map { k =>
      val delta = sum(deltas.take(k))
      Vec(offsets.map(offset => delta === U(offset, IDX bits))).asBits
    }
    // thermometer decode: nEq(k) == "exactly k leading valid slots" (k < IFW),
    // nEq(IFW) == "all IFW valid". Exactly one holds under the precondition.
    val nEq = Vec(Bool(), IFW + 1)
    nEq(0) := !io.inst_valid(0)
    for (k <- 1 until IFW) nEq(k) := io.inst_valid(k - 1) && !io.inst_valid(k)
    nEq(IFW) := io.inst_valid(IFW - 1)

    for (i <- 0 until IFW) {
      val doRetU = io.inst_valid(i) && io.is_ret(i)
      ptOut(i) := doRetU || io.predict_taken_in(i)
      // min(i,n): take prefOh(i) when n >= i (== inst_valid(i-1), thermometer),
      // else prefOh(n). Exactly one arm -- the k<i arms are the disjoint nEq(k).
      val kSel = Vec(Bool(), i + 1)
      for (k <- 0 until i) kSel(k) := nEq(k)
      kSel(i) := (if (i == 0) True else io.inst_valid(i - 1))
      val dOhU = if (i == 0) prefOh(0) else OhSel(kSel.asBits, (0 to i).map(prefOh(_)))
      val sel = Vec(Bool(), DEPTH + 1)
      for (entry <- 0 until DEPTH) {
        val selected = offsets.zipWithIndex.map { case (offset, b) =>
          dOhU(b) && pointerOh((entry - offset + DEPTH) % DEPTH)
        }.reduce(_ || _)
        sel(entry) := doRetU && selected
      }
      sel(DEPTH) := !doRetU
      ptgtOut(i) := OhSel(sel.asBits, stackAt :+ ptgtIn(i))
      if (cfg.frontendPredictCofactors) for (direction <- 0 until 2) {
        io.case_taken_out(direction)(i):=doRetU || io.case_taken_in(direction)(i)
        io.case_target_out(direction)(i*32,32 bits):=
          OhSel(sel.asBits,stackAt :+ io.case_target_in(direction)(i*32,32 bits))
        io.case_initialized_out(direction)(i):=
          OhSel(sel.asBits,initializedAt :+ io.case_initialized_in(direction)(i).asBits)(0)
      }
      if (cfg.frontendLaneValidity) io.predict_initialized_out(i):=
        OhSel(sel.asBits,initializedAt :+ io.predict_initialized_in(i).asBits)(0)
    }

    // WRITE side: the ORIGINAL takenSeen-cut serial chain, bit-identical
    // (pushEn/pushIdx/tosNext are flop inputs with slack; a post-taken slot's
    // call/ret must NOT move the stack, so the cut stays load-bearing here).
    var t: UInt = tosSpec
    var takenSeen: Bool = False
    for (i <- 0 until IFW) {
      val active = io.inst_valid(i) && !takenSeen
      val doRet  = active && io.is_ret(i)
      val doCall = active && io.is_call(i)
      val tAfterRet  = Mux(doRet, t - 1, t)
      val tAfterCall = Mux(doCall, tAfterRet + 1, tAfterRet)
      pushEn(i)  := doCall
      pushIdx(i) := tAfterCall
      pushVal(i) := seqNext(i)
      t = tAfterCall
      takenSeen = takenSeen || doRet || (active && io.predict_taken_in(i))
    }
    val tosNext = t

    io.predict_taken_out  := ptOut.asBits
    io.predict_target_out := ptgtOut.asBits

    // committed stack: advanced only by resolved (in-order) calls/returns
    val commitRetAddr = ooo.FastAdd.pcNext(io.from_cb_pc,io.from_cb_is_compressed,cfg.fpgaNativeAdd)
    val tosCommitNext = UInt(IDX bits); tosCommitNext := tosCommit
    when(io.from_cb_update_en && io.from_cb_is_ret)  { tosCommitNext := tosCommit - 1 }
    when(io.from_cb_update_en && io.from_cb_is_call) { tosCommitNext := tosCommit + 1 }

    // pointer flops (ungated)
    tosCommit := tosCommitNext
    when(io.flush)            { tosSpec := tosCommitNext }
    .elsewhen(io.fetch_fire)  { tosSpec := tosNext }

    // Speculative and committed stacks use enabled registers.
    when(io.from_cb_update_en && io.from_cb_is_call) {
      rasCommitMem(tosCommitNext) := commitRetAddr
    }
    when(io.flush) {
      for (i <- 0 until DEPTH) {
        rasSpecMem(i) := Mux(
          io.from_cb_update_en && io.from_cb_is_call && (U(i, IDX bits) === tosCommitNext),
          commitRetAddr, rasCommitMem(i))
      }
    }.elsewhen(io.fetch_fire) {
      for (i <- 0 until IFW) {
        when(pushEn(i)) { rasSpecMem(pushIdx(i)) := pushVal(i) }
      }
    }
  }
}
