package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** Register alias table with same-bundle rename forwarding. */
class Rat(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("rat_spinal")
  val IDW   = cfg.idWidth
  val CDBW  = cfg.cdbWidth     // [CDB_WIDTH]
  val AIDX  = cfg.arfIdx
  val PIDX  = cfg.prfIdx
  val ADEP  = cfg.arfDepth
  val EW    = PIDX + 1         // {valid, phy}

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    val rrf_mem_flat  = in Bits (ADEP * PIDX bits)
    val from_id_rs1_arch_flat = in  Bits (IDW * AIDX bits)
    val from_id_rs2_arch_flat = in  Bits (IDW * AIDX bits)
    val from_id_write_en      = in  Bits (IDW bits)
    // early-qualified rename intent (ff_valid && uopsValid && hasRd -- WITHOUT the
    // fl/rob/dispatch readies): drives only the READ intra-bundle forward select.
    // Whenever any consumer latches the read outputs (RS entry write, ROB push) the
    // dropped readies are all true, so fwd_en == write_en on every consuming cycle;
    // on non-consuming cycles the outputs are don't-care. Mem writes keep write_en.
    val from_id_fwd_en        = in  Bits (IDW bits)
    val from_id_rd_arch_flat  = in  Bits (IDW * AIDX bits)
    val from_id_rd_phy_flat   = in  Bits (IDW * PIDX bits)
    val from_id_rs1_phy_flat  = out Bits (IDW * PIDX bits)
    val from_id_rs2_phy_flat  = out Bits (IDW * PIDX bits)
    val from_id_rs1_valid     = out Bits (IDW bits)
    val from_id_rs2_valid     = out Bits (IDW bits)
    val cdb_valid        = in Bits (CDBW bits)
    val cdb_rd_phy_flat  = in Bits (CDBW * PIDX bits)
    val cdb_rd_arch_flat = in Bits (CDBW * AIDX bits)
  }
  noIoPrefix()

  def rs1Arch(i: Int) = io.from_id_rs1_arch_flat(i * AIDX, AIDX bits).asUInt
  def rs2Arch(i: Int) = io.from_id_rs2_arch_flat(i * AIDX, AIDX bits).asUInt
  def rdArch(i: Int)  = io.from_id_rd_arch_flat(i * AIDX, AIDX bits).asUInt
  def rdPhy(i: Int)   = io.from_id_rd_phy_flat(i * PIDX, PIDX bits)
  def writeEn(i: Int) = io.from_id_write_en(i)
  def fwdEn(i: Int)   = io.from_id_fwd_en(i)
  def cdbRdPhy(j: Int)  = io.cdb_rd_phy_flat(j * PIDX, PIDX bits)
  def cdbRdArch(j: Int) = io.cdb_rd_arch_flat(j * AIDX, AIDX bits).asUInt
  def cdbValid(j: Int)  = io.cdb_valid(j)
  val rrf = io.rrf_mem_flat.subdivideIn(ADEP slices)   // rrf(i) = retirement phy for arch i

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // identity reset: arch i -> {valid=1, phy=i}
    val mem = Vec((0 until ADEP).map(i => RegInit(B((BigInt(1) << PIDX) | i, EW bits))))
    mem.zipWithIndex.foreach { case (row, i) => row.setName(s"ratEntry_$i") }

    when(io.backend_flush) {
      for (i <- 0 until ADEP) { mem(i) := True ## rrf(i) }
    }.otherwise {
      for (j <- 0 until CDBW) {
        when(cdbValid(j) && (mem(cdbRdArch(j))(PIDX - 1 downto 0) === cdbRdPhy(j))) {
          mem(cdbRdArch(j))(PIDX) := True
        }
      }
      for (i <- 0 until IDW) {
        when(writeEn(i)) {
          mem(rdArch(i))(PIDX) := False
          mem(rdArch(i))(PIDX - 1 downto 0) := rdPhy(i)
        }
      }
    }

    // Forward same-bundle renames from the youngest earlier writer of each architectural register.
    val rs1Phy   = Vec(Bits(PIDX bits), IDW)
    val rs2Phy   = Vec(Bits(PIDX bits), IDW)
    val rs1Valid = Vec(Bool(), IDW)
    val rs2Valid = Vec(Bool(), IDW)
    def cdbHitOn(v: Bits): Bool =
      Vec((0 until CDBW).map(j => cdbValid(j) && (cdbRdPhy(j) === v))).asBits.orR
    val ready = if (cfg.ratParallelRead) Vec((0 until ADEP).map(r =>
      mem(r)(PIDX) || cdbHitOn(mem(r)(PIDX - 1 downto 0)))) else null
    def readOne(i: Int, arch: UInt, phyOut: Bits, valOut: Bool): Unit = {
      val select = if (cfg.ratParallelRead)
        Vec((0 until ADEP).map(r => arch === r)).asBits else null
      val memPhy = if (cfg.ratParallelRead)
        ooo.OhSel(select, (0 until ADEP).map(r => mem(r)(PIDX - 1 downto 0)))
        else mem(arch)(PIDX - 1 downto 0)
      val memVal = if (cfg.ratParallelRead) (select & ready.asBits).orR else mem(arch)(PIDX)
      var phy: Bits = memPhy
      var vld: Bool = memVal
      var hit: Bool = if (cfg.ratParallelRead) False else cdbHitOn(memPhy)
      for (j <- 0 until i) {   // ascending: youngest older slot wins, as before
        val fwd = fwdEn(j) && (rdArch(j) === arch)
        phy = Mux(fwd, rdPhy(j), phy)
        vld = Mux(fwd, False, vld)
        hit = Mux(fwd, cdbHitOn(rdPhy(j)), hit)
      }
      val isR0 = arch === 0
      phyOut := Mux(isR0, B(0, PIDX bits), phy)
      valOut := isR0 || hit || vld
    }
    for (i <- 0 until IDW) {
      readOne(i, rs1Arch(i), rs1Phy(i), rs1Valid(i))
      readOne(i, rs2Arch(i), rs2Phy(i), rs2Valid(i))
    }
    io.from_id_rs1_phy_flat := rs1Phy.asBits
    io.from_id_rs2_phy_flat := rs2Phy.asBits
    io.from_id_rs1_valid    := rs1Valid.asBits
    io.from_id_rs2_valid    := rs2Valid.asBits
  }
}
