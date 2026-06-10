# Roadmap — SpinalHDL OOO core

Goal: a functioning, RVFI-clean, IPC-parity RV32IM(C) out-of-order core in
SpinalHDL, with issue/fetch width as a **generator parameter** — the foundation
for the scalable/customizable/efficient core that motivated the rewrite.

## Guiding principles

1. **The SV core in `../hdl` is the oracle.** Same RVFI monitor, same spike
   co-sim, same CoreMark IPC numbers (im 1.4265 / imc 1.3819). Bring-up = "match
   the oracle," never "redesign."
2. **Translate, don't reinvent** — port the proven microarchitecture first; defer
   new ideas (N-wide, MSHR, 3-wide) to *after* parity, when they're cheap.
3. **Validate incrementally via module-swap** (see below) — avoid a big-bang
   integration. Every merged step is RVFI-clean on coremark_im.
4. **Reuse the whole measurement loop** — Verilator/RVFI/CoreMark harness, the
   Yosys→OpenROAD PPA/PD4 flow, the SRAM blackboxes, `DW_div_seq`. SpinalHDL emits
   Verilog, so none of it is rebuilt.

## The key technique: module-swap co-validation

Because both cores emit Verilog with the same module boundaries, we replace **one
SV module at a time** with its SpinalHDL-generated twin inside the *existing* SV
core, and run the full RVFI + CoreMark harness. Each port = one RVFI-clean swap.
When every module is swapped, the core is 100% SpinalHDL — with no big-bang.

Requirements per swappable module:
- Its SpinalHDL Verilog ports match the SV module's (post-sv2v) ports. Leaf
  modules (decoder, ALU, AGU, mul, predictors, cache ctrl) have clean port lists
  and swap directly. Interface-heavy SV modules (which sv2v inlines into `cpu`)
  are swapped as a *subsystem* once their internal Bundles are defined.
- A sim build variant that substitutes the generated `.v` for the SV `.sv` of
  that module (a `make` knob, Phase 0).

## Phases

### Phase 0 — Toolchain spine  *(mostly done)*
- [x] sbt project, `CpuConfig` (ported params), `Cpu` stub emitting `module cpu`.
- [x] **clk/rst naming**: explicit clk/rst IO + a `ClockingArea` (active-high sync
  reset) -> `gen/cpu.v` ports are exactly `clk, rst, bmem_*` (verified).
- [x] **sim integration**: `sim/build_spinal.sh` generates `gen/cpu.v` and
  Verilator-builds it against the real memory model + SRAM blackboxes + HVL
  harness, using the minimal `hvl/verilator_spinal/top_tb_spinal.sv` (drops the
  SV-hierarchy-coupled `perf_monitor` + rvfi `monitor` taps). GATE MET: builds,
  links, and simulates (stub -> expected TIMEOUT, no crash). `DW_div_seq` is the
  local `hvl/common/dw_mock.sv`, no external IP.
- [ ] **module-swap knob**: extend the script to substitute selected generated
  `.v` for their SV `.sv` (do when the first leaf module lands, Phase 2).
- [ ] **golden-vector capture**: dump per-module I/O traces from the SV core for
  the pure modules (do alongside the first leaf-module port, Phase 2).
- [ ] **rvfi/perf rebinding**: regenerate the rvfi tap file against the SpinalHDL
  ROB hierarchy (name-preserved) + rewrite perf_monitor taps (Phase 3, needs ROB).

### Phase 1 — Foundations: types + interfaces
- [ ] Port `pkg/types.sv` structs to SpinalHDL `Bundle`s: `uop`, `fetch_packet`,
  `decode_packet`, `rob_entry`, `rvfi_dbg`, RS-entry types, cache-line types.
- [ ] Port `hdl/common/interfaces/*` to Bundles + `IMasterSlave` (cacheline,
  frontend_fifo, fifo_backend, cb_bp, execute, lsu, commit, rename).
- [ ] Common utils: `ClockGate`, `OneHotMux`, `SkidBuffer`, `bmem`/`dmem`
  arbiters, `cache_adapter`, lru/plru/valid arrays.
- Gate: compiles; Bundles round-trip through generation cleanly.

