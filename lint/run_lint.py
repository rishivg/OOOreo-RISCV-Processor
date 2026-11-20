#!/usr/bin/env python3
"""Generate RTL and check it with available Verilog frontends."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from rtl_sources import sources
from generate_rtl import generate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "tool",
        nargs="?",
        default="all",
        choices=("all", "verilator", "icarus", "yosys"),
    )
    parser.add_argument("top", nargs="?", default="cpu")
    args = parser.parse_args()
    out = ROOT / "lint/reports"
    rtl = out / "rtl"
    out.mkdir(parents=True, exist_ok=True)
    generate(rtl)
    files = list(map(str, sources(rtl, simulation=True)))
    commands = {
        "verilator": [
            "verilator",
            "--lint-only",
            "-Wall",
            "-Wno-fatal",
            "--top-module",
            args.top,
            str(ROOT / "sim/verilator_warn.vlt"),
            *files,
        ],
        "icarus": ["iverilog", "-g2012", "-t", "null", "-s", args.top, *files],
        "yosys": [
            "yosys",
            "-p",
            "read_verilog -sv "
            + " ".join(json.dumps(p) for p in files)
            + f"; hierarchy -check -top {args.top}",
        ],
    }
    results = {}
    for tool in commands if args.tool == "all" else [args.tool]:
        if not shutil.which(commands[tool][0]):
            results[tool] = "missing"
            continue
        log = out / f"{tool}_{args.top}.log"
        with log.open("w") as stream:
            status = subprocess.run(
                commands[tool], cwd=out, stdout=stream, stderr=subprocess.STDOUT
            ).returncode
        results[tool] = "failed" if status else "passed"
        if status:
            print(log.read_text())
        print(f"{tool}: {results[tool]}")
    (out / "lint_report.json").write_text(
        json.dumps({"top_module": args.top, "results": results}, indent=2) + "\n"
    )
    return int(any(status != "passed" for status in results.values()))


if __name__ == "__main__":
    sys.exit(main())
