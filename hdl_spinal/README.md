# hdl_spinal — the SpinalHDL OOO core

A from-scratch SpinalHDL re-implementation of the OOOreo RV32IM(C) out-of-order
core, with **issue/fetch width as a generator parameter**. The existing SV core
in `../hdl` is the *executable reference spec* — same RVFI monitor, same spike
co-sim, same CoreMark IPC targets.

Why: SpinalHDL makes the core scalable + customizable without the SV
non-power-of-2 / whole-pipeline-widen pain (see `../spike` for the head-to-head
that drove this decision). The generated Verilog reuses the **entire** existing
measurement loop: Verilator + RVFI + CoreMark, the Yosys→OpenROAD PPA/PD4 flow,
the SRAM blackboxes, and the `DW_div_seq` IP.

## Layout (mirrors `../hdl`)

```
hdl_spinal/
  build.sbt, project/             SpinalHDL 1.12 sbt project
  src/main/scala/ooo/
    Config.scala                  <- pkg/types.sv  (CpuConfig generator params)
    Cpu.scala                     <- hdl/cpu.sv    (top, emits module `cpu`)
    Generate.scala                emit gen/cpu.v
    common/                       <- hdl/common/   (interfaces, caches-utils, gates)
    frontend/                     <- hdl/frontend/
      bpred/  icache/
    backend/                      <- hdl/backend/
      decode/  rename/  execute/  branch/
    memory/                       <- hdl/memory/   (LSU, dcache)
  gen/                            generated Verilog (git-ignored)
```

Each `package.scala` documents the SV→Scala module mapping for that folder.

## Build

```
sbt "runMain ooo.Generate"        # -> gen/cpu.v
sbt test                          # SpinalSim unit tests (as modules land)
```

## Status

Skeleton only: `Cpu` is a stub with the `bmem` boundary tied off. Real porting
proceeds per **ROADMAP.md**, validated module-by-module against the SV oracle.

See `../spike` for the validated `RenameRob` and `IssueQueue` prototypes that
seed the `rename` and `execute` packages.
