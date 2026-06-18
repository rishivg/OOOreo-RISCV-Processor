# Area-reduction plan — get the branch predictors out of flops

Goal: cut OOOreo's cell area / flop count toward NaxRiscv's efficiency (NaxRiscv
~10.3 KFF vs OOOreo ~41 K flops) **while keeping TAGE's IPC edge**. Measured on
the first real SpinalHDL PPA (Nangate45, rvfi-pruned, all-opts: 904,615 µm²).

## Root cause (from the per-module area report, final all-opts PPA)

| Module | Cell area | % of core | Why it's big |
|--------|-----------|-----------|--------------|
| `tage_spinal` | 207,256 µm² | **22.9 %** | 4 tables × 256 × 14 b in **flops** + a 16-port read-mux fabric (4 fetch slots × 4 tables, each a 256:1 / 14-bit mux) |
| `ubtb_spinal` | 113,474 µm² | **12.5 %** | 2 banks × 64 entries **fully-associative CAM** = 4 slots × 2 banks × 64 = **512 20-bit comparators** + priority/target muxes, all flops |
| **TAGE + uBTB** | **320,730 µm²** | **35.5 %** | |

The predictors are **35 % of the core**, all flip-flops, because the ASIC SRAM
library is single-port-only and these structures are heavily multi-ported
(TAGE: 16 predict reads + 1 commit read + 1 write per cycle; uBTB: 512-way CAM).
NaxRiscv sidesteps this on FPGA by putting its (smaller BTB+GShare) in BRAM.

## Levers, ordered by effort / risk

### A1 — TAGE table-depth 256 → 128 (or 64)   [trivial, do first]
- `Config.scala:48 tageDepth = 128` (tageIdx auto-derives via log2Up). One line.
- Halves storage (14,336 → 7,168 flops) **and** the read-mux depth (256:1 → 128:1).
- Precedent: 1024 → 256 already held IPC-parity (memory). CoreMark's branch
  footprint is small, so 128 likely holds; test 64 too.
- **Est. area:** TAGE 207 K → ~110–130 K  (≈ **-80 K µm², -9 % of core**).
- **Risk:** low. RVFI-safe (pure predictor). Gate on IPC-parity vs 1.4995/1.4498.
- **Validate:** `build_spinal.sh` — must stay ≥ baseline IPC.

### A2 — uBTB fully-associative → set-associative   [medium, big win]
- Rewrite `Ubtb.scala`: index PC bits into a set, compare only that set's ways
  (e.g. 4-way × 16-set = 64 entries, same capacity). Comparators drop
  **512 → 32** (4 slots × 2 banks × 4 ways); target/tag arrays shrink to a small
  per-set mux.
- Even kept in flops this is a huge cut; if the per-set arrays are made
  single-read (bank by slot-PC so the 4 sequential slots hit different banks) they
  can become SRAM.
- **Est. area:** uBTB 113 K → ~35–55 K  (≈ **-60 K µm², -7 % of core**).
- **Risk:** medium — set-assoc adds conflict misses. Memory says uBTB is at the
  capacity knee at 64 fully-assoc, so pick ways/sets to keep the working set
  resident; **validate IPC** (this is the one that could cost IPC).
- RVFI-safe (pure predictor).

### A3 — TAGE → banked single-port SRAM   [structural prize, multi-session]
- The 16 predict-reads/cycle (4 slots × 4 tables) are the multi-port blocker.
- Path: a **block-level** predictor reads each table **once** per fetch
  (block-PC indexed → 4 reads, one per table) → 4 single-port SRAMs.
- BUT memory found a block-granular FTB predictor was −37 % IPC (loses per-slot
  accuracy). So a naive block-TAGE is risky. A hybrid (block-indexed SRAM tables
  + a small per-slot flop "way" correction) may keep accuracy — research-grade.
- **Est. area:** the prize (~150 K off) but high effort + IPC risk. Defer until
  after A1/A2 measure.

### A4 — PHT/bimodal shrink   [minor]
- `phtDepth 1024 → 512`. ~1 K flops. Memory already did 4096 → 1024. Minor.

## Combined expectation
A1 + A2 (both cheap-ish, RVFI-safe, IPC-gated): **~-140 K µm² (≈ -15 % of core)**,
flop count ~41 K → ~30–33 K — **NaxRiscv-competitive on flops while keeping TAGE's
IPC**. A3 is the long-term path to full SRAM-backed predictors.

## Order
1. A1 (one line, validate IPC) — immediate.
2. A2 (set-assoc uBTB, validate IPC) — the bigger structural cut.
3. Re-run PPA, compare area/flops.
4. A3 (banked-SRAM TAGE) — later, research-grade.
