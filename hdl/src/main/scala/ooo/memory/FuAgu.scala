package ooo.memory

import spinal.core._
import ooo.{CpuConfig, FastAdd}

/** Combinational effective-address generation, byte masks, and store-data alignment. */
class FuAgu(cfg: CpuConfig = CpuConfig(), sharedImmediate: Boolean = false) extends Component {
  setDefinitionName(if (sharedImmediate) "fu_agu_shared_imm" else "fu_agu")
  if (cfg.keepTimingHierarchy) addAttribute("keep_hierarchy", "yes")

  val aguRegW = cfg.aguRegW
  val aguLsqW = AguLsq.width(cfg)

  // memopc_t (lsu_types) -- fu_opcode = {is_store, funct3}
  def MEM_LB  = B"4'b0000"; def MEM_LH  = B"4'b0001"; def MEM_LW  = B"4'b0010"
  def MEM_LBU = B"4'b0100"; def MEM_LHU = B"4'b0101"
  def MEM_SB  = B"4'b1000"; def MEM_SH  = B"4'b1001"; def MEM_SW  = B"4'b1010"

  val io = new Bundle {
    val clk         = in  Bool()
    val rst         = in  Bool()
    val stb_match_targets = if (cfg.lsuCarryFreeStoreMatch) in Bits((cfg.stbDepth+1)*32 bits) else null
    val agu_stb_matches = if (cfg.lsuCarryFreeStoreMatch) out Bits(cfg.stbDepth+1 bits) else null
    val prv_valid   = in  Bool()
    val prv_ready   = out Bool()
    val agu_reg_in  = in  Bits (aguRegW bits)
    // Shannon-through-PRF/AGU (see MemRs): agu_reg_in's rs1_value/imm carry the
    // issue-select COFACTOR-0 (D$-miss) operands, these the cofactor-1 (D$-hit)
    // ones; both eff-addr adds run in parallel off registered/early state and
    // alt_sel (the late LSU-lane cdb_valid) picks LAST.
    val alt_rs1_value = in Bits (32 bits)
    val alt_imm       = in Bits (32 bits)
    val alt_sel       = in Bool()
    val alt_operand_select = if (cfg.lsuOperandSpeculation) in Bool() else null
    val base_sources_flat = if (cfg.memCdbSpeculation) in Bits(160 bits) else null
    val base_source_select = if (cfg.memCdbSpeculation) in Bits(7 bits) else null
    val alt_way_rs1_flat = if (cfg.lsuWaySpeculation) in Bits(cfg.lsuBypassCandidates * 32 bits) else null
    val alt_way_select = if (cfg.lsuWaySpeculation) in Bits(cfg.lsuBypassCandidates bits) else null
    val fast_sources_flat = if (cfg.aluAguFusion) in Bits(cfg.numFastBypass * AluAddressSource.width bits) else null
    val fast_select = if (cfg.aluAguFusion) in Bits(cfg.numFastBypass bits) else null
    val fast_value = if (cfg.aluAguFusion) in Bits(32 bits) else null
    val nxt_valid   = out Bool()
    val to_lsq      = out Bits (aguLsqW bits)
    // AGU hi16 split (FastAdd.withHiSplit): the addr's upper half as conditional
    // sums + the carry into bit 16. Request-side capture points (D$ srTag pieces,
    // AtomicUnit tAddr hi) take THESE -- ready a block-carry-merge earlier than
    // to_lsq's merged addr -- and compose Mux(c16, hi1, hi0) off registers in the
    // response cycle. to_lsq keeps the merged addr for the LDQ/STQ entry captures.
    val agu_hi0 = out Bits (16 bits)
    val agu_hi1 = out Bits (16 bits)
    val agu_c16 = out Bool()
    val agu_ordered = if (cfg.mmio) out Bool() else null
    val agu_clint = if (cfg.zicsr) out Bool() else null
    val agu_clint_read_sel = if (cfg.zicsr) out Bits(Clint.offsets.size bits) else null
    // Zicsr: this access is misaligned for its size (load/store-address-misaligned
    // exception; LsuTop reports it on the ROB's exception port). A CSR op uses the
    // byte opcode MEM_LB, so rs1's value never trips this.
    val agu_misaligned = if (cfg.zicsr) out Bool() else null
    val agu_is_store   = if (cfg.zicsr) out Bool() else null
  }
  noIoPrefix()

