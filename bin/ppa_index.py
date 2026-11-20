#!/usr/bin/python3
"""Append screening runs to JSONL or print a bounded comparison table."""

import argparse
from collections import deque
import json
from pathlib import Path
import sys
import time

DISPLAY_KNOBS = (
    "PNR_DIE_UM", "PNR_DENSITY", "PNR_MACRO_MY", "PNR_SPLIT_ICTAG",
    "PNR_DC_GRID", "PNR_TIMING_DRIVEN", "PNR_CTS",
)


def load_knobs(config_path):
    """Read selected nonempty settings from config.env."""
    if not config_path or not Path(config_path).exists():
        return {}
    knobs = {}
    for line in Path(config_path).read_text().splitlines():
        name, separator, value = line.strip().partition("=")
        if separator and name in DISPLAY_KNOBS and value:
            knobs[name.removeprefix("PNR_").lower()] = value
    return knobs


def cmd_append(args):
    ppa = json.loads(args.ppa.read_text())
    frequency = ppa.get("fmax_mhz")
    record = {
        "ts": time.strftime("%Y-%m-%d %H:%M:%S"),
        "name": args.name,
        "clock_ps": round(ppa["clk_period_ns"] * 1000),
        "knobs": load_knobs(args.config),
        "wns_ns": ppa.get("wns_ns"),
        "tns_ns": ppa.get("tns_ns"),
        "fmax_mhz": round(frequency, 2) if frequency is not None else None,
        "area_um2": ppa.get("area_um2"),
        "power_w": ppa.get("power_total_w"),
    }
    if ppa.get("walls"):
        name, slack = min(ppa["walls"].items(), key=lambda pair: pair[1])
        record["worst_wall"] = f"{name}:{slack:+.2f}"
    args.index.parent.mkdir(parents=True, exist_ok=True)
    with args.index.open("a") as stream:
        stream.write(json.dumps(record) + "\n")


def metric(value, specification):
    return format(value, specification) if value is not None else "-"


def cmd_table(args):
    if not args.index.exists():
        print("(no runs yet)", file=sys.stderr)
        return
    selected = set(args.names.split(",")) if args.names else None
    rows = deque(maxlen=args.n)
    with args.index.open() as stream:
        for line in stream:
            if line.strip():
                record = json.loads(line)
                if selected is None or record["name"] in selected:
                    rows.append(record)
    header = ["when", "name", "clk_ps", "wns", "tns", "setup_MHz", "area_um2", "mW", "knobs / worst wall"]
    table = [header]
    for record in rows:
        knobs = " ".join(f"{name}={value}" for name, value in record.get("knobs", {}).items())
        extra = " ".join(value for value in (knobs, record.get("worst_wall", "")) if value)
        power = record.get("power_w")
        table.append([
            record["ts"][5:16], record["name"], str(record["clock_ps"]),
            metric(record.get("wns_ns"), "+.2f"), metric(record.get("tns_ns"), "+.2f"),
            metric(record.get("fmax_mhz"), ".1f"),
            str(record["area_um2"]) if record.get("area_um2") is not None else "-",
            metric(power * 1e3 if power is not None else None, ".0f"), extra,
        ])
    widths = [max(len(row[column]) for row in table) for column in range(len(header))]
    for index, row in enumerate(table):
        print("  ".join(cell.ljust(width) for cell, width in zip(row, widths)).rstrip())
        if index == 0:
            print("  ".join("-" * width for width in widths))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    append = subcommands.add_parser("append")
    append.add_argument("index", type=Path)
    append.add_argument("--name", required=True)
    append.add_argument("--ppa", required=True, type=Path)
    append.add_argument("--config", type=Path)
    table = subcommands.add_parser("table")
    table.add_argument("index", type=Path)
    table.add_argument("--names")
    table.add_argument("-n", type=int, default=30)
    args = parser.parse_args()
    if args.command == "table" and args.n <= 0:
        parser.error("-n must be positive")
    (cmd_append if args.command == "append" else cmd_table)(args)


if __name__ == "__main__":
    main()
