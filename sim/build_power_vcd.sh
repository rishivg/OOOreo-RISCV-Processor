#!/usr/bin/env bash
# Dump a bounded activity window to verilator_power/build/run/sim_power.vcd.
set -euo pipefail
cd "$(dirname "$0")"
program=${1:-coremark_imc}
start=${2:-50000}
length=${3:-10000}
exec make run TRACE=1 BUILD_DIR="$PWD/verilator_power/build" \
    PROG="../testcode/$program.elf" \
    SIM_ARGS="+DUMP_VCD=1 +DUMP_START_CYC=$start +DUMP_LEN_CYC=$length"
