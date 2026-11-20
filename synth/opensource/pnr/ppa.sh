#!/bin/bash
# ASIC screening: [--remap] [--name LABEL] [--clock-ps PS] [--sweep NAME:KEY=VALUE] [-j N] [--list].
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
DIR=synth/opensource/pnr
RUNS="$DIR/runs"
source "$ROOT/tools/versions.lock"
IMG="$ORFS_IMAGE"

# ---------------- args ----------------
REMAP=0; NAME=""; SWEEPS=(); JOBS=3; LIST=0; CANON=0; WALLS="${PNR_RPT_WALLS:-}"
CLOCK_PS="${PNR_CLOCK_PS:-}"; FASTMAP="${PNR_FAST_MAP:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remap)      REMAP=1 ;;
    --canonical)  CANON=1 ;;
    --fast-map)   FASTMAP=1 ;;
    --name)       NAME="$2"; shift ;;
    --clock-ps)   CLOCK_PS="$2"; shift ;;
    --die)        PNR_DIE_UM="$2"; shift ;;
    --density)    PNR_DENSITY="$2"; shift ;;
    --walls)      WALLS=1 ;;
    --sweep)      SWEEPS+=("$2"); shift ;;
    -j)           JOBS="$2"; shift ;;
    --list)       LIST=1 ;;
    *) echo "ppa.sh: unknown arg $1" >&2; exit 2 ;;
  esac; shift
done
mkdir -p "$RUNS"
if [[ $LIST == 1 ]]; then python3 bin/ppa_index.py table "$RUNS/index.jsonl"; exit 0; fi

# default clock = the committed architectural clock (options.json). --clock-ps
# overrides the PNR TARGET only -- the sim/DRAM-model clock is untouched, so IPC
# gates stay comparable (a *committed* options.json clock change DOES move the
# DRAM ns->cycle ceilings; re-verify the gate pair when retuning it).
OPT_CLOCK=$(python3 bin/get_options.py clock)

# ---------------- netlist (sbt + yosys), staleness-guarded ----------------
if [[ $REMAP == 1 || ! -f "$DIR/netlist_pnr.v" ]]; then
  echo "[ppa] generating SpinalHDL core -> synth/opensource/cpu.v (gen: ${CPU_GEN:-ooo.Generate})"
  python3 bin/generate_rtl.py "$ROOT/hdl/gen" --generator "${CPU_GEN:-ooo.Generate}"
  cp hdl/gen/cpu.v synth/opensource/cpu.v
  MAP_YS="$DIR/map_pnr.ys"
  [[ "${FASTMAP:-}" == "1" ]] && MAP_YS="$DIR/map_pnr_fast.ys"   # abc -fast, A/B sweeps only
  # PNR_MAP_YS: run an ALTERNATE mapping script (hierarchy experiments). Path is
  # relative to the repo root, since yosys runs with /w = root inside the image.
  [[ -n "${PNR_MAP_YS:-}" ]] && MAP_YS="$PNR_MAP_YS"
  echo "[ppa] yosys mapping (real fakeram macros) via $(basename "$MAP_YS")..."
  docker run --rm -v "$ROOT":/w -w /w "$IMG" yosys -s "$MAP_YS" > "$DIR/yosys_pnr.log" 2>&1
  # OpenSTA/OpenROAD's structural Verilog reader can't parse #(.param(...)) on
  # instances; strip the only one (DW_div_seq). Done ONCE here, post-remap --
  # the netlist is immutable between remaps.
  perl -0777 -pi -e 's/DW_div_seq\s*#\([^)]*(?:\([^)]*\)[^)]*)*\)\s*(\\\S+\s|\w+)\s*\(/DW_div_seq $1 (/sg' \
    "$DIR/netlist_pnr.v"