  // Combinational address generation is always ready.
  io.prv_ready := True
  io.nxt_valid := io.prv_valid

  // unpack agu_reg_in directly (no input register) -- LSB-first:
  //   rs2_value[31:0] rs1_value[63:32] imm[95:64] fu_opcode[99:96] rob_id[105:100]
  val rs2_value = AguReg.rs2Value(io.agu_reg_in)
  val rs1_value = AguReg.rs1Value(io.agu_reg_in)
  val imm       = AguReg.imm(io.agu_reg_in)
  val altImm = if (sharedImmediate) imm else io.alt_imm
  val fu_op     = AguReg.fuOpcode(io.agu_reg_in)
  val rob       = AguReg.robId(io.agu_reg_in, cfg)

  val baseSources = if (cfg.memCdbSpeculation)
    Seq(rs1_value) ++ io.base_sources_flat.subdivideIn(5 slices) ++ Seq(B(0,32 bits))
    else Seq(rs1_value)
  val baseValue = if (cfg.memCdbSpeculation) ooo.OhSel(io.base_source_select,baseSources) else rs1_value
  val alternateValue = if (cfg.memCdbSpeculation)
    Mux(io.alt_operand_select,io.alt_rs1_value,baseValue) else io.alt_rs1_value
  val regularRs1 = Mux(io.alt_sel,alternateValue,baseValue)
  val selRs1 = if (cfg.aluAguFusion) Mux(io.fast_select.orR,io.fast_value,regularRs1) else regularRs1
  val selImm = Mux(io.alt_sel, altImm, imm)
  val ordered = if (cfg.mmio) Bool() else null
  def addressSum(value: Bits, offset: Bits) =
    if (cfg.aguSignedImmediate)
      FastAdd.withSignedHiSplit(value.asUInt,offset(11 downto 0).asSInt,16,
        nativeCarry=cfg.fpgaNativeAdd,orPropagate=cfg.aguOrCarry,carrySelectAt=cfg.aguCarrySelectAt)
    else FastAdd.withHiSplit(value.asUInt,offset.asUInt,16,nativeCarry=cfg.fpgaNativeAdd,orPropagate=cfg.aguOrCarry)
  def misaligned(address: Bits): Bool = {
    val half = fu_op === MEM_LH || fu_op === MEM_LHU || fu_op === MEM_SH
    val word = fu_op === MEM_LW || fu_op === MEM_SW
    (half && address(0)) || (word && (address(1) || address(0)))
  }
  val (c16, hi0, hi1, unaligned_addr) = if (cfg.lsuWaySpeculation) {
    // Distribute the late way selection across address generation; no extra stage.
    type Address = (Bool,Bits,Bits,Bits,Bool,Bool,Bits,Bool)
    def summarize(parts: (UInt,Bool,UInt,UInt)): Address = {
      val (lo,carry,high0,high1) = parts
      val addr = Mux(carry,high1,high0) ## lo
      val device = if (cfg.mmio) DeviceRegion.orderedSplit(lo.asBits,high0.asBits,high1.asBits,carry,cfg) else False
      val isClint = Mux(carry,high1 === U(cfg.clintHi16,16 bits),high0 === U(cfg.clintHi16,16 bits))
      (carry,high0.asBits,high1.asBits,addr,device,isClint,Clint.registerSelect(addr),misaligned(addr))
    }
    def add(value: Bits,offset: Bits): Address = {
      val result = summarize(addressSum(value,offset))
      if (cfg.fpgaNativeAdd) result
      else {
        val displacement = if (cfg.aguSignedImmediate) offset(11 downto 0).asSInt.resize(32).asBits else offset
        result.copy(_7 = Clint.registerAddSelect(value,displacement))
      }
    }
    val fast = if (cfg.aluAguFusion) (0 until cfg.numFastBypass).map { k =>
      val source = io.fast_sources_flat(k * AluAddressSource.width,AluAddressSource.width bits)
      val offset = if (cfg.aguSignedImmediate) altImm(11 downto 0).asSInt.resize(32).asUInt
        else altImm.asUInt
      val fusedSum = summarize(FastAdd.withCsaHiSplit(AluAddressSource.a(source).asUInt,
        AluAddressSource.b(source).asUInt,offset,AluAddressSource.cin(source),16,
        nativeCarry=cfg.fpgaNativeAdd,orPropagate=cfg.aguOrCarry))
      val fused = if (cfg.fpgaNativeAdd) fusedSum else {
        val a = AluAddressSource.a(source); val b = AluAddressSource.b(source); val c = offset.asBits
        val sum = a ^ b ^ c
        val carry = ((a & b) | (a & c) | (b & c)) |<< 1
        fusedSum.copy(_7 = Clint.registerAddSelect(sum,carry,AluAddressSource.cin(source)))
      }
      val zero = add(B(0,32 bits),altImm); val one = add(B(1,32 bits),altImm)
      val other = add(AluAddressSource.other(source),altImm)
      def value(get: Address => Bits): Bits = Mux(AluAddressSource.add(source),get(fused),
        Mux(AluAddressSource.cmp(source),Mux(AluAddressSource.compare(source),get(one),get(zero)),get(other)))
      (value(_._1.asBits)(0),value(_._2),value(_._3),value(_._4),value(_._5.asBits)(0),
        value(_._6.asBits)(0),value(_._7),value(_._8.asBits)(0))
    } else Seq.empty[Address]
    def choose(normal: Bits,get: Address => Bits): Bits = if (cfg.aluAguFusion)
      Mux(io.fast_select.orR,ooo.OhSel(io.fast_select,fast.map(get)),normal) else normal
    def baseAddress(offset: Bits): Address = if (cfg.memCdbSpeculation) {
      val arms = baseSources.map(add(_,offset))
      def get(field: Address => Bits): Bits = ooo.OhSel(io.base_source_select,arms.map(field))
      (get(_._1.asBits)(0),get(_._2),get(_._3),get(_._4),get(_._5.asBits)(0),
        get(_._6.asBits)(0),get(_._7),get(_._8.asBits)(0))
    } else add(rs1_value,offset)
    val primary = baseAddress(imm)
    val ways = (0 until cfg.lsuBypassCandidates).map(w => add(io.alt_way_rs1_flat(w * 32,32 bits),altImm))
    val select = io.alt_way_select
    val operandBase = if (cfg.lsuOperandSpeculation && !sharedImmediate) baseAddress(altImm) else primary
    def selected(get: Address => Bits): Bits = {
      val forwarded = ooo.OhSel(select,ways.map(get))
      if (cfg.lsuOperandSpeculation) {
        val base = get(operandBase)
        Mux(io.alt_operand_select,forwarded,Mux(select.orR,base,B(0,base.getWidth bits)))
      } else forwarded
    }
    if (cfg.zicsr) {
      io.agu_misaligned := choose(Mux(io.alt_sel,selected(_._8.asBits),primary._8.asBits),_._8.asBits)(0)
      io.agu_clint := choose(Mux(io.alt_sel,selected(_._6.asBits),primary._6.asBits),_._6.asBits)(0)
      io.agu_clint_read_sel := choose(Mux(io.alt_sel,selected(_._7),primary._7),_._7)
    }
    if (cfg.mmio) ordered := choose(Mux(io.alt_sel,selected(_._5.asBits),primary._5.asBits),_._5.asBits)(0)
    (choose(Mux(io.alt_sel,selected(_._1.asBits),primary._1.asBits),_._1.asBits)(0),
      choose(Mux(io.alt_sel,selected(_._2),primary._2),_._2),
      choose(Mux(io.alt_sel,selected(_._3),primary._3),_._3),
      choose(Mux(io.alt_sel,selected(_._4),primary._4),_._4))
  } else if (cfg.aguParallelAdd) {
    // Keep the late bypass-valid signal after both effective-address adders.
    val (loA, cA, hiA0, hiA1) = addressSum(rs1_value,imm)
    val (loB, cB, hiB0, hiB1) = addressSum(io.alt_rs1_value,altImm)
    val addrA = Mux(cA,hiA1,hiA0) ## loA
    val addrB = Mux(cB,hiB1,hiB0) ## loB
    if (cfg.zicsr) {
      io.agu_misaligned := Mux(io.alt_sel,misaligned(addrB),misaligned(addrA))
      io.agu_clint := Mux(io.alt_sel,
        Mux(cB,hiB1 === U(cfg.clintHi16,16 bits),hiB0 === U(cfg.clintHi16,16 bits)),
        Mux(cA,hiA1 === U(cfg.clintHi16,16 bits),hiA0 === U(cfg.clintHi16,16 bits)))
      io.agu_clint_read_sel := Mux(io.alt_sel,Clint.registerSelect(addrB),Clint.registerSelect(addrA))
    }
    if (cfg.mmio) ordered := Mux(io.alt_sel,
      DeviceRegion.orderedSplit(loB.asBits,hiB0.asBits,hiB1.asBits,cB,cfg),
      DeviceRegion.orderedSplit(loA.asBits,hiA0.asBits,hiA1.asBits,cA,cfg))
    (Mux(io.alt_sel,cB,cA), Mux(io.alt_sel,hiB0,hiA0),
      Mux(io.alt_sel,hiB1,hiA1), Mux(io.alt_sel,addrB,addrA))
  } else {
    val (lo, carry, high0, high1) = addressSum(selRs1,selImm)
    if (cfg.mmio) ordered := DeviceRegion.orderedSplit(lo.asBits,high0.asBits,high1.asBits,carry,cfg)
    (carry, high0, high1, Mux(carry,high1,high0) ## lo)
  }
  if (cfg.zicsr && !cfg.lsuWaySpeculation && !cfg.aguParallelAdd) {
    io.agu_clint := unaligned_addr(31 downto 16) === B(cfg.clintHi16,16 bits)
    io.agu_clint_read_sel := Clint.registerSelect(unaligned_addr)
  }
  io.agu_hi0 := hi0.asBits
  io.agu_hi1 := hi1.asBits
  io.agu_c16 := c16
  if (cfg.mmio) io.agu_ordered := ordered
  // the issued entry's true rs1 (debug/RVFI field) -- same selection
  val rs1_dbg = selRs1
  if (cfg.lsuCarryFreeStoreMatch) {
    val offset=if (cfg.aguSignedImmediate) selImm(11 downto 0).asSInt.resize(32).asBits else selImm
    for (target <- 0 to cfg.stbDepth)
      io.agu_stb_matches(target):=AguWordMatch.carryFree(selRs1,offset,io.stb_match_targets(target*32,32 bits))
  }
  val a10 = unaligned_addr(1 downto 0).asUInt                        // byte offset

  // Place SB/SH data in the addressed byte lanes; unused lanes are zero.
  val sb = rs2_value(7 downto 0); val z8 = B(0, 8 bits); val z16 = B(0, 16 bits)
  val sh = rs2_value(15 downto 0)
  val wdata = Bits(32 bits)
  switch(fu_op) {
    is(MEM_SB) { wdata := a10.mux(
                   0       -> (z8  ## z8  ## z8 ## sb),
                   1       -> (z8  ## z8  ## sb ## z8),
                   2       -> (z8  ## sb  ## z16),
                   default -> (sb  ## z8  ## z16)) }          // a10 == 3
    is(MEM_SH) { wdata := Mux(unaligned_addr(1), sh ## z16, z16 ## sh) }
    is(MEM_SW) { wdata := rs2_value }
    default    { wdata := B(0, 32 bits) }
  }

  // byte mask
  val mask = Bits(4 bits)
  switch(fu_op) {
    is(MEM_LB, MEM_LBU, MEM_SB) { mask := B"4'b0001" |<< a10 }
    is(MEM_LH, MEM_LHU, MEM_SH) { mask := B"4'b0011" |<< a10 }
    is(MEM_LW, MEM_SW)          { mask := B"4'b1111" }
    default                     { mask := B(0, 4 bits) }
  }

  if (cfg.zicsr) {
    if (!cfg.lsuWaySpeculation && !cfg.aguParallelAdd)
      io.agu_misaligned := misaligned(unaligned_addr)
    io.agu_is_store   := fu_op(3)
  }

  // pack to_lsq (first field = MSB)
  // AtomicUnit uses the rs2 debug payload as its read-modify-write operand.
  // Queue-local RVFI copies may be discarded; this architectural operand must
  // remain. CsrUnit obtains its rs1 operand from the effective-address field.
  val rs1Payload = if (cfg.rvfi) rs1_dbg else B(0, 32 bits)
  val rs2Payload = if (cfg.rvfi || cfg.aExt) rs2_value else B(0, 32 bits)
  io.to_lsq := AguLsq.pack(rob, unaligned_addr, wdata, mask, rs1Payload, rs2Payload)
}
