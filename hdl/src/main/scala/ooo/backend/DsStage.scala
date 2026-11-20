package ooo.backend

import spinal.core._
import ooo.CpuConfig

/** Dispatch valid decoded operations to the matching reservation stations. */
class DsStage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ds_stage_spinal")
  val IDW = cfg.idWidth
  val SEL = log2Up(IDW)
  def RS_INT = B"2'b00"; def RS_INTM = B"2'b01"; def RS_BR = B"2'b10"; def RS_MEM = B"2'b11"

  val io = new Bundle {
    val prv_valid = in Bool(); val prv_ready = out Bool()
    val uops_valid = in Bits (IDW bits)
    val rs_type_flat = in Bits (IDW * 2 bits)
    val to_int_rs_ready  = in Bool(); val to_intm_rs_ready = in Bool()
    val to_br_rs_ready   = in Bool(); val to_mem_rs_ready  = in Bool()
    val to_int_rs_valid  = out Bits (IDW bits)
    val to_intm_rs_valid = out Bits (IDW bits)
    val to_br_rs_valid   = out Bool(); val to_mem_rs_valid = out Bool()
    val br_sel  = out UInt (SEL bits); val mem_sel = out UInt (SEL bits)
  }
  noIoPrefix()

  def rsType(i: Int)  = io.rs_type_flat(i * 2, 2 bits)
  def dispatchValid(i: Int) = io.prv_valid && io.uops_valid(i)

  // ready collection (independent of prv_ready)
  val dispatchReady = Vec(Bool(), IDW)
  for (i <- 0 until IDW) {
    dispatchReady(i) := True
    when(dispatchValid(i)) {
      switch(rsType(i)) {
        is(RS_INT)  { dispatchReady(i) := io.to_int_rs_ready }
        is(RS_INTM) { dispatchReady(i) := io.to_intm_rs_ready }
        is(RS_BR)   { dispatchReady(i) := io.to_br_rs_ready }
        is(RS_MEM)  { dispatchReady(i) := io.to_mem_rs_ready }
      }
    }
  }
  val prvReady = dispatchReady.reduce(_ && _)
  io.prv_ready := prvReady

  // valids
  val intV = Vec(Bool(), IDW); val intmV = Vec(Bool(), IDW)
  for (i <- 0 until IDW) {
    intV(i)  := (rsType(i) === RS_INT)  && dispatchValid(i) && prvReady
    intmV(i) := (rsType(i) === RS_INTM) && dispatchValid(i) && prvReady
  }
  io.to_int_rs_valid := intV.asBits
  io.to_intm_rs_valid := intmV.asBits

  // BR / MEM: first matching slot
  val brAny = Bool(); brAny := False; val brSel = UInt(SEL bits); brSel := 0
  val memAny = Bool(); memAny := False; val memSel = UInt(SEL bits); memSel := 0
  for (i <- IDW - 1 downto 0) {
    when((rsType(i) === RS_BR) && dispatchValid(i))  { brAny := True;  brSel := U(i, SEL bits) }
    when((rsType(i) === RS_MEM) && dispatchValid(i)) { memAny := True; memSel := U(i, SEL bits) }
  }
  io.to_br_rs_valid  := brAny && prvReady
  io.to_mem_rs_valid := memAny && prvReady
  io.br_sel := brSel; io.mem_sel := memSel
}
