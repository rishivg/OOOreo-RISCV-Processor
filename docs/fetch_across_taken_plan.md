# Fetch-across-taken-branch plan

Goal: recover the ~5.6 % IQ-starve (front-end supply limiter) by delivering
instructions from a taken branch's TARGET in the same fetch, instead of wasting
the post-branch slots and eating a redirect.

## Why this is the right lever (and the loop buffer was not)
The IQ-starve is genuine fetch **bandwidth**, not redirect **bubbles**:
- `inst_queue` DEPTH 8→32 gave +0.15 % (memory) — buffering doesn't help.
- A **loop buffer (FIFO replay)** was implemented (Codex, 2026-06-17) and
  **REGRESSED IPC**: naive −12 % (1.50→1.32), conservative −5 % (1.50→1.42),
  RVFI-clean, reverted. Replaying buffered packets adds **no new bandwidth** — it
  re-serves what was already fetched, plus wrap/stall overhead.

Therefore the fix must **add** instructions per cycle on a taken branch. The
constraint: the I$ SRAM is **single-port** — no two non-contiguous block reads
per cycle.

## Key enabler: the line is already 32 B, we only use 16 B
The icache **data array is 256 b = 32 B per line**; if1/fetch_align consume only
`IF_BLK_SIZE = 16 B` (IF_WIDTH=4 words) via a barrel-shift on `pc`. **The other
16 B of the read line is already out of the SRAM, just discarded.** That is free
bandwidth for any taken branch whose target lands in the SAME 32 B line — and
tight CoreMark loops + short forward branches overwhelmingly do.

## B1 — Intra-line fetch-across-taken   [primary, tractable, single SRAM read]
When the predicted-taken branch's target is within the **same 32 B line** already
read, deliver `{slots 0..i (up to the taken branch)} ++ {target slots}` from that
one line read — no 2nd SRAM access, no coherence problem.

Implementation:
1. **Widen the icache→if1 datapath to the full 32 B line** (icache `ufp_rdata`
   256 b; move the 16 B barrel-shift selection into fetch_align). `Icache.scala`,
   `If1Stage.scala`, `FrontendTop.scala` parcel window.
2. **fetch_align two-run extraction** (`FetchAlign.scala`): currently it walks one
   contiguous parcel run from `pc`. Add: if a predicted-taken branch is found at
   extracted slot `i` and its target offset is within the 32 B window, restart the
   parcel walk at the target offset and continue filling up to IF_WIDTH. Emit the
   per-slot `inst_pc` accordingly (discontiguous PCs across the taken branch).
3. **pc_next** = target + (#target slots consumed) when the across-taken fill
   happened; predictors already produce per-slot `inst_pc`, so TAGE/uBTB/RAS need
   the discontiguous PCs (they already take per-slot `inst_pc[]`).
4. Cross-line target (target NOT in the window): fall back to today's behaviour
   (truncate + redirect). B1 only fires for same-line targets.

- **Est. IPC:** +2–4 % (captures tight-loop back-edges + short forward branches —
  the bulk of CoreMark's taken branches). RVFI-safe (same-line bytes, predictions
  unchanged in meaning).
- **Risk:** medium-high. It's **on the critical fetch loop** (icache→fetch_align→
  pc_next→SRAM, the measured Fmax wall) — the 2-run extraction lengthens
  fetch_align, so **watch Fmax**. CoreMark/MHz (= IPC) still wins even if Fmax dips
  slightly, but measure both. The C-ext parcel/halfword alignment across the
  taken branch is the fiddly part (mirror the existing span/carry logic).

## B2 — Cross-line target tracelet (BTIC)   [secondary, after measuring B1 residual]
For targets in a different line (far loops, most calls), store the first 1–2
target instructions in the uBTB entry, captured the first time the target is
fetched; merge them post-branch like B1.
- Needs **coherence**: invalidate a tracelet when its I$ line is refilled/evicted
  (CoreMark has no self-modifying code, but correctness demands it).
- **Est. IPC:** +1–2 % on top of B1. **Risk:** high (coherence + critical path).
- Only pursue if B1 leaves significant IQ-starve.

## B3 — Banked I$ (two non-contiguous reads/cycle)   [not recommended]
Splitting the I$ into banks to read sequential + target lines same-cycle: large
area/complexity, and single-port-per-bank can't guarantee different banks. Skip
for OOOreo unless a large-footprint workload demands it.

## Order
1. **B1 intra-line** — implement, validate RVFI-clean + IPC ≥ baseline, measure
   Fmax via PPA. This is the real bandwidth add.
2. Re-profile IQ-starve. If meaningful cross-line residual remains → B2.
3. Skip B3.

## Note on stacking with the area plan
B1 widens the fetch datapath (more parcels through fetch_align/predictors), which
slightly grows front-end area — opposite of the area plan. Sequence so the area
wins (A1 TAGE shrink, A2 set-assoc uBTB) are measured independently of B1.
