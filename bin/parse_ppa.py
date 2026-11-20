#!/usr/bin/python3
"""Parse post-repair OpenROAD screening results; setup-only Fmax is unqualified."""

import argparse
import json
import math
from pathlib import Path
import re
import sys

NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"


def number(pattern, text):
    match = re.search(pattern, text)
    return float(match[1]) if match else None


def checks_clean(report):
    """OpenSTA can print negative slack without a VIOLATED label."""
    slacks = re.findall(rf"(?m)^.*\s({NUMBER})\s*$", report)
    return "VIOLATED" not in report and all(float(slack) >= 0 for slack in slacks)


def parse(text, period_ns):
    if not math.isfinite(period_ns) or period_ns <= 0:
        raise ValueError("clock period must be positive and finite")
    _, marker, timing = text.partition("timing AFTER repair_design")
    if not marker:
        raise ValueError("no post-repair timing section")
    wns = number(rf"wns max\s+({NUMBER})(?=\s|$)", timing)
    if wns is None:
        raise ValueError("no post-repair WNS")
    achievable_ns = period_ns - wns
    if not math.isfinite(achievable_ns) or achievable_ns <= 0:
        raise ValueError("setup slack implies a nonpositive or nonfinite period")
    frequency_mhz = 1000.0 / achievable_ns
    if not math.isfinite(frequency_mhz):
        raise ValueError("setup estimate exceeds floating-point range")
    power = number(rf"Total\s+{NUMBER}\s+{NUMBER}\s+{NUMBER}\s+({NUMBER})\s+100", text)
    area = re.search(r"Design area\s+(\d+)\s+um\^2\s+(\d+)%", text)

    families = []
    _, marker, critical = text.partition("===== critical paths")
    if marker:
        critical = critical.split("===== wall:", 1)[0]
        paths = re.findall(
            rf"Startpoint: (\S+)[\s\S]*?Endpoint: (\S+)[\s\S]*?({NUMBER})\s+slack", critical)
        seen = set()
        for source, destination, slack in paths:
            family = (source.rsplit("/", 1)[0], destination.rsplit("/", 1)[0])
            if family not in seen:
                seen.add(family)
                families.append({"from": source, "to": destination, "slack_ns": float(slack)})
    walls = {}
    for match in re.finditer(r"===== wall: (\w+) =====([\s\S]*?)(?======|\Z)", text):
        slack = number(rf"({NUMBER})\s+slack", match[2])
        if slack is not None:
            walls[match[1]] = slack

    cts = "running clock_tree_synthesis" in text or "clock tree =====" in text
    clock_note = "ideal clock (no CTS)"
    if cts:
        clock_note = "CTS-built propagated clock"
        if "running post-CTS repair_timing -setup" in text:
            clock_note += " (setup-repaired post-CTS)"
    activity_note = ("default switching activity (NOT SAIF-annotated -- dynamic-power deltas are unreliable)"
                     if power is not None else "power not evaluated")
    record = {
        "clk_period_ns": period_ns,
        "wns_ns": wns,
        "tns_ns": number(rf"tns max\s+({NUMBER})(?=\s|$)", timing),
        "met_timing": wns >= 0,
        "achievable_period_ns": achievable_ns,
        "fmax_mhz": frequency_mhz,
        "power_total_w": power,
        "area_um2": int(area[1]) if area else None,
        "utilization_pct": int(area[2]) if area else None,
        "note": f"post-global-placement, repair_design buffered, {clock_note}; estimated parasitics; "
                f"{activity_note}; oversized fakeram macros.",
        "cts": cts,
        "setup_only_fmax_not_qualified": True,
    }
    for marker, key in [("CLOCK_CHECKS", "clock_checks_clean"), ("ELECTRICAL", "electrical_clean")]:
        start, end = "FINAL_" + marker + "\n", "FINAL_" + marker + "_END"
        if start in text and end in text:
            record[key] = checks_clean(text.split(start, 1)[1].split(end, 1)[0])
            record["met_timing"] &= record[key]
    if families:
        record["worst_families"] = families[:5]
    if walls:
        record["walls"] = walls
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--period-ns", type=float, required=True)
    parser.add_argument("-o", "--out", type=Path)
    args = parser.parse_args()
    try:
        record = parse(args.log.read_text(), args.period_ns)
    except ValueError as error:
        parser.error(str(error))
    output = json.dumps(record, indent=2)
    if args.out:
        args.out.write_text(output + "\n")
    print(output)
    power = record["power_total_w"]
    power_label = f"{power * 1e3:.0f} mW" if power is not None else "not evaluated"
    print(f"\nSetup-only estimate {record['fmax_mhz']:.1f} MHz "
          f"(WNS {record['wns_ns']:+.2f} ns @ {args.period_ns} ns), "
          f"power {power_label}, area {record['area_um2']} um^2", file=sys.stderr)


if __name__ == "__main__":
    main()
