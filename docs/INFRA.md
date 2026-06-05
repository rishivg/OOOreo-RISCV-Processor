# OOOreo infrastructure

Five subsystems that defend the two things this project optimizes — measured IPC
and OoO correctness — and close the PD4 loop. All wired into CI
(`.github/workflows/ci.yml`).

## 1. Performance-regression gate
Every commit's IPC (and mispredict rates, RS-full cycles, …) is captured and
gated against a committed baseline.
- `bin/parse_perf.py` — `simulation.log` → `perf.json` (IPC from `monitor.sv`'s
  segment markers; counters from `perf_monitor.sv`).
- `bin/check_perf.py` — fail (exit 1) on IPC drop > tol (default 0.5%) or any RVFI error.
- `sim/perf_baseline.json` — committed baseline (coremark_im @ IPC 1.0776).
- `make -C sim perf PROG=... PERF_NAME=...` then `make -C sim perf-check`; re-baseline with `perf-update`.
- CI job **performance** runs coremark and gates.

## 2. Formal verification (`formal/`)
- **Tier 1 (works today):** `make -C formal fifo` proves `sync_fifo` (yosys reads
  its SVA natively). `free_list` target flattens via sv2v — but sv2v 0.0.13.1
  strips concurrent SVA (documented in `formal/Makefile`); needs SVA preservation.
- **Tier 2 (framework):** `formal/riscv-formal/` packs the core's `rob_i.rvfi_itf`
  retirement trace into riscv-formal's flat `rvfi_*` (NRET=2). Two prereqs to
  close, in `rvfi_wrapper.sv` (expose taps as ports; bring up checks shallow-first).
- CI job **formal** (nightly) runs tier-1 via oss-cad-suite.

## 3. Broader correctness corpus
- `sim/regress.py` — multi-program runner; PASS/FAIL/BUILD/TIMEOUT + IPC + first
  divergence, exit-coded. `make -C sim` / direct invocation.
- `bin/gen_fuzz.py` — random trap-free RV32IM programs (RVFI-checked every retire),
  linked at the reset PC `0xaaaaa000`, `-nostdlib` (no newlib needed).
- CI job **fuzz** (nightly, non-blocking) runs 16 seeds — a hang/RVFI-error is a finding.
- **Bug found + fixed:** fuzz seeds 2,3 hung; bisected to a mul-high op completing
  the same cycle a divide broadcasts on the shared CDB. The parallel multiplier's
  pipeline (`fu_mul.sv`) shifted unconditionally, so a div-backpressured (`nxt_ready=0`)
  completed result was dropped → ROB head hung forever. Fix: freeze the pipeline on
  output backpressure (`output_stall = nxt_valid && ~nxt_ready`). RVFI-clean,
  CoreMark IPC unchanged, 20/20 fuzz seeds pass. (CoreMark's 2 divides never hit
  this — the documented mul/div CDB latent-bug risk, caught day one.)

## 4. PPA → PD4 (`synth/opensource/pnr/`, `make -C synth ppa`)
sv2v → yosys (real fakeram macros) → OpenROAD floorplan/place/**repair_design**/STA.
The buffering is the point: the raw netlist's unbuffered control nets give garbage
STA (WNS −181,781 ns); after `repair_design` → **WNS −10.69 ns @2.78 ns (Fmax ≈74 MHz),
power 948 mW, area 1.25M µm²**. `bin/parse_ppa.py` + `bin/compute_pd4.py` →
**PD4 = 1.67e-10 W·s⁴** (coremark). CI job **ppa** (manual).

## 5. Pinned toolchain
- `tools/versions.lock` — single source of truth (verilator 5.032, yosys 0.52 lint
  / 0.64 synth-via-docker, sv2v 0.0.13.1, riscv-gcc 14.2, ORFS image **by digest**,
  oss-cad-suite, riscv-formal commit).
- `flake.nix` — reproducible `nix develop` shell. `.devcontainer/` — Codespaces.
- `scripts/install_toolchain.sh` sources the lock and pulls the pinned OpenROAD image.

> Note: the core's reset PC is hardwired to `0xaaaaa000` (`frontend_top.sv:48`);
> programs must link there. This is why `ooo_test.elf` (linked at 0x1eceb000)
> times out — a pre-existing corpus issue surfaced while building #3.
