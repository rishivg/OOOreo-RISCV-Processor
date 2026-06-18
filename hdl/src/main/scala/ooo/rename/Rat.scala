package ooo.rename

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/backend/rename/rat.sv` -- the register alias table.
  *
  * ARF_DEPTH entries of {valid, phy}. Reset to identity (arch i -> phy i, valid);
  * on backend_flush reloads from the retirement map rrf_mem (all valid). Normal:
  * CDB sets a mapping's valid when its phy still matches; dispatch writes the new
  * (phy, invalid) for each renamed dest. Reads do intra-bundle forwarding (younger
  * slot sees older slot's dest) + transparent CDB valid + r0 handling.
  *
  * Named rat_spinal; sim/swap_shims/rat.sv carries id_rat_itf.rat + cdb_itf.rat[5]
  * and flattens the rrf_mem[ARF_DEPTH] unpacked-array input.
  */
class Rat(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("rat_spinal")
  val IDW   = cfg.idWidth      // 2
  val CDBW  = cfg.cdbWidth     // 5
  val AIDX  = cfg.arfIdx       // 5
  val PIDX  = cfg.prfIdx       // 6
  val ADEP  = cfg.arfDepth     // 32
  val EW    = PIDX + 1         // {valid, phy}

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val backend_flush = in Bool()
    val rrf_mem_flat  = in Bits (ADEP * PIDX bits)
    // id_rat_itf.rat from_id
    val from_id_rs1_arch_flat = in  Bits (IDW * AIDX bits)
    val from_id_rs2_arch_flat = in  Bits (IDW * AIDX bits)
    val from_id_write_en      = in  Bits (IDW bits)
    val from_id_rd_arch_flat  = in  Bits (IDW * AIDX bits)
    val from_id_rd_phy_flat   = in  Bits (IDW * PIDX bits)
    val from_id_rs1_phy_flat  = out Bits (IDW * PIDX bits)
    val from_id_rs2_phy_flat  = out Bits (IDW * PIDX bits)
    val from_id_rs1_valid     = out Bits (IDW bits)
    val from_id_rs2_valid     = out Bits (IDW bits)
    // cdb_itf.rat cdb[CDB_WIDTH]
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
  def cdbRdPhy(j: Int)  = io.cdb_rd_phy_flat(j * PIDX, PIDX bits)
  def cdbRdArch(j: Int) = io.cdb_rd_arch_flat(j * AIDX, AIDX bits).asUInt
  def cdbValid(j: Int)  = io.cdb_valid(j)
  val rrf = io.rrf_mem_flat.subdivideIn(ADEP slices)   // rrf(i) = retirement phy for arch i

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    // identity reset: arch i -> {valid=1, phy=i}
    val mem = Vec((0 until ADEP).map(i => RegInit(B((BigInt(1) << PIDX) | i, EW bits))))

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

    // ---- reads ----
    val rs1Phy   = Vec(Bits(PIDX bits), IDW)
    val rs2Phy   = Vec(Bits(PIDX bits), IDW)
    val rs1Valid = Vec(Bool(), IDW)
    val rs2Valid = Vec(Bool(), IDW)
    for (i <- 0 until IDW) {
      rs1Phy(i)   := mem(rs1Arch(i))(PIDX - 1 downto 0)
      rs2Phy(i)   := mem(rs2Arch(i))(PIDX - 1 downto 0)
      rs1Valid(i) := mem(rs1Arch(i))(PIDX)
      rs2Valid(i) := mem(rs2Arch(i))(PIDX)
      // intra-bundle forward from older slots
      for (j <- 0 until i) {
        when(writeEn(j) && (rdArch(j) === rs1Arch(i))) { rs1Phy(i) := rdPhy(j); rs1Valid(i) := False }
        when(writeEn(j) && (rdArch(j) === rs2Arch(i))) { rs2Phy(i) := rdPhy(j); rs2Valid(i) := False }
      }
      // transparent CDB: a result this cycle makes the operand ready
      for (j <- 0 until CDBW) {
        when(cdbValid(j)) {
          when(cdbRdPhy(j) === rs1Phy(i)) { rs1Valid(i) := True }
          when(cdbRdPhy(j) === rs2Phy(i)) { rs2Valid(i) := True }
        }
      }
      // r0
      when(rs1Arch(i) === 0) { rs1Phy(i) := 0; rs1Valid(i) := True }
      when(rs2Arch(i) === 0) { rs2Phy(i) := 0; rs2Valid(i) := True }
    }
    io.from_id_rs1_phy_flat := rs1Phy.asBits
    io.from_id_rs2_phy_flat := rs2Phy.asBits
    io.from_id_rs1_valid    := rs1Valid.asBits
    io.from_id_rs2_valid    := rs2Valid.asBits
  }
}
