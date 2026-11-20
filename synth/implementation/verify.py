#!/usr/bin/env python3
"""Check implementation files and power sums; optionally rerun physical timing."""

import argparse
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parent


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


def unpack(path, destination):
    with destination.open("wb") as stream:
        subprocess.run(["zstd", "-dc", str(path)], stdout=stream, check=True)


def verify_files():
    manifest = json.loads((ROOT / "files.json").read_text())
    for name, expected in manifest.items():
        path = (ROOT / name).resolve()
        if not path.is_relative_to(ROOT) or digest(path) != expected:
            raise ValueError(f"Implementation file does not match its manifest: {name}")


def verify_power(native, result):
    names = set()
    with native.open() as stream:
        for line in stream:
            if line.startswith("C\t"):
                name = line.split("\t")[1]
                if name in names:
                    raise ValueError(f"Duplicate native instance: {name}")
                names.add(name)
    with gzip.open(ROOT / "leaf-power.json.gz", "rt") as stream:
        rows = json.load(stream)
    if (len(rows) != len(names) or len(names) != result["physical_leaf_instances"]
            or {row["name"] for row in rows} != names):
        raise ValueError("Power export does not cover each physical instance exactly once")
    for row in rows:
        if not all(type(row[key]) in (int, float) and math.isfinite(row[key])
                   for key in ("internal", "switching", "leakage", "total")):
            raise ValueError(f"Invalid power value for {row['name']}")

    def binary32(value):
        return struct.unpack("<f", struct.pack("<f", value))[0]

    components = {key: math.fsum(binary32(row[key]) for row in rows)
                  for key in ("internal", "switching", "leakage")}
    for key, value in components.items():
        if abs(value - result["power_components_w"][key]) > 1e-13:
            raise ValueError(f"Power component does not match: {key}")
    total = math.fsum(components.values())
    if abs(total - result["power_w"]) > 1e-13:
        raise ValueError("Power total does not match")
    return total


def verify_timing(tool, layout, output, result):
    executable = shutil.which(tool)
    if executable is None or digest(Path(executable)) != result["openroad_sha256"]:
        raise ValueError("OpenROAD binary does not match the implementation tool hash")
    log = output / "timing.log"
    with log.open("w") as stream:
        subprocess.run([executable, "-exit", str(ROOT / "timing.tcl")],
                       env=dict(os.environ, LAYOUT_DB=str(layout)), stdout=stream,
                       stderr=subprocess.STDOUT, check=True)
    text = log.read_text()
    verify_timing_report(text, result)


def verify_timing_report(text, result):
    for marker, key in (("SETUP", "setup_slack_ns"), ("HOLD", "hold_slack_ns")):
        match = re.search(marker + r"\s+worst slack (?:max|min)\s+([+-]?[0-9.]+)", text)
        if match is None or abs(float(match[1]) - result[key]) > 1e-9:
            raise ValueError(f"Timing does not match: {marker}")
    for marker in ("ELECTRICAL", "CLOCK"):
        section = text.split(marker + "\n", 1)[1].split(marker + "_END", 1)[0]
        values = re.findall(r"(?m)^.*\s([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*$", section)
        if "VIOLATED" in section or any(float(value) < 0 for value in values):
            raise ValueError(f"Physical check failed: {marker}")
    area = re.search(r"Design area\s+(\d+)\s+um\^2", text)
    if area is None or int(area[1]) != result["area_um2"]:
        raise ValueError("Area does not match")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "reports")
    parser.add_argument("--openroad", help="pinned OpenROAD executable for timing replay")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / "verification.json"
    report_path.unlink(missing_ok=True)
    verify_files()
    result = json.loads((ROOT / "result.json").read_text())
    layout, native = output / "layout.odb", output / "native.tsv"
    unpack(ROOT / "layout.odb.zst", layout)
    unpack(ROOT / "native.tsv.zst", native)
    if digest(layout) != result["layout_sha256"] or digest(native) != result["native_graph_sha256"]:
        raise ValueError("Decoded implementation data does not match")
    power = verify_power(native, result)
    if args.openroad:
        verify_timing(args.openroad, layout, output, result)
    report = dict(verified=True,frequency_mhz=result["frequency_mhz"],power_w=power,
                  physical_instances=result["physical_leaf_instances"],timing_replayed=bool(args.openroad))
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
