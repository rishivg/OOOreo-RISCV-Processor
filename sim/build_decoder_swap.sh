#!/bin/bash
# ROADMAP Phase 2 module-swap co-validation: build the FULL SV core but replace
# hdl/backend/decode/decoder.sv with the SpinalHDL-generated hdl_spinal/gen/decoder.v,
# then run coremark_im through the real RVFI monitor + perf_monitor. Success =
# RVFI-clean to $finish at the SAME IPC as the all-SV core (im 1.426545).
#
# hdl/ is left pristine: the swap is done purely by filtering the file list.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROG="${PROG:-$ROOT/testcode/coremark_im.elf}"
GEN_DECODER="$ROOT/hdl_spinal/gen/decoder.v"

echo "[1/4] generate SpinalHDL decoder -> hdl_spinal/gen/decoder.v"
( cd "$ROOT/hdl_spinal" && sbt -batch "runMain ooo.GenerateDecoder" ) || { echo "GEN FAILED"; exit 1; }
[ -f "$GEN_DECODER" ] || { echo "missing $GEN_DECODER"; exit 1; }

echo "[2/4] assemble file list (SV decoder excluded, generated decoder added)"
PKG="$ROOT/pkg/types.sv"
# every hdl .sv EXCEPT the decoder we are swapping out
HDL_SRCS=$(find "$ROOT/hdl" -name '*.sv' ! -path "$ROOT/hdl/backend/decode/decoder.sv" | sort)
COMM_HVL=$(find "$ROOT/hvl/common" \( -name '*.sv' -o -name '*.v' -o -name '*.o' \) | sort)
VER_HVL=$(find "$ROOT/hvl/verilator" \( -name '*.sv' -o -name '*.v' -o -name '*.o' -o -name '*.cpp' \) | sort)
SRAM=$(find "$ROOT/sram/output" -name '*.v' | sort)
NO_FLOAT=$(python3 "$ROOT/bin/get_options.py" no_float)
DW_IP=$(python3 "$ROOT/bin/get_options.py" dw_ip)

# sanity: ensure we really dropped the SV decoder
if echo "$HDL_SRCS" | grep -q "decode/decoder.sv"; then echo "FILTER FAILED: decoder.sv still present"; exit 1; fi

echo "[3/4] verilator build (swapped decoder)"
BUILD="$ROOT/sim/verilator_swap"
rm -rf "$BUILD/build"; mkdir -p "$BUILD/build"
# RVFI reference table the monitor needs (same as sim/Makefile)
( cd "$ROOT/sim" && python3 "$ROOT/bin/rvfi_reference.py" 8 "$NO_FLOAT" )
cd "$BUILD"
verilator \
  +incdir+"$ROOT/hvl/common" $NO_FLOAT +define+DW_SUPPRESS_WARN \
  +incdir+"$ROOT/hvl/verilator" +define+ECE411_VERILATOR \
  -Wall -Wno-fatal --timescale 1ps/1ps -Mdir build -O1 -CFLAGS "-O1" \
  --x-assign fast --x-initial fast --noassert --cc --exe --build \
  "$ROOT/sim/verilator_warn.vlt" \
  $PKG $HDL_SRCS "$GEN_DECODER" $COMM_HVL $VER_HVL $SRAM $DW_IP \
  --top-module top_tb 2>&1 | tee build/compile_swap.log
if [ ! -x build/Vtop_tb ]; then echo "BUILD FAILED"; exit 1; fi
echo "BUILD OK"

echo "[4/4] run coremark_im (RVFI + perf)"
( cd "$ROOT/sim" && python3 "$ROOT/bin/generate_memory_file.py" -32 "$PROG" )
find . -maxdepth 1 -type f -delete
./build/Vtop_tb \
  +TIMEOUT_ECE411="${TIMEOUT:-10000000}" \
  +CLOCK_PERIOD_PS_ECE411="$(python3 "$ROOT/bin/get_options.py" clock)" \
  +BRAM_0_ON_X_ECE411="$(python3 "$ROOT/bin/get_options.py" bmem_x)" \
  +MEMLST_ECE411="$ROOT/sim/bin/memory_32.lst" \
  +NO_DUMP_ALL_ECE411=1 2>&1 | tee simulation.log | tail -25

echo "=========================================================="
if grep -qiE "Timed out|TIMEOUT" simulation.log; then echo "RESULT: TIMEOUT (FAIL)"; exit 1; fi
if grep -qi "finish" simulation.log; then echo "RESULT: reached \$finish (RVFI-clean if no monitor error above)"; else echo "RESULT: no \$finish seen"; fi