### Phase 2 — Pure / leaf modules (swap-validated, lowest risk)
Port + SpinalSim unit-test (vs golden vectors) + module-swap into the SV core,
each RVFI-clean on coremark_im:
- [ ] `Decoder`, `Decompressor` (RV32C — 18-vector test from the SV bring-up).
- [ ] `FuAlu`, `FuAgu`, `FuMul` (MUL_LATENCY=2); `FuDiv` wraps `DW_div_seq`.
- [ ] Branch predictors: `Ubtb`, `Ras`, `Tage` — pure predictors, RVFI-safe, so
  swap-in can only change IPC, never correctness. Confirm IPC matches.
- [ ] `Icache` + `IcacheCtrl` and `Dcache` + `DcacheCtrl` (arrays = SV SRAM
  blackboxes via `BlackBox`).
- Gate: each swap RVFI-clean; predictor/cache swaps hold IPC within noise.

### Phase 3 — Structural subsystems
Port as whole subsystems (their internal interfaces are SpinalHDL Bundles now):
- [ ] **Rename**: `Rat` + `FreeList` + `Rob` + `Rrf`. Seeded by the validated
  `../spike/.../RenameRob`. Swap the rename subsystem; RVFI-clean.
- [ ] **Execute**: `Prf`, `IntRs` (+ `IssueArbiter`, fast-bypass), `IntmRs`.
  Seeded by the `../spike/.../IssueQueue` wakeup-CAM+select proto.
- [ ] **Branch**: `BrRs` + `FuBr` + `ControlBuffer` (predictor training path).
- [ ] **Memory/LSU**: `MemRs` + `FuAgu`, `LoadQueue` (spec-load + AGU bypass +
  violation), `StoreQueue` (forwarding), `StoreBuf`, `LsuAdapter`.
- [ ] **Frontend**: `If1Stage`, `FetchAlign`, `InstQueue` (the IF_WIDTH=4
  compacting queue — reuse the SV advance logic), `FrontendTop`.
- Gate: after each subsystem swap, full RVFI-clean + IPC parity on coremark_im.

### Phase 4 — Full integration  *(the milestone)*
- [ ] All modules swapped → retire the SV `cpu`; the SpinalHDL `Cpu` is the DUT.
- [ ] RVFI-clean to `$finish` on coremark_im. **"Functioning OOO processor."**

### Phase 5 — Parity
- [ ] Match IPC: coremark_im 1.4265, then C-ext → coremark_imc 1.3819
  (decompressor + fetch_align + per-instr predictor PCs + carry/span).
- [ ] Pass the perf-regression gate (`sim/perf_baseline.json`) and re-run the
  PPA/PD4 flow on `gen/cpu.v`. Gate: IPC within 0.5%, PPA in the same ballpark.

### Phase 6 — The payoff: parameterize
- [ ] `idWidth` / issue width as a real generator parameter (the thing SV
  couldn't do cleanly). Sweep width 2→3→4, measure IPC + PPA.
- [ ] Add the 3rd ALU + non-pow2 handling that SV made painful — now a config.

### Phase 7+ — Deferred levers (now cheap, configurable)
3-wide issue, MSHR/non-blocking D-cache, privileged/CSR/trap (deployability),
A-extension. Each becomes a generator option rather than a rewrite.

## Risk register
- **Interface→Bundle fidelity**: SV modports vs SpinalHDL `IMasterSlave` — get the
  master/slave directions right or swaps mis-wire. Mitigate: golden-vector tests.
- **RVFI debug ports**: the monitor reads `rvfi_*`; keep them as `Cpu` outputs
  (Phase 1 bundle) so the harness binds unchanged. (Most are already pruned in
  synth — see memory; functional `pc_rdata` stays.)
- **Module-swap port matching**: requires the generated `.v` port names/widths to
  match the post-sv2v SV ports. Script the comparison; sv2v the SV side for the
  reference port list.
- **Sim version**: SpinalSim needs Verilator 5-compatible SpinalHDL (1.12+) and
  `fork := true` (locked in build.sbt).
- **Big interface-heavy modules** can't be leaf-swapped (sv2v inlines them into
  `cpu`) — swap them at subsystem granularity (Phase 3), not individually.

## Definition of done
A single `CpuConfig` knob spins a width-N OOO core that is RVFI-clean, hits the SV
core's CoreMark IPC at width 2, and runs through the existing PPA/PD4 flow — at
which point width 3/4 and the deployability features are configuration, not
rewrites.
