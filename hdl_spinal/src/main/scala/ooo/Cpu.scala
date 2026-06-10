package ooo

import spinal.core._

/** Top-level core. Emits a Verilog module named `cpu` whose ports match the SV
  * `hdl/cpu.sv` boundary EXACTLY (clk, rst, bmem_*), so it drops straight into
  * the existing HVL testbench + SRAM blackboxes + RVFI monitor.
  *
  * clk/rst are explicit IO driving an internal ClockDomain (active-high sync
  * reset), so the generated port names are `clk`/`rst` -- not SpinalHDL's default
  * `clk`/`reset`. ALL clocked logic lives in the `core` ClockingArea.
  *
  * SKELETON: outputs are tied off. Subsystems are filled in per ROADMAP.md, each
  * validated against the SV core as oracle (module-swap co-validation).
  */
class Cpu(cfg: CpuConfig = CpuConfig()) extends Component {
  setDefinitionName("cpu")

  val io = new Bundle {
    val clk = in  Bool()
    val rst = in  Bool()
    // backing-memory (bmem) interface -- identical to hdl/cpu.sv
    val bmem_addr   = out UInt (32 bits)
    val bmem_read   = out Bool ()
    val bmem_write  = out Bool ()
    val bmem_wdata  = out Bits (64 bits)
    val bmem_ready  = in  Bool ()
    val bmem_raddr  = in  UInt (32 bits)
    val bmem_rdata  = in  Bits (64 bits)
    val bmem_rvalid = in  Bool ()
  }
  noIoPrefix()

  // explicit clock domain so the ports are named clk/rst (active-high sync reset)
  val coreDomain = ClockDomain(
    clock  = io.clk,
    reset  = io.rst,
    config = ClockDomainConfig(resetActiveLevel = HIGH, resetKind = SYNC)
  )

  val core = new ClockingArea(coreDomain) {
    // ---- tie-offs until the pipeline is ported (ROADMAP Phase 1+) ----
    io.bmem_addr  := 0
    io.bmem_read  := False
    io.bmem_write := False
    io.bmem_wdata := 0

    // TODO(ROADMAP): val frontend = Frontend(cfg) ; val backend = Backend(cfg) ;
    //                val lsu = Lsu(cfg) ; wire bmem arbiter + caches.
  }
}
