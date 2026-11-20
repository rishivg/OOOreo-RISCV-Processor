#!/usr/bin/python3
"""Generate RV32IM[A/C] memory, branch, and bounded-loop stress programs."""

import argparse
from pathlib import Path
import random
import sys

from fuzz_program import (
    HALT, IMMEDIATE_OPS, REGISTER_OPS, SHIFT_OPS, TEXT_BASE,
    compile_program, strip_attributes, text_size,
)

BRANCH_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
# RV32A uses x30 for word-aligned addresses within the scratch page.
ATOMIC_OPS = [
    "amoswap.w",
    "amoadd.w",
    "amoand.w",
    "amoor.w",
    "amoxor.w",
    "amomax.w",
    "amomin.w",
    "amomaxu.w",
    "amominu.w",
]
# Offsets must respect each operation's alignment to stay trap-free.
LOAD_OPS = [("lw", 4), ("lh", 2), ("lhu", 2), ("lb", 1), ("lbu", 1)]
STORE_OPS = [("sw", 4), ("sh", 2), ("sb", 1)]

# Keep scratch 1 MiB above reset to avoid self-modifying code; checked after linking.
MEM_BASE = TEXT_BASE + 0x100000
MAX_SCRATCH_OFFSET = 2040  # Fits a signed 12-bit offset within the scratch page.


