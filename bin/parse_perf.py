#!/usr/bin/python3
"""Parse a Verilator/VCS simulation.log into a structured perf JSON.

Pulls IPC from the segment markers emitted by hvl/common/monitor.sv and the
microarchitectural counters emitted by hvl/common/perf_monitor.sv. Used by
check_perf.py (regression gating) and compute_pd4.py (PD4 figure-of-merit).

Usage:
    parse_perf.py <simulation.log> --program <name> [--period-ps N] [-o out.json]
"""
import argparse, json, re, sys


def _num(pattern, text, cast=int, default=None):
    m = re.search(pattern, text)
    return cast(m.group(1)) if m else default


def parse(text, program, period_ps):
    # ---- IPC (segment window preferred, else whole-run total) ----
    ipc = _num(r"Monitor:\s*Segment IPC:\s*([0-9.]+)", text, float)
    ipc_kind = "segment"
    if ipc is None:
        ipc = _num(r"Monitor:\s*Total IPC:\s*([0-9.]+)", text, float)
        ipc_kind = "total"
    # Segment Time is in simulation ps == segment_cycles * clock_period_ps.
    seg_time_ps = _num(r"Monitor:\s*Segment Time:\s*([0-9]+)", text, int)
    if seg_time_ps is None:
        seg_time_ps = _num(r"Monitor:\s*Total Time:\s*([0-9]+)", text, int)
    seg_cycles = round(seg_time_ps / period_ps) if seg_time_ps else None

    # ---- perf_monitor counters ----
    run_cycles = _num(r"Cycles\s*:\s*(\d+)", text)

    # branch block: three "mispredicts : N (R%)" lines under Total/Cond/Uncond
    mis = re.findall(r"mispredicts\s*:\s*(\d+)\s*\(([0-9.]+)%\)", text)

    def brrate(i):
        return {"mispredict": int(mis[i][0]), "rate_pct": float(mis[i][1])} if i < len(mis) else {}

    rvfi_errors = len(re.findall(r"RVFI Monitor [Ee]rror|Monitor error \d+ in channel", text))

    return {
        "program": program,
        "ipc": ipc,
        "ipc_kind": ipc_kind,
        "segment_cycles": seg_cycles,
        "run_cycles": run_cycles,
        "clock_period_ps": period_ps,
        "branch": {
            "total":           _num(r"Total branches\s*:\s*(\d+)", text),
            **{f"total_{k}": v for k, v in brrate(0).items()},
            "cond_total":      _num(r"Conditional branches\s*:\s*(\d+)", text),
            **{f"cond_{k}": v for k, v in brrate(1).items()},
            "uncond_total":    _num(r"Unconditional \(jal/jalr\)\s*:\s*(\d+)", text),
            **{f"uncond_{k}": v for k, v in brrate(2).items()},
        },
        "dispatch_stall": {
            "int":  _num(r"INT  RS full\s*:\s*(\d+)", text),
            "intm": _num(r"INTM RS full\s*:\s*(\d+)", text),
            "br":   _num(r"BR   RS full\s*:\s*(\d+)", text),
            "mem":  _num(r"MEM  RS full\s*:\s*(\d+)", text),
        },
        "lsu": {
            "loads":          _num(r"Loads completed\s*:\s*(\d+)", text),
            "disambig_block": _num(r"Load disambig-block cyc\s*:\s*(\d+)", text),
            "viol":           _num(r"Spec-load violations\s*:\s*(\d+)", text),
            "viol_flush":     _num(r"Spec-load viol flushes\s*:\s*(\d+)", text),
        },
        "muldiv": {
            "mul": _num(r"Multiplies\s*:\s*(\d+)", text),
            "div": _num(r"Divides\s*:\s*(\d+)", text),
        },
        "dcache": {
            "misses":         _num(r"DCache misses\s*:\s*(\d+)", text),
            "miss_stall_cyc": _num(r"DCache miss-stall cyc\s*:\s*(\d+)", text),
            "stb_full_cyc":   _num(r"Store-buf-full cyc\s*:\s*(\d+)", text),
        },
        "rvfi_errors": rvfi_errors,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--program", required=True)
    ap.add_argument("--period-ps", type=int, default=2780)
    ap.add_argument("-o", "--out")
    a = ap.parse_args()
    with open(a.log) as f:
        data = parse(f.read(), a.program, a.period_ps)
    if data["ipc"] is None:
        print("parse_perf: ERROR no IPC found in log (sim did not complete?)", file=sys.stderr)
        sys.exit(2)
    out = json.dumps(data, indent=2)
    if a.out:
        with open(a.out, "w") as f:
            f.write(out + "\n")
    print(out)


if __name__ == "__main__":
    main()
