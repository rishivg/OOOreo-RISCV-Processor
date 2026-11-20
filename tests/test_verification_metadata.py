import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("qualification", ROOT / "verification/run.py")
qualification = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qualification)


class VerificationMetadataTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        (self.work / "rtl").mkdir()
        (self.work / "model").mkdir()
        (self.work / "rtl/cpu.v").write_text("module cpu; endmodule")
        (self.work / "rtl/configuration.json").write_text(json.dumps({
            "config": {}, "rtl_sha256": qualification.sha(self.work / "rtl/cpu.v")}))
        (self.work / "model/Vverification_top").write_text("simulator")
        qualification._metadata.clear()

    def test_rtl_is_hashed_once_and_compiler_queried_once(self):
        with patch.object(qualification, "sha", wraps=qualification.sha) as digest:
            with patch.object(qualification.subprocess, "check_output", return_value="GCC test\n") as compiler:
                for _ in range(5):
                    qualification.report(self.work, "benchmarks", [{"status": "passed"}])
                self.assertEqual(compiler.call_count, 1)
            rtl_reads = [call for call in digest.call_args_list if call.args[0] == self.work / "rtl/cpu.v"]
            self.assertEqual(len(rtl_reads), 1)

    def test_rewritten_rtl_is_rejected_even_at_same_size(self):
        qualification.metadata(self.work)
        (self.work / "rtl/cpu.v").write_text("module bad; endmodule")
        with self.assertRaisesRegex(RuntimeError, "inputs changed"):
            qualification.metadata(self.work)

    def test_rebuilt_simulator_is_rejected(self):
        qualification.metadata(self.work)
        (self.work / "model/Vverification_top").write_text("different simulator")
        with self.assertRaisesRegex(RuntimeError, "inputs changed"):
            qualification.metadata(self.work)

    def test_mixed_rtl_and_configuration_are_rejected_at_start(self):
        (self.work / "rtl/configuration.json").write_text(json.dumps({"rtl_sha256": "stale"}))
        with self.assertRaisesRegex(ValueError, "hashes differ"):
            qualification.metadata(self.work)
