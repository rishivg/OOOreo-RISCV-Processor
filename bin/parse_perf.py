#!/usr/bin/python3
"""Extract IPC and available optional counters from a simulator log."""

import argparse
import json
from pathlib import Path
import re
import sys

from simulation_log import RVFI_ERROR, monitor_ipc
from get_options import value


def counter(pattern, text):
    match = re.search(pattern, text)
    return int(match[1]) if match else None


def parse(text, program, period_ps):
    if period_ps <= 0:
        raise ValueError("clock period must be positive")
    measurement = monitor_ipc(text, prefer_segment=True)
    measurement_time = measurement.time_ps if measurement else None
    measurement_cycles = round(measurement_time / period_ps) if measurement_time is not None else None
    run_cycles = counter(r"Cycles\s*:\s*(\d+)", text)

    # branch block: three "mispredicts : N (R%)" lines under Total/Cond/Uncond
    mispredicts = re.findall(r"mispredicts\s*:\s*(\d+)\s*\(([0-9.]+)%\)", text)

    def branch_mispredicts(index):
        return (
            {"mispredict": int(mispredicts[index][0]), "rate_pct": float(mispredicts[index][1])}
            if index < len(mispredicts)
            else {}
        )

    return {
        "program": program,
        "ipc": float(measurement.value) if measurement else None,
        "ipc_kind": measurement.kind if measurement else "total",
        "segment_cycles": measurement_cycles,
        "run_cycles": run_cycles,
        "clock_period_ps": period_ps,
        "branch": {
            "total": counter(r"Total branches\s*:\s*(\d+)", text),
            **{f"total_{k}": v for k, v in branch_mispredicts(0).items()},
            "cond_total": counter(r"Conditional branches\s*:\s*(\d+)", text),
            **{f"cond_{k}": v for k, v in branch_mispredicts(1).items()},
            "uncond_total": counter(r"Unconditional \(jal/jalr\)\s*:\s*(\d+)", text),
            **{f"uncond_{k}": v for k, v in branch_mispredicts(2).items()},
        },
        "dispatch_stall": {
            "int": counter(r"INT  RS full\s*:\s*(\d+)", text),
            "intm": counter(r"INTM RS full\s*:\s*(\d+)", text),
            "br": counter(r"BR   RS full\s*:\s*(\d+)", text),
            "mem": counter(r"MEM  RS full\s*:\s*(\d+)", text),
        },
        "lsu": {
            "loads": counter(r"Loads completed\s*:\s*(\d+)", text),
            "disambig_block": counter(r"Load disambig-block cyc\s*:\s*(\d+)", text),
            "viol": counter(r"Spec-load violations\s*:\s*(\d+)", text),
            "viol_flush": counter(r"Spec-load viol flushes\s*:\s*(\d+)", text),
        },
        "muldiv": {
            "mul": counter(r"Multiplies\s*:\s*(\d+)", text),
            "div": counter(r"Divides\s*:\s*(\d+)", text),
        },
        "dcache": {
            "misses": counter(r"DCache misses\s*:\s*(\d+)", text),
            "miss_stall_cyc": counter(r"DCache miss-stall cyc\s*:\s*(\d+)", text),
            "stb_full_cyc": counter(r"Store-buf-full cyc\s*:\s*(\d+)", text),
        },
        "rvfi_errors": len(RVFI_ERROR.findall(text)),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--program", required=True)
    parser.add_argument("--period-ps", type=int, default=value("clock"))
    parser.add_argument("-o", "--out", type=Path)
    args = parser.parse_args()
    try:
        data = parse(args.log.read_text(), args.program, args.period_ps)
    except ValueError as error:
        parser.error(str(error))
    if data["ipc"] is None:
        print(
            "parse_perf: ERROR no IPC found in log (sim did not complete?)",
            file=sys.stderr,
        )
        sys.exit(2)
    output = json.dumps(data, indent=2)
    if args.out:
        args.out.write_text(output + "\n")
    print(output)


if __name__ == "__main__":
    main()
