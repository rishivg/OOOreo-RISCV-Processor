#!/usr/bin/env python3
"""Build the RVFI simulator, reusing only content-verified RTL and binaries."""

import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from build_cache import build_lock, cached_verilator
from generate_rtl import generate
from rtl_sources import defines, sources


def build(directory, generator, jobs, trace, force=False):
    directory = Path(directory).resolve()
    rtl = directory / "rtl"
    generate(rtl, generator, dict(os.environ, RVFI="1"), force=force)
    inputs = [ROOT / "sim/verilator_warn.vlt", ROOT / "pkg/types.sv",
              *sources(rtl, simulation=True),
              *(ROOT / "hvl/common" / name for name in (
                  "mem_itf.sv", "mon_itf.sv", "dram_w_burst_frfcfs_controller.sv",
                  "monitor.sv", "rvfimon.v")),
              ROOT / "hvl/verilator_spinal/top_tb_spinal.sv",
              ROOT / "hvl/verilator/verilator_harness.cpp"]
    command = ["verilator", "--cc", "--exe", "--build", "-j", str(jobs),
               "--top-module", "top_tb", "--Mdir", str(directory),
               "-Wall", "-Wno-fatal", "--timescale", "1ps/1ps", "-O1", "-CFLAGS", "-O1",
               "--x-assign", "fast", "--x-initial", "fast", "--noassert",
               *(["--trace", "--trace-depth", "99"] if trace else []),
               f"+incdir+{ROOT / 'hvl/common'}",
               *defines(rtl), *map(str, inputs)]

    rebuilt = cached_verilator(directory / ".model.json", [*inputs, Path(__file__),
                           ROOT / "bin/rtl_sources.py", rtl / "configuration.json"],
                           directory / "Vtop_tb", command, directory / "compile.log",
                           cwd=ROOT, force=force)
    print(f"Simulator {'built' if rebuilt else 'reused'}: {directory / 'Vtop_tb'}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=ROOT / "sim/verilator/build")
    parser.add_argument("--generator", default="ooo.Generate")
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    parser.add_argument("--trace", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    with build_lock(args.build_dir.resolve() / ".build-flow"):
        build(args.build_dir, args.generator, args.jobs, args.trace, args.force)


if __name__ == "__main__":
    main()