else
  # stale-netlist guard: measuring an old netlist after an RTL edit is the #1
  # silent flow mistake. Warn loudly (mtime heuristic).
  if [[ -n "$(find hdl/src/main/scala -name '*.scala' -newer "$DIR/netlist_pnr.v" -print -quit 2>/dev/null)" ]]; then
    echo "[ppa] *** WARNING: hdl/src/main/scala has files NEWER than netlist_pnr.v" >&2
    echo "[ppa] ***          results will measure the OLD netlist -- rerun with --remap" >&2
  fi
  want_ys="$(basename "${PNR_MAP_YS:-$DIR/map_pnr.ys}")"
  got_ys="$(grep -m1 -oP "Executing script file .\K[^']+" "$DIR/yosys_pnr.log" 2>/dev/null | xargs -r basename)"
  if [[ -n "$got_ys" && "$got_ys" != "$want_ys" ]]; then
    echo "[ppa] *** FATAL: netlist_pnr.v was mapped by '$got_ys', but this run expects '$want_ys'." >&2
    echo "[ppa] ***        Re-run with --remap (or set PNR_MAP_YS to match)." >&2
    exit 3
  fi
fi

# ---------------- one OpenROAD run ----------------
# run_one <name> <clock_ps> <extra_env...>   -> runs/<name>/{openroad.log,ppa.json,config.env}
run_one() {
  local name="$1" clk="$2"; shift 2
  local rdir="$RUNS/$name"; mkdir -p "$rdir"
  local envs=( OOOREO_CLOCK_PERIOD_PS="$clk"
               PNR_DIE_UM="${PNR_DIE_UM:-}" PNR_DENSITY="${PNR_DENSITY:-}" PNR_CTS="${PNR_CTS:-}"
               PNR_CTS_RT="${PNR_CTS_RT:-}"
               PNR_MACRO_MY="${PNR_MACRO_MY:-}" PNR_SPLIT_ICTAG="${PNR_SPLIT_ICTAG:-}"
               PNR_DC_GRID="${PNR_DC_GRID:-}" PNR_TIMING_DRIVEN="${PNR_TIMING_DRIVEN:-}"
               PNR_ICT_Y="${PNR_ICT_Y:-}" PNR_PRED_Y="${PNR_PRED_Y:-}"
               PNR_RPT_COUNT="${PNR_RPT_COUNT:-}" PNR_RPT_WALLS="${PNR_RPT_WALLS:-}"
               PNR_OUT="${PNR_OUT:-}" PNR_WRITE_DEF="${PNR_WRITE_DEF:-}"
               PNR_REPAIR_TIMING="${PNR_REPAIR_TIMING:-}"
               OOOREO_VCD="${OOOREO_VCD:-}" OOOREO_VCD_SCOPE="${OOOREO_VCD_SCOPE:-}"
               "$@" )
  printf '%s\n' "${envs[@]}" > "$rdir/config.env"
  local dockenv=(); local e
  for e in "${envs[@]}"; do dockenv+=( -e "$e" ); done
  local gpu=(); [[ "${PNR_GPU:-}" == "1" ]] && gpu=( --gpus all )
  docker run --rm "${gpu[@]}" "${dockenv[@]}" -v "$ROOT":/w -w /w "$IMG" \
    /OpenROAD-flow-scripts/tools/install/OpenROAD/bin/openroad -no_init -exit \
    "$DIR/run_pnr.tcl" > "$rdir/openroad.log" 2>&1
  python3 bin/parse_ppa.py "$rdir/openroad.log" \
    --period-ns "$(python3 -c "print($clk/1000.0)")" -o "$rdir/ppa.json" > /dev/null
  python3 bin/ppa_index.py append "$RUNS/index.jsonl" --name "$name" \
    --ppa "$rdir/ppa.json" --config "$rdir/config.env"
}

# ---------------- sweep mode: parallel probes, no canonical side effects ----------------
if [[ ${#SWEEPS[@]} -gt 0 ]]; then
  echo "[ppa] sweep: ${#SWEEPS[@]} runs, $JOBS in parallel @ base clock ${CLOCK_PS:-$OPT_CLOCK} ps"
  pids=(); names=()
  for spec in "${SWEEPS[@]}"; do
    name="${spec%%:*}"; kv="${spec#*:}"; [[ "$kv" == "$spec" ]] && kv=""
    clk="${CLOCK_PS:-$OPT_CLOCK}"; extra=()
    IFS=',' read -ra pairs <<< "$kv"
    for p in "${pairs[@]}"; do [[ -z "$p" ]] && continue
      k="${p%%=*}"; v="${p#*=}"
      case "$k" in
        clock)   clk="$v" ;;
        die)     extra+=( PNR_DIE_UM="$v" ) ;;
        density) extra+=( PNR_DENSITY="$v" ) ;;
        my)      extra+=( PNR_MACRO_MY="$v" ) ;;
        split)   extra+=( PNR_SPLIT_ICTAG="$v" ) ;;
        dcgrid)  extra+=( PNR_DC_GRID="$v" ) ;;
        td)      extra+=( PNR_TIMING_DRIVEN="$v" ) ;;
        icty)    extra+=( PNR_ICT_Y="$v" ) ;;
        predy)   extra+=( PNR_PRED_Y="$v" ) ;;
        walls)   extra+=( PNR_RPT_WALLS="$v" ) ;;
        rt)      extra+=( PNR_REPAIR_TIMING="$v" ) ;;
        cts)     extra+=( PNR_CTS="$v" ) ;;
        ctsrt)   extra+=( PNR_CTS_RT="$v" ) ;;
        *) echo "ppa.sh: unknown sweep key '$k' in '$spec'" >&2; exit 2 ;;
      esac
    done
    run_one "$name" "$clk" "${extra[@]}" &
    pids+=($!); names+=("$name")
    while [[ $(jobs -rp | wc -l) -ge $JOBS ]]; do wait -n; done
  done
  wait
  echo; python3 bin/ppa_index.py table "$RUNS/index.jsonl" --names "$(IFS=,; echo "${names[*]}")"
  exit 0
fi

# ---------------- single run ----------------
CLK="${CLOCK_PS:-$OPT_CLOCK}"
RNAME="${NAME:-default}"
extra=(); [[ -n "$WALLS" ]] && extra+=( PNR_RPT_WALLS="$WALLS" )
echo "[ppa] OpenROAD floorplan -> place -> repair_design -> STA @ ${CLK} ps -> runs/$RNAME/ ..."
run_one "$RNAME" "$CLK" "${extra[@]+"${extra[@]}"}"
python3 -c "import json;d=json.load(open('$RUNS/$RNAME/ppa.json'));print('[ppa] %s: %.1f MHz (wns %+0.2f, tns %+0.2f) %d um2 %.3f W' % ('$RNAME',d['fmax_mhz'],d['wns_ns'],d['tns_ns'] or 0,d['area_um2'],d['power_total_w']))"

if [[ -z "$NAME" && ( -z "$CLOCK_PS" || $CANON == 1 ) ]]; then
  cp "$RUNS/$RNAME/openroad.log" "$DIR/openroad_pnr.log"
  cp "$RUNS/$RNAME/ppa.json"     "$DIR/ppa.json"
  shopt -s nullglob
  for pj in sim/perf/*.json; do
    n=$(basename "$pj" .json)
    python3 bin/compute_pd4.py --perf "$pj" --ppa "$DIR/ppa.json" -o "$DIR/pd4_${n}.json" || true
  done
  echo "[ppa] done -> $DIR/ppa.json , $DIR/pd4_*.json"
else
  echo "[ppa] done -> $RUNS/$RNAME/ (canonical ppa.json untouched)"
fi
