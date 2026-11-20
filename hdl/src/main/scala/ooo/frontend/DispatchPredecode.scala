package ooo.frontend

import spinal.core._
import ooo.CpuConfig

object DispatchPredecode {
  /** Control, call and return flags from a raw 16- or 32-bit instruction. */
  def controlFlags(inst: Bits, compressed: Bool): (Bool, Bool, Bool) = {
    // 32-bit form
    val op32 = inst(6 downto 0); val rd32 = inst(11 downto 7); val rs1_32 = inst(19 downto 15)
    val linkRd32 = (rd32 === 1) || (rd32 === 5); val linkRs1_32 = (rs1_32 === 1) || (rs1_32 === 5)
    val jal32 = op32 === B"7'b1101111"; val jalr32 = op32 === B"7'b1100111"; val br32 = op32 === B"7'b1100011"
    val ctrl32 = br32 || jal32 || jalr32
    val call32 = (jal32 || jalr32) && linkRd32
    val ret32  = jalr32 && linkRs1_32 && !linkRd32
    // compressed form (fields all within the low 16b = the lane's own parcel)
    val q = inst(1 downto 0); val f3 = inst(15 downto 13); val i12 = inst(12)
    val rs2h = inst(6 downto 2); val rs1h = inst(11 downto 7)
    val cJal  = (q === B"2'b01") && (f3 === B"3'b001")                                   // c.jal  -> jal x1
    val cJ    = (q === B"2'b01") && (f3 === B"3'b101")                                   // c.j    -> jal x0
    val cBeqz = (q === B"2'b01") && (f3 === B"3'b110")                                   // c.beqz
    val cBnez = (q === B"2'b01") && (f3 === B"3'b111")                                   // c.bnez
    val cJr   = (q === B"2'b10") && (f3 === B"3'b100") && !i12 && (rs2h === 0)           // c.jr   -> jalr x0,rs1
    val cJalr = (q === B"2'b10") && (f3 === B"3'b100") && i12 && (rs2h === 0) && (rs1h =/= 0) // c.jalr -> jalr x1,rs1
    val ctrlC = cJal || cJ || cBeqz || cBnez || cJr || cJalr
    val callC = cJal || cJalr
    val retC  = cJr && ((rs1h === 1) || (rs1h === 5))
    (Mux(compressed, ctrlC, ctrl32), Mux(compressed, callC, call32), Mux(compressed, retC, ret32))
  }

  val width = 6
  def isBranch(inst: Bits): Bool = {
    val op = inst(6 downto 0)
    (op === B"7'b1100011") || (op === B"7'b1101111") || (op === B"7'b1100111")
  }

  // Predecode dispatch-control fields when enqueueing, removing instruction decode from the ready path.
  private def OP_LUI   = B"7'b0110111"; private def OP_AUIPC = B"7'b0010111"
  private def OP_JAL   = B"7'b1101111"; private def OP_JALR  = B"7'b1100111"
  private def OP_BR    = B"7'b1100011"; private def OP_LOAD  = B"7'b0000011"
  private def OP_STORE = B"7'b0100011"; private def OP_IMM   = B"7'b0010011"
  private def OP_REG   = B"7'b0110011"; private def OP_AMO   = B"7'b0101111"
  private def RS_INT = B"2'b00"; private def RS_INTM = B"2'b01"
  private def RS_BR  = B"2'b10"; private def RS_MEM  = B"2'b11"

