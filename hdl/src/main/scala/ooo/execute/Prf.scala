package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** Multiwrite physical register file with CDB and fast ALU bypasses.
  * FPGA storage uses one distributed-memory bank per write lane and a per-row
  * owner tag. ASIC storage uses flops. The highest write lane wins collisions;
  * physical register zero always reads as zero.
  */
class Prf(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("prf_spinal")
  val CDBW = cfg.cdbWidth
  val RDP  = cfg.prfReadPorts
  val NFB  = cfg.numFastBypass
  val PIDX = cfg.prfIdx
  val DEPTH = cfg.prfDepth
  val BPW  = BypassT.width(cfg)
  val MEMPRE = cfg.memrsDepth    // memRs rs1 pre-read ports (one per entry)
  val INTMPRE = cfg.intmrsDepth  // intmRs rs1+rs2 pre-read ports (one PAIR per entry)
  val BRPRE   = cfg.brrsDepth    // brRs  rs1+rs2 pre-read ports (one PAIR per entry)
  val BNW  = cfg.bypassNetW
  val SELW = log2Up(cfg.intIssueWidth)
  val io = new Bundle {
    val clk = in Bool()
    val from_rs_rs1_phy_flat   = in  Bits (RDP * PIDX bits)
    val from_rs_rs2_phy_flat   = in  Bits (RDP * PIDX bits)
    val from_rs_rs_bypass_flat = in  Bits (RDP * BPW bits)
    val from_rs_rs1_value_flat = out Bits (RDP * 32 bits)
    val from_rs_rs2_value_flat = out Bits (RDP * 32 bits)
    val cdb_valid_flat    = in Bits (CDBW bits)
    val cdb_rd_phy_flat   = in Bits (CDBW * PIDX bits)
    val cdb_rd_value_flat = in Bits (CDBW * 32 bits)
    val alu_bypass_flat   = in Bits (NFB * BNW bits)
    // Per-entry memory operands for the ASIC path. FPGA read sharing places
    // the selected request in port zero and leaves the remaining ports unused.
    val pre_rs1_select_flat = if (cfg.memPrfPredecode) in Bits(MEMPRE * (DEPTH - 1) bits) else null
    val pre_rs1_phy_flat    = in  Bits (MEMPRE * PIDX bits)
    val pre_rs1_bypass_flat = in  Bits (MEMPRE * BPW bits)
    val pre_rs1_value_flat  = out Bits (MEMPRE * 32 bits)
    // Multiply/divide operand pairs.
    val ipre_phy1_flat   = in  Bits (INTMPRE * PIDX bits)
    val ipre_phy2_flat   = in  Bits (INTMPRE * PIDX bits)
    val ipre_bypass_flat = in  Bits (INTMPRE * BPW bits)
    val ipre_value1_flat = out Bits (INTMPRE * 32 bits)
    val ipre_value2_flat = out Bits (INTMPRE * 32 bits)
    // Branch operand pairs.
    val bpre_select1 = if (cfg.brPrfSharedPredecode) in Bits(DEPTH - 1 bits) else null
    val bpre_select2 = if (cfg.brPrfSharedPredecode) in Bits(DEPTH - 1 bits) else null
    val bpre_phy1_flat   = in  Bits (BRPRE * PIDX bits)
    val bpre_phy2_flat   = in  Bits (BRPRE * PIDX bits)
    val bpre_bypass_flat = in  Bits (BRPRE * BPW bits)
    val bpre_value1_flat = out Bits (BRPRE * 32 bits)
    val bpre_value2_flat = out Bits (BRPRE * 32 bits)
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

  val storage = new ClockingArea(domain) {
    val winning = Vec(Bool(), CDBW)
    for (i <- 0 until CDBW) {
      val overridden = (i + 1 until CDBW).map(j =>
        cdbValid(j) && cdbRdPhy(j) === cdbRdPhy(i)).fold(False)(_ || _)
      winning(i) := cdbValid(i) && cdbRdPhy(i) =/= 0 &&
        cdbRdPhy(i).resize(PIDX + 1) < U(DEPTH, PIDX + 1 bits) && !overridden
    }
    val mem = if (!cfg.prfLutRam) Vec((0 until DEPTH).map(r =>
      if (r == 0) B(0, 32 bits) else Reg(Bits(32 bits)))) else null
    val banks = if (cfg.prfLutRam) (0 until CDBW).map { i =>
      val bank = Mem(Bits(32 bits), DEPTH)
      bank.addAttribute("ram_style", "distributed")
      bank.write(cdbRdPhy(i), cdbRdValue(i), winning(i))
      bank
    } else Seq.empty[Mem[Bits]]
    val owner = if (cfg.prfLutRam) Vec((0 until DEPTH).map(r =>
      if (r == 0) U(0, log2Up(CDBW) bits) else Reg(UInt(log2Up(CDBW) bits)))) else null
    for (r <- 1 until DEPTH) {
      if (cfg.prfLutRam) {
        for (i <- 0 until CDBW) when(winning(i) && cdbRdPhy(i) === r) { owner(r) := i }
      } else {
        mem(r).setName(s"storage_$r")
        // A row match already proves range/nonzero and equal-address collisions.
        val hits = (0 until CDBW).map(i => cdbValid(i) && cdbRdPhy(i) === r)
        val select = Bits(CDBW bits)
        for (i <- 0 until CDBW)
          select(i) := hits(i) && !hits.drop(i + 1).foldLeft(False)(_ || _)
        when(select.orR) { mem(r) := ooo.OhSel(select, (0 until CDBW).map(cdbRdValue)) }
      }
    }
    def read(phy: UInt, decoded: Bits = null): Bits = {
      if (decoded != null) return ooo.OhSel(decoded,(1 until DEPTH).map(mem(_)))
      val value = if (cfg.prfLutRam) {
        val arms = Vec(banks.map(_.readAsync(phy)))
        arms(owner(phy))
      } else if (cfg.prfBinaryRead) mem(phy)
      else {
        val select = Bits(DEPTH - 1 bits)
        for (r <- 1 until DEPTH) select(r - 1) := phy === r
        ooo.OhSel(select, (1 until DEPTH).map(mem(_)))
      }
      Mux(phy =/= 0 && phy.resize(PIDX + 1) < U(DEPTH, PIDX + 1 bits), value, B(0, 32 bits))
    }
  }

  // bypass_t layout (MSB->LSB): rs1_bypass_en[CDBW+1], rs2_bypass_en[CDBW+1],
  //                              rs1_bypass_sel[SELW], rs2_bypass_sel[SELW]
  def rs1En(i: Int)  = rsBypass(i)(BPW - 1 downto BPW - (CDBW + 1))
  def rs2En(i: Int)  = rsBypass(i)(BPW - (CDBW + 1) - 1 downto 2 * SELW)
  def rs1Sel(i: Int) = rsBypass(i)(2 * SELW - 1 downto SELW).asUInt
  def rs2Sel(i: Int) = rsBypass(i)(SELW - 1 downto 0).asUInt

  // Resolve one-hot bypass enables across
  // cdbWidth lanes: en[k] (k<CDBW) -> CDB lane k, en[CDBW] -> fast bypass,
  // en==0 -> PRF read (or 0 for phy0).
  def readVal(en: Bits, sel: UInt, phy: UInt, decoded: Bits = null): Bits = {
    // Decode once per port and share the selects across all 32 data bits.
    // Physical register zero is architectural zero and has no stored read arm.
    val stored = storage.read(phy,decoded)
    val v = Bits(32 bits)
    switch(en) {
      is(B(0, CDBW + 1 bits)) { v := stored }
      for (k <- 0 until CDBW) {
        is(B(BigInt(1) << k, CDBW + 1 bits)) { v := cdbRdValue(k) }
      }
      is(B(BigInt(1) << CDBW, CDBW + 1 bits)) { v := aluBypassRdValue(sel) }
      default          { v := B(0, 32 bits) }
    }
    v
  }

  val rs1Out = Vec(Bits(32 bits), RDP)
  val rs2Out = Vec(Bits(32 bits), RDP)
  for (i <- 0 until RDP) {
    rs1Out(i) := readVal(rs1En(i), rs1Sel(i), rs1Phy(i))
    rs2Out(i) := readVal(rs2En(i), rs2Sel(i), rs2Phy(i))
  }
  io.from_rs_rs1_value_flat := rs1Out.asBits
  io.from_rs_rs2_value_flat := rs2Out.asBits

  // pre-read group: same readVal, but every input is a REGISTERED memRs entry
  // field, so these resolve from cycle start instead of behind the issue select.
  def preByp(i: Int)    = io.pre_rs1_bypass_flat(i * BPW, BPW bits)
  def preRs1En(i: Int)  = preByp(i)(BPW - 1 downto BPW - (CDBW + 1))
  def preRs1Sel(i: Int) = preByp(i)(2 * SELW - 1 downto SELW).asUInt
  def preRs1Phy(i: Int) = io.pre_rs1_phy_flat(i * PIDX, PIDX bits).asUInt
  val preOut = Vec(Bits(32 bits), MEMPRE)
  for (i <- 0 until MEMPRE) {
    val decoded = if (cfg.memPrfPredecode) io.pre_rs1_select_flat(i * (DEPTH - 1),DEPTH - 1 bits) else null
    preOut(i) := readVal(preRs1En(i),preRs1Sel(i),preRs1Phy(i),decoded)
  }
  io.pre_rs1_value_flat := preOut.asBits

  // intmRs pre-read group (PRF-2): same readVal, both operands, all inputs are
  // REGISTERED intmRs entry fields so every read resolves from cycle start.
  def iByp(i: Int)     = io.ipre_bypass_flat(i * BPW, BPW bits)
  def iRs1En(i: Int)   = iByp(i)(BPW - 1 downto BPW - (CDBW + 1))
  def iRs2En(i: Int)   = iByp(i)(BPW - (CDBW + 1) - 1 downto 2 * SELW)
  def iRs1Sel(i: Int)  = iByp(i)(2 * SELW - 1 downto SELW).asUInt
  def iRs2Sel(i: Int)  = iByp(i)(SELW - 1 downto 0).asUInt
  def iPhy1(i: Int)    = io.ipre_phy1_flat(i * PIDX, PIDX bits).asUInt
  def iPhy2(i: Int)    = io.ipre_phy2_flat(i * PIDX, PIDX bits).asUInt
  val ipreOut1 = Vec(Bits(32 bits), INTMPRE)
  val ipreOut2 = Vec(Bits(32 bits), INTMPRE)
  for (i <- 0 until INTMPRE) {
    ipreOut1(i) := readVal(iRs1En(i), iRs1Sel(i), iPhy1(i))
    ipreOut2(i) := readVal(iRs2En(i), iRs2Sel(i), iPhy2(i))
  }
  io.ipre_value1_flat := ipreOut1.asBits
  io.ipre_value2_flat := ipreOut2.asBits

  // brRs pre-read group (PRF-3): same readVal, both operands, all inputs are
  // REGISTERED brRs entry fields so every read resolves from cycle start.
  def bByp(i: Int)     = io.bpre_bypass_flat(i * BPW, BPW bits)
  def bRs1En(i: Int)   = bByp(i)(BPW - 1 downto BPW - (CDBW + 1))
  def bRs2En(i: Int)   = bByp(i)(BPW - (CDBW + 1) - 1 downto 2 * SELW)
  def bRs1Sel(i: Int)  = bByp(i)(2 * SELW - 1 downto SELW).asUInt
  def bRs2Sel(i: Int)  = bByp(i)(SELW - 1 downto 0).asUInt
  def bPhy1(i: Int)    = io.bpre_phy1_flat(i * PIDX, PIDX bits).asUInt
  def bPhy2(i: Int)    = io.bpre_phy2_flat(i * PIDX, PIDX bits).asUInt
  val bpreOut1 = Vec(Bits(32 bits), BRPRE)
  val bpreOut2 = Vec(Bits(32 bits), BRPRE)
  for (i <- 0 until BRPRE) {
    val decoded1 = if (cfg.brPrfSharedPredecode && i == 0) io.bpre_select1 else null
    val decoded2 = if (cfg.brPrfSharedPredecode && i == 0) io.bpre_select2 else null
    bpreOut1(i) := readVal(bRs1En(i), bRs1Sel(i), bPhy1(i), decoded1)
    bpreOut2(i) := readVal(bRs2En(i), bRs2Sel(i), bPhy2(i), decoded2)
  }
  io.bpre_value1_flat := bpreOut1.asBits
  io.bpre_value2_flat := bpreOut2.asBits
}
