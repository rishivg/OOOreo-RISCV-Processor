"""Compile and execute a binding testbench, retaining diagnostics for each stage."""

from pathlib import Path
import subprocess


def run_testbench(directory, sources, *, timeout=90):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    binary = directory / "sim"
    binary.unlink(missing_ok=True)
    run_log = directory / "run.log"
    run_log.unlink(missing_ok=True)
    stages = (
        ("compile", ["iverilog", "-g2012", "-s", "tb", "-o", str(binary),
                     *map(str, sources)], None),
        ("run", ["vvp", str(binary)], timeout),
    )
    for stage, command, limit in stages:
        log = directory / f"{stage}.log"
        with log.open("w") as stream:
            try:
                subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                               check=True, timeout=limit)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
                raise RuntimeError(f"Icarus {stage} failed; see {log}") from error
    return run_log.read_text()
