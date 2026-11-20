#!/usr/bin/env python3
"""Resolve memory, divider, and simulation bindings from generated configuration."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NATIVE_MEMORIES = {
    "dcache_data_array",
    "dcache_data_bank",
    "dcache_tag_array",
    "icache_data_array",
    "icache_data_bank",
}


def configuration(directory):
    return json.loads((Path(directory) / "configuration.json").read_text())["config"]


def sources(directory, simulation=False):
    cfg = configuration(directory)
    impl = cfg["implementation"]
    files = [Path(directory) / "cpu.v"]
    files += sorted(
        p
        for p in (ROOT / "sram/output").glob("*/*.v")
        if impl["memory"] != "native" or p.stem not in NATIVE_MEMORIES
    )
    if impl["memory"] == "native":
        files.append(ROOT / "fpga/rtl/xilinx_mem_wrappers.v")
    files.append(
        ROOT
        / (
            "hvl/common/dw_mock.sv"
            if impl["divider"] == "mock"
            else "hdl/src/main/verilog/dw_div_seq_iterative.v"
        )
    )
    if simulation and impl["clockGate"] == "bufgctrl":
        files.append(ROOT / "fpga/sim/clock_cells.v")
    return files


def defines(directory):
    cfg = configuration(directory)
    return [
        f"+define+OOO_{key.upper()}"
        for key in ("zicsr", "lowPower", "mmio")
        if cfg[key]
    ]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--simulation", action="store_true")
    parser.add_argument("--defines", action="store_true")
    args = parser.parse_args()
    for item in (
        defines(args.directory)
        if args.defines
        else sources(args.directory, args.simulation)
    ):
        print(item)
