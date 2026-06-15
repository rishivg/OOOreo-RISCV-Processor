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
SHIM=""          # optional extra SV file(s): an interface-adapting shim for the swap
EXTRA_EXCLUDE=""  # optional 2nd SV file to drop (e.g. a leaf the SpinalHDL re-emits)

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
  fu_agu)
    GEN_MAIN="ooo.GenerateFuAgu"; GEN_V="$ROOT/hdl_spinal/gen/fu_agu.v"
    EXCLUDE="$ROOT/hdl/memory/mem_rs/fu_agu.sv"
    PROGS=("coremark_im" "coremark_imc")        # every load/store exercises the AGU
    ;;
  dcache_ctrl)
    GEN_MAIN="ooo.GenerateDcacheCtrl"; GEN_V="$ROOT/hdl_spinal/gen/dcache_ctrl.v"
    EXCLUDE="$ROOT/hdl/memory/dcache/dcache_ctrl.sv"
    PROGS=("coremark_im" "coremark_imc")        # every D-cache miss exercises the FSM
    ;;
  control_buffer)
    GEN_MAIN="ooo.GenerateControlBuffer"; GEN_V="$ROOT/hdl_spinal/gen/control_buffer_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/branch/control_buffer.sv"
    SHIM="$ROOT/sim/swap_shims/control_buffer.sv" # carries ds_rs_mono/br_cdb/cb_rob/cb_bp
    PROGS=("coremark_im" "coremark_imc")          # every committed branch trains via the CB
    ;;
  icache_ctrl)
    GEN_MAIN="ooo.GenerateIcacheCtrl"; GEN_V="$ROOT/hdl_spinal/gen/icache_ctrl_spinal.v"
    EXCLUDE="$ROOT/hdl/frontend/icache/icache_ctrl.sv"
    SHIM="$ROOT/sim/swap_shims/icache_ctrl.sv"  # parameterized + un-flattens arrays
    PROGS=("coremark_im" "coremark_imc")        # every I-cache miss exercises the FSM
    ;;
  fu_mul)
    GEN_MAIN="ooo.GenerateFuMul"; GEN_V="$ROOT/hdl_spinal/gen/fu_mul.v"
    EXCLUDE="$ROOT/hdl/backend/execute/intm_rs/fu_mul.sv"
    PROGS=("coremark_im" "coremark_imc")        # ~9700 multiplies in CoreMark
    ;;
  fu_alu)
    GEN_MAIN="ooo.GenerateFuAlu"; GEN_V="$ROOT/hdl_spinal/gen/fu_alu_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/execute/int_rs/fu_alu.sv"
    SHIM="$ROOT/sim/swap_shims/fu_alu.sv"       # carries the cdb_itf SV interface
    PROGS=("coremark_im" "coremark_imc")        # every ALU op exercises it
    ;;
  fu_br)
    GEN_MAIN="ooo.GenerateFuBr"; GEN_V="$ROOT/hdl_spinal/gen/fu_br_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/branch/br_rs/fu_br.sv"
    SHIM="$ROOT/sim/swap_shims/fu_br.sv"        # carries cdb_itf + br_cdb_itf
    PROGS=("coremark_im" "coremark_imc")        # every branch/jal/jalr exercises it
    ;;
  issue_arbiter)
    GEN_MAIN="ooo.GenerateIssueArbiter"; GEN_V="$ROOT/hdl_spinal/gen/issue_arbiter_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/execute/int_rs/issue_arbiter.sv"
    SHIM="$ROOT/sim/swap_shims/issue_arbiter.sv" # un-flattens the unpacked-array ports
    PROGS=("coremark_im" "coremark_imc")        # every INT issue exercises it
    ;;
  int_rs)
    GEN_MAIN="ooo.GenerateIntRs"; GEN_V="$ROOT/hdl_spinal/gen/int_rs_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/execute/int_rs/int_rs.sv"
    SHIM="$ROOT/sim/swap_shims/int_rs.sv"       # carries ds_rs/rs_prf/cdb interfaces
    PROGS=("coremark_im" "coremark_imc")        # the whole integer RS subsystem
    ;;
  br_rs)
    GEN_MAIN="ooo.GenerateBrRs"; GEN_V="$ROOT/hdl_spinal/gen/br_rs_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/branch/br_rs/br_rs.sv"
    SHIM="$ROOT/sim/swap_shims/br_rs.sv"        # carries ds_rs_mono/rs_prf/cdb/br_cdb
    PROGS=("coremark_im" "coremark_imc")        # the branch RS subsystem
    ;;
  intm_rs)
    GEN_MAIN="ooo.GenerateIntmRs"; GEN_V="$ROOT/hdl_spinal/gen/intm_rs_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/execute/intm_rs/intm_rs.sv"
    SHIM="$ROOT/sim/swap_shims/intm_rs.sv"      # +SV fu_div (DW); mul/div RS subsystem
    EXTRA_EXCLUDE="$ROOT/hdl/backend/execute/intm_rs/fu_mul.sv"  # intm_rs_spinal re-emits fu_mul
    PROGS=("coremark_im" "coremark_imc")
    ;;
  lsu_adapter)
    GEN_MAIN="ooo.GenerateLsuAdapter"; GEN_V="$ROOT/hdl_spinal/gen/lsu_adapter_spinal.v"
    EXCLUDE="$ROOT/hdl/memory/lsu_adapter.sv"
    SHIM="$ROOT/sim/swap_shims/lsu_adapter.sv"  # 4x ds_rs_mono_itf; fans out uop
    PROGS=("coremark_im" "coremark_imc")        # every memory dispatch fans out here
    ;;
  store_buf)
    GEN_MAIN="ooo.GenerateStoreBuf"; GEN_V="$ROOT/hdl_spinal/gen/store_buf_spinal.v"
    EXCLUDE="$ROOT/hdl/memory/store_buf.sv"
    SHIM="$ROOT/sim/swap_shims/store_buf.sv"    # stq_stb + stb_dmem + ldq_stb itfs
    PROGS=("coremark_im" "coremark_imc")        # every committed store drains via the STB
    ;;
  hit_detection)
    GEN_MAIN="ooo.GenerateHitDetection"; GEN_V="$ROOT/hdl_spinal/gen/hit_detection_spinal.v"
    EXCLUDE="$ROOT/hdl/memory/dcache/hit_detection.sv"
    SHIM="$ROOT/sim/swap_shims/hit_detection.sv"  # parameterized + un-flattens arrays
    PROGS=("coremark_im" "coremark_imc")          # every D-cache access does hit detect
    ;;
  rob)
    GEN_MAIN="ooo.GenerateRob"; GEN_V="$ROOT/hdl_spinal/gen/rob_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/rename/rob.sv"
    SHIM="$ROOT/sim/swap_shims/rob.sv"          # 6 itfs + rvfi_itf tap + perf taps
    PROGS=("coremark_im" "coremark_imc")        # the whole commit/RVFI path
    ;;
  free_list)
    GEN_MAIN="ooo.GenerateFreeList"; GEN_V="$ROOT/hdl_spinal/gen/free_list_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/rename/free_list.sv"
    SHIM="$ROOT/sim/swap_shims/free_list.sv"    # id_fl_itf.fl + rrf_fl_itf.fl
    PROGS=("coremark_im" "coremark_imc")        # every rename pops/pushes the free list
    ;;
  rat)
    GEN_MAIN="ooo.GenerateRat"; GEN_V="$ROOT/hdl_spinal/gen/rat_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/rename/rat.sv"
    SHIM="$ROOT/sim/swap_shims/rat.sv"          # id_rat_itf + cdb_itf.rat[5] + rrf_mem[32]
    PROGS=("coremark_im" "coremark_imc")        # every rename reads/writes the RAT
    ;;
  prf)
    GEN_MAIN="ooo.GeneratePrf"; GEN_V="$ROOT/hdl_spinal/gen/prf_spinal.v"
    EXCLUDE="$ROOT/hdl/backend/execute/prf.sv"
    SHIM="$ROOT/sim/swap_shims/prf.sv"          # rs_prf_itf[5]+cdb_itf.prf[5]+bypass[2]
    PROGS=("coremark_im" "coremark_imc")        # every register read/write hits the PRF
    ;;
  fetch_align)
    GEN_MAIN="ooo.GenerateFetchAlign"; GEN_V="$ROOT/hdl_spinal/gen/fetch_align.v"
    EXCLUDE="$ROOT/hdl/frontend/fetch_align.sv"
    EXTRA_EXCLUDE="$ROOT/hdl/frontend/decompressor.sv"  # fetch_align re-emits decompressor
    PROGS=("coremark_imc" "coremark_im")        # imc exercises the C-realign; im = regression
    ;;
  tage)
    GEN_MAIN="ooo.GenerateTage"; GEN_V="$ROOT/hdl_spinal/gen/tage_spinal.v"
    EXCLUDE="$ROOT/hdl/frontend/branch_predictor/tage.sv"
    SHIM="$ROOT/sim/swap_shims/tage.sv"         # carries cb_bp_itf.bp from_cb
    PROGS=("coremark_im" "coremark_imc")        # every conditional branch trains TAGE
    ;;
  ubtb)
    GEN_MAIN="ooo.GenerateUbtb"; GEN_V="$ROOT/hdl_spinal/gen/ubtb_spinal.v"
    EXCLUDE="$ROOT/hdl/frontend/branch_predictor/ubtb.sv"
    SHIM="$ROOT/sim/swap_shims/ubtb.sv"         # carries cb_bp_itf.bp from_cb
    PROGS=("coremark_im" "coremark_imc")        # every taken branch/jump trains the uBTB
    ;;
  ras)
    GEN_MAIN="ooo.GenerateRas"; GEN_V="$ROOT/hdl_spinal/gen/ras_spinal.v"
    EXCLUDE="$ROOT/hdl/frontend/branch_predictor/ras.sv"
    SHIM="$ROOT/sim/swap_shims/ras.sv"          # carries cb_bp_itf.bp from_cb
    PROGS=("coremark_im" "coremark_imc")        # every call/return exercises the RAS
    ;;
  mem_rs)
    GEN_MAIN="ooo.GenerateMemRs"; GEN_V="$ROOT/hdl_spinal/gen/mem_rs_spinal.v"
    EXCLUDE="$ROOT/hdl/memory/mem_rs/mem_rs.sv"
    SHIM="$ROOT/sim/swap_shims/mem_rs.sv"       # carries ds_rs_mono/rs_prf/cdb/agu_lsq
    EXTRA_EXCLUDE="$ROOT/hdl/memory/mem_rs/fu_agu.sv"  # mem_rs_spinal re-emits fu_agu
    PROGS=("coremark_im" "coremark_imc")        # the memory RS subsystem
    ;;
  *) echo "unknown module: $MOD"; exit 2 ;;
esac

echo "[1/4] generate SpinalHDL $MOD -> ${GEN_V#$ROOT/}"
( cd "$ROOT/hdl_spinal" && sbt -batch "runMain $GEN_MAIN" ) || { echo "GEN FAILED"; exit 1; }
[ -f "$GEN_V" ] || { echo "missing $GEN_V"; exit 1; }

echo "[2/4] assemble file list (SV $MOD excluded, generated twin added)"
PKG="$ROOT/pkg/types.sv"
HDL_SRCS=$(find "$ROOT/hdl" -name '*.sv' ! -path "$EXCLUDE" ${EXTRA_EXCLUDE:+! -path "$EXTRA_EXCLUDE"} | sort)
COMM_HVL=$(find "$ROOT/hvl/common" \( -name '*.sv' -o -name '*.v' -o -name '*.o' \) | sort)
if [ "${DROP_PERF:-0}" = "1" ]; then
  COMM_HVL=$(echo "$COMM_HVL" | grep -v 'perf_monitor.sv')   # taps swapped-module internals
  echo "    (perf_monitor.sv dropped -- it taps internals of $MOD)"
fi
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
  $PKG $HDL_SRCS "$GEN_V" $SHIM $COMM_HVL $VER_HVL $SRAM $DW_IP \
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