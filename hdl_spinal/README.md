# hdl_spinal — the OOOreo OOO core (SpinalHDL)

The OOOreo RV32IMC out-of-order core, written in SpinalHDL, with issue/fetch
width and all resource sizes as **generator parameters** (`CpuConfig`). This is
the core — the original SystemVerilog implementation has been retired; SpinalHDL
emits the Verilog (`gen/cpu.v`) that drives the whole flow: Verilator + RVFI +
CoreMark, and the Yosys→OpenROAD PPA/PD4 synthesis.

The only external modules are vendor/IP, instantiated as blackboxes: the SRAM
macros (`../sram/output`) and the `DW_div_seq` sequential divider
(`../hvl/common/dw_mock.sv`).

## Status

Complete and RVFI-clean. The full core (`cpu`) simulates against the riscv-formal
monitor + CoreMark at the reference IPC: **coremark_im 1.426545 / coremark_imc
1.381854**. It was brought up module-by-module against the (now-removed) SV core
as an executable oracle — every leaf, subsystem, and cluster was validated
bit-for-bit before the SV core was deleted.

## Layout

```
hdl_spinal/
  build.sbt, project/             SpinalHDL 1.12 sbt project
  src/main/scala/ooo/
    Config.scala                  CpuConfig generator params (widths, depths, ...)
    Cpu.scala                     top -- emits module `cpu` (bmem boundary + rvfi_flat)
    Generate.scala                emit gen/cpu.v (default config)
    GenerateCpuBig.scala          emit gen/cpu.v from a larger config (param demo)
    common/                       skid_buffer, cache_adapter, bmem_arbiter
    frontend/                     if1_stage, icache, fetch_align, decompressor,
      bpred/                      inst_queue, frontend_top; tage/ubtb/ras
    backend/                      id_stage, ds_stage, rat/free_list/rob/rrf,
      decode/ rename/ execute/    int_rs/intm_rs/branch_top, FUs, prf, backend_top
    memory/                       LSU (lsu_top, ldq/stq/stb, dcache), cache arrays
  src/test/scala/ooo/             SpinalSim unit tests (decoder/decompressor/agu)
  gen/                            generated Verilog (git-ignored)
```

## Build & validate

```
sbt "runMain ooo.Generate"        # -> gen/cpu.v (default config)
sbt test                          # SpinalSim unit tests
../sim/build_spinal.sh            # generate + Verilator + RVFI monitor + CoreMark
CPU_GEN=ooo.GenerateCpuBig ../sim/build_spinal.sh   # validate a different config
make -C ../synth synth            # Yosys area synthesis of gen/cpu.v
```

## Configurability

`CpuConfig` drives the whole core. Resource capacities (reservation stations, LSU
queues, control buffer, branch predictors) vary freely and stay RVFI-clean —
`GenerateCpuBig` is a validated example at a different IPC. Issue/fetch width
(`idWidth`/`ifWidth`) is parameterised throughout; widening past the original
2-wide issue additionally needs the 2-way-specific dispatch logic (id_stage
filter, the CDB lane map) generalised.