def gen_asm(seed, n, atomics=False, rvc=False, pad_bytes=0, loops=False, divide=True):
    rng = random.Random(seed)
    register_ops = REGISTER_OPS if divide else [
        op for op in REGISTER_OPS if not op.startswith(("div", "rem"))
    ]

    # Bias RVC registers toward x8..x15 to stress mixed-width fetch and dense dependencies.
    def register(lower, upper):
        if rvc and rng.random() < 0.70:
            return f"x{rng.randint(8, 15)}"
        return f"x{rng.randint(lower, upper)}"

    # Reserve x31 for the memory base and x29 for counted loops when enabled.
    destination_limit = 28 if loops else 29

    def rd():
        return register(1, destination_limit)  # Keep the address and loop registers intact.

    def rs():
        return register(0, 31)

    body = []
    labels_by_instruction = {}
    label_index = 0

    body.append(f"    lui x31, %hi({MEM_BASE})")
    body.append(f"    addi x31, x31, %lo({MEM_BASE})")
    for i in range(1, 31):
        body.append(f"    li x{i}, {rng.randint(-2048, 2047)}")
    # Initialize the scratch line to keep the monitor's loads defined.
    for off in range(0, 64, 4):
        body.append(f"    sw x{rng.randint(1,30)}, {off}(x31)")

    def memory_offset(alignment):
        # Cluster accesses into two cache lines to stress forwarding and disambiguation.
        limit = 64 if rng.random() < 0.75 else MAX_SCRATCH_OFFSET + 1
        return rng.randrange(0, limit, alignment)

    # Only one loop may be open at a time.
    loop_label = None
    loop_remaining = 0

    def close_loop():
        nonlocal loop_label
        body.append("    addi x29, x29, -1")
        branch_index = len(body)  # Position of the backward branch.
        # Forward branches must not skip the decrement by targeting the backward branch.
        if branch_index in labels_by_instruction:
            labels_by_instruction.setdefault(branch_index + 1, []).extend(
                labels_by_instruction.pop(branch_index))
        # x29 is reserved and decreases on every backward edge.
        # Use x29 > 0 so entry without initialization also terminates.
        body.append(f"    blt x0, x29, {loop_label}")
        loop_label = None

    for _ in range(n):
        if loops and loop_label is None and rng.random() < 0.05:
            label_index += 1
            loop_label = f".Lb{label_index}"
            body.append(f"    li x29, {rng.randint(2, 8)}")
            labels_by_instruction.setdefault(len(body), []).append(loop_label)
            loop_remaining = rng.randint(3, 12)
        if loop_label is not None:
            if loop_remaining <= 0:
                close_loop()
            else:
                loop_remaining -= 1
        kind = rng.random()
        if kind < 0.34:
            body.append(f"    {rng.choice(register_ops)} {rd()}, {rs()}, {rs()}")
        elif kind < 0.50:
            body.append(f"    {rng.choice(IMMEDIATE_OPS)} {rd()}, {rs()}, {rng.randint(-2048, 2047)}")
        elif kind < 0.58:
            body.append(f"    {rng.choice(SHIFT_OPS)} {rd()}, {rs()}, {rng.randint(0, 31)}")
        elif kind < 0.74:
            mnemonic, alignment = rng.choice(STORE_OPS)
            body.append(f"    {mnemonic} {rs()}, {memory_offset(alignment)}(x31)")
        elif kind < 0.90:
            mnemonic, alignment = rng.choice(LOAD_OPS)
            body.append(f"    {mnemonic} {rd()}, {memory_offset(alignment)}(x31)")
        elif atomics and kind < 0.95:
            # Atomic accesses alias ordinary memory traffic to exercise LSU ordering and forwarding.
            off = rng.randrange(0, 64, 4)
            body.append(f"    addi x30, x31, {off}")
            if rng.random() < 0.35:
                body.append(f"    lr.w {rd()}, (x30)")
                body.append(f"    sc.w {rd()}, {rs()}, (x30)")
            else:
                body.append(f"    {rng.choice(ATOMIC_OPS)} {rd()}, {rs()}, (x30)")
        else:
            # Forward branches skip at most four generated instructions.
            span = rng.randint(1, 4)
            label_index += 1
            name = f".Lf{label_index}"
            body.append(f"    {rng.choice(BRANCH_OPS)} {rs()}, {rs()}, {name}")
            labels_by_instruction.setdefault(len(body) + span, []).append(name)

    if loop_label is not None:
        close_loop()

    # Forward targets beyond the generated body land in the halt block.
    tail = max(labels_by_instruction, default=0)
    while len(body) <= tail:
        body.append(HALT)
    body.append(HALT)
    # Pad beyond the halt to cover speculative fetches into subsequent cache lines.
    body.extend([HALT] * 64)
    while len(body) % 8 != 0:
        body.append(HALT)

    out = [".section .text", ".globl _start", "_start:"]
    for i, ins in enumerate(body):
        for name in labels_by_instruction.get(i, []):
            out.append(f"{name}:")
        out.append(ins)
    # Pad the linked section to 32 bytes, including mixed RVC instruction widths.
    # The CLI measures linked size and supplies filler past the halt.
    out.extend([HALT] * (pad_bytes // 4))
    if pad_bytes % 4:
        out.append("    c.nop")  # Two-byte residual in compressed mode.
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--n", type=int, default=600)
    parser.add_argument("-o", "--out", required=True)
    parser.add_argument("--asm-only", action="store_true")
    parser.add_argument(
        "--no-div",
        action="store_true",
        help="exclude div/rem (isolates divide-in-flight interactions)",
    )
    parser.add_argument(
        "--atomics",
        action="store_true",
        help="also emit RV32A AMOs and lr/sc pairs (builds -march=rv32ima)",
    )
    parser.add_argument(
        "--compressed",
        action="store_true",
        help="emit mixed 16/32-bit instructions with an x8..x15 register bias; "
        "changes a seed's program relative to uncompressed mode",
    )
    parser.add_argument(
        "--loops",
        action="store_true",
        help="emit bounded backward branches; reserve x29 as the loop counter",
    )
    args = parser.parse_args()
    assembly = gen_asm(args.seed, args.n, args.atomics, args.compressed,
                       loops=args.loops, divide=not args.no_div)
    if args.asm_only:
        Path(args.out).write_text(assembly)
        print(args.out)
        return
    arch = "rv32im" + ("a" if args.atomics else "") + ("c" if args.compressed else "")
    compile_program(assembly, args.out, arch)
    # Measure RVC section size and relink with exact 32-byte alignment filler.
    size = text_size(args.out)
    pad = (-size) % 32
    if pad:
        compile_program(gen_asm(args.seed, args.n, args.atomics, args.compressed, pad, args.loops,
                                divide=not args.no_div), args.out, arch)
        size = text_size(args.out)
        if size % 32:
            print(f"align pass failed: .text={size:#x}", file=sys.stderr)
            sys.exit(1)
    # Reject scratch overlap to prevent self-modifying code.
    end = TEXT_BASE + size
    if end > MEM_BASE:
        print(
            f"FATAL: .text ends {end:#x}, overruns MEM_BASE {MEM_BASE:#x} by "
            f"{end - MEM_BASE} bytes -- lower --n or raise MEM_BASE",
            file=sys.stderr,
        )
        sys.exit(1)
    strip_attributes(args.out)
    print(f"{args.out}  (seed={args.seed}, n={args.n})")


if __name__ == "__main__":
    main()
