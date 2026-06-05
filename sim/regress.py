#!/usr/bin/python3
"""Multi-program regression runner for the Verilator model.

Runs each program through `make run_verilator_top_tb`, classifies PASS/FAIL from
the RVFI monitor (the riscv-formal ISA reference in hvl/common/monitor.sv checks
every retired instruction), surfaces the FIRST divergence on failure, collects
IPC, prints a summary table, and exits non-zero if anything failed.

Usage:
    regress.py PROG...                      # explicit ELFs/.s files
    regress.py --dir ../testcode            # all *.elf / *.s in a dir
    regress.py --dir ../testcode --skip coremark_imc  # coremark_imc needs C-ext
"""
import argparse, glob, os, re, subprocess, sys, time

GREEN, RED, YEL, DIM, RST = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"
LOG = "verilator/simulation.log"

FAIL_PATS = [
    (re.compile(r"RVFI Monitor [Ee]rror|Monitor error (\d+) in channel (\d+).*?at time (\d+)"), "RVFI"),
    (re.compile(r"TB Error: Timed out"), "TIMEOUT"),
    (re.compile(r"Spurious|Error: |\$fatal|Assertion failed"), "ERROR"),
]


def classify(log):
    """Return (status, note). PASS requires an IPC print and no error markers."""
    for pat, kind in FAIL_PATS:
        m = pat.search(log)
        if m:
            line = log[max(0, m.start() - 0):m.end() + 60].splitlines()[0].strip()
            return kind, line
    ipc = re.search(r"Monitor:\s*(?:Segment|Total) IPC:\s*([0-9.]+)", log)
    if ipc:
        return "PASS", ipc.group(1)
    return "NOFINISH", "no IPC/halt printed (hang or crash)"


def run_one(prog, timeout):
    prog = os.path.abspath(prog)
    env = dict(os.environ)
    try:
        r = subprocess.run(["make", "run_verilator_top_tb", f"PROG={prog}"],
                           capture_output=True, text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", f"killed after {timeout}s", None
    if r.returncode != 0 and not os.path.exists(LOG):
        # build/elaboration failed before the sim ran (e.g. assembler/linker error)
        tail = (r.stderr or r.stdout).strip().splitlines()
        msg = next((l for l in tail if re.search(r"error|cannot find|undefined", l, re.I)), tail[-1] if tail else "")
        return "BUILD", msg.strip()[:80], None
    if not os.path.exists(LOG):
        return "NOLOG", "simulation.log missing", None
    log = open(LOG, errors="replace").read()
    status, note = classify(log)
    ipc = note if status == "PASS" else None
    cyc = re.search(r"Cycles\s*:\s*(\d+)", log)
    return status, note, (ipc, cyc.group(1) if cyc else None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("progs", nargs="*")
    ap.add_argument("--dir")
    ap.add_argument("--skip", nargs="*", default=[])
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()

    progs = list(a.progs)
    if a.dir:
        for ext in ("*.elf", "*.s"):
            progs += sorted(glob.glob(os.path.join(a.dir, ext)))
    progs = [p for p in progs if not any(s in os.path.basename(p) for s in a.skip)]
    if not progs:
        print("regress: no programs", file=sys.stderr); sys.exit(2)

    # ensure model is built once up front
    subprocess.run(["make", "verilator/build/Vtop_tb"], check=True)

    rows, failed = [], 0
    for p in progs:
        name = os.path.basename(p)
        t0 = time.time()
        status, note, extra = run_one(p, a.timeout)
        dt = time.time() - t0
        ipc = extra[0] if extra else None
        ok = status == "PASS"
        failed += not ok
        col = GREEN if ok else RED
        print(f"{col}{status:<9}{RST} {name:<26} {('IPC ' + ipc) if ipc else '':<12} "
              f"{DIM}{dt:5.1f}s{RST}  {'' if ok else RED + note[:70] + RST}")
        rows.append((name, status, ipc))

    print("-" * 70)
    npass = sum(1 for _, s, _ in rows if s == "PASS")
    print(f"{npass}/{len(rows)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
