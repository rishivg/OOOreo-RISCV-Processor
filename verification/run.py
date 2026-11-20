#!/usr/bin/env python3
"""Build pinned verification workloads and run them on the RVFI-enabled MCU core."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import struct
import subprocess
import sys
import threading
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / "bin"))
from rtl_sources import sources
from build_cache import digest as sha
from build_cache import build_lock, cached_verilator
from generate_rtl import generate

ARCH = "rv32imac_zicsr_zifencei"
FLAGS = [f"-march={ARCH}", "-mabi=ilp32", "-O2", "-mcmodel=medany",
         "-msmall-data-limit=0", "-ffreestanding", "-fno-common"]


class VerificationMetadata:
    """Snapshot build metadata once, rejecting changes during a qualification run."""

    def __init__(self, work):
        self.work = work
        self.inputs = [work / "rtl/cpu.v", work / "rtl/configuration.json",
                       work / "model/Vverification_top", HERE / "sources.json",
                       HERE / "sim.cpp", HERE / "top.sv"]
        self.stats = self.input_stats()
        self.fields = {
            "sources": json.loads((HERE / "sources.json").read_text()),
            "rtl_sha256": sha(work / "rtl/cpu.v"),
            "adapter_sha256": {path.name: sha(path) for path in (HERE / "sim.cpp", HERE / "top.sv")},
            "configuration": json.loads((work / "rtl/configuration.json").read_text()),
        }
        if self.fields["configuration"]["rtl_sha256"] != self.fields["rtl_sha256"]:
            raise ValueError("RTL and configuration hashes differ; regenerate the model")
        self.compilers = {}
        self.check()

    def input_stats(self):
        return [(stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns)
                for stat in (path.stat() for path in self.inputs)]

    def check(self):
        if self.input_stats() != self.stats:
            raise RuntimeError("Qualification inputs changed during the run; restart the suite")

    def compiler(self, suite):
        compiler = (str(self.work / "gcc15/riscv/bin/riscv64-unknown-elf-gcc")
                    if suite == "act4" else "riscv64-unknown-elf-gcc")
        if compiler not in self.compilers:
            self.compilers[compiler] = subprocess.check_output(
                [compiler, "--version"], text=True).splitlines()[0]
        return self.compilers[compiler]


_metadata = {}
_metadata_lock = threading.Lock()


def metadata(work):
    work = work.resolve()
    with _metadata_lock:
        if work not in _metadata:
            _metadata[work] = VerificationMetadata(work)
        result = _metadata[work]
    result.check()
    return result


def dv_tests():
    # The lightweight tooling checks do not require the workload-generation stack.
    import yaml
    return yaml.safe_load((HERE / "dv.yaml").read_text())


def image_sha(path):
    """Hash loadable bytes and zero-fill extents, excluding temporary ELF symbols."""
    data = Path(path).read_bytes()
    header = struct.unpack_from("<16sHHIIIIIHHHHHH", data)
    digest = hashlib.sha256(struct.pack("<II", header[4], header[7]))
    for index in range(header[10]):
        segment = struct.unpack_from("<8I", data, header[5] + index * header[9])
        if segment[0] == 1:
            digest.update(struct.pack("<4I", segment[3], segment[4], segment[5], segment[6]))
            digest.update(data[segment[1]:segment[1]+segment[4]])
    return digest.hexdigest()


def command(args, log=None, **kwargs):
    args = list(map(str, args))
    group = kwargs.pop("process_group", False)
    if log:
        with Path(log).open("w") as stream:
            if group:
                timeout = kwargs.pop("timeout", None)
                process = subprocess.Popen(args, stdout=stream, stderr=subprocess.STDOUT,
                                           start_new_session=True, **kwargs)
                try:
                    code = process.wait(timeout=timeout)
                    if code:
                        raise subprocess.CalledProcessError(code, args)
                finally:
                    # Upstream PyFlow may leave solver workers after its timeout.
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    process.wait()
            else:
                subprocess.run(args, stdout=stream, stderr=subprocess.STDOUT, check=True, **kwargs)
    else:
        subprocess.run(args, check=True, **kwargs)


def fetch(work):
    upstream = work / "upstream"
    upstream.mkdir(parents=True, exist_ok=True)
    for name, spec in json.loads((HERE / "sources.json").read_text()).items():
        dest = upstream / name
        if not dest.exists():
            command(["git", "init", dest])
            command(["git", "-C", dest, "remote", "add", "origin", spec["url"]])
        current = subprocess.run(["git", "-C", dest, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        if current != spec["commit"]:
            command(["git", "-C", dest, "fetch", "--depth", "1", "origin", spec["commit"]])
            command(["git", "-C", dest, "checkout", "--detach", spec["commit"]])
        print(name, spec["commit"], flush=True)


def model(work, jobs):
    with build_lock(work / "model/.build-flow"):
        build_model(work, jobs)


def build_model(work, jobs):
    _metadata.pop(work.resolve(), None)
    env = dict(os.environ, CPU_PROFILE="mcu", CPU_TARGET="asic", RVFI="1", RTL_OUT=str(work / "rtl"))
    overrides = re.findall(r'(?:env[IB]\(|env\.get(?:OrElse)?\()"([A-Z0-9_]+)"',
                           (ROOT / "hdl/src/main/scala/ooo/Config.scala").read_text())
    for name in overrides:
        if name not in ("CPU_PROFILE", "CPU_TARGET", "RVFI"):
            env.pop(name, None)
    known = ("C_EXT", "A_EXT", "ZICSR", "LOW_POWER", "MMIO")
    env.update(dict.fromkeys(known, "1"))
    generate(work / "rtl", env=env, log=work / "rtl.log")
    inputs = [ROOT / "sim/verilator_warn.vlt", ROOT / "pkg/types.sv",
              *sources(work / "rtl", simulation=True), HERE / "top.sv", HERE / "sim.cpp"]
    build_command = list(map(str, ["verilator", "--cc", "--exe", "--build", "-j", jobs,
        "--top-module", "verification_top", "--Mdir", work / "model", "-Wno-fatal",
        "-O2", "-CFLAGS", "-O2", *inputs]))

    rebuilt = cached_verilator(work / "model/.build.json", [*inputs, Path(__file__),
        ROOT / "bin/rtl_sources.py", work / "rtl/configuration.json"],
        work / "model/Vverification_top", build_command, work / "model-build.log", cwd=ROOT)
    print(f"Qualification simulator {'built' if rebuilt else 'reused'}", flush=True)


def compile_elf(work, name, inputs, extra=(), startup=True):
    out = work / "elfs" / (name + ".elf")
    out.parent.mkdir(parents=True, exist_ok=True)
    libc = work / "newlib/riscv64-unknown-elf"
    command(["riscv64-unknown-elf-gcc", *FLAGS, "-nostdlib", "-nostartfiles", "-Wl,--no-relax",
             "-Wl,-T," + str(HERE / "link.ld"), "-I" + str(libc / "include"), *extra,
             *([HERE / "start.S", HERE / "runtime.c"] if startup else []), *inputs,
             "-L" + str(libc / "lib"), "-lm", "-lc", "-lgcc", "-o", out],
            out.with_suffix(".build.log"))
    return out


def run_elf(work, elf, limit, latency, trace=False):
    logs = work / "logs"
    logs.mkdir(exist_ok=True)
    stem = elf.stem + f"-lat{latency}"
    log = logs / (stem + ".log")
    start = time.monotonic()
    record = {"name": elf.stem, "elf_sha256": sha(elf), "load_image_sha256": image_sha(elf), "rtl_sha256": metadata(work).fields["rtl_sha256"],
              "memory_latency": latency, "cycle_limit": limit, "log": str(log), "status": "failed"}
    try:
        command([work / "model/Vverification_top", elf, limit,
                 logs / (stem + ".csv") if trace else "-", latency], log, timeout=600)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
        record["error"] = str(error)
    match = re.search(r"^RESULT (\{.*\})$", log.read_text(), re.M)
    if match:
        record.update(json.loads(match.group(1)))
        if record["exit_code"] == 0 and "error" not in record:
            record["status"] = "passed"
    elif "error" not in record:
        record["error"] = "simulator did not report program completion"
    record["seconds"] = round(time.monotonic() - start, 3)
    print(record["status"].upper(), elf.stem, record.get("cycles", record.get("error")), flush=True)
    return record


def report(work, suite, rows):
    out = work / "reports"
    out.mkdir(exist_ok=True)
    context = metadata(work)
    data = {"suite": suite, "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            **context.fields,
            "compiler_flags": "ACT4 generated makefiles; see act-build.log" if suite == "act4" else FLAGS,
            "compiler": context.compiler(suite), "results": rows}
    if suite == "random":
        data["generation"] = json.loads((work / "dv-current.json").read_text())
    (out / (suite + ".json")).write_text(json.dumps(data, indent=2) + "\n")


def benchmarks(work, args):
    rows = []
    emb = work / "upstream/embench"
    for directory in sorted((emb / "src").iterdir()):
        if not directory.is_dir() or (args.only and directory.name not in args.only):
            continue
        name = "embench-" + directory.name
        try:
            elf = compile_elf(work, name, [*sorted(directory.glob("*.c")), emb / "support/main.c", emb / "support/beebsc.c"],
                              ["-I" + str(emb / "support"), "-I" + str(directory), "-DWARMUP_HEAT=1", "-DGLOBAL_SCALE_FACTOR=1"])
            record = run_elf(work, elf, args.limit, args.latency)
            if record["status"] == "passed" and not record.get("measured_cycles"):
                record.update(status="failed", error="missing benchmark timing markers")
        except subprocess.CalledProcessError as error:
            record = {"name": name, "status": "build-failed", "error": str(error)}
            print("BUILD FAILED", name, flush=True)
        rows.append(record)
        report(work, "benchmarks", rows)
    if not args.only or "coremark" in args.only:
        core = work / "upstream/coremark"
        for mode in ("performance", "validation"):
            elf = compile_elf(work, "coremark-" + mode,
                              [core / ("core_" + name + ".c") for name in ("list_join", "main", "matrix", "state", "util")]
                              + [HERE / "coremark/core_portme.c"],
                              ["-I" + str(HERE / "coremark"), "-I" + str(core), "-DITERATIONS=0", "-DTOTAL_DATA_SIZE=2000",
                               "-DCPU_HZ=1000000", "-D" + mode.upper() + "_RUN=1"])
            record = run_elf(work, elf, args.limit, args.latency)
            text = Path(record["log"]).read_text()
            if record["status"] == "passed" and "Correct operation validated" not in text:
                record.update(status="failed", error="CoreMark did not validate the run")
            record["simulated_clock_hz"] = 1000000
            for label, key in (("Total ticks", "benchmark_cycles"), ("Iterations", "iterations"),
                               ("Total time (secs)", "simulated_seconds")):
                match = re.search(re.escape(label) + r"\s*:\s*(\d+)", text)
                if match:
                    record[key] = int(match.group(1))
            if record.get("benchmark_cycles"):
                record["iterations_per_mhz"] = record["iterations"] * 1e6 / record["benchmark_cycles"]
            record["measurement_scope"] = "RTL simulation; no physical frequency or power measurement"
            rows.append(record)
            report(work, "benchmarks", rows)
    return all(r["status"] == "passed" for r in rows) and bool(rows)


def mcu(work, args):
    elf = compile_elf(work, "mcu-directed", [HERE / "mcu.c"])
    rows = [run_elf(work, elf, args.limit, latency) for latency in (8, 24)]
    for row in rows:
        if row["status"] == "passed" and not row["sleep_cycles"]:
            row.update(status="failed", error="WFI never gated the core clock")
    speculative = compile_elf(work, "speculation", [HERE / "speculation.S"], startup=False)
    rows.extend(run_elf(work, speculative, args.limit, latency, trace=True) for latency in (8, 24))
    report(work, "mcu", rows)
    return all(row["status"] == "passed" for row in rows)


def sail_retirements(path):
    rows = []
    for line in path.read_text().splitlines():
        match = re.match(r"\[\d+\] \[M\]: 0x([0-9A-F]+) \(0x([0-9A-F]+)\)", line)
        if match:
            rows.append([int(match[1], 16), int(match[2], 16), 0, 0])
        match = re.match(r"x(\d+) <- 0x([0-9A-F]+)", line)
        if match and rows:
            rows[-1][2:] = [int(match[1]), int(match[2], 16)]
        # A faulting instruction does not retire. The ensuing handler instructions
        # remain in the comparison, including reads of mcause/mepc/mtval.
        if line.startswith("trapping from "):
            if rows:
                rows.pop()
    return rows


def compare_sail(work, args, elf, record):
    if record["status"] == "passed":
        trace = work / "logs" / (elf.stem + "-sail.trace")
        try:
            command(["sail_riscv_sim", "--config", HERE / "act4/sail.json", "--trace-instr", "--trace-gpr",
                     "--trace-exception", "--trace-output", trace, "--inst-limit", "1000000", elf],
                    trace.with_suffix(".log"), timeout=120)
            if "SUCCESS" not in trace.with_suffix(".log").read_text():
                raise ValueError("Sail did not report successful HTIF completion")
            expected = sail_retirements(trace)
            actual = [[int(x, 16) for x in line.split(",")[:4]] for line in
                      (work / "logs" / (elf.stem + f"-lat{args.latency}.csv")).read_text().splitlines()]
            mismatch = next((i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]), None)
            if not actual or len(expected) < len(actual) or mismatch is not None:
                raise ValueError(f"Sail retirement mismatch at {mismatch}; RTL={len(actual)}, Sail={len(expected)}")
            record["compared_retirements"] = len(actual)
            record["reference"] = "Sail 0.16, retired PC/instruction/register writes through HTIF completion"
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
            record.update(status="failed", error=str(error))
            print("REFERENCE FAILED", elf.stem, error, flush=True)


def dv_source(work):
    patch = HERE / "riscv-dv.patch"
    revision = json.loads((HERE / "sources.json").read_text())["riscv-dv"]["commit"]
    marker = {"commit": revision, "patch_sha256": sha(patch)}
    destination = work / ("dv-tool-" + marker["patch_sha256"][:12])
    manifest = destination / ".qualification.json"
    if not manifest.exists():
        if destination.exists():
            raise ValueError(f"incomplete private generator copy: {destination}")
        original = work / "upstream/riscv-dv"
        head = subprocess.check_output(["git", "-C", original, "rev-parse", "HEAD"], text=True).strip()
        if head != revision or subprocess.run(["git", "-C", original, "diff", "--quiet", "HEAD"]).returncode:
            raise ValueError("RISCV-DV checkout must match the pinned, unmodified revision")
        shutil.copytree(original, destination,
                        ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))
        for relative in re.findall(r"^\+\+\+ b/(.+)$", patch.read_text(), re.M):
            file = destination / relative
            file.write_text(file.read_text())  # Normalize upstream CRLF before applying the pinned patch.
        command(["patch", "--batch", "-p1", "-i", patch], cwd=destination)
        manifest.write_text(json.dumps(marker, indent=2) + "\n")
    if json.loads(manifest.read_text()) != marker:
        raise ValueError("private generator provenance mismatch")
    return destination


def random_tests(work, args):
    upstream = dv_source(work)
    env = dict(os.environ, PYTHONPATH=os.pathsep.join((str(upstream / "pygen"), str(upstream))))
    output = work / "dv-runs" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    output.mkdir(parents=True)
    generation = {"directory": str(output), "source": str(upstream), "start_seed": 1,
                  "patch_sha256": sha(HERE / "riscv-dv.patch"), "status": "running"}
    (work / "dv-current.json").write_text(json.dumps(generation, indent=2) + "\n")
    try:
        command([sys.executable, upstream / "run.py", "--target", "rv32imc", "--testlist", HERE / "dv.yaml",
             "--test", "all", "--simulator", "pyflow", "--steps", "gen", "--start_seed", "1",
             "--gen_timeout", "60", "-o", output], output / "generation.log", cwd=upstream, env=env, timeout=300, process_group=True)
        generation["status"] = "passed"
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        generation.update(status="failed", error=str(error))
        print("RISCV-DV generation incomplete; recording failures alongside valid programs", flush=True)
    (work / "dv-current.json").write_text(json.dumps(generation, indent=2) + "\n")
    return random_run(work, args)


def random_run(work, args):
    rows = []
    generation = json.loads((work / "dv-current.json").read_text())
    directory = Path(generation["directory"])
    programs = sorted((directory / "asm_test").glob("*.S"))
    tests = dv_tests()
    expected_programs = []
    for test in tests:
        generation_log = directory / ("sim_" + test["test"] + "_0.log")
        generator_failed = not generation_log.exists() or "CRITICAL" in generation_log.read_text()
        for index in range(test["iterations"]):
            program = directory / "asm_test" / f"{test['test']}_{index}.S"
            if generator_failed or program not in programs:
                rows.append({"name": program.stem, "status": "generator-failed",
                             "error": "missing output or upstream PyFlow CRITICAL error; not an RTL failure",
                             "log": str(generation_log)})
            else:
                expected_programs.append(program)
    report(work, "random", rows)
    for program in expected_programs:
        try:
            elf = compile_elf(work, program.stem, [program],
                              ["-Wa,-I," + str(work / "upstream/riscv-dv/user_extension")], startup=False)
            record = run_elf(work, elf, args.limit, args.latency, trace=True)
        except subprocess.CalledProcessError as error:
            rows.append({"name": program.stem, "status": "build-failed", "error": str(error),
                         "log": str(work / "elfs" / (program.stem + ".build.log")),
                         "source_sha256": sha(program)})
            report(work, "random", rows)
            continue
        compare_sail(work, args, elf, record)
        record["source_sha256"] = sha(program)
        record["seed"] = int(re.search(r"RISCV_DV_SEED=(\d+)", program.read_text())[1])
        rows.append(record)
        report(work, "random", rows)
    stress_ok = stress(work, args)
    return all(row["status"] == "passed" for row in rows) and stress_ok and generation["status"] == "passed"


def stress(work, args):
    from gen_memory_fuzz import gen_asm
    rows = []
    directory = work / "stress"
    directory.mkdir(exist_ok=True)
    for seed in range(1, 17):
        program = directory / f"stress-{seed}.S"
        text = gen_asm(seed, 2000, atomics=True, rvc=True, loops=True)
        text = text.replace("slti x0, x0, -256", "j completed")
        text += ("completed:\nla t0,tohost\nli t1,1\nsw t1,0(t0)\nsw zero,4(t0)\n1: j 1b\n"
                 ".section .tohost,\"aw\"\n.balign 8\n.globl tohost\ntohost: .dword 0\n"
                 ".globl fromhost\nfromhost: .dword 0\n")
        program.write_text(text)
        elf = compile_elf(work, program.stem, [program], startup=False)
        record = run_elf(work, elf, args.limit, args.latency, trace=True)
        compare_sail(work, args, elf, record)
        record.update(seed=seed, generator="bin/gen_memory_fuzz.py", source_sha256=sha(program),
                      coverage="mixed-width arithmetic, branches, bounded loops, overlapping loads/stores, AMOs")
        rows.append(record)
        report(work, "stress", rows)
    return all(row["status"] == "passed" for row in rows)


def check_harness(work, args):
    directory = work / "canaries"
    directory.mkdir(exist_ok=True)
    rows = []
    for name, body in (("nonzero-exit", "return 7;"), ("timeout", 'for (;;) __asm__ volatile("nop");')):
        program = directory / (name + ".c")
        program.write_text("int main(void) { " + body + " }\n")
        elf = compile_elf(work, name, [program])
        row = run_elf(work, elf, 10000, args.latency)
        if row["status"] != "failed" or (name == "nonzero-exit" and row.get("exit_code") != 7):
            raise ValueError(f"harness accepted negative control {name}")
        row["expected_failure"] = True
        rows.append(row)
    elf = compile_elf(work, "mip-write", [HERE / "mip-write.c"])
    mip = run_elf(work, elf, 10000, args.latency, trace=True)
    rows.append(mip)
    if mip["status"] != "passed":
        report(work, "diagnostics", rows)
        raise ValueError("mip write regression failed")
    program = directory / "trace-mismatch.c"
    program.write_text("int main(void) { return 0; }\n")
    elf = compile_elf(work, program.stem, [program])
    row = run_elf(work, elf, 10000, args.latency, trace=True)
    compare_sail(work, args, elf, row)
    if row["status"] != "passed":
        raise ValueError("positive reference control failed")
    trace = work / "logs" / (elf.stem + f"-lat{args.latency}.csv")
    original = trace.read_text()
    fields = original.splitlines()[0].split(",")
    fields[0] = f"{int(fields[0], 16)^4:x}"
    try:
        trace.write_text(",".join(fields) + "\n" + "\n".join(original.splitlines()[1:]) + "\n")
        compare_sail(work, args, elf, row)
    finally:
        trace.write_text(original)
    if row["status"] != "failed" or "mismatch at 0" not in row.get("error", ""):
        raise ValueError("reference comparator accepted a corrupted PC")
    row["expected_failure"] = True
    rows.append(row)
    report(work, "diagnostics", rows)
    return True


def act_build(work, args):
    env = dict(os.environ, PATH=str(work / "gcc15/riscv/bin") + os.pathsep + os.environ["PATH"])
    upstream = work / "upstream/act4"
    command(["act", HERE / "act4/test_config.yaml", "--test-dir", upstream / "tests",
             "--coverpoint-dir", upstream / "coverpoints", "--workdir", work / "act", "--jobs", args.jobs,
             "--fast", "--keep-going"], work / "act-build.log", env=env)


def act_run(work, args):
    programs = sorted((work / "act/oooreo-rv32imac/elfs").rglob("*.elf"))
    if not programs:
        raise ValueError("no final ACT4 self-checking ELFs; run act-build first")
    rows = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        pending = {pool.submit(run_elf, work, elf, args.limit, args.latency, True): elf for elf in programs}
        for future in as_completed(pending):
            row = future.result()
            trace = work / "logs" / (pending[future].stem + f"-lat{args.latency}.csv")
            if row["status"] != "passed" and trace.exists():
                retired = trace.read_text().splitlines()
                row["observed_retirements"] = len(retired)
                row["last_retirement"] = retired[-1] if retired else None
            if row["status"] == "passed" and "RVCP-SUMMARY: TEST PASSED" not in Path(row["log"]).read_text():
                row.update(status="failed", error="missing ACT4 self-checking pass summary")
            rows.append(row)
            report(work, "act4", sorted(rows, key=lambda r: r["name"]))
    print(f"ACT4: {sum(row['status']=='passed' for row in rows)}/{len(rows)} passed", flush=True)
    return all(row["status"] == "passed" for row in rows)


def export_results(work, args):
    config = json.loads((work / "rtl/configuration.json").read_text())
    retained = ("name", "status", "elf_sha256", "load_image_sha256", "source_sha256", "seed",
                "cycles", "retired", "sleep_cycles", "measured_cycles", "measured_retired",
                "memory_latency", "cycle_limit", "exit_code", "benchmark_cycles", "iterations",
                "simulated_seconds", "iterations_per_mhz", "compared_retirements", "expected_failure", "error")
    suites = {}
    reports = {}
    expected = {"benchmarks": 2 + sum(p.is_dir() for p in (work / "upstream/embench/src").iterdir()),
                "act4": len(list((work / "act/oooreo-rv32imac/elfs").rglob("*.elf"))),
                "random": sum(t["iterations"] for t in dv_tests()),
                "stress": 16, "mcu": 4, "diagnostics": 4}
    for name in ("benchmarks", "act4", "random", "stress", "mcu", "diagnostics"):
        data = json.loads((work / "reports" / (name + ".json")).read_text())
        if data["rtl_sha256"] != config["rtl_sha256"]:
            raise ValueError(f"{name} belongs to a different RTL build")
        if len(data["results"]) != expected[name]:
            raise ValueError(f"{name} is incomplete: expected {expected[name]} results")
        reports[name] = data
        outcomes = {}
        rows = []
        for record in data["results"]:
            row = {key: record[key] for key in retained if key in record}
            if row["status"] == "failed" and row.get("expected_failure"):
                row["status"] = "expected-failure"
            if "log" in record:
                row["log"] = str(Path(record["log"]).relative_to(work))
            outcomes[row["status"]] = outcomes.get(row["status"], 0) + 1
            rows.append(row)
        suites[name] = {"outcomes": outcomes, "adapter_sha256": data["adapter_sha256"], "results": rows}
    source_files = (ROOT / "hdl/src/main/scala/ooo").glob("**/*.scala")
    result = {"date": datetime.datetime.now(datetime.timezone.utc).date().isoformat(),
              "repository_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "rtl_source_sha256": {str(p.relative_to(ROOT)): sha(p) for p in sorted(source_files)},
              "configuration": config, "sources": json.loads((HERE / "sources.json").read_text()),
              "release_artifacts": json.loads((HERE / "tools.json").read_text()),
              "benchmark_compiler": reports["benchmarks"]["compiler"],
              "act_compiler": reports["act4"]["compiler"],
              "bare_metal_compile_flags": FLAGS,
              "reference": "Sail 0.16; retired PC/instruction/destination register writes through HTIF completion",
              "compared_retirements": sum(r.get("compared_retirements", 0)
                  for name in ("random", "stress") for r in reports[name]["results"]),
              "generator": reports["random"]["generation"],
              "work_directory": str(work), "suites": suites,
              "limitations": ["ACT4 results apply only to the configured tests; no coverage closure or third-party certification",
                              "CoreMark is cycle-normalized RTL simulation; physical MHz and power were not measured",
                              "Differential comparison does not directly compare CSR side effects or memory stores",
                              "No full-core formal proof or silicon validation"]}
    modules = work / "reports/modules.json"
    if modules.exists():
        module_results = json.loads(modules.read_text())
        if module_results["rtl_sha256"] == config["rtl_sha256"]:
            result["modules"] = module_results
    (HERE / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Saved", HERE / "results.json", flush=True)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step", choices=("fetch", "model", "benchmarks", "mcu", "random", "random-run", "stress", "check-harness", "act-build", "act-run", "export", "all"))
    parser.add_argument("--work", type=Path, default=HERE / "work")
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    parser.add_argument("--limit", type=int, default=50000000)
    parser.add_argument("--latency", type=int, default=8)
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    if args.jobs < 1 or args.limit < 1 or args.latency < 1:
        parser.error("--jobs, --limit and --latency must be positive")
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    if args.step == "fetch":
        fetch(work)
    elif args.step == "model":
        model(work, args.jobs)
    else:
        steps = {"benchmarks": benchmarks, "mcu": mcu, "random": random_tests, "random-run": random_run,
                 "act-build": act_build, "act-run": act_run, "stress": stress, "check-harness": check_harness, "export": export_results}
        if args.step == "all":
            fetch(work)
            model(work, args.jobs)
            act_build(work, args)
            results = [step(work, args) for step in (benchmarks, act_run, random_tests, mcu, check_harness)]
            export_results(work, args)
            return 0 if all(results) else 1
        result = steps[args.step](work, args)
        if result is False:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
