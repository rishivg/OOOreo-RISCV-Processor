#!/usr/bin/python3
"""Generate reproducible, trap-free RV32IM ALU/multiply/divide programs and ELFs."""

import argparse
from pathlib import Path
import random

from fuzz_program import (
    HALT, IMMEDIATE_OPS, REGISTER_OPS, SHIFT_OPS, compile_program, strip_attributes,
)


def gen_asm(seed, n):
    rng = random.Random(seed)

    def rd():
        return f"x{rng.randint(1, 31)}"

    def rs():
        return f"x{rng.randint(0, 31)}"

    body = []
    # Seed varied operands before exercising dependencies.
    for i in range(1, 32):
        body.append(f"    li x{i}, {rng.randint(-2048, 2047)}")
    for _ in range(n):
        kind = rng.random()
        if kind < 0.55:
            body.append(f"    {rng.choice(REGISTER_OPS)} {rd()}, {rs()}, {rs()}")
        elif kind < 0.85:
            body.append(
                f"    {rng.choice(IMMEDIATE_OPS)} {rd()}, {rs()}, {rng.randint(-2048, 2047)}"
            )
        else:
            body.append(f"    {rng.choice(SHIFT_OPS)} {rd()}, {rs()}, {rng.randint(0, 31)}")
    # Pad with the monitor halt instruction to a full 32-byte memory line.
    insns = body + [HALT]
    while len(insns) % 8 != 0:
        insns.append(HALT)
    return ".section .text\n.globl _start\n_start:\n" + "\n".join(insns) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--n", type=int, default=400)
    parser.add_argument("-o", "--out", required=True)
    parser.add_argument("--asm-only", action="store_true")
    args = parser.parse_args()
    assembly = gen_asm(args.seed, args.n)

    if args.asm_only:
        Path(args.out).write_text(assembly)
        print(args.out)
        return

    compile_program(assembly, args.out)
    strip_attributes(args.out)
    print(f"{args.out}  (seed={args.seed}, n={args.n})")


if __name__ == "__main__":
    main()
