# Source-built qualification

Pins: [sources.json](sources.json), [requirements.txt](requirements.txt),
[tools.json](tools.json), [riscv-dv.patch](riscv-dv.patch).

The MCU ASIC profile enables C, A, Zicsr, MMIO, sleep and RVFI. Its Verilator
harness models SRAM and sparse RAM at `0xaaaaa000`–`0xaeaaa000`; external reads
return four 64-bit beats after eight cycles. MCU tests also use 24-cycle latency.
These simulations do not measure physical clock, area or power.

## Run

Linux x86_64 requires C/C++ build tools, make, curl, uv, Java/sbt, Verilator,
patch and RV32-capable RISC-V GCC. Setup installs pinned Python, Sail, Ruby/UDB,
ACT4, PyFlow dependencies and RV32 newlib, checking release hashes and signed
Debian packages. Benchmarks use GCC 14.2.0; ACT uses GCC 16.1.0 under `gcc15/`. Run from the repository root:

```sh
qual_work="$HOME/oooreo-qualification"
bash verification/setup.sh "$qual_work"
source "$qual_work/activate.sh"
python verification/run.py all --work "$qual_work"
```

`all` fetches pinned sources, builds the model and workloads, runs qualification and
exports `results.json`; `--help` lists individual stages. `benchmarks --only coremark`
selects both CoreMark modes; other names select Embench workloads. `random` also
runs local stress; `random-run` resumes `dv-current.json`. `--limit` sets the cycle
bound; failing suites return nonzero.

After RTL or driver edits, run `model` to verify inputs and reuse unchanged products.
Execution always runs; qualification rejects changed inputs, mixed RTL reports and
incomplete exports. Keep artifacts in the work directory: `reports/*.json` records
hashes, configuration, compiler, latency and logs; `logs/*.csv` records retirement
and memory fields in hexadecimal. Load-image hashes exclude temporary ELF symbols.

## Workloads and reporting

The suite runs configured ACT4 instruction tests, Embench-IoT workloads,
CoreMark performance/validation modes, RISCV-DV programs, local randomized stress
and directed MCU checks. Results are generated for the resolved configuration;
keep the exported report with its source and tool pins.

Sail comparisons check retired PC, instruction and destination-register writes
through HTIF completion. Faulting instructions do not retire; handler instructions
remain compared. Stores, next PC and CSR effects are not compared directly.

CoreMark uses a nominal 1 MHz simulation timer with automatic calibration;
report iterations/MHz with the configuration and iteration count. Embench uses
`WARMUP_HEAT=1 GLOBAL_SCALE_FACTOR=1` and reports raw cycles. Simulation results
do not establish a physical clock frequency or a certified benchmark score.

## Coverage limits

Directed fixtures cover legal `mip` writes, speculative illegal instructions,
traps, misaligned memory, MMIO byte writes, atomics/LR-SC, FENCE.I, interrupts and
WFI wake-up. Harness canaries check rejection of nonzero exits, timeouts and
corrupted traces; expected failures are recorded separately. The pinned RISCV-DV
patch fixes generator alignment, register exclusions and error propagation;
upstream ACT tests remain unchanged.

ACT selected I/M/Zca/Zaamo/Zalrsc/Zicsr/Zicntr/Zifencei/Zmmul; no standalone Sm
tests matched the machine-only configuration. Finite suites do not establish
coverage closure, a full-core proof, silicon validation or third-party certification.
