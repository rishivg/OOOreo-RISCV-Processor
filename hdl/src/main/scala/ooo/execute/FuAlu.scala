package ooo.execute

import spinal.core._
import ooo.{CpuConfig, FastAdd}
import ooo.backend.decode.DecodeConsts._

/** Two-stage integer ALU with first-stage bypass and registered CDB output. */
class FuAlu(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("fu_alu_spinal")

  val regW    = cfg.fuAluRegW   // fu_alu_reg_t (149)
  val bypassW = cfg.bypassNetW  // bypass_network_t (39)
  val RIDX    = cfg.robIdx
  val AIDX    = cfg.arfIdx
  val PIDX    = cfg.prfIdx

  val io = new Bundle {
    val clk          = in  Bool()
    val rst          = in  Bool()
    val int_rs_valid = in  Bool()
    val fu_alu_ready = out Bool()
    val fu_alu_reg_in = in  Bits (regW bits)
    val bypass        = out Bits (bypassW bits)
    val address_source = if (cfg.aluAguFusion) out Bits(ooo.memory.AluAddressSource.width bits) else null
    // flattened cdb_itf.fu (all outputs)
    val cdb_rob_id        = out Bits (RIDX bits)
    val cdb_rd_phy        = out Bits (PIDX bits)
    val cdb_rd_arch       = out Bits (AIDX bits)
    val cdb_rd_value      = out Bits (32 bits)
    val cdb_rs1_value_dbg = out Bits (32 bits)
    val cdb_rs2_value_dbg = out Bits (32 bits)
    val cdb_valid         = out Bool()
  }
  noIoPrefix()

  // ALU is single-cycle and always ready (result on the fast-bypass net)
  io.fu_alu_ready := True
  val cdb_ready = True

  val domain = ClockDomain(
    clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  new ClockingArea(domain) {
    // stage 1 register
    val fu_alu_valid   = RegInit(False)
    when(io.fu_alu_ready) { fu_alu_valid := io.int_rs_valid }
    val fu_alu_reg_out = Reg(Bits(regW bits))
    when(io.int_rs_valid && io.fu_alu_ready) { fu_alu_reg_out := io.fu_alu_reg_in }

    // unpack fu_alu_reg_out (LSB-first):
    //   rs2[31:0] rs1[63:32] opB[95:64] opA[127:96] fu_opcode[131:128]
    //   rd_phy[137:132] rd_arch[142:138] rob_id[148:143]
    val rs2_value = FuAluReg.rs2Value(fu_alu_reg_out)
    val rs1_value = FuAluReg.rs1Value(fu_alu_reg_out)
    val fu_opcode = FuAluReg.fuOpcode(fu_alu_reg_out)
    val rd_phy    = FuAluReg.rdPhy(fu_alu_reg_out, cfg)
    val rd_arch   = FuAluReg.rdArch(fu_alu_reg_out, cfg)
    val rob_id    = FuAluReg.robId(fu_alu_reg_out, cfg)

    // IntRs selects operands before registration to keep muxes off the adder path.
    val a = FuAluReg.opA(fu_alu_reg_out)
    val b = FuAluReg.opB(fu_alu_reg_out)
    // Mask shifter inputs for non-shift opcodes; their outputs are then unused.
    val isShift = (fu_opcode === ALU_SLL) || (fu_opcode === ALU_SRL) || (fu_opcode === ALU_SRA)
    val shMask32 = Cat(Seq.fill(32)(isShift))
    val aSh = a & shMask32
    val sh = (b(4 downto 0) & Cat(Seq.fill(5)(isShift))).asUInt

    // Share add/subtract arithmetic and derive comparisons from its carry/sign outputs.
    val isSubCls = (fu_opcode === ALU_SUB) || (fu_opcode === ALU_SLT) || (fu_opcode === ALU_SLTU)
    val bEff     = b ^ Cat(Seq.fill(32)(isSubCls))
    val (sumU, sumCout) = FastAdd.withCout(a.asUInt, bEff.asUInt, carryIn = isSubCls,
      nativeCarry = cfg.fpgaNativeAdd)
    val addRes = sumU.asBits            // ALU_ADD arm  (isSubCls=0 -> a + b)
    val subRes = sumU.asBits            // ALU_SUB arm  (isSubCls=1 -> a - b)
    val sltu   = !sumCout               // !cout(a + ~b + 1) == a <u b
    val slt    = Mux(a(31) =/= b(31), a(31), subRes(31))

    // Decode the ALU opcode once and combine result arms with a balanced one-hot mux.
    val earlyOps  = Seq(ALU_SLL, ALU_SRA, ALU_XOR, ALU_SRL, ALU_OR, ALU_AND)
    val earlyVals = if (cfg.fpgaSharedShift) {
      val left = fu_opcode === ALU_SLL
      val arithmetic = fu_opcode === ALU_SRA
      val input = Mux(left, aSh.reversed, aSh)
      val signedInput = ((arithmetic && aSh(31)).asBits ## input).asSInt
      val right = (signedInput >> sh).asBits(31 downto 0)
      val shifted = Mux(left, right.reversed, right)
      Seq(shifted, shifted, (a ^ b), shifted, (a | b), (a & b))
    } else Seq((aSh |<< sh), (aSh.asSInt >> sh).asBits, (a ^ b),
                        (aSh |>> sh), (a | b), (a & b))
    val earlyOh = Bits(earlyOps.length bits)
    for (k <- earlyOps.indices) earlyOh(k) := (fu_opcode === earlyOps(k))
    val earlyVal = ooo.OhSel(earlyOh, earlyVals)

    val isAddSub = (fu_opcode === ALU_ADD) || (fu_opcode === ALU_SUB)
    val isSltCls = (fu_opcode === ALU_SLT) || (fu_opcode === ALU_SLTU)
    val sltVal   = B(0, 31 bits) ## Mux(fu_opcode === ALU_SLTU, sltu, slt)
    val alu_out  = Mux(isAddSub, addRes, Mux(isSltCls, sltVal, earlyVal))

    if (cfg.aluAguFusion) io.address_source := ooo.memory.AluAddressSource.pack(
      a,bEff,isSubCls,earlyVal,sltVal(0),isAddSub,isSltCls)

    // bypass_network_t (MSB-first: valid rd_phy rd_value)
    io.bypass := fu_alu_valid.asBits ## rd_phy ## alu_out

    // stage 2: CDB register
    val cdb_valid = RegInit(False)
    when(cdb_ready) { cdb_valid := fu_alu_valid }
    io.cdb_valid := cdb_valid

    val r_rob_id  = Reg(Bits(RIDX bits)) init(0)
    val r_rd_arch = Reg(Bits(AIDX bits)) init(0)
    val r_rd_phy  = Reg(Bits(PIDX bits)) init(0)
    val r_rd_val  = Reg(Bits(32 bits)) init(0)
    val r_rs1_dbg = Reg(Bits(32 bits)) init(0)
    val r_rs2_dbg = Reg(Bits(32 bits)) init(0)
    when(fu_alu_valid && cdb_ready) {
      r_rob_id  := rob_id
      r_rd_arch := rd_arch
      r_rd_phy  := rd_phy
      r_rd_val  := alu_out
      r_rs1_dbg := rs1_value
      r_rs2_dbg := rs2_value
    }
    io.cdb_rob_id        := r_rob_id
    io.cdb_rd_arch       := r_rd_arch
    io.cdb_rd_phy        := r_rd_phy
    io.cdb_rd_value      := r_rd_val
    // RVFI-only (see FuAgu). Tying the outputs sweeps the capture registers.
    io.cdb_rs1_value_dbg := (if (cfg.rvfi) r_rs1_dbg else B(0, 32 bits))
    io.cdb_rs2_value_dbg := (if (cfg.rvfi) r_rs2_dbg else B(0, 32 bits))
  }
}
