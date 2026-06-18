package ooo.frontend

import spinal.core._

/** Port-compatible SpinalHDL twin of `hdl/frontend/decompressor.sv`.
  *
  * Combinational RV32C -> RV32I expander. A full 32-bit instruction
  * (inst_in[1:0]==2'b11) passes through; the integer RV32C subset expands to its
  * base encoding; FP/RV64 forms decode to a canonical illegal (all-zero).
  *
  * Module name + ports match the SV module so it drops into fetch_align.sv by-name
  * (`decompressor d_i (.inst_in, .inst_out, .is_compressed)`). Combinational-only
  * => SpinalHDL emits no clk/reset ports.
  */
class Decompressor extends Component {
  setDefinitionName("decompressor")

  val io = new Bundle {
    val inst_in       = in  Bits (32 bits)
    val inst_out      = out Bits (32 bits)
    val is_compressed = out Bool ()
  }
  noIoPrefix()

  val ILLEGAL = B(0, 32 bits)

  // replicate a single bit n times (for the fixed-width sign-bit fields in the
  // SV {{N{inst[12]}}, ...} immediates -- NOT a resize, part of a fixed assembly)
  def rep(b: Bool, n: Int): Bits = (1 until n).foldLeft(b.asBits)((acc, _) => acc ## b)

  // 3-bit popular register field c.rs'/c.rd' -> x8..x15
  def creg(r: Bits): Bits = B"2'b01" ## r   // r is 3 bits -> 5 bits

  val quad   = io.inst_in(1 downto 0)
  val funct3 = io.inst_in(15 downto 13)
  io.is_compressed := quad =/= B"2'b11"

  // common compressed register fields
  val rd_h  = io.inst_in(11 downto 7)
  val rs1_h = io.inst_in(11 downto 7)
  val rs2_h = io.inst_in(6 downto 2)
  val rd_p  = creg(io.inst_in(4 downto 2))
  val rs1_p = creg(io.inst_in(9 downto 7))
  val rs2_p = creg(io.inst_in(4 downto 2))

  // base-ISA encoders (widths: f7=7 rs2=5 rs1=5 f3=3 rd=5 op=7 ; imm widths noted)
  def encR(f7: Bits, rs2: Bits, rs1: Bits, f3: Bits, rd: Bits, op: Bits): Bits =
    f7 ## rs2 ## rs1 ## f3 ## rd ## op
  def encI(imm: Bits /*12*/, rs1: Bits, f3: Bits, rd: Bits, op: Bits): Bits =
    imm ## rs1 ## f3 ## rd ## op
  def encS(imm: Bits /*12*/, rs2: Bits, rs1: Bits, f3: Bits, op: Bits): Bits =
    imm(11 downto 5) ## rs2 ## rs1 ## f3 ## imm(4 downto 0) ## op
  def encB(imm: Bits /*13*/, rs2: Bits, rs1: Bits, f3: Bits, op: Bits): Bits =
    imm(12) ## imm(10 downto 5) ## rs2 ## rs1 ## f3 ## imm(4 downto 1) ## imm(11) ## op
  def encU(imm: Bits /*20 = [31:12]*/, rd: Bits, op: Bits): Bits =
    imm ## rd ## op
  def encJ(imm: Bits /*21*/, rd: Bits, op: Bits): Bits =
    imm(20) ## imm(10 downto 1) ## imm(11) ## imm(19 downto 12) ## rd ## op

  val i12 = io.inst_in(12)

  // assorted compressed immediates (mirror decompressor.sv exactly)
  val imm_ci       = (i12 ## io.inst_in(6 downto 2)).asSInt.resize(12).asBits          // 6-bit signed
  val imm_lw       = B"5'b0" ## io.inst_in(5) ## io.inst_in(12 downto 10) ## io.inst_in(6) ## B"2'b00"
  val imm_addi4spn = B"2'b0" ## io.inst_in(10 downto 7) ## io.inst_in(12 downto 11) ## io.inst_in(5) ## io.inst_in(6) ## B"2'b00"
  val imm_addi16sp = rep(i12, 3) ## io.inst_in(4 downto 3) ## io.inst_in(5) ## io.inst_in(2) ## io.inst_in(6) ## B"4'b0000"
  val imm_lui      = rep(i12, 15) ## io.inst_in(6 downto 2)                            // [31:12] = 20 bits
  val imm_lwsp     = B"4'b0" ## io.inst_in(3 downto 2) ## i12 ## io.inst_in(6 downto 4) ## B"2'b00"
  val imm_swsp     = B"4'b0" ## io.inst_in(8 downto 7) ## io.inst_in(12 downto 9) ## B"2'b00"
  val imm_cb       = rep(i12, 5) ## io.inst_in(6 downto 5) ## io.inst_in(2) ## io.inst_in(11 downto 10) ## io.inst_in(4 downto 3) ## B"1'b0"
  val imm_cj       = rep(i12, 10) ## io.inst_in(8) ## io.inst_in(10 downto 9) ## io.inst_in(6) ##
                     io.inst_in(7) ## io.inst_in(2) ## io.inst_in(11) ## io.inst_in(5 downto 3) ## B"1'b0"

  io.inst_out := ILLEGAL
  when(quad === B"2'b11") {
    io.inst_out := io.inst_in                                                          // already 32-bit
  } otherwise {
    switch(quad) {
      //----------------------------------------------------------------- C0
      is(B"2'b00") {
        switch(funct3) {
          is(B"3'b000") {
            io.inst_out := Mux(io.inst_in(12 downto 2) === 0, ILLEGAL,                 // reserved
                               encI(imm_addi4spn, B(2, 5 bits), B"3'b000", rd_p, B"7'b0010011")) // c.addi4spn
          }
          is(B"3'b010") { io.inst_out := encI(imm_lw, rs1_p, B"3'b010", rd_p, B"7'b0000011") }   // c.lw
          is(B"3'b110") { io.inst_out := encS(imm_lw, rs2_p, rs1_p, B"3'b010", B"7'b0100011") }  // c.sw
          default       { io.inst_out := ILLEGAL }                                     // FP / reserved
        }
      }
      //----------------------------------------------------------------- C1
      is(B"2'b01") {
        switch(funct3) {
          is(B"3'b000") { io.inst_out := encI(imm_ci, rd_h, B"3'b000", rd_h, B"7'b0010011") }    // c.addi / c.nop
          is(B"3'b001") { io.inst_out := encJ(imm_cj, B(1, 5 bits), B"7'b1101111") }             // c.jal
          is(B"3'b010") { io.inst_out := encI(imm_ci, B(0, 5 bits), B"3'b000", rd_h, B"7'b0010011") } // c.li
          is(B"3'b011") {
            io.inst_out := Mux(rd_h === B(2, 5 bits),
                               encI(imm_addi16sp, B(2, 5 bits), B"3'b000", B(2, 5 bits), B"7'b0010011"), // c.addi16sp
                               encU(imm_lui, rd_h, B"7'b0110111"))                     // c.lui
          }
          is(B"3'b100") {
            switch(io.inst_in(11 downto 10)) {
              is(B"2'b00") { io.inst_out := encI(B"6'b0" ## i12 ## io.inst_in(6 downto 2), rs1_p, B"3'b101", rs1_p, B"7'b0010011") } // c.srli
              is(B"2'b01") { io.inst_out := encI(B"7'b0100000" ## io.inst_in(6 downto 2), rs1_p, B"3'b101", rs1_p, B"7'b0010011") } // c.srai (arith)
              is(B"2'b10") { io.inst_out := encI(imm_ci, rs1_p, B"3'b111", rs1_p, B"7'b0010011") }  // c.andi
              is(B"2'b11") {
                switch(i12 ## io.inst_in(6 downto 5)) {
                  is(B"3'b000") { io.inst_out := encR(B"7'b0100000", rs2_p, rs1_p, B"3'b000", rs1_p, B"7'b0110011") } // c.sub
                  is(B"3'b001") { io.inst_out := encR(B"7'b0000000", rs2_p, rs1_p, B"3'b100", rs1_p, B"7'b0110011") } // c.xor
                  is(B"3'b010") { io.inst_out := encR(B"7'b0000000", rs2_p, rs1_p, B"3'b110", rs1_p, B"7'b0110011") } // c.or
                  is(B"3'b011") { io.inst_out := encR(B"7'b0000000", rs2_p, rs1_p, B"3'b111", rs1_p, B"7'b0110011") } // c.and
                  default       { io.inst_out := ILLEGAL }                             // c.subw/addw = RV64
                }
              }
            }
          }
          is(B"3'b101") { io.inst_out := encJ(imm_cj, B(0, 5 bits), B"7'b1101111") }              // c.j
          is(B"3'b110") { io.inst_out := encB(imm_cb, B(0, 5 bits), rs1_p, B"3'b000", B"7'b1100011") } // c.beqz
          is(B"3'b111") { io.inst_out := encB(imm_cb, B(0, 5 bits), rs1_p, B"3'b001", B"7'b1100011") } // c.bnez
          // all 8 funct3 covered -> no default
        }
      }
      //----------------------------------------------------------------- C2
      is(B"2'b10") {
        switch(funct3) {
          is(B"3'b000") { io.inst_out := encI(B"6'b0" ## i12 ## io.inst_in(6 downto 2), rd_h, B"3'b001", rd_h, B"7'b0010011") } // c.slli
          is(B"3'b010") {
            io.inst_out := Mux(rd_h === 0, ILLEGAL,                                    // c.lwsp rd!=0
                               encI(imm_lwsp, B(2, 5 bits), B"3'b010", rd_h, B"7'b0000011")) // c.lwsp
          }
          is(B"3'b100") {
            when(i12 === False) {
              io.inst_out := Mux(rs2_h === 0,
                                 encI(B(0, 12 bits), rs1_h, B"3'b000", B(0, 5 bits), B"7'b1100111"),  // c.jr
                                 encR(B(0, 7 bits), rs2_h, B(0, 5 bits), B"3'b000", rd_h, B"7'b0110011")) // c.mv
            } otherwise {
              when(rs1_h === 0 && rs2_h === 0) {
                io.inst_out := B"32'h00100073"                                         // c.ebreak
              } elsewhen(rs2_h === 0) {
                io.inst_out := encI(B(0, 12 bits), rs1_h, B"3'b000", B(1, 5 bits), B"7'b1100111")     // c.jalr
              } otherwise {
                io.inst_out := encR(B(0, 7 bits), rs2_h, rd_h, B"3'b000", rd_h, B"7'b0110011")        // c.add
              }
            }
          }
          is(B"3'b110") { io.inst_out := encS(imm_swsp, rs2_h, B(2, 5 bits), B"3'b010", B"7'b0100011") } // c.swsp
          default       { io.inst_out := ILLEGAL }                                     // FP forms
        }
      }
      default { io.inst_out := ILLEGAL }
    }
  }
}
