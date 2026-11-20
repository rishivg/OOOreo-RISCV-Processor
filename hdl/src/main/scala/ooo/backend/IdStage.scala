package ooo.backend

import spinal.core._
import ooo.CpuConfig
import ooo.backend.decode.DecoderPayload

/** Decode, dependency filtering, and two-wide dispatch admission. */
class IdStage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("id_stage_spinal")
  val IDW = cfg.idWidth
  val AIDX = cfg.arfIdx
  val PIDX = cfg.prfIdx
  def RS_BR = B"2'b10"; def RS_MEM = B"2'b11"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_fifo_valid = in Bool()
    val from_fifo_inst_flat = in Bits (IDW * 32 bits)
    val from_fifo_decoded_flat = if (cfg.iqParallelDecode) in Bits(IDW * DecoderPayload.width(cfg) bits) else null
    val from_fifo_valid_slots = in Bits (IDW bits)
    // enqueue-time pre-decode from the IQ (see InstQueue.preDecode). These
    // are value-identical to the local Decoder's rs_type / is_store / is_atomic
    // and to (rd_arch =/= 0), but arrive at the cycle start instead of after an
    // opcode decode of the IQ read data.
    val from_fifo_pre_rs_type_flat = in Bits (IDW * 2 bits)
    val from_fifo_pre_is_store     = in Bits (IDW bits)
    val from_fifo_pre_is_atomic    = in Bits (IDW bits)
    val from_fifo_pre_has_rd       = in Bits (IDW bits)
    val from_fifo_ready = out Bool()
    val nxt_valid = out Bool(); val nxt_ready = in Bool()
    val to_fl_ready = in Bool(); val to_fl_free_idx_flat = in Bits (IDW * PIDX bits)
    val to_rob_ready = in Bool()
    // Decoded micro-operations
    val rs_type_flat   = out Bits (IDW * 2 bits)
    val fu_type_flat   = out Bits (IDW * 2 bits)
    val fu_opcode_flat = out Bits (IDW * 4 bits)
    val op1_sel        = out Bits (IDW bits)
    val op2_sel        = out Bits (IDW bits)
    val imm_flat       = out Bits (IDW * 32 bits)
    val rd_arch_flat   = out Bits (IDW * AIDX bits)
    val rs1_arch_flat  = out Bits (IDW * AIDX bits)
    val rs2_arch_flat  = out Bits (IDW * AIDX bits)
    val is_store       = out Bits (IDW bits)
    val is_atomic      = out Bits (IDW bits)        // RV32A (aExt)
    val amo_op_flat    = out Bits (IDW * 4 bits)    // RV32A (aExt)
    val is_csr         = if (cfg.zicsr) out Bits (IDW bits) else null        // Zicsr
    val csr_ctrl_flat  = if (cfg.zicsr) out Bits (IDW * 20 bits) else null   // Zicsr
    val exc_valid      = if (cfg.zicsr) out Bits (IDW bits) else null        // Zicsr: decode-time exception
    val exc_cause_flat = if (cfg.zicsr) out Bits (IDW * 4 bits) else null    // Zicsr
    // control
    val uops_valid     = out Bits (IDW bits)
    val uop_rd_phy_flat = out Bits (IDW * PIDX bits)
    val to_fl_valid    = out Bits (IDW bits)
    val to_rat_write_en = out Bits (IDW bits)
    val to_rob_valid   = out Bool()
  }
  noIoPrefix()

  def freeIdx(i: Int) = io.to_fl_free_idx_flat(i * PIDX, PIDX bits)

  // decode
  val rsType = Vec(Bits(2 bits), IDW); val fuType = Vec(Bits(2 bits), IDW); val fuOp = Vec(Bits(4 bits), IDW)
  val op1 = Vec(Bits(1 bits), IDW); val op2 = Vec(Bits(1 bits), IDW); val imm = Vec(Bits(32 bits), IDW)
  val rdArch = Vec(Bits(AIDX bits), IDW); val rs1Arch = Vec(Bits(AIDX bits), IDW); val rs2Arch = Vec(Bits(AIDX bits), IDW)
  val isStore = Vec(Bool(), IDW)
  val isAtomic = Vec(Bool(), IDW); val amoOp = Vec(Bits(4 bits), IDW)
  val isCsr    = if (cfg.zicsr) Vec(Bool(), IDW) else null
  val csrCtrl  = if (cfg.zicsr) Vec(Bits(20 bits), IDW) else null
  val excValid = if (cfg.zicsr) Vec(Bool(), IDW) else null
  val excCause = if (cfg.zicsr) Vec(Bits(4 bits), IDW) else null
  for (i <- 0 until IDW) {
    val decoded = if (cfg.iqParallelDecode) {
      val payload = DecoderPayload(cfg)
      payload.assignFromBits(io.from_fifo_decoded_flat(i * DecoderPayload.width(cfg), DecoderPayload.width(cfg) bits))
      payload
    } else DecoderPayload.decode(io.from_fifo_inst_flat(i * 32, 32 bits), cfg)
    rsType(i) := decoded.rs_type; fuType(i) := decoded.fu_type; fuOp(i) := decoded.fu_opcode
    op1(i) := decoded.op1_sel; op2(i) := decoded.op2_sel; imm(i) := decoded.imm
    rdArch(i) := decoded.rd_arch; rs1Arch(i) := decoded.rs1_arch; rs2Arch(i) := decoded.rs2_arch
    isStore(i) := decoded.is_store
    isAtomic(i) := decoded.is_atomic; amoOp(i) := decoded.amo_op
    if (cfg.zicsr) {
      isCsr(i) := decoded.is_csr; csrCtrl(i) := decoded.csr_ctrl
      excValid(i) := decoded.exc_valid; excCause(i) := decoded.exc_cause
    }
  }
  io.rs_type_flat := rsType.asBits; io.fu_type_flat := fuType.asBits; io.fu_opcode_flat := fuOp.asBits
  io.op1_sel := op1.asBits; io.op2_sel := op2.asBits; io.imm_flat := imm.asBits
  io.rd_arch_flat := rdArch.asBits; io.rs1_arch_flat := rs1Arch.asBits; io.rs2_arch_flat := rs2Arch.asBits
  io.is_store := isStore.asBits
  io.is_atomic := isAtomic.asBits; io.amo_op_flat := amoOp.asBits
  if (cfg.zicsr) {
    io.is_csr := isCsr.asBits; io.csr_ctrl_flat := csrCtrl.asBits
    io.exc_valid := excValid.asBits; io.exc_cause_flat := excCause.asBits
  }

  def rawValid(i: Int) = io.from_fifo_valid_slots(i)

  // 2-way filter (br/mem split)
  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  val uopsValid = Vec(Bool(), IDW)
  val ffReady = Bool()
  new ClockingArea(domain) {
    val isBr  = Vec(Bool(), IDW); val isMem = Vec(Bool(), IDW)
    for (i <- 0 until IDW) {
      // rs_type comes from the IQ's pre-decode, NOT the local Decoder, so
      // the hazard -> mask -> uopsValid -> from_fifo_ready chain no longer has an
      // opcode decode at its head. Value-identical by construction.
      val preRsType = io.from_fifo_pre_rs_type_flat(i * 2, 2 bits)
      isBr(i)  := (preRsType === RS_BR) && rawValid(i) && io.from_fifo_valid
      isMem(i) := (preRsType === RS_MEM) && rawValid(i) && io.from_fifo_valid
    }
    // A younger load may co-dispatch with a branch; serial operations and stores remain restricted.
    val store1 = isMem(1) && (io.from_fifo_pre_is_store(1) || io.from_fifo_pre_is_atomic(1))
    val hazard = (isBr(0) && (isBr(1) || store1)) || (isMem(0) && isMem(1))
    val advance = io.to_fl_ready && io.to_rob_ready && io.nxt_ready

    val stalled = RegInit(False)
    when(hazard) {
      when(!stalled && advance) { stalled := True }
        .elsewhen(stalled && advance) { stalled := False }
    }.otherwise { stalled := False }

    val mask = Bits(IDW bits); mask := B"2'b11"
    when(hazard) { mask := Mux(stalled, B"2'b10", B"2'b01") }
    for (i <- 0 until IDW) uopsValid(i) := rawValid(i) && mask(i)
    ffReady := Mux(hazard, stalled && advance, advance)
  }
  io.uops_valid := uopsValid.asBits
  io.from_fifo_ready := ffReady

  // rename control
  val flValid = Vec(Bool(), IDW); val writeEn = Vec(Bool(), IDW); val rdPhy = Vec(Bits(PIDX bits), IDW)
  for (i <- 0 until IDW) {
    // hasRd off the pre-decode -- same value as (rdArch(i) =/= 0), but it
    // no longer waits on the Decoder's rd_en mux (this is the rename data leg).
    val hasRd = io.from_fifo_pre_has_rd(i)
    flValid(i) := io.from_fifo_valid && uopsValid(i) && io.to_rob_ready && io.nxt_ready && hasRd
    writeEn(i) := io.from_fifo_valid && uopsValid(i) && io.to_fl_ready && io.to_rob_ready && io.nxt_ready && hasRd
    rdPhy(i)   := Mux(hasRd, freeIdx(i), B(0, PIDX bits))
  }
  io.to_fl_valid := flValid.asBits
  io.to_rat_write_en := writeEn.asBits
  io.uop_rd_phy_flat := rdPhy.asBits
  io.to_rob_valid := io.from_fifo_valid && io.to_fl_ready && io.nxt_ready
  io.nxt_valid    := io.from_fifo_valid && io.to_fl_ready && io.to_rob_ready
}
