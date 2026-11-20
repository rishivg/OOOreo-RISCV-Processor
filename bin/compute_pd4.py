#!/usr/bin/python3
"""Combine performance and PPA records: PD4 = power × (cycles / frequency)^4."""

import argparse
import json
import math
from pathlib import Path
import sys


def compute(performance, ppa):
    cycles = performance.get("segment_cycles")
    if cycles is None:
        cycles = performance.get("run_cycles")
    frequency_mhz = ppa.get("fmax_mhz")
    power_w = ppa.get("power_total_w")
    for name, value, zero_allowed in [("cycles", cycles, False),
                                      ("fmax_mhz", frequency_mhz, False),
                                      ("power_total_w", power_w, True)]:
        if (type(value) not in (int, float) or not math.isfinite(value)
                or value < 0 or value == 0 and not zero_allowed):
            bound = "nonnegative" if zero_allowed else "positive"
            raise ValueError(f"{name} must be {bound} and finite")
    try:
        delay_s = cycles / (frequency_mhz * 1e6)
        pd = power_w * delay_s
        pd4 = power_w * delay_s**4
    except (OverflowError, ZeroDivisionError) as error:
        raise ValueError("derived metrics exceed floating-point range") from error
    if (not all(math.isfinite(value) for value in (delay_s, pd, pd4))
            or delay_s <= 0 or power_w > 0 and pd4 == 0):
        raise ValueError("derived metrics exceed floating-point range")
    return {
        "program": performance.get("program"),
        "ipc": performance.get("ipc"),
        "cycles": cycles,
        "fmax_mhz": frequency_mhz,
        "power_total_w": power_w,
        "area_um2": ppa.get("area_um2"),
        "delay_ns": delay_s * 1e9,
        "pd": pd,
        "pd4": pd4,
        "pd4_units": "W * s^4",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--perf", required=True, type=Path)
    parser.add_argument("--ppa", required=True, type=Path)
    parser.add_argument("-o", "--out", type=Path)
    args = parser.parse_args()
    try:
        record = compute(json.loads(args.perf.read_text()), json.loads(args.ppa.read_text()))
    except ValueError as error:
        parser.error(str(error))
    output = json.dumps(record, indent=2)
    if args.out:
        args.out.write_text(output + "\n")
    print(output)
    print(f"\nPD4 = {record['pd4']:.4e} W*s^4   (frequency {record['fmax_mhz']:.1f} MHz, "
          f"{record['cycles']} cyc -> {record['delay_ns'] / 1e3:.2f} us, "
          f"{record['power_total_w'] * 1e3:.1f} mW)", file=sys.stderr)


if __name__ == "__main__":
    main()
