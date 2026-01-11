# Restructure plan (high level)

This document maps the proposed reorganizations and where files will move.

Moves performed in this change:
- `scripts/` -> `tooling/dev/scripts/`
- `tools/` -> `tooling/analysis/tools/`
- `bin/` -> `tooling/sim/bin/`

Suggested future moves:
- `hdl/` -> keep but add internal grouping (`hdl/core`, `hdl/common`, `hdl/mem`, `hdl/arch`)
- `hvl/` -> split into `tb/` (runtime testbench) and `verif/` (formal/test infrastructure)
- Consolidate CI helpers into `tooling/build/`
