#!/bin/bash
# ROADMAP Phase 0 -- build the SpinalHDL core (gen/cpu.v) against the existing
# memory model + bmem boundary through Verilator. Excludes the SV-hierarchy-
# coupled checkers (perf_monitor; the rvfi `monitor` taps) -- those rebind once
# the SpinalHDL ROB exists (Phase 3). Uses the minimal top_tb in
# hvl/verilator_spinal/. The stub core never fetches, so a run just TIMES OUT;
# success here = "generates, compiles, links, simulates without crashing".
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROG="${PROG:-$ROOT/testcode/coremark_im.elf}"

echo "[1/3] generate SpinalHDL core -> hdl_spinal/gen/cpu.v"
( cd "$ROOT/hdl_spinal" && sbt -batch "runMain ooo.Generate" ) || { echo "GEN FAILED"; exit 1; }

echo "[2/3] verilator build"
CPU="$ROOT/hdl_spinal/gen/cpu.v"
HVL_COMMON=$(find "$ROOT/hvl/common" \( -name '*.sv' -o -name '*.v' \) ! -name 'perf_monitor.sv' | sort)
TB="$ROOT/hvl/verilator_spinal/top_tb_spinal.sv"
HARNESS=$(find "$ROOT/hvl/verilator" -name '*.cpp')
SRAM=$(find "$ROOT/sram/output" -name '*.v')
NOFLOAT=$(python3 "$ROOT/bin/get_options.py" no_float)

BUILD="$ROOT/sim/verilator_spinal"
rm -rf "$BUILD/build"; mkdir -p "$BUILD/build"
cd "$BUILD"
verilator \
  +incdir+"$ROOT/hvl/common" $NOFLOAT +define+DW_SUPPRESS_WARN \
  +incdir+"$ROOT/hvl/verilator" +define+ECE411_VERILATOR \
  -Wall -Wno-fatal -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-DECLFILENAME -Wno-WIDTHEXPAND \
  --timescale 1ps/1ps -Mdir build -O1 -CFLAGS "-O1" \
  --x-assign fast --x-initial fast --noassert --cc --exe --build \
  "$ROOT/sim/verilator_warn.vlt" \
  $CPU $HVL_COMMON "$TB" $HARNESS $SRAM \
  --top-module top_tb 2>&1 | tee build/compile_spinal.log
if [ ! -x build/Vtop_tb ]; then echo "BUILD FAILED"; exit 1; fi
echo "BUILD OK -> $BUILD/build/Vtop_tb"

echo "[3/3] smoke run (stub -> expected TIMEOUT, best-effort)"
( cd "$ROOT/sim" && python3 "$ROOT/bin/generate_memory_file.py" -32 "$PROG" ) || true
./build/Vtop_tb \
  +TIMEOUT_ECE411=5000 \
  +CLOCK_PERIOD_PS_ECE411="$(python3 "$ROOT/bin/get_options.py" clock)" \
  +BRAM_0_ON_X_ECE411="$(python3 "$ROOT/bin/get_options.py" bmem_x)" \
  +MEMLST_ECE411="$ROOT/sim/bin/memory_32.lst" \
  +NO_DUMP_ALL_ECE411=1 2>&1 | tail -5 || true
echo "RUN_DONE (timeout expected for the stub)"
