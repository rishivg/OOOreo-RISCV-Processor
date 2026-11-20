"""Shared instruction sets and bare-metal ELF construction for fuzz generators."""

from pathlib import Path
import subprocess

TEXT_BASE = 0xAAAAA000
HALT = "    slti x0, x0, -256"
REGISTER_OPS = [
    "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
    "mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu",
]
IMMEDIATE_OPS = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SHIFT_OPS = ["slli", "srli", "srai"]


def compile_program(assembly, output, arch="rv32im"):
    source = Path(str(output) + ".s")
    source.write_text(assembly)
    result = subprocess.run([
        "riscv64-unknown-elf-gcc", f"-march={arch}", "-mabi=ilp32",
        "-nostdlib", "-nostartfiles", "-mcmodel=medany", "-Wl,--no-relax",
        f"-Wl,-Ttext={TEXT_BASE:#x}", "-Wl,-e,_start", str(source), "-o", str(output),
    ], capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(result.stderr)


def text_size(elf):
    sections = subprocess.check_output(
        ["riscv64-unknown-elf-readelf", "-S", str(elf)], text=True)
    for line in sections.splitlines():
        fields = line.split()
        if len(fields) > 6 and fields[2] == ".text":
            return int(fields[6], 16)
    raise ValueError(f"No .text section in {elf}")


def strip_attributes(elf):
    subprocess.run([
        "riscv64-unknown-elf-objcopy", "--remove-section", ".riscv.attributes", str(elf),
    ], check=True)
