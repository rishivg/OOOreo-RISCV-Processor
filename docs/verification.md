# Verification

Run from the repository root after installing the tools listed in the [README](../README.md):

```sh
python3 -m unittest discover -s tests          # Python tools
(cd hdl && sbt -batch test)                    # RTL modules
make -C lint lint                             # Verilog frontends
(cd hdl && sbt -batch 'testOnly ooo.FastAddSim') # focused module suite
python3 sim/regress.py testcode/coremark_*.elf  # benchmark corpus
```

## FPGA bindings

```sh
python3 fpga/tests/check_memories.py
python3 fpga/tests/check_divider.py
```

These compare six memory configurations and eleven divider configurations with
their behavioral references. Each case retains its testbench, `compile.log` and
`run.log` under `fpga/build/{memory,divider}-checks/`. A positional directory
overrides the destination; simulation times out after 90 seconds.

## Build reuse

Caches verify input/configuration hashes, tool identities, flags and generated
bytes. Failed builds are not reusable; shared output directories are locked.
Tests and program execution always run. Module-test RTL omits the commit banner;
product RTL retains it and regenerates when the repository revision changes.

| Setting | Purpose |
| --- | --- |
| `SPINALSIM_WORKSPACE` | Module simulator workspace |
| `TEST_SIM_CACHE_ENTRIES` | Linked-model cache limit; default 256 |
| `TEST_KEEP_BUILD=1` | Retain compiler-only headers |
| `make -C sim build FORCE_BUILD=1 JOBS=2` | Force a simulator rebuild |
| `python3 bin/generate_rtl.py /tmp/ooo-rtl --force` | Force RTL generation |

`sim/regress.py` accepts `--build-dir`, `--timeout` and `--force-build` from any
working directory. It deduplicates paths and runs programs serially. Logs are in
`BUILD_DIR/run/logs/`; `run/simulation.log` holds the last run. Use a separate
build directory for each configuration.

## Coverage and measurements

Module tests cover execution, queues, caches, predictors, CSR/MMIO and sleep.
`SpinalHelperSpec` proves payload layouts, load formatting, priority masks,
exclusive prefixes and masked selection using unrestricted Yosys SAT inputs,
including zero/multiple requests and odd-sized arrays. Proof logs live in
`hdl/target/helper-checks/`.
Component proofs do not establish full-chip equivalence or timing.

The RVFI harness uses `hvl/common/rvfimon.v`. `bin/gen_fuzz.py` generates ALU/M/D
programs; `bin/gen_memory_fuzz.py` adds memory traffic, branches, bounded loops,
optional atomics and compression. `testcode/build_bare.sh testcode/csr_test.s`
builds a fixture at reset PC `0xaaaaa000`; benchmark ELFs are test fixtures.

`options.json` sets the simulator clock, memory initialization and fixture compiler
ISA. The RTL configuration is selected separately through `CpuConfig`.
Standalone assembly links without a C runtime at the default reset PC. Compiling
C sources also requires RV32 newlib and libm; the host installer supplies GCC only.

`sim/regress.py` displays total IPC. `make -C sim perf PROG=...` records segment
IPC/time when available, otherwise total IPC/time. `perf-update` records a reference
for the chosen configuration; `perf-check` compares against it. `PERF_REFERENCE`
overrides the default `sim/perf-reference.json`. RVFI errors fail for new programs
too, and `perf-update` rejects failing records. Compare matching programs,
configurations and memory clocks.

[Source-built qualification](../verification/README.md) covers ACT4, Embench,
CoreMark, Sail comparisons and MCU checks. Its generated reports identify
sources and coverage limits; changed inputs invalidate a qualification run.
