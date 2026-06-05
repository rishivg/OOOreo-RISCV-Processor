# Formal Verification

Property-based and ISA-level formal verification with **SymbiYosys (sby)**.

## Why
OOOreo's hardest correctness risks live in rarely-reached interleavings that
benchmarks don't hit: speculative load issue + memory-ordering recovery, branch
checkpoint/GHR resync, free-list permutation, ROB pointer invariants. Formal
explores these exhaustively (up to a bound) instead of by luck.

## Tools (not vendored)
`sby` + `yosys` + an SMT solver (boolector/yices). Reproducible install:
the [YosysHQ oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases),
then `source <oss-cad-suite>/environment`.

## Layout
```
formal/
  Makefile              top driver (fifo | free_list | riscv-formal)
  sby/                  per-target sby configs
    sync_fifo.sby         self-contained module proof (works today)
    free_list.sby         interface module, proved after sv2v flatten
  fv/                   formal wrappers exposing interface modules to yosys
    free_list_fv.sv       free_list with plain ports + invariants
  riscv-formal/         ISA-level RVFI proofs (the headline for an OoO core)
    rvfi_wrapper.sv       packs rob_i.rvfi_itf -> flat rvfi_* (NRET=2)
    checks.cfg            check set + depths (insn/reg/pc/mem/liveness)
    fetch.sh              pinned riscv-formal checkout
    Makefile              genchecks + sby
```

## Two tiers

### 1. Module invariant proofs (tractable, run today)
Self-contained or sv2v-flattened modules with inline SVA. `free_list.sv` already
ships an inline `fl_no_overflow` assertion; `fv/free_list_fv.sv` adds environment
constraints + a range invariant and is flattened by sv2v (open yosys can't read
SV interfaces directly).
```
make fifo         # sync_fifo
make free_list    # free_list (sv2v flatten -> sby)
```
Grow this tier by adding inline `assert property` to ROB / store_queue /
load_queue (the spec-load invariant) and an `fv/` wrapper per interface module.
These assertions ALSO fire in Verilator simulation, so every CI sim run exercises
them for free.

### 2. riscv-formal (ISA-level, framework)
Proves every *retired* instruction is ISA-legal and memory ordering holds, using
the core's existing `rob_i.rvfi_itf` retirement trace. Status: **scaffolding** —
two prerequisites to close (documented in `rvfi_wrapper.sv`):
  1. expose the `rvfi_itf` taps as flat `cpu_rvfi` ports (mirrors the sim-only
     `hvl/common/rvfi_reference.svh`) so they survive sv2v flattening;
  2. the cache-backed OoO state is deep — bring up `insn`/`reg`/`pc` checks first
     (cheap, per-instruction), then `mem`/`liveness` with care.
```
cd riscv-formal && ./fetch.sh && make
```

## CI
`.github/workflows/ci.yml` runs tier-1 proofs nightly via oss-cad-suite.
riscv-formal (tier-2) is opt-in (`workflow_dispatch`) until the taps land.
