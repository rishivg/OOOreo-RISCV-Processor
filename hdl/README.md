# RTL configuration

The core lives in `src/main/scala/ooo/`; module tests live in `src/test/scala/ooo/`.
`CpuConfig` defines resources and widths; `CpuImplementation` selects target
bindings. Reservation payloads live in `execute/ExecutionPayloads.scala` and
`RsEntryLayout.scala`; `RsEntry.scala` controls slots and `RsUtil.scala` shares
priority and bypass helpers.

```sh
(cd hdl && sbt -batch test)
CPU_PROFILE=mcu-efficient CPU_TARGET=fpga \
  python3 bin/generate_rtl.py /tmp/ooo-rtl
```

Run from the repository root. The helper writes `cpu.v` and `configuration.json`
with [content-checked reuse](../docs/verification.md#build-reuse); `--force`
regenerates. Direct `sbt -batch 'runMain ooo.Generate'` from `hdl/` always emits
to `RTL_OUT` (default `gen/`).

| Setting | Choices or examples |
| --- | --- |
| `CPU_PROFILE` | `benchmark`, `mcu`, `mcu-efficient` |
| `CPU_TARGET` | `asic`, `fpga` |
| ISA and interfaces | `C_EXT`, `A_EXT`, `ZICSR`, `LOW_POWER`, `MMIO`, `RVFI` |
| Resource sizes | `ROB_DEPTH`, `PRF_DEPTH`, `IQ_DEPTH`, station/queue depths |
| Divider latency | `DIV_CYCLES=3..33`; the external implementation must match |
| Operand sharing | `FPGA_SHARED_SHIFT`, `PRF_READ_SHARING` (memory/intm/branch bits) |
| Multiplier reduction | `MUL_DADDA_REDUCTION` preserves carry prefixes; `MUL_COMPACT_SIGNS` requires it |
| Multiplier carry | See [multiplier options](#multiplier-options) below |
| Shared branch row decode | `BR_PRF_SHARED_PREDECODE` requires branch sharing and decoded flop-array reads |
| Predictor counters | `TAGE_COUNTER_BITS=1..8` (default 3), `TAGE_ALT_COUNTER_BITS=1..8` (default 4) |

Profiles resolve first, target defaults next, then explicit environment overrides.
The exact option names, dependencies and supported sizes are in
[`CpuConfig.fromEnvironment`](src/main/scala/ooo/Config.scala). Resolved settings
and the generated RTL hash are recorded in `configuration.json`.

Validation requires two-wide dispatch/retirement/integer issue, four CDB lanes,
five PRF read ports and two fast-bypass lanes. Queue, predictor and cache sizes
must satisfy their implementation constraints.

MCU profiles share the ALU shifter and branch/multiply operand reads. Set
`FPGA_SHARED_SHIFT=0 PRF_READ_SHARING=0` for separate datapaths. The legacy
shifter option applies to both targets; FPGA defaults share all operand groups.

For ASIC source experiments, `PRF_READ_SHARING=4 BR_PRF_SHARED_PREDECODE=1`
shares branch operand reads and compares registered tags before the late grant.
It requires `PRF_LUTRAM=0 PRF_BINARY_READ=0`. Predictor counter widths retain their
original defaults; changing them changes prediction behavior and IPC.

Implementation options are checked before elaboration. Their effect on timing
must be measured for the chosen target. The [physical result](../synth/implementation/README.md)
and [FPGA flow](../fpga/README.md) document their respective constraints.

## Multiplier options

With the Booth multiplier, `MUL_DADDA_REDUCTION=1 MUL_COMPACT_SIGNS=1` enables
the Dadda tree and compact signs. Both default off and preserve two pipeline
stages and stalls.

| Setting | Default | Effect |
| --- | --- | --- |
| `MUL_CARRY_TOPOLOGY` | `auto` | `auto`, `kogge-stone`, `sklansky`, `brent-kung`, `han-carlson`; Dadda's `auto` selects Brent–Kung |
| `MUL_KEEP_PROPAGATE` | `0` | Preserve propagate nodes as well as generate nodes |
| `MUL_OR_CARRY` | `0` | Inclusive OR carry propagation; sum propagation remains XOR |

Other reduction modes and `FastAdd` callers retain their existing carry defaults.
See [Brent and Kung's topology](https://maths-people.anu.edu.au/~brent/pub/pub060.html)
and the optional [Nangate45 full-adder mapping](../synth/README.md#full-adder-mapping).

## Writing and reviewing RTL

The project pins SpinalHDL 1.12.0. Scala `if` and loops construct hardware during
elaboration; `when` and `Mux` describe runtime logic. Calling a hardware-producing
function twice can build two circuits: bind shared results to a `val`.

- Preserve assignment priority: the last active assignment wins. Register
  declarations determine state; an unassigned register holds its value.
- Keep widths explicit at interfaces. `.resized` may truncate as well as extend;
  use it only when the discarded bits are intentional.
- `Bundle.asBits` and `Cat(Iterable)` put the first field at the LSB.
  `Cat(a, b)` and `a ## b` put `a` at the MSB. Reservation payloads use
  `RsEntryLayout` for both packing and field access, independently of Bundle order.
- `OhSel` returns zero for no selections and ORs multiple selections.
  `PrioSelect` chooses the lowest index; its data is ignored when no request wins.
  Spinal's default `MuxOH` has different assumptions and is not a drop-in replacement.
- Reset validity/control state; reset payloads only when their contents must be
  defined before validity. Keep memory read enables and collision policies explicit.
- Check generated RTL and matched synthesis after a structural change. Shorter
  Scala code does not establish lower area, power, or delay.

References: [semantics](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Semantic/rules.html),
[assignments and widths](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Semantic/assignments.html),
[Bundle packing](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Data%20types/bundle.html),
[selection utilities in 1.12.0](https://github.com/SpinalHDL/SpinalHDL/blob/v1.12.0/lib/src/main/scala/spinal/lib/Utils.scala).
