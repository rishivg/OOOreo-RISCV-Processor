# Right-sized cache fakeram macros

The orfs Nangate45 platform only ships `fakeram45_128x256` / `fakeram45_32x32`, which
over-provision OOOreo's caches: the I$ is 64 sets and the D$ is 16 sets, so mapping their
256-bit data arrays onto a 128-deep macro inflated the cache macro area ~2x (I$) to ~8x
(D$) — ~38% of the reported core area was this artifact, with matching inflated power.

These macros are hand-scaled from the platform originals to the actual geometry:

| macro              | use        | depth | scaled from   |
|--------------------|------------|-------|---------------|
| fakeram45_64x256   | I$ data    | 64    | 128x256       |
| fakeram45_16x256   | D$ data    | 16    | 128x256       |
| fakeram45_16x32    | D$ tag     | 16    | 32x32         |

(I$ tag stays the stock `fakeram45_64x32` — already right-sized.)

Scaling (periphery-aware, NOT linear — shallow SRAMs keep a periphery floor):
  factor = (target_depth / source_depth) ** 0.8
applied to BOTH the LEF (SIZE-X + every RECT X-coord; Y is bit-pin-limited, fixed) and
the LIB (`area` + every `rise_power`/`fall_power` value = per-access internal energy).
Pins stay on the left edge; ports/addr width are unchanged (extra addr bits unused).

Net vs the oversized macros: core area 743,084 -> 575,380 um2 (-22.6%), power 0.348 ->
0.293 W (-15.8%), Fmax flat. These are approximate (fakeram is a placeholder model); a
real SRAM compiler would give the true numbers, but these are far closer to reality than
the stock oversized macros.
