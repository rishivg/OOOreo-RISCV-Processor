package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/execute/prf.sv` -- the physical register file.
  *
  * CDB_WIDTH write ports (clock-gated; write when valid && rd_phy!=0) and CDB_WIDTH
  * read ports, each resolving rs1/rs2 through a one-hot bypass select: read PRF (or
  * 0 for phy0), forward from one of the CDB_WIDTH CDB lanes, or from one of the fast
  * ALU bypass lanes. Only `clk` (no reset; the array is not reset in SV).
  *
  * Named prf_spinal; sim/swap_shims/prf.sv carries the rs_prf_itf[CDB_WIDTH],
  * cdb_itf.prf[CDB_WIDTH] and bypass_network_t[NUM_FAST_BYPASS] ports flattened.
  */
class Prf(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("prf_spinal")
  val CDBW = cfg.cdbWidth        // 5
  val NFB  = cfg.numFastBypass   // 2
  val PIDX = cfg.prfIdx          // 6
  val DEPTH = cfg.prfDepth       // 64
  val BPW  = 2 * (CDBW + 1) + 2 * log2Up(cfg.intIssueWidth)   // bypass_t = 14
  val BNW  = 1 + PIDX + 32        // bypass_network_t = 39
  val SELW = log2Up(cfg.intIssueWidth)   // 1

  val io = new Bundle {
    val clk = in Bool()
    // rs_prf_itf.prf from_rs[CDB_WIDTH]
    val from_rs_rs1_phy_flat   = in  Bits (CDBW * PIDX bits)
    val from_rs_rs2_phy_flat   = in  Bits (CDBW * PIDX bits)
    val from_rs_rs_bypass_flat = in  Bits (CDBW * BPW bits)
    val from_rs_rs1_value_flat = out Bits (CDBW * 32 bits)
    val from_rs_rs2_value_flat = out Bits (CDBW * 32 bits)
    // cdb_itf.prf cdb[CDB_WIDTH]
    val cdb_valid_flat    = in Bits (CDBW bits)
    val cdb_rd_phy_flat   = in Bits (CDBW * PIDX bits)
    val cdb_rd_value_flat = in Bits (CDBW * 32 bits)
    // bypass_network_t alu_bypass[NUM_FAST_BYPASS]
    val alu_bypass_flat   = in Bits (NFB * BNW bits)
  }
  noIoPrefix()

  def cdbValid(i: Int)  = io.cdb_valid_flat(i)
  def cdbRdPhy(i: Int)  = io.cdb_rd_phy_flat(i * PIDX, PIDX bits).asUInt
  def cdbRdValue(i: Int): Bits = io.cdb_rd_value_flat(i * 32, 32 bits)
  def rs1Phy(i: Int)    = io.from_rs_rs1_phy_flat(i * PIDX, PIDX bits).asUInt
  def rs2Phy(i: Int)    = io.from_rs_rs2_phy_flat(i * PIDX, PIDX bits).asUInt
  def rsBypass(i: Int)  = io.from_rs_rs_bypass_flat(i * BPW, BPW bits)
  // bypass_network_t layout (MSB->LSB): valid, rd_phy[PIDX], rd_value[32]
  def aluBypassRdValue(k: UInt): Bits = io.alu_bypass_flat.subdivideIn(NFB slices)(k)(31 downto 0)

  val domain = ClockDomain(clock = io.clk)

  val prfData = new ClockingArea(domain) {
    val mem = Vec(Reg(Bits(32 bits)), DEPTH)        // [1..DEPTH-1] used; index 0 reads as 0
    for (i <- 0 until CDBW) {
      when(cdbValid(i) && (cdbRdPhy(i) =/= 0)) { mem(cdbRdPhy(i)) := cdbRdValue(i) }
    }
  }.mem

  // bypass_t layout (MSB->LSB): rs1_bypass_en[CDBW+1], rs2_bypass_en[CDBW+1],
  //                              rs1_bypass_sel[SELW], rs2_bypass_sel[SELW]
  def rs1En(i: Int)  = rsBypass(i)(BPW - 1 downto BPW - (CDBW + 1))
  def rs2En(i: Int)  = rsBypass(i)(BPW - (CDBW + 1) - 1 downto 2 * SELW)
  def rs1Sel(i: Int) = rsBypass(i)(2 * SELW - 1 downto SELW).asUInt
  def rs2Sel(i: Int) = rsBypass(i)(SELW - 1 downto 0).asUInt

  // one-hot bypass resolution (mirrors the SV unique case)
  def readVal(en: Bits, sel: UInt, phy: UInt): Bits = {
    val v = Bits(32 bits)
    switch(en) {
      is(B"6'b000000") { v := Mux(phy === 0, B(0, 32 bits), prfData(phy)) }
      is(B"6'b000001") { v := cdbRdValue(0) }
      is(B"6'b000010") { v := cdbRdValue(1) }
      is(B"6'b000100") { v := cdbRdValue(2) }
      is(B"6'b001000") { v := cdbRdValue(3) }
      is(B"6'b010000") { v := cdbRdValue(4) }
      is(B"6'b100000") { v := aluBypassRdValue(sel) }
      default          { v := B(0, 32 bits) }
    }
    v
  }

  val rs1Out = Vec(Bits(32 bits), CDBW)
  val rs2Out = Vec(Bits(32 bits), CDBW)
  for (i <- 0 until CDBW) {
    rs1Out(i) := readVal(rs1En(i), rs1Sel(i), rs1Phy(i))
    rs2Out(i) := readVal(rs2En(i), rs2Sel(i), rs2Phy(i))
  }
  io.from_rs_rs1_value_flat := rs1Out.asBits
  io.from_rs_rs2_value_flat := rs2Out.asBits
}
