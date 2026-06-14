#!/bin/bash
# ROADMAP Phase 2 module-swap co-validation (generalized over leaf modules).
#
#   sim/build_swap.sh <module>
#
# Builds the FULL SV core with one SV module filtered OUT of the file list and the
# SpinalHDL-generated Verilog twin put in its place, then runs the relevant
# CoreMark program(s) through the real RVFI monitor + perf_monitor. Success =
# RVFI-clean to $finish at the SAME IPC as the all-SV core. hdl/ stays pristine.
#
# Supported <module>: decoder | decompressor
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="${1:?usage: build_swap.sh <decoder|decompressor>}"

case "$MOD" in
  decoder)
    GEN_MAIN="ooo.GenerateDecoder"; GEN_V="$ROOT/hdl_spinal/gen/decoder.v"
    EXCLUDE="$ROOT/hdl/backend/decode/decoder.sv"
    PROGS=("coremark_im")                       # RV32I exercises the full decoder
    ;;
  decompressor)
    GEN_MAIN="ooo.GenerateDecompressor"; GEN_V="$ROOT/hdl_spinal/gen/decompressor.v"
    EXCLUDE="$ROOT/hdl/frontend/decompressor.sv"
    PROGS=("coremark_imc" "coremark_im")        # imc exercises C-decode; im = regression
    ;;
  *) echo "unknown module: $MOD"; exit 2 ;;
esac

echo "[1/4] generate SpinalHDL $MOD -> ${GEN_V#$ROOT/}"
( cd "$ROOT/hdl_spinal" && sbt -batch "runMain $GEN_MAIN" ) || { echo "GEN FAILED"; exit 1; }
[ -f "$GEN_V" ] || { echo "missing $GEN_V"; exit 1; }

echo "[2/4] assemble file list (SV $MOD excluded, generated twin added)"
PKG="$ROOT/pkg/types.sv"
HDL_SRCS=$(find "$ROOT/hdl" -name '*.sv' ! -path "$EXCLUDE" | sort)
COMM_HVL=$(find "$ROOT/hvl/common" \( -name '*.sv' -o -name '*.v' -o -name '*.o' \) | sort)
VER_HVL=$(find "$ROOT/hvl/verilator" \( -name '*.sv' -o -name '*.v' -o -name '*.o' -o -name '*.cpp' \) | sort)
SRAM=$(find "$ROOT/sram/output" -name '*.v' | sort)
NO_FLOAT=$(python3 "$ROOT/bin/get_options.py" no_float)
DW_IP=$(python3 "$ROOT/bin/get_options.py" dw_ip)
if echo "$HDL_SRCS" | grep -qF "$EXCLUDE"; then echo "FILTER FAILED: $EXCLUDE still present"; exit 1; fi

echo "[3/4] verilator build (swapped $MOD)"
BUILD="$ROOT/sim/verilator_swap"
rm -rf "$BUILD/build"; mkdir -p "$BUILD/build"
( cd "$ROOT/sim" && python3 "$ROOT/bin/rvfi_reference.py" 8 "$NO_FLOAT" )
cd "$BUILD"
verilator \
  +incdir+"$ROOT/hvl/common" $NO_FLOAT +define+DW_SUPPRESS_WARN \
  +incdir+"$ROOT/hvl/verilator" +define+ECE411_VERILATOR \
  -Wall -Wno-fatal --timescale 1ps/1ps -Mdir build -O1 -CFLAGS "-O1" \
  --x-assign fast --x-initial fast --noassert --cc --exe --build \
  "$ROOT/sim/verilator_warn.vlt" \
  $PKG $HDL_SRCS "$GEN_V" $COMM_HVL $VER_HVL $SRAM $DW_IP \
  --top-module top_tb 2>&1 | tee build/compile_swap.log
if [ ! -x build/Vtop_tb ]; then echo "BUILD FAILED"; exit 1; fi
echo "BUILD OK"

echo "[4/4] run program(s): ${PROGS[*]}"
RC=0
for P in "${PROGS[@]}"; do
  ELF="$ROOT/testcode/$P.elf"
  echo "----- $P -----"
  ( cd "$ROOT/sim" && python3 "$ROOT/bin/generate_memory_file.py" -32 "$ELF" ) >/dev/null
  ./build/Vtop_tb \
    +TIMEOUT_ECE411="${TIMEOUT:-10000000}" \
    +CLOCK_PERIOD_PS_ECE411="$(python3 "$ROOT/bin/get_options.py" clock)" \
    +BRAM_0_ON_X_ECE411="$(python3 "$ROOT/bin/get_options.py" bmem_x)" \
    +MEMLST_ECE411="$ROOT/sim/bin/memory_32.lst" \
    +NO_DUMP_ALL_ECE411=1 > "sim_$P.log" 2>&1
  IPC=$(grep -i "Segment IPC" "sim_$P.log" | tail -1)
  ERR=$(grep -iE "error|mismatch|fault" "sim_$P.log" | grep -ivE "no_float|0 error" | head -1)
  if grep -qiE "Timed out|TIMEOUT" "sim_$P.log"; then echo "  TIMEOUT (FAIL)"; RC=1
  elif [ -n "$ERR" ]; then echo "  MONITOR ERROR: $ERR (FAIL)"; RC=1
  elif grep -qi "finish" "sim_$P.log"; then echo "  \$finish, $IPC (RVFI-clean)";
  else echo "  no \$finish (FAIL)"; RC=1; fi
done
exit $RC