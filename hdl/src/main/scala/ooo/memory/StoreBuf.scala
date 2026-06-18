package ooo.memory

import spinal.core._
import ooo.CpuConfig

/** SpinalHDL port of `hdl/memory/store_buf.sv` -- the post-commit store buffer: a
  * FIFO of retired stores draining to the D-cache, with load-forwarding conflict
  * detection (a younger load that overlaps a buffered store's bytes must wait).
  *
  * Named store_buf_spinal; sim/swap_shims/store_buf.sv carries stq_stb_itf.stb,
  * stb_dmem_itf.cache and the ldq_stb_itf.stb unpacked-array conflict ports.
  */
class StoreBuf(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("store_buf_spinal")
  val DEPTH = cfg.stbDepth     // 4
  val IDX   = cfg.stbIdx       // 2
  val LDQ   = cfg.ldqDepth     // 8

  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool()
    // stq_stb_itf.stb from_stq
    val from_stq_valid = in  Bool()
    val from_stq_ready = out Bool()
    val from_stq_addr  = in  Bits (32 bits)
    val from_stq_wmask = in  Bits (4 bits)
    val from_stq_wdata = in  Bits (32 bits)
    // stb_dmem_itf.cache dmem
    val dmem_valid = out Bool()
    val dmem_ready = in  Bool()
    val dmem_addr  = out Bits (32 bits)
    val dmem_wmask = out Bits (4 bits)
    val dmem_wdata = out Bits (32 bits)
    // ldq_stb_itf.stb from_ldq
    val ldq_addr_flat  = in  Bits (LDQ * 32 bits)
    val ldq_rmask_flat = in  Bits (LDQ * 4 bits)
    val has_conflicting_store = out Bits (LDQ bits)
    val dbg_full = out Bool()   // perf_monitor taps stb_i.full
  }
  noIoPrefix()

  def ldqAddr(i: Int)  = io.ldq_addr_flat(i * 32, 32 bits)
  def ldqRmask(i: Int) = io.ldq_rmask_flat(i * 4, 4 bits)

  val domain = ClockDomain(clock = io.clk, reset = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC))

  new ClockingArea(domain) {
    val valid = Vec(RegInit(False), DEPTH)
    val addr  = Vec(Reg(Bits(32 bits)), DEPTH)
    val mask  = Vec(Reg(Bits(4 bits)), DEPTH)
    val wdata = Vec(Reg(Bits(32 bits)), DEPTH)
    val wrPtr = RegInit(U(0, IDX + 1 bits))
    val rdPtr = RegInit(U(0, IDX + 1 bits))
    val wrActual = wrPtr(IDX - 1 downto 0); val wrFlag = wrPtr(IDX)
    val rdActual = rdPtr(IDX - 1 downto 0); val rdFlag = rdPtr(IDX)

    val full  = (wrActual === rdActual) && (wrFlag === !rdFlag)
    val empty = wrPtr === rdPtr
    io.from_stq_ready := !full

    val enqueue     = io.from_stq_valid && !full
    val wantDequeue = !empty
    val dequeue     = wantDequeue && io.dmem_ready

    when(enqueue) {
      valid(wrActual) := True
      addr(wrActual)  := io.from_stq_addr
      mask(wrActual)  := io.from_stq_wmask
      wdata(wrActual) := io.from_stq_wdata
      wrPtr := wrPtr + 1
    }
    when(dequeue) {
      valid(rdActual) := False
      rdPtr := rdPtr + 1
    }

    // D-cache drain port
    io.dmem_valid := wantDequeue
    io.dmem_wmask := mask(rdActual)
    io.dmem_addr  := addr(rdActual)(31 downto 2) ## B(0, 2 bits)
    io.dmem_wdata := wdata(rdActual)

    // load-forwarding conflict: buffered store overlaps the load's bytes
    val conflict = Vec(Bool(), LDQ)
    for (i <- 0 until LDQ) {
      conflict(i) := (0 until DEPTH).map { j =>
        valid(j) && (addr(j)(31 downto 2) === ldqAddr(i)(31 downto 2)) &&
        ((ldqRmask(i) & ~mask(j)) =/= ldqRmask(i))
      }.reduce(_ || _)
    }
    io.has_conflicting_store := conflict.asBits
    io.dbg_full := full
  }
}
