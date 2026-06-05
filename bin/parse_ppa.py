#!/usr/bin/python3
"""Parse the OpenROAD P&R log (run_pnr.tcl) into a PPA JSON.

Extracts the POST-repair_design timing (the trustworthy, buffered number), power,
and area. Fmax is derived from the achievable period = clk_period - WNS.

Usage:
    parse_ppa.py synth/opensource/pnr/openroad_pnr.log --period-ns 2.78 -o ppa.json
"""
import argparse, json, re, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--period-ns", type=float, required=True)
    ap.add_argument("-o", "--out")
    a = ap.parse_args()
    text = open(a.log).read()

    # take timing from AFTER the repair_design marker (the buffered, trustworthy run)
    after = text.split("timing AFTER repair_design", 1)
    if len(after) < 2:
        print("parse_ppa: no post-repair timing section", file=sys.stderr); sys.exit(2)
    seg = after[1]
    wns = float(re.search(r"wns max\s+(-?[0-9.]+)", seg).group(1))
    tns_m = re.search(r"tns max\s+(-?[0-9.]+)", seg)
    tns = float(tns_m.group(1)) if tns_m else None

    # achievable period (ns) and Fmax (MHz). WNS<0 => slower than target.
    achievable_ns = a.period_ns - wns
    fmax_mhz = 1000.0 / achievable_ns

    # power: the Total row "... <total> 100.0%"
    pm = re.search(r"Total\s+[\d.e+-]+\s+[\d.e+-]+\s+[\d.e+-]+\s+([\d.e+-]+)\s+100", text)
    power_total_w = float(pm.group(1)) if pm else None

    am = re.search(r"Design area\s+(\d+)\s+um\^2\s+(\d+)%", text)
    area_um2 = int(am.group(1)) if am else None
    util_pct = int(am.group(2)) if am else None

    rec = {
        "clk_period_ns": a.period_ns,
        "wns_ns": wns,
        "tns_ns": tns,
        "met_timing": wns >= 0,
        "achievable_period_ns": achievable_ns,
        "fmax_mhz": fmax_mhz,
        "power_total_w": power_total_w,
        "area_um2": area_um2,
        "utilization_pct": util_pct,
        "note": "post-global-placement, repair_design buffered, ideal clock (no CTS); "
                "estimated parasitics; default switching activity; oversized fakeram macros.",
    }
    out = json.dumps(rec, indent=2)
    if a.out:
        open(a.out, "w").write(out + "\n")
    print(out)
    print(f"\nFmax {fmax_mhz:.1f} MHz (WNS {wns:+.2f} ns @ {a.period_ns} ns), "
          f"power {power_total_w*1e3:.0f} mW, area {area_um2} um^2", file=sys.stderr)


if __name__ == "__main__":
    main()
