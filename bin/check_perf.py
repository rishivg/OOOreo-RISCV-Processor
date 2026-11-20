#!/usr/bin/python3
"""Compare IPC and RVFI errors; --update saves a valid current run as the reference."""

import argparse
import json
import math
from pathlib import Path
import sys

GREEN, RED, YELLOW, DIM, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"


def load(path):
    return json.loads(Path(path).read_text())


def validate(records):
    for program, record in records.items():
        ipc = record.get("ipc")
        if type(ipc) not in (int, float) or not math.isfinite(ipc) or ipc <= 0:
            raise ValueError(f"{program}: IPC must be a positive finite number")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("perf", nargs="+", help="current performance JSON files")
    parser.add_argument("--reference", required=True)
    parser.add_argument("--tol", type=float, default=0.005,
                        help="maximum relative IPC drop (default 0.5%%)")
    parser.add_argument("--update", action="store_true", help="replace the reference")
    args = parser.parse_args()
    if not math.isfinite(args.tol) or args.tol < 0:
        parser.error("--tol must be finite and nonnegative")
    try:
        current = {record["program"]: record for record in map(load, args.perf)}
        validate(current)
        if args.update:
            if any(record.get("rvfi_errors", 0) for record in current.values()):
                raise ValueError("cannot save a reference containing RVFI errors")
            Path(args.reference).write_text(json.dumps(current, indent=2) + "\n")
            print(f"reference updated: {args.reference} ({', '.join(current)})")
            return
        reference = load(args.reference)
        validate(reference)
    except (FileNotFoundError, ValueError) as error:
        parser.error(str(error))

    print(f"{'program':<16}{'reference':>10}{'current':>10}{'Δ%':>9}   verdict")
    print("-" * 60)
    failed = False
    for program, record in sorted(current.items()):
        previous = reference.get(program)
        ipc = record["ipc"]
        relative = (ipc - previous["ipc"]) / previous["ipc"] if previous else None
        errors = record.get("rvfi_errors", 0)
        if errors:
            verdict = f"{RED}FAIL: {errors} RVFI errors{RESET}"
            failed = True
        elif relative is None:
            verdict = f"{YELLOW}NEW (not in reference){RESET}"
        elif relative < -args.tol:
            verdict = f"{RED}FAIL: IPC -{-relative * 100:.2f}% (> {args.tol * 100:.2f}%){RESET}"
            failed = True
        elif relative > args.tol:
            verdict = f"{GREEN}IMPROVED +{relative * 100:.2f}%{RESET}"
        else:
            verdict = f"{GREEN}ok{RESET}"

        old_ipc = f"{previous['ipc']:.4f}" if previous else "—"
        delta = f"{relative * 100:+.2f}%" if relative is not None else "new"
        print(f"{program:<16}{old_ipc:>10}{ipc:>10.4f}{delta:>9}   {verdict}")
        current_rate = record.get("branch", {}).get("cond_rate_pct")
        previous_rate = previous.get("branch", {}).get("cond_rate_pct") if previous else None
        if current_rate is not None and previous_rate is not None and abs(current_rate - previous_rate) >= 0.5:
            print(f"{DIM}{'':<16}cond-mispredict {previous_rate:.2f}% -> {current_rate:.2f}%{RESET}")

    print("-" * 60)
    print(f"{RED if failed else GREEN}PERF GATE: {'FAIL' if failed else 'PASS'}{RESET}")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
