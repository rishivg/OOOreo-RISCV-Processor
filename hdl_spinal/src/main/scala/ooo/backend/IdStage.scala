package ooo.backend

import spinal.core._
import ooo.CpuConfig
import ooo.backend.decode.Decoder

/** SpinalHDL port of `hdl/backend/decode/id_stage.sv` -- the decode + filter +
  * rename stage (ID_WIDTH == 2). Instantiates the Decoder twins, runs the 2-way
  * branch/mem split filter (dispatch_stalled flop), pops the free list / reads &
  * writes the RAT / notifies the ROB. The uop_t and rvfi_dbg_t payloads are
  * assembled natively in the shim from these decoder/control outputs + the packet
  * fields + the RAT/ROB feedback.
  *
  * Named id_stage_spinal; re-emits the Decoder (module `decoder`) -> EXTRA_EXCLUDE
  * the SV decoder.sv. sim/swap_shims/id_stage.sv carries fifo_backend_itf +
  * id_rat_itf + id_fl_itf + id_rob_itf and builds uop/rvfi natively.
  */
class IdStage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("id_stage_spinal")
  val IDW = cfg.idWidth        // 2
  val AIDX = cfg.arfIdx        // 5
  val PIDX = cfg.prfIdx        // 6
  def RS_BR = B"2'b10"; def RS_MEM = B"2'b11"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_fifo_valid = in Bool()
    val from_fifo_inst_flat = in Bits (IDW * 32 bits)
    val from_fifo_valid_slots = in Bits (IDW bits)
    val from_fifo_ready = out Bool()
    val nxt_valid = out Bool(); val nxt_ready = in Bool()
    val to_fl_ready = in Bool(); val to_fl_free_idx_flat = in Bits (IDW * PIDX bits)
    val to_rob_ready = in Bool()
    // decoder results (uop fields built in shim)
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
    // control
    val uops_valid     = out Bits (IDW bits)
    val uop_rd_phy_flat = out Bits (IDW * PIDX bits)
    val to_fl_valid    = out Bits (IDW bits)
    val to_rat_write_en = out Bits (IDW bits)
    val to_rob_valid   = out Bool()
  }
  noIoPrefix()

  def freeIdx(i: Int) = io.to_fl_free_idx_flat(i * PIDX, PIDX bits)

  // ---- decode ----
  val rsType = Vec(Bits(2 bits), IDW); val fuType = Vec(Bits(2 bits), IDW); val fuOp = Vec(Bits(4 bits), IDW)
  val op1 = Vec(Bits(1 bits), IDW); val op2 = Vec(Bits(1 bits), IDW); val imm = Vec(Bits(32 bits), IDW)
  val rdArch = Vec(Bits(AIDX bits), IDW); val rs1Arch = Vec(Bits(AIDX bits), IDW); val rs2Arch = Vec(Bits(AIDX bits), IDW)
  val isStore = Vec(Bool(), IDW)
  for (i <- 0 until IDW) {
    val dec = new Decoder(cfg)
    dec.io.inst := io.from_fifo_inst_flat(i * 32, 32 bits)
    rsType(i) := dec.io.rs_type; fuType(i) := dec.io.fu_type; fuOp(i) := dec.io.fu_opcode
    op1(i) := dec.io.op1_sel; op2(i) := dec.io.op2_sel; imm(i) := dec.io.imm
    rdArch(i) := dec.io.rd_arch; rs1Arch(i) := dec.io.rs1_arch; rs2Arch(i) := dec.io.rs2_arch
    isStore(i) := dec.io.is_store
  }
  io.rs_type_flat := rsType.asBits; io.fu_type_flat := fuType.asBits; io.fu_opcode_flat := fuOp.asBits
  io.op1_sel := op1.asBits; io.op2_sel := op2.asBits; io.imm_flat := imm.asBits
  io.rd_arch_flat := rdArch.asBits; io.rs1_arch_flat := rs1Arch.asBits; io.rs2_arch_flat := rs2Arch.asBits
  io.is_store := isStore.asBits

  def rawValid(i: Int) = io.from_fifo_valid_slots(i)

  // ---- 2-way filter (br/mem split) ----
  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  val uopsValid = Vec(Bool(), IDW)
  val ffReady = Bool()
  new ClockingArea(domain) {
    val isBr  = Vec(Bool(), IDW); val isMem = Vec(Bool(), IDW)
    for (i <- 0 until IDW) {
      isBr(i)  := (rsType(i) === RS_BR) && rawValid(i) && io.from_fifo_valid
      isMem(i) := (rsType(i) === RS_MEM) && rawValid(i) && io.from_fifo_valid
    }
    val hazard = (isBr(0) && (isBr(1) || isMem(1))) || (isMem(0) && isMem(1))
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

  // ---- rename control ----
  val flValid = Vec(Bool(), IDW); val writeEn = Vec(Bool(), IDW); val rdPhy = Vec(Bits(PIDX bits), IDW)
  for (i <- 0 until IDW) {
    val hasRd = rdArch(i) =/= 0
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
