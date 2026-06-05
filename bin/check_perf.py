#!/usr/bin/python3
"""Performance regression gate.

Compares one or more current perf JSONs (from parse_perf.py) against a committed
baseline and FAILS (exit 1) on an IPC regression beyond tolerance or any RVFI
error. Prints a per-program delta table. Use --update to rewrite the baseline
(after an intentional, reviewed change).

Usage:
    check_perf.py --baseline sim/perf_baseline.json perf_coremark.json perf_ooo.json
    check_perf.py --baseline sim/perf_baseline.json --update perf_*.json
    check_perf.py --baseline sim/perf_baseline.json --tol 0.005 perf_*.json
"""
import argparse, json, sys

GREEN, RED, YELLOW, DIM, RST = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"


def load(p):
    with open(p) as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("perf", nargs="+", help="current perf JSON file(s)")
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--tol", type=float, default=0.005,
                    help="max tolerated relative IPC drop (default 0.5%%)")
    ap.add_argument("--update", action="store_true", help="rewrite baseline from current and exit")
    a = ap.parse_args()

    current = {d["program"]: d for d in (load(p) for p in a.perf)}

    if a.update:
        with open(a.baseline, "w") as f:
            json.dump(current, f, indent=2)
            f.write("\n")
        print(f"baseline updated: {a.baseline} ({', '.join(current)})")
        return

    try:
        base = load(a.baseline)
    except FileNotFoundError:
        print(f"check_perf: no baseline at {a.baseline}; run with --update first", file=sys.stderr)
        sys.exit(2)

    print(f"{'program':<16}{'baseline':>10}{'current':>10}{'Δ%':>9}   verdict")
    print("-" * 60)
    failed = False
    for prog, cur in sorted(current.items()):
        ipc = cur["ipc"]
        rvfi = cur.get("rvfi_errors", 0)
        if prog not in base:
            print(f"{prog:<16}{'—':>10}{ipc:>10.4f}{'new':>9}   {YELLOW}NEW (not in baseline){RST}")
            continue
        b = base[prog]["ipc"]
        rel = (ipc - b) / b if b else 0.0
        tag = f"{GREEN}ok{RST}"
        if rvfi:
            tag = f"{RED}FAIL: {rvfi} RVFI errors{RST}"; failed = True
        elif rel < -a.tol:
            tag = f"{RED}FAIL: IPC -{-rel*100:.2f}% (> {a.tol*100:.2f}%){RST}"; failed = True
        elif rel > a.tol:
            tag = f"{GREEN}IMPROVED +{rel*100:.2f}%{RST}"
        col = RED if rel < -a.tol else (GREEN if rel > a.tol else DIM)
        print(f"{prog:<16}{b:>10.4f}{ipc:>10.4f}{col}{rel*100:>+8.2f}%{RST}   {tag}")
        # secondary context (non-gating): flag notable mispredict-rate moves
        cm = cur["branch"].get("cond_rate_pct"); bm = base[prog]["branch"].get("cond_rate_pct")
        if cm is not None and bm is not None and abs(cm - bm) >= 0.5:
            arrow = "↑" if cm > bm else "↓"
            print(f"{DIM}{'':<16}cond-mispredict {bm:.2f}% -> {cm:.2f}% {arrow}{RST}")

    print("-" * 60)
    if failed:
        print(f"{RED}PERF GATE: FAIL{RST}")
        sys.exit(1)
    print(f"{GREEN}PERF GATE: PASS{RST}")


if __name__ == "__main__":
    main()
