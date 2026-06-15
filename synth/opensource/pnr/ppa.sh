#!/bin/bash
# Reproducible PPA (Power/Performance/Area) + PD4 flow for OOOreo.
#
#   RTL --sv2v--> cpu.v --yosys(map_pnr.ys)--> netlist_pnr.v (real fakeram macros)
#       --OpenROAD(run_pnr.tcl: floorplan/place/repair_design/STA)--> log
#       --parse_ppa.py--> ppa.json   --(+ perf.json)--compute_pd4.py--> pd4.json
#
# Why P&R and not just synthesis: the raw yosys+abc netlist has no buffering, so
# global control nets fan out to thousands of flops on one gate and STA reports
# garbage (WNS ~ -180000 ns). repair_design buffers the placed design, giving a
# trustworthy WNS/power. See ../../../.../memory opensource-synthesis-flow.
#
# Usage (from repo root):  synth/opensource/pnr/ppa.sh [--remap]
#   --remap   re-run yosys mapping (slow, ~50 min); otherwise reuse netlist_pnr.v
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
DIR=synth/opensource/pnr
IMG=openroad/orfs:latest
PERIOD_PS=$(python3 bin/get_options.py clock)          # e.g. 2780
PERIOD_NS=$(python3 -c "print($PERIOD_PS/1000.0)")

if [[ "${1:-}" == "--remap" || ! -f "$DIR/netlist_pnr.v" ]]; then
  # The core is SpinalHDL -> emit Verilog directly (no sv2v) to synth/opensource/cpu.v.
  echo "[ppa] generating SpinalHDL core -> synth/opensource/cpu.v"
  ( cd hdl_spinal && sbt -batch "runMain ooo.Generate" )
  cp hdl_spinal/gen/cpu.v synth/opensource/cpu.v
  # PNR_FAST_MAP=1 uses abc -fast (single-pass map, ~5x faster) instead of the
  # timing-iterated abc -D 1000. Lower QoR but fine for relative A/B sweeps.
  MAP_YS="$DIR/map_pnr.ys"
  if [[ "${PNR_FAST_MAP:-}" == "1" ]]; then MAP_YS="$DIR/map_pnr_fast.ys"; fi
  echo "[ppa] yosys mapping (real fakeram macros) via $(basename "$MAP_YS")..."
  docker run --rm -v "$ROOT":/w -w /w "$IMG" yosys -s "$MAP_YS" \
    > "$DIR/yosys_pnr.log" 2>&1
fi

# OpenSTA/OpenROAD's structural Verilog reader can't parse #(.param(...)) overrides
# on instances; strip the only one (DW_div_seq -- its lib/lef are param-free).
perl -0777 -pi -e 's/DW_div_seq\s*#\([^)]*(?:\([^)]*\)[^)]*)*\)\s*divider\s*\(/DW_div_seq divider (/s' \
  "$DIR/netlist_pnr.v"

echo "[ppa] OpenROAD floorplan -> place -> repair_design -> STA @ ${PERIOD_NS} ns..."
# Forward optional floorplan knobs (die size / placement density / CTS) so a
# tighter floorplan can be swept without editing run_pnr.tcl. Unset -> run_pnr.tcl
# defaults reproduce the original loose 1600um / density-0.6 / ideal-clock run.
# PNR_GPU=1 adds --gpus all so OpenROAD's CUDA global placer can run (needs
# nvidia-container-toolkit; OpenROAD auto-uses the GPU when one is visible).
GPU_FLAG=""
if [[ "${PNR_GPU:-}" == "1" ]]; then GPU_FLAG="--gpus all"; fi
docker run --rm $GPU_FLAG -e ECE411_CLOCK_PERIOD_PS="$PERIOD_PS" \
  -e PNR_DIE_UM="${PNR_DIE_UM:-}" -e PNR_DENSITY="${PNR_DENSITY:-}" -e PNR_CTS="${PNR_CTS:-}" \
  -e PNR_OUT="${PNR_OUT:-}" -e PNR_WRITE_DEF="${PNR_WRITE_DEF:-}" \
  -v "$ROOT":/w -w /w "$IMG" \
  /OpenROAD-flow-scripts/tools/install/OpenROAD/bin/openroad -no_init -exit \
  "$DIR/run_pnr.tcl" > "$DIR/openroad_pnr.log" 2>&1

python3 bin/parse_ppa.py "$DIR/openroad_pnr.log" --period-ns "$PERIOD_NS" -o "$DIR/ppa.json"

# combine with each captured perf JSON into a PD4 record
shopt -s nullglob
for pj in sim/perf/*.json; do
  name=$(basename "$pj" .json)
  python3 bin/compute_pd4.py --perf "$pj" --ppa "$DIR/ppa.json" -o "$DIR/pd4_${name}.json" || true
done
echo "[ppa] done -> $DIR/ppa.json , $DIR/pd4_*.json"
