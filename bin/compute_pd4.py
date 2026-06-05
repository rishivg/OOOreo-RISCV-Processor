#!/usr/bin/python3
"""Compute the ECE411 PD4 figure-of-merit: Power x Delay^4.

Delay = benchmark execution time = cycles / Fmax (seconds). Lower PD4 is better.
Merges a perf JSON (cycles, from parse_perf.py) with a PPA JSON (Fmax, power,
area, from parse_ppa.py) into one combined record.

Usage:
    compute_pd4.py --perf sim/perf/coremark_im.json --ppa synth/opensource/pnr/ppa.json
"""
import argparse, json, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--perf", required=True)
    ap.add_argument("--ppa", required=True)
    ap.add_argument("-o", "--out")
    a = ap.parse_args()
    perf = json.load(open(a.perf))
    ppa = json.load(open(a.ppa))

    cycles = perf.get("segment_cycles") or perf.get("run_cycles")
    fmax_hz = ppa.get("fmax_mhz")
    power_w = ppa.get("power_total_w")
    if not (cycles and fmax_hz and power_w is not None):
        print("compute_pd4: missing inputs (need cycles, fmax_mhz, power_total_w)", file=sys.stderr)
        sys.exit(2)
    fmax_hz *= 1e6
    delay_s = cycles / fmax_hz
    pd4 = power_w * delay_s ** 4

    rec = {
        "program": perf.get("program"),
        "ipc": perf.get("ipc"),
        "cycles": cycles,
        "fmax_mhz": ppa.get("fmax_mhz"),
        "power_total_w": power_w,
        "area_um2": ppa.get("area_um2"),
        "delay_ns": delay_s * 1e9,
        "pd": power_w * delay_s,           # Power-Delay (PD1) for reference
        "pd4": pd4,                         # the ECE411 metric
        "pd4_units": "W * s^4",
    }
    out = json.dumps(rec, indent=2)
    if a.out:
        open(a.out, "w").write(out + "\n")
    print(out)
    print(f"\nPD4 = {pd4:.4e} W*s^4   (Fmax {ppa['fmax_mhz']:.1f} MHz, "
          f"{cycles} cyc -> {delay_s*1e6:.2f} us, {power_w*1e3:.1f} mW)", file=sys.stderr)


if __name__ == "__main__":
    main()
