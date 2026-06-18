#!/bin/bash
# Produce formal/build/cpu_rvfi_flat.v: the SpinalHDL OOOreo core + the cpu_rvfi
# RVFI exposure shim + the external blackbox models (SRAM macros, DW_div_seq), as
# a single Verilog file for riscv-formal's yosys flow (read by checks.cfg).
#
# The core is SpinalHDL -> it emits plain Verilog directly (no sv2v of the core);
# only the small SV shim (which uses the rvfi_dbg_t struct from pkg/types.sv) is
# run through sv2v to flatten its struct field accesses to bit-slices.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SV2V=${SV2V:-sv2v}
OUT=formal/build
mkdir -p "$OUT"

echo "[formal] generating SpinalHDL core -> hdl/gen/cpu.v"
( cd hdl && sbt -batch "runMain ooo.Generate" )

echo "[formal] sv2v the rvfi exposure shim (pkg + cpu_rvfi) -> plain Verilog"
"$SV2V" pkg/types.sv formal/riscv-formal/cpu_rvfi.sv > "$OUT/cpu_rvfi_shim.v"

echo "[formal] combine core + shim + SRAM/divider models -> $OUT/cpu_rvfi_flat.v"
cat hdl/gen/cpu.v "$OUT/cpu_rvfi_shim.v" \
    sram/output/*/*.v hvl/common/dw_mock.sv > "$OUT/cpu_rvfi_flat.v"

echo "[formal] wrote $OUT/cpu_rvfi_flat.v (top: cpu_rvfi)"
