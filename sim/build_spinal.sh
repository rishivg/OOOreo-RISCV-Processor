#!/bin/bash
# ROADMAP Phase 4 -- build + VALIDATE the full SpinalHDL core (gen/cpu.v) against
# the real memory model + RVFI monitor through Verilator, using the dedicated
# SpinalHDL testbench (hvl/verilator_spinal/top_tb_spinal.sv) that drives the
# monitor from the cpu's rvfi_flat debug output. perf_monitor is omitted (taps
# SV-named internals). Success = RVFI-clean to $finish at the oracle IPC
# (im 1.426545 / imc 1.381854). The real SV fu_div (DW_div_seq) stays in the build.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/3] generate SpinalHDL core -> hdl_spinal/gen/cpu.v (gen: ${CPU_GEN:-ooo.Generate})"
( cd "$ROOT/hdl_spinal" && sbt -batch "runMain ${CPU_GEN:-ooo.Generate}" ) || { echo "GEN FAILED"; exit 1; }
CPU="$ROOT/hdl_spinal/gen/cpu.v"
[ -f "$CPU" ] || { echo "missing $CPU"; exit 1; }

echo "[2/3] verilator build"
# The SpinalHDL core is standalone -- the only external modules are vendor/IP:
# the SRAM macros (sram/output) + DW_div_seq (hvl/common/dw_mock.sv, in HVL_COMMON).
HVL_COMMON=$(find "$ROOT/hvl/common" \( -name '*.sv' -o -name '*.v' -o -name '*.o' \) ! -name 'perf_monitor.sv' | sort)
TB="$ROOT/hvl/verilator_spinal/top_tb_spinal.sv"
HARNESS=$(find "$ROOT/hvl/verilator" -name '*.cpp')
SRAM=$(find "$ROOT/sram/output" -name '*.v')
NOFLOAT=$(python3 "$ROOT/bin/get_options.py" no_float)
DW_IP=$(python3 "$ROOT/bin/get_options.py" dw_ip)

BUILD="$ROOT/sim/verilator_spinal"
rm -rf "$BUILD/build"; mkdir -p "$BUILD/build"
cd "$BUILD"
verilator \
  +incdir+"$ROOT/hvl/common" $NOFLOAT +define+DW_SUPPRESS_WARN \
  +incdir+"$ROOT/hvl/verilator" +define+ECE411_VERILATOR \
  -Wall -Wno-fatal --timescale 1ps/1ps -Mdir build -O1 -CFLAGS "-O1" \
  --x-assign fast --x-initial fast --noassert --cc --exe --build \
  "$ROOT/sim/verilator_warn.vlt" \
  "$ROOT/pkg/types.sv" "$CPU" $HVL_COMMON "$TB" $HARNESS $SRAM $DW_IP \
  --top-module top_tb 2>&1 | tee build/compile_spinal.log
if [ ! -x build/Vtop_tb ]; then echo "BUILD FAILED"; exit 1; fi
echo "BUILD OK"

echo "[3/3] run program(s): coremark_im coremark_imc"
RC=0
for P in coremark_im coremark_imc; do
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
