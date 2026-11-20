#!/usr/bin/env python3
"""Check the simulator build once, then run each distinct program with RVFI checks."""

import argparse
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

SIM_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(SIM_ROOT.parent / "bin"))
from simulation_log import classify

GREEN, RED, DIM, RESET = "\033[32m", "\033[31m", "\033[2m", "\033[0m"


def default_build_dir():
    # Make interprets a relative BUILD_DIR from the sim directory.
    return (SIM_ROOT / os.environ.get("BUILD_DIR", "verilator/build")).resolve()


def make_command(target, build_dir):
    return ["make", "-C", str(SIM_ROOT), target, f"BUILD_DIR={build_dir}"]


def run_one(program, timeout, build_dir=None):
    build_dir = default_build_dir() if build_dir is None else Path(build_dir).resolve()
    log_path = build_dir / "run/simulation.log"
    log_path.unlink(missing_ok=True)
    command = [*make_command("run-only", build_dir), f"PROG={Path(program).resolve()}"]
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, errors="replace", start_new_session=True) as process:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate()
            return "TIMEOUT", f"killed after {timeout}s"
        returncode = process.returncode
    if returncode and not log_path.exists():
        lines = (stderr or stdout).strip().splitlines()
        message = next((line for line in lines if re.search(r"error|cannot find|undefined", line, re.I)),
                       lines[-1] if lines else "")
        return "BUILD", message.strip()[:80]
    if not log_path.exists():
        return "NOLOG", "simulation.log missing"
    text = log_path.read_text(errors="replace")
    status, note = classify(text)
    if returncode and status == "PASS":
        status, note = "ERROR", f"simulator exited with status {returncode}"
    return status, note


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("programs", nargs="*", type=Path)
    parser.add_argument("--dir", type=Path)
    parser.add_argument("--skip", nargs="*", default=[])
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--build-dir", type=Path, default=default_build_dir())
    parser.add_argument("--force-build", action="store_true")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be positive and finite")
    programs = args.programs
    if args.dir:
        programs += sorted(args.dir.glob("*.elf")) + sorted(args.dir.glob("*.s"))
    programs = list(dict.fromkeys(path.resolve() for path in programs
                                  if not any(skip in path.name for skip in args.skip)))
    if not programs:
        parser.error("no programs selected")
    for program in programs:
        if not program.is_file():
            parser.error(f"program does not exist: {program}")
    build_dir = args.build_dir.resolve()
    command = make_command("build", build_dir)
    if args.force_build:
        command.append("FORCE_BUILD=1")
    subprocess.run(command, check=True)
    logs = build_dir / "run/logs"
    logs.mkdir(parents=True, exist_ok=True)
    failed = 0
    for index, program in enumerate(programs):
        start = time.monotonic()
        status, note = run_one(program, args.timeout, build_dir)
        elapsed = time.monotonic() - start
        passed = status == "PASS"
        ipc = note if passed else None
        failed += not passed
        color = GREEN if passed else RED
        print(f"{color}{status:<9}{RESET} {program.name:<26} "
              f"{('IPC ' + ipc) if ipc else '':<12} {DIM}{elapsed:5.1f}s{RESET}  "
              f"{'' if passed else RED + note[:70] + RESET}")
        log = build_dir / "run/simulation.log"
        if log.exists():
            shutil.copyfile(log, logs / f"{index:03d}-{program.stem}.log")
    print(f"{len(programs) - failed}/{len(programs)} passed")
    return int(failed != 0)


if __name__ == "__main__":
    sys.exit(main())