  case class DispatchFields() extends Bundle {
    val rsType = Bits(2 bits)
    val isStore = Bool(); val isAtomic = Bool(); val hasRd = Bool(); val isBr = Bool()
  }
  /** Dispatch controls from a raw parcel, including the decompressor's reserved forms. */
  def decodeParcel(inst: Bits, cfg: CpuConfig): Bits = {
    val normal=decode(inst,cfg).asBits
    if (!cfg.cExt) return normal
    val c=DispatchFields()
    c.rsType:=RS_INT;c.isStore:=False;c.isAtomic:=False;c.hasRd:=False;c.isBr:=False
    val rdNonzero=inst(11 downto 7) =/= 0
    val rs2Nonzero=inst(6 downto 2) =/= 0
    val funct3=inst(15 downto 13)
    def branch(): Unit = {c.rsType:=RS_BR;c.isBr:=True}
    def load(): Unit = {c.rsType:=RS_MEM;c.hasRd:=True}
    def store(): Unit = {c.rsType:=RS_MEM;c.isStore:=True}
    switch(inst(1 downto 0)) {
      is(B"2'b00") {
        switch(funct3) {
          is(B"3'b000") {c.hasRd:=inst(12 downto 2) =/= 0}
          is(B"3'b010") {load()}
          is(B"3'b110") {store()}
        }
      }
      is(B"2'b01") {
        switch(funct3) {
          is(B"3'b000",B"3'b010",B"3'b011") {c.hasRd:=rdNonzero}
          is(B"3'b001") {branch();c.hasRd:=True}
          is(B"3'b100") {c.hasRd:=(inst(11 downto 10) =/= B"2'b11") || !inst(12)}
          is(B"3'b101",B"3'b110",B"3'b111") {branch()}
        }
      }
      is(B"2'b10") {
        switch(funct3) {
          is(B"3'b000") {c.hasRd:=rdNonzero}
          is(B"3'b010") {when(rdNonzero) {load()}}
          is(B"3'b100") {
            c.hasRd:=rdNonzero && (rs2Nonzero || inst(12))
            when(!rs2Nonzero && (!inst(12) || rdNonzero)) {branch()}
          }
          is(B"3'b110") {store()}
        }
      }
    }
    Mux(inst(1 downto 0) =/= B"2'b11",c.asBits,normal)
  }

  def decode(inst: Bits, cfg: CpuConfig): DispatchFields = {
    val p = DispatchFields()
    val op = inst(6 downto 0)
    // amoEn is a Scala-constant False when !aExt, so every term below reduces
    // bit-identically in an RV32IM elaboration -- same argument as the Decoder.
    val amoEn = if (cfg.aExt) (op === OP_AMO) else False
    // Register-register operations use funct7(0) to select the M-extension station.
    p.rsType := RS_INT                                        // Decoder's default
    switch(op) {
      is(OP_AUIPC, OP_JAL, OP_JALR, OP_BR) { p.rsType := RS_BR }
      is(OP_LOAD, OP_STORE)                { p.rsType := RS_MEM }
      is(OP_REG) { p.rsType := Mux(inst(25), RS_INTM, RS_INT) }  // funct7(0) = inst(25)
      default    { /* LUI / IMM / unknown -> RS_INT */ }
    }
    if (cfg.aExt) when(op === OP_AMO) { p.rsType := RS_MEM }
    // CSR operations and enabled barriers execute serially at the ROB head.
    val csrEn  = if (cfg.zicsr) (op === B"7'b1110011") && (inst(14 downto 12) =/= 0) else False
    val mretEn = if (cfg.zicsr) (op === B"7'b1110011") && (inst(14 downto 12) === 0) && (inst(31 downto 20) === B"12'h302") else False
    val wfiEn = if (cfg.lowPower) inst === B"32'h10500073" else False
    val fenceEn = if (cfg.zicsr) (op === B"7'b0001111") &&
      (inst(14 downto 12) === 0 || inst(14 downto 12) === 1) else False
    val barrierEn = wfiEn || fenceEn
    if (cfg.zicsr) when(csrEn || mretEn || barrierEn) { p.rsType := RS_MEM }
    p.isStore  := op === OP_STORE
    // isAtomic is really "serial-at-head": IdStage's br0+X1 hazard filter uses it to
    // keep an irreversible head-executed op out of slot 1 behind a branch. CSR/mret
    // have exactly that property.
    p.isAtomic := (if (cfg.zicsr) amoEn || csrEn || mretEn || barrierEn else amoEn)
    // Only instructions that write a nonzero architectural register allocate a destination.
    val rdEn = (op === OP_LUI) || (op === OP_AUIPC) || (op === OP_IMM) ||
               (op === OP_REG) || (op === OP_JAL)  || (op === OP_JALR) ||
               (op === OP_LOAD) || amoEn
    p.hasRd := (if (cfg.zicsr) rdEn || csrEn else rdEn) && (inst(11 downto 7) =/= 0)
    p.isBr  := isBranch(inst)   // the one-branch-per-bundle cap, also off the read side
    p
  }

}
