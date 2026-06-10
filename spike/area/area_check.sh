#!/bin/bash
# Map a generated Verilog/SystemVerilog file to Nangate45 and report cell area --
# the SAME library/flow as the main PPA, so chisel-vs-spinal output is comparable.
#
#   ./area_check.sh ../gen/RenameRob_chisel_w2.sv RenameRob
#   ./area_check.sh ../gen/RenameRob_spinal_w4.v  RenameRob
set -euo pipefail
V="$(readlink -f "$1")"
TOP="${2:-RenameRob}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"          # repo root (docker mount)
REL="${V#"$ROOT"/}"
IMG=openroad/orfs:latest
LIB=/OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib

echo "[area] $REL  (top=$TOP)"
docker run --rm -v "$ROOT":/w -w /w "$IMG" yosys -p "
  read_verilog -sv $REL;
  hierarchy -check -top $TOP;
  synth -flatten -top $TOP;
  dfflibmap -liberty $LIB;
  abc -liberty $LIB;
  stat -liberty $LIB;
" 2>&1 | grep -E "Chip area|Number of cells|Number of wires|\\\$_DFF|   [A-Z].*_X" | tail -40
