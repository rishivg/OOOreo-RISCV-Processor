from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
import generate_memory_file as memory


class MemoryImageTest(unittest.TestCase):
    @unittest.skipUnless(all(shutil.which("riscv64-unknown-elf-" + tool)
                             for tool in ("gcc", "objdump", "objcopy")), "RISC-V tools required")
    def test_standalone_assembly_needs_no_c_runtime_and_starts_at_reset(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "program.s"
            source.write_text(".globl _start\n_start:\naddi x1, x0, 7\nslti x0, x0, -256\n")
            output = Path(temporary) / "images"
            memory.generate([source], [32], output)
            words = (output / "memory_32.lst").read_text().splitlines()
            self.assertEqual(words[0], f"@{0xaaaaa000 // 32:08x}")
            self.assertEqual(int(words[1], 16) & ((1 << 64) - 1), 0xf000201300700093)

    def test_sections_are_extracted_once_for_all_word_widths(self):
        headers = """ 0 .text 00000020 00001000 00001000 00000040 2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
 1 .data 00000020 00002000 00002000 00000060 2**2
                  CONTENTS, ALLOC, LOAD, DATA
 2 .bss 00000040 00003000 00003000 00000080 2**2
                  ALLOC
"""
        copies = []

        def command(*args, **kwargs):
            if args[0].endswith("objcopy"):
                copies.append(args[4])
                Path(args[-1]).write_bytes(bytes(range(32)))
            return type("Result", (), {"stdout": headers})()

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "images"
            with patch.object(memory, "command", side_effect=command):
                memory.generate([Path(temporary) / "program.elf"], [1,4,8,32,4], output)
            self.assertEqual(copies, [".text", ".data"])
            words = (output / "memory_4.lst").read_text().splitlines()
            self.assertEqual(words[:2], ["@00000400", "03020100"])
            self.assertIn("@00000800", words)
            self.assertFalse(any("00000c00" in word for word in words))
            self.assertEqual(len(list(output.glob("memory_*.lst"))), 4)

    def test_invalid_widths_fail_before_external_commands(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(memory, "command") as command:
                for widths in ([], [0], [-1]):
                    with self.assertRaisesRegex(ValueError, "positive"):
                        memory.generate([Path("program.elf")], widths, temporary)
                command.assert_not_called()
