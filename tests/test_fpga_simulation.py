from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fpga/tests"))
from icarus import run_testbench


@unittest.skipUnless(shutil.which("iverilog") and shutil.which("vvp"), "Icarus required")
class FpgaSimulationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name) / "case with spaces"
        self.directory.mkdir()
        self.source = self.directory / "tb.v"

    def run_source(self, source, **kwargs):
        self.source.write_text(source)
        return run_testbench(self.directory, [self.source], **kwargs)

    def test_each_invocation_executes_the_current_testbench(self):
        for marker in ("FIRST", "SECOND"):
            output = self.run_source(
                f'module tb; initial begin $display("{marker}"); $finish; end endmodule')
            self.assertEqual(output.splitlines()[0], marker)
            self.assertEqual((self.directory / "run.log").read_text(), output)

    def test_compile_failure_clears_the_previous_run_log(self):
        self.run_source("module tb; initial $finish; endmodule")
        with self.assertRaisesRegex(RuntimeError, "compile failed; see .*compile.log"):
            self.run_source("this is not Verilog")
        self.assertFalse((self.directory / "run.log").exists())
        self.assertTrue((self.directory / "compile.log").read_text())

    def test_simulator_failure_retains_diagnostics(self):
        with self.assertRaisesRegex(RuntimeError, "run failed; see .*run.log"):
            self.run_source('module tb; initial $fatal(1, "failure canary"); endmodule')
        self.assertIn("failure canary", (self.directory / "run.log").read_text())

    def test_hanging_testbench_times_out(self):
        with self.assertRaisesRegex(RuntimeError, "run failed; see .*run.log"):
            self.run_source("module tb; initial forever #1; endmodule", timeout=0.1)
        self.assertTrue((self.directory / "run.log").exists())
