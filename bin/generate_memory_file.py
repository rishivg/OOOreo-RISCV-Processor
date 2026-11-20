#!/usr/bin/env python3
"""Compile a RISC-V program or convert an ELF into simulator memory words."""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile

from get_options import value

ROOT = Path(__file__).resolve().parents[1]


def command(*args, **kwargs):
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def generate(inputs, widths, output=None):
    output = Path(output) if output is not None else ROOT / "sim/bin"
    output.mkdir(parents=True, exist_ok=True)
    widths = list(dict.fromkeys(widths))
    if not widths or any(width <= 0 for width in widths):
        raise ValueError("select positive memory word widths in bytes")
    elf = inputs[0]
    if len(inputs) != 1 or elf.suffix.lower() != ".elf":
        elf = output / (inputs[0].stem + ".elf")
        standalone_assembly = len(inputs) == 1 and inputs[0].suffix.lower() in (".s", ".asm")
        startup = [] if standalone_assembly else [ROOT / "bin/startup.s"]
        command(
            "riscv64-unknown-elf-gcc",
            "-mcmodel=medany",
            "-ffreestanding",
            "-nostartfiles",
            *(["-nostdlib"] if standalone_assembly else []),
            "-static",
            "-static-libgcc",
            "-Wl,--no-relax",
            f"-march={value('arch')}",
            f"-mabi={value('abi')}",
            "-Ofast",
            "-flto",
            "-Wall",
            "-Wextra",
            "-Wno-unused",
            "-T",
            ROOT / "bin/link.ld",
            "-I",
            inputs[0].parent,
            *startup,
            *inputs,
            *([] if standalone_assembly else ["-lm", "-lgcc", "-lc"]),
            "-o",
            elf,
        )
    with (output / (inputs[0].stem + ".dis")).open("w") as stream:
        command("riscv64-unknown-elf-objdump", "-D", "-Mnumeric", elf, stdout=stream)
    headers = command(
        "riscv64-unknown-elf-objdump", "-h", elf, capture_output=True, text=True
    ).stdout
    sections = re.findall(
        r"^\s*\d+\s+(\S+)\s+([0-9a-f]+)\s+[0-9a-f]+\s+([0-9a-f]+)[^\n]*\n([^\n]*)",
        headers,
        re.M,
    )
    with tempfile.TemporaryDirectory() as temporary:
        payload = Path(temporary) / "section.bin"
        loadable = []
        for name, size, address, flags in sections:
            if "LOAD" not in flags:
                continue
            size, address = int(size, 16), int(address, 16)
            for width in widths:
                if address % width or size % width:
                    raise ValueError(f"{name} must be aligned and padded to {width} bytes")
            # Extraction is independent of the requested output word widths.
            command("riscv64-unknown-elf-objcopy", "-O", "binary", "-j", name, elf, payload)
            loadable.append((address, payload.read_bytes()))
        for width in widths:
            path = output / f"memory_{width}.lst"
            with path.open("w") as stream:
                for address, data in loadable:
                    if data:
                        stream.write(f"@{address // width:08x}\n")
                        for offset in range(0, len(data), width):
                            word = int.from_bytes(
                                data[offset : offset + width], "little"
                            )
                            stream.write(f"{word:0{width * 2}x}\n")
            print(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for width in (1, 4, 8, 32):
        parser.add_argument(
            f"-{width}", dest="widths", action="append_const", const=width
        )
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "sim/bin")
    args = parser.parse_args()
    if not args.widths:
        parser.error("select at least one word width: -1, -4, -8, or -32")
    try:
        generate([path.resolve() for path in args.inputs], args.widths, args.output_dir.resolve())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"memory image: {error}\n")
