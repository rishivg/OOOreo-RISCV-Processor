# ASIC screening

```sh
make -C synth synth        # generic Yosys synthesis
make -C synth ppa-remap    # Nangate45 / OpenROAD screening via Docker
```

`synth/opensource/pnr/ppa.sh` supports named runs, clock sweeps and environment
overrides; `--list` displays saved runs. Install the container pinned in
`tools/versions.lock` with `NO_DOCKER=0 scripts/install_toolchain.sh`.
RTL generation reuses verified outputs; synthesis and physical analysis execute
when requested.

SRAM/divider models and Liberty/LEF geometries are placeholders, not characterized
silicon. Width variants come from [gen_width_scaled.py](opensource/pnr/fakeram/gen_width_scaled.py);
[gen_1r1w.py](opensource/pnr/fakeram/gen_1r1w.py) derives predictor port variants.
Keep their single-port parents for regeneration. `macro_wrappers.v` and
`run_pnr.tcl` choose the active geometries. Physical qualification requires a
real PDK, characterized macros and matched constraints.

Report tables retain missing power as unknown. `setup_MHz` is a setup-only
estimate; `compute_pd4.py` requires positive cycles/frequency and nonnegative
power, all finite.

The [physical implementation package](implementation/README.md) contains the
layout, models and checks for the published result. Source synthesis is a
separate flow and does not reproduce that layout.

## Full-adder mapping

The optional Nangate45 script extracts complete two-output full adders before ABC:

```sh
MUL_DADDA_REDUCTION=1 MUL_COMPACT_SIGNS=1 \
PNR_MAP_YS=synth/opensource/pnr/map_pnr_fa.ys \
synth/opensource/pnr/ppa.sh --remap --name dadda-fa
```

The mapping instantiates `FA_X1`; generated RTL remains portable. The pattern
stays in a separate in-memory Yosys design, following the multiple-output mapping
discussion in [Tempia Calvino's thesis, §4.4](https://si2.epfl.ch/demichel/graduates/theses/alessandro.pdf).
Both outputs and non-overlapping cuts must match; mapped configurations still
need whole-chip physical qualification.
