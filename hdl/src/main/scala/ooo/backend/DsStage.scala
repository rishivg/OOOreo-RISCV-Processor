package ooo.backend

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/decode/ds_stage.sv` -- the dispatch stage:
  * routes each renamed uop to its reservation station by rs_type (INT/INTM per-slot;
  * BR/MEM take the first matching slot), collects the per-slot ready into prv_ready,
  * and keeps the per-RS "RS full" perf counters.
  *
  * The uop payload is routed in the shim (this module emits the valids, the BR/MEM
  * source-slot select, prv_ready, and the perf counters). Named ds_stage_spinal;
  * sim/swap_shims/ds_stage.sv carries the ds_rs_itf/ds_rs_mono_itf interfaces and
  * surfaces the perf-tapped perf_*_rs_block counters by name.
  */
class DsStage(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("ds_stage_spinal")
  val IDW = cfg.idWidth        // 2
  val SEL = log2Up(IDW)        // 1
  def RS_INT = B"2'b00"; def RS_INTM = B"2'b01"; def RS_BR = B"2'b10"; def RS_MEM = B"2'b11"

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val prv_valid = in Bool(); val prv_ready = out Bool()
    val uops_valid = in Bits (IDW bits)
    val rs_type_flat = in Bits (IDW * 2 bits)
    val uop_rs_type_flat = in Bits (IDW * 2 bits)   // uops[i].rs_type (for perf)
    val to_int_rs_ready  = in Bool(); val to_intm_rs_ready = in Bool()
    val to_br_rs_ready   = in Bool(); val to_mem_rs_ready  = in Bool()
    val to_int_rs_valid  = out Bits (IDW bits)
    val to_intm_rs_valid = out Bits (IDW bits)
    val to_br_rs_valid   = out Bool(); val to_mem_rs_valid = out Bool()
    val br_sel  = out UInt (SEL bits); val mem_sel = out UInt (SEL bits)
    // perf counters (tapped by perf_monitor)
    val dbg_perf_int  = out Bits (32 bits); val dbg_perf_intm = out Bits (32 bits)
    val dbg_perf_br   = out Bits (32 bits); val dbg_perf_mem  = out Bits (32 bits)
  }
  noIoPrefix()

  def rsType(i: Int)  = io.rs_type_flat(i * 2, 2 bits)
  def uopRs(i: Int)   = io.uop_rs_type_flat(i * 2, 2 bits)
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

  // perf counters (use uops[i].rs_type; increment when a valid slot's RS is full)
  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))
  new ClockingArea(domain) {
    val pInt = RegInit(U(0, 32 bits)); val pIntm = RegInit(U(0, 32 bits))
    val pBr = RegInit(U(0, 32 bits)); val pMem = RegInit(U(0, 32 bits))
    for (i <- 0 until IDW) {
      when(!dispatchReady(i) && dispatchValid(i)) {
        switch(uopRs(i)) {
          is(RS_INT)  { pInt := pInt + 1 }
          is(RS_INTM) { pIntm := pIntm + 1 }
          is(RS_BR)   { pBr := pBr + 1 }
          is(RS_MEM)  { pMem := pMem + 1 }
        }
      }
    }
    io.dbg_perf_int := pInt.asBits; io.dbg_perf_intm := pIntm.asBits
    io.dbg_perf_br := pBr.asBits; io.dbg_perf_mem := pMem.asBits
  }
}
