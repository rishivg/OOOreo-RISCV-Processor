# Bilingual spike: N-wide Rename + ROB

Purpose: decide between **Chisel** and **SpinalHDL** for a future scalable,
customizable, high-performance OoO core by implementing the *single hardest piece
to parameterize* — the N-wide rename + ROB allocate/commit — in both, with an
identical spec, and comparing (a) ergonomics, (b) generated-Verilog cleanliness,
(c) area at width 2 vs 4.

This folder is fully self-contained and independent of the SystemVerilog core in
`../hdl`. Nothing here touches the existing design.

```
spike/
  chisel/   RenameRob in Chisel 6 (CIRCT/firtool -> SystemVerilog)
  spinal/   RenameRob in SpinalHDL 1.10 (-> Verilog)
  area/     Yosys + Nangate45 area check (same flow as the main PPA)
  gen/      generated Verilog (git-ignored)
```

## The module spec (identical in both)

`RenameRob(width W, nArch=32, nPhys=64, robDepth=32)` — one cycle of dispatch:

- **Inputs:** `W` dispatch slots `{valid, rd, rs1, rs2, rdWen}`, a `dispatchFire`
  pulse, and a `W`-wide `commitReady` mask (in-order prefix).
- **Rename:** look up `rs1/rs2/rd` in the RAT, **with intra-bundle forwarding** —
  slot *i* sees the renames of any earlier slot *j<i* that writes the same arch
  reg (youngest wins). Each `rdWen` slot pops a fresh physical reg from the free
  list; its `oldPdst` is the map *before* it writes.
- **canDispatch:** all-or-nothing — enough free regs for every writer AND ROB room
  for every valid slot.
- **ROB:** circular buffer; on dispatch push one entry/valid-slot `{rd, pdst,
  oldPdst, rdWen}`; commit the in-order `commitReady` prefix from the head,
  returning each committed writer's `oldPdst` to the free list.
- **Outputs:** `W` renamed slots `{prs1, prs2, pdst, oldPdst}`, `canDispatch`,
  and `W` committed slots `{valid, freed}`.

Why this module: it concentrates everything that makes N-wide painful in plain
SystemVerilog — the O(N^2) intra-bundle forwarding, N read/write ports on the
RAT / free list / ROB, prefix-popcount allocation indices, and circular-buffer
pointers that advance by 0..N. `width` is the non-power-of-2 scaling axis.

`nFree = nPhys-nArch = 32` and `robDepth = 32` are kept powers of two so the
free-list/ROB *depth* wrap is trivial — this isolates the comparison on the
`width` parameterization, which is the real question.

## Run it

Modules: `renamerob` and `issuequeue` (swap the package name below for either).

Chisel — generate SystemVerilog + sim:
```
cd chisel
sbt "runMain renamerob.Emit 2"  "runMain renamerob.Emit 4"   # ../gen/RenameRob_chisel_w{2,4}.sv
sbt "runMain issuequeue.Emit 2" "runMain issuequeue.Emit 4"  # ../gen/IssueQueue_chisel_w{2,4}.sv
sbt test                                                     # ChiselSim (Verilator), all specs
```

SpinalHDL — generate Verilog + sim:
```
cd spinal
sbt "runMain renamerob.Emit 2"  "runMain renamerob.Emit 4"   "runMain renamerob.Sim"
sbt "runMain issuequeue.Emit 2" "runMain issuequeue.Emit 4"  "runMain issuequeue.Sim"
```

Area (same Nangate45 flow as the main PPA, via the orfs docker):
```
cd area
./area_check.sh ../gen/RenameRob_chisel_w2.sv RenameRob
./area_check.sh ../gen/RenameRob_spinal_w2.v  RenameRob
# repeat for the w4 files; compare areas + read the generated Verilog by eye
```

## What to look for

1. **Ergonomics** — which source you'd rather write the rest of the core in
   (the intra-bundle forward + the multi-port circular buffers are the tell).
2. **Generated Verilog** — open the `gen/*.{sv,v}` files: readability matters for
   ASIC gate-level debug. SpinalHDL emits direct Verilog; Chisel emits via firtool.
3. **Area at W=2 vs W=4** — how each scales, and whether one synthesizes leaner
   for the same spec (ABC re-optimizes, so expect them close — but check).

## Measured results (Nangate45, this machine)

Two modules with *different* N-scaling shapes:
- **RenameRob** — prefix-sum allocation + O(N^2) intra-bundle forwarding.
- **IssueQueue** — wakeup CAM (entries x N ports) + N-way priority select.

| module / metric        | Chisel | SpinalHDL | winner |
|------------------------|--------|-----------|--------|
| RenameRob  area W=2    | 8056   | 9093      | Chisel -11% |
| RenameRob  area W=4    | 12990  | 14021     | Chisel -7%  |
| IssueQueue area W=2    | 4284   | 4129      | Spinal -4%  |
| IssueQueue area W=4    | 5989   | 5827      | Spinal -3%  |
| both sims              | PASS   | PASS      | tie     |

**The headline: area/QoR is a wash** -- the two tools land within ~3-13% and the
*direction flips by module* (ABC re-optimizes the combinational logic either way).
So pick on ergonomics + ecosystem, not area. Both scale sub-2x W=2->W=4 (shared
structures don't all double).

Ergonomic notes from writing all four:
- **Chisel** compiled both modules first try; cleaner default width semantics
  (`PopCount` is fixed-width). Needs one firtool lowering flag for a clean Yosys read.
- **SpinalHDL** is stricter: it *rejected* a variable-width `CountOne` comparison
  at elaboration (`OUT OF RANGE CONSTANT`) -- upfront friction, but it catches
  width sloppiness Chisel silently accepts. Plus the `in`/`out` keyword and
  `Seq`-vs-`Vec` papercuts. Emits plain Verilog directly (no firtool).

## Toolchain notes (gotchas hit while building this)

- **Chisel** needs a firtool lowering option to be Yosys-readable without sv2v:
  `-lowering-options=disallowLocalVariables,disallowPackedArrays` (else Yosys'
  Verilog-2005 frontend rejects `automatic` locals inside `always` blocks). The
  code itself compiled first try.
- **SpinalHDL**: (a) don't name an IO field `in`/`out` (direction keywords) —
  this twin uses `io.disp`; (b) masks fed to `CountOne`/`.take` must be Scala
  `Seq[Bool]`, not a SpinalHDL `Vec`; (c) `fork := true` is required in build.sbt
  for SpinalSim; (d) **SpinalHDL 1.12.0** is needed for Verilator 5.x (1.10.1
  segfaults in `sc_time_stamp()` against Verilator 5.032).
- Both emit plain Verilog that drops straight into the existing Yosys -> OpenROAD
  PPA flow, so the measurement loop ports over either way.
