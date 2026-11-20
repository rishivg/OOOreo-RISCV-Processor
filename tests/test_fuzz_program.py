from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
import gen_memory_fuzz
from fuzz_program import TEXT_BASE, text_size


class FuzzProgramTest(unittest.TestCase):
    def test_divide_filter_does_not_change_later_programs(self):
        expected = gen_memory_fuzz.gen_asm(19, 500)
        filtered = gen_memory_fuzz.gen_asm(19, 500, divide=False)
        self.assertNotRegex(filtered, r"\b(?:divu?|remu?)\b")
        self.assertRegex(expected, r"\b(?:divu?|remu?)\b")
        self.assertEqual(gen_memory_fuzz.gen_asm(19, 500), expected)

    def test_forward_branches_do_not_skip_loop_decrements(self):
        for seed in range(16):
            assembly = gen_memory_fuzz.gen_asm(seed, 500, atomics=True, rvc=True, loops=True)
            instructions = []
            labels = {}
            for line in assembly.splitlines():
                if line.endswith(":"):
                    labels[line[:-1]] = len(instructions)
                elif line.startswith("    "):
                    instructions.append(line.strip())
            self.assertTrue(any(insn.startswith("blt x0, x29, .Lb") for insn in instructions))
            for index, instruction in enumerate(instructions):
                if instruction.startswith("blt x0, x29, .Lb"):
                    self.assertEqual(instructions[index - 1], "addi x29, x29, -1")
                    self.assertNotIn(index, [target for label, target in labels.items()
                                             if label.startswith(".Lf")])

    @unittest.skipUnless(shutil.which("riscv64-unknown-elf-gcc"), "RISC-V toolchain required")
    def test_cli_builds_aligned_compressed_atomic_elf(self):
        with tempfile.TemporaryDirectory() as directory:
            elf = Path(directory) / "stress.elf"
            subprocess.run([
                sys.executable, str(ROOT / "bin/gen_memory_fuzz.py"), "--seed", "19",
                "--n", "256", "--atomics", "--compressed", "--loops", "--no-div",
                "--out", str(elf),
            ], check=True, capture_output=True, text=True)
            data = elf.read_bytes()
            self.assertEqual(data[:6], b"\x7fELF\x01\x01")
            self.assertEqual(struct.unpack_from("<I", data, 24)[0], TEXT_BASE)
            self.assertGreater(text_size(elf), 0)
            self.assertEqual(text_size(elf) % 32, 0)
            self.assertNotRegex(elf.with_suffix(".elf.s").read_text(), r"\b(?:divu?|remu?)\b")
