package ooo.execute

import spinal.core._
import ooo.CpuConfig

/** In-order branch resolution and misprediction recovery. */
class ControlBuffer(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("control_buffer_spinal")
  val DEPTH = cfg.cbDepth
  val IDX   = log2Up(DEPTH)
  val PROV  = cfg.bpProvW
  val RIDX  = cfg.robIdx
  def BR_AUIPC = B"4'b1111"

  case class CbEntry() extends Bundle {
    val rob_id = Bits(RIDX bits); val miss_predict = Bool(); val target_address = Bits(32 bits)
    val branch_taken = Bool(); val pc = Bits(32 bits); val fu_opcode = Bits(4 bits)
    val kp = Bits(log2Up(cfg.ifWidth) bits); val is_call = Bool(); val is_ret = Bool(); val is_compressed = Bool()
    val prov = Bits(PROV bits)
  }

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    val from_ds_valid = in Bool()
    val from_ds_ready = out Bool()
    val uop_rob_id = in Bits (RIDX bits);  val uop_pc = in Bits (32 bits)
    val uop_fu_opcode = in Bits (4 bits); val uop_kp = in Bits (log2Up(cfg.ifWidth) bits)
    val uop_prov = in Bits (PROV bits)
    val uop_is_compressed = in Bool(); val uop_inst = in Bits (32 bits)
    val branch_ready = in Bool()
    val br_cdb_valid = in Bool(); val br_cdb_rob_id = in Bits (RIDX bits)
    val br_cdb_miss_predict = in Bool(); val br_cdb_target = in Bits (32 bits)
    val br_cdb_branch_taken = in Bool()
    val to_rob_rob_id = out Bits (RIDX bits); val to_rob_miss_predict = out Bool()
    val to_rob_target = out Bits (32 bits); val to_rob_ready = out Bool()
    val to_rob_dequeue = in Bool()
    val to_bp_update_en = out Bool(); val to_bp_pc = out Bits (32 bits)
    val to_bp_fu_opcode = out Bits (4 bits); val to_bp_branch_taken = out Bool()
    val to_bp_target = out Bits (32 bits); val to_bp_kp = out Bits (log2Up(cfg.ifWidth) bits)
    val to_bp_is_call = out Bool(); val to_bp_is_ret = out Bool(); val to_bp_is_compressed = out Bool()
    val to_bp_prov = out Bits (PROV bits)
  }
  noIoPrefix()

  // RAS classification of the enqueuing branch (x1/x5 are link registers)
  val enq_opcode = io.uop_inst(6 downto 0)
  val enq_rd     = io.uop_inst(11 downto 7)
  val enq_rs1    = io.uop_inst(19 downto 15)
  val enq_link_rd  = (enq_rd === 1) || (enq_rd === 5)
  val enq_link_rs1 = (enq_rs1 === 1) || (enq_rs1 === 5)
  val enq_is_call = ((enq_opcode === B"7'b1101111") || (enq_opcode === B"7'b1100111")) && enq_link_rd
  val enq_is_ret  = (enq_opcode === B"7'b1100111") && enq_link_rs1 && !enq_link_rd

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val fifo   = Vec(Reg(CbEntry()), DEPTH)
    val wr_ptr = RegInit(U(0, IDX + 1 bits))
    val rd_ptr = RegInit(U(0, IDX + 1 bits))
    val wr_actual = wr_ptr(IDX - 1 downto 0); val wr_flag = wr_ptr(IDX)
    val rd_actual = rd_ptr(IDX - 1 downto 0); val rd_flag = rd_ptr(IDX)

    val empty = wr_ptr === rd_ptr
    val full  = (wr_actual === rd_actual) && (wr_flag =/= rd_flag)
    io.from_ds_ready := !full
    val enqueue = io.from_ds_valid && io.branch_ready && (io.uop_fu_opcode =/= BR_AUIPC)
    val dequeue = io.to_rob_dequeue

    when(enqueue && !full) {
      fifo(wr_actual).rob_id        := io.uop_rob_id
      fifo(wr_actual).pc            := io.uop_pc
      fifo(wr_actual).fu_opcode     := io.uop_fu_opcode
      fifo(wr_actual).kp            := io.uop_kp
      fifo(wr_actual).prov          := io.uop_prov
      fifo(wr_actual).is_call       := enq_is_call
      fifo(wr_actual).is_ret        := enq_is_ret
      fifo(wr_actual).is_compressed := io.uop_is_compressed
      wr_ptr := wr_ptr + 1
    }
    for (i <- 0 until DEPTH) {
      when(io.br_cdb_valid && (fifo(i).rob_id === io.br_cdb_rob_id)) {
        fifo(i).miss_predict   := io.br_cdb_miss_predict
        fifo(i).target_address := io.br_cdb_target
        fifo(i).branch_taken   := io.br_cdb_branch_taken
      }
    }
    when(dequeue) { rd_ptr := rd_ptr + 1 }

    val head = if (!cfg.implementation.isFpga && DEPTH >= 2 && (DEPTH & (DEPTH - 1)) == 0) {
      val headSelect = Reg(Bits(DEPTH bits)) init(B(1,DEPTH bits))
      headSelect.setName("cbHeadSelect")
      when(dequeue) {
        for (i <- 0 until DEPTH) headSelect((i + 1) % DEPTH) := headSelect(i)
      }
      val entry = CbEntry()
      entry.assignFromBits(ooo.OhSel(headSelect,fifo.map(_.asBits)))
      entry
    } else fifo(rd_actual)
    io.to_rob_rob_id       := head.rob_id
    io.to_rob_miss_predict := head.miss_predict
    io.to_rob_target       := head.target_address
    io.to_rob_ready        := !empty

    io.to_bp_update_en     := dequeue
    io.to_bp_pc            := head.pc
    io.to_bp_fu_opcode     := head.fu_opcode
    io.to_bp_branch_taken  := head.branch_taken
    io.to_bp_target        := head.target_address
    io.to_bp_kp            := head.kp
    io.to_bp_prov          := head.prov
    io.to_bp_is_call       := head.is_call
    io.to_bp_is_ret        := head.is_ret
    io.to_bp_is_compressed := head.is_compressed
  }
}
