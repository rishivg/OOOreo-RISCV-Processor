# Roadmap — SpinalHDL OOO core

## Status: DONE (Phases 0–4 complete; standalone, RVFI-clean)

The whole core is SpinalHDL and the SystemVerilog core has been removed. The
generated `cpu` is RVFI-clean on CoreMark at the reference IPC (im 1.426545 /
imc 1.381854) via `../sim/build_spinal.sh`.

### How it was built (the recipe)

While the SV core still existed it was the **executable oracle**: every SpinalHDL
module was dropped into the otherwise-SV core (a generated-Verilog twin + a thin
SV shim) and run through the full RVFI + CoreMark harness — each port a
bit-for-bit RVFI-clean swap, no big-bang. Progression: leaves → subsystems
(RS/rename/rob) → clusters (lsu_top, frontend_top, backend_top) → `cpu` top
(Phase 4). Then the last blackboxed leaves (fu_div, cache arrays, skid_buffer)
were ported so the core is standalone, and the SV core + swap harness were
deleted. Correctness is now self-contained: the riscv-formal monitor (driven from
`cpu.rvfi_flat`) checks every committed instruction against the ISA.

External blackboxes that remain (vendor/IP, not part of the core): the SRAM macros
and `DW_div_seq`.

## Remaining levers (future work)

- **N-wide issue** (`idWidth` > 2): `CpuConfig` carries the width, but the
  original 2-way dispatch logic is width-specific — the id_stage branch/mem-split
  filter, the CDB lane subset, and `INT_ISSUE_WIDTH` must be generalised. RVFI is
  config-independent (per-instruction ISA check), so a wider core is directly
  validatable.
- **Wider fetch** (`ifWidth` = 8): mostly internal to the front-end; needs the
  remaining fixed-`IF_WIDTH` range assumptions (fetch_align / icache read) made
  fully cfg-derived.
- **Resource scaling**: RS/queue/predictor depths already vary freely and stay
  correct (see `GenerateCpuBig`). Bumping `prfDepth`/`robDepth` additionally needs
  the `DW_div_seq` operand widths (intm_rs_reg_t) to follow — i.e. a parameterised
  divider — since those reg widths cross the IP boundary.
- Deferred uarch ideas (MSHR D-cache, privileged/CSR, A-ext) as config, not
  rewrite.
