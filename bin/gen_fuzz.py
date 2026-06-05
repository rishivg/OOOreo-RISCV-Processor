#!/usr/bin/python3
"""Generate a randomized, trap-free RV32IM program and build it into an ELF.

Emits a straight-line stream of register-register / register-immediate ALU and
M-extension ops over x1..x31 (no memory, no control flow, no x0 writes) ending in
a self-loop halt. Every retired instruction is checked against the ISA by the
riscv-formal monitor in simulation -> this is randomized ISA co-simulation that
stresses rename / issue / wakeup / multi-FU execute / in-order commit. Because it
is bare (-nostdlib), it builds with just the compiler (no newlib needed).

Usage:
    gen_fuzz.py --seed 7 --n 400 -o fuzz_07.elf
    gen_fuzz.py --seed 7 --n 400 --asm-only -o fuzz_07.s
"""
import argparse, os, random, subprocess, sys

R3 = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
      "mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"]
RI = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
RSH = ["slli", "srli", "srai"]


def gen_asm(seed, n):
    rng = random.Random(seed)
    def rd():  return f"x{rng.randint(1, 31)}"      # never write x0
    def rs():  return f"x{rng.randint(0, 31)}"
    body = []
    # seed the register file with varied immediates so ops aren't all-zero
    for i in range(1, 32):
        body.append(f"    li x{i}, {rng.randint(-2048, 2047)}")
    for _ in range(n):
        k = rng.random()
        if k < 0.55:
            body.append(f"    {rng.choice(R3)} {rd()}, {rs()}, {rs()}")
        elif k < 0.85:
            body.append(f"    {rng.choice(RI)} {rd()}, {rs()}, {rng.randint(-2048, 2047)}")
        else:
            body.append(f"    {rng.choice(RSH)} {rd()}, {rs()}, {rng.randint(0, 31)}")
    # halt = the core's magic terminate instruction (slti x0,x0,-256 == 0xF0002013),
    # the same convention the repo's directed tests use (see testcode/ooo_test.s).
    # halt = the core's magic terminate instruction (slti x0,x0,-256 == 0xF0002013),
    # the repo's directed-test convention (see testcode/ooo_test.s). Every line in
    # `body` is exactly one 4-byte instruction (li immediates are bounded to a
    # 12-bit signed range, so each is a single addi). Pad with extra halts so the
    # instruction count is a multiple of 8 (= 32-byte .text size), which the
    # memory-file converter requires (section size % 32 == 0). Trailing .balign
    # padding gets dropped by the assembler, so pad explicitly.
    HALT = "    slti x0, x0, -256"
    insns = body + [HALT]
    while len(insns) % 8 != 0:
        insns.append(HALT)
    return ".section .text\n.globl _start\n_start:\n" + "\n".join(insns) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--n", type=int, default=400)
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--asm-only", action="store_true")
    a = ap.parse_args()
    here = os.path.dirname(os.path.abspath(__file__))
    asm = gen_asm(a.seed, a.n)

    if a.asm_only:
        open(a.out, "w").write(asm)
        print(a.out); return

    s_path = a.out + ".s"
    open(s_path, "w").write(asm)
    # Link .text at the core's hardwired reset PC (frontend_top.sv: 0xaaaaa000),
    # not bin/link.ld's 0x1eceb000 -- otherwise the fetch starts in empty memory.
    cmd = ["riscv64-unknown-elf-gcc", "-march=rv32im", "-mabi=ilp32",
           "-nostdlib", "-nostartfiles", "-mcmodel=medany", "-Wl,--no-relax",
           "-Wl,-Ttext=0xaaaaa000", "-Wl,-e,_start", s_path, "-o", a.out]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr, file=sys.stderr); sys.exit(1)
    # Drop the non-loadable .riscv.attributes section (VMA 0, unaligned) that the
    # memory-file converter rejects; only loadable .text needs to remain.
    subprocess.run(["riscv64-unknown-elf-objcopy", "--remove-section", ".riscv.attributes",
                    a.out], check=True)
    print(f"{a.out}  (seed={a.seed}, n={a.n})")


if __name__ == "__main__":
    main()
