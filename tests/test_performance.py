from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from parse_perf import parse
from simulation_log import classify, monitor_ipc


class MonitorMeasurementTest(unittest.TestCase):
    def test_cli_defaults_to_the_configured_simulator_clock(self):
        period = json.loads((ROOT / "options.json").read_text())["clock"]
        with tempfile.TemporaryDirectory() as temporary:
            log = Path(temporary) / "simulation.log"
            log.write_text(f"Monitor: Total IPC: 1.25\nMonitor: Total Time: {period * 10}\n")
            output = subprocess.check_output([
                sys.executable, str(ROOT / "bin/parse_perf.py"), str(log), "--program", "fixture",
            ], text=True)
        record = json.loads(output)
        self.assertEqual(record["clock_period_ps"], period)
        self.assertEqual(record["segment_cycles"], 10)

    def test_window_preference_keeps_ipc_and_time_together(self):
        log = ("Monitor: Segment IPC: 1.25\nMonitor: Segment Time: 2000\n"
               "Monitor: Total IPC: 0.75\nMonitor: Total Time: 6000\n")
        self.assertEqual(classify(log), ("PASS", "0.75"))
        record = parse(log, "benchmark", 100)
        self.assertEqual((record["ipc"], record["segment_cycles"]), (1.25, 20))
        self.assertEqual(monitor_ipc(log).time_ps, 6000)

    def test_missing_window_time_never_borrows_the_other_time(self):
        for log in ("Monitor: Segment IPC: 1.25\nMonitor: Total Time: 6000\n",
                    "Monitor: Total IPC: 0.75\nMonitor: Segment Time: 2000\n"):
            self.assertIsNone(parse(log, "benchmark", 100)["segment_cycles"])

    def test_malformed_ipc_does_not_mark_a_simulation_complete(self):
        for value in (".", "1.2.3", "NaN", "inf"):
            self.assertEqual(classify(f"Monitor: Total IPC: {value}\n")[0], "NOFINISH")

    def test_rvfi_error_without_a_timestamp_is_still_a_failure(self):
        log = "Monitor: Total IPC: 1.25\nMonitor error 3 in channel 0\n"
        self.assertEqual(classify(log)[0], "RVFI")
        self.assertEqual(parse(log, "benchmark", 100)["rvfi_errors"], 1)

    def test_invalid_clock_period_is_rejected(self):
        for period in (0, -100):
            with self.assertRaisesRegex(ValueError, "period must be positive"):
                parse("Monitor: Total IPC: 1.25", "benchmark", period)


class PerformanceGateTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.current = self.root / "current.json"
        self.reference = self.root / "reference.json"
        self.reference.write_text(json.dumps({"known": {"ipc": 1.0}}))

    def check(self, record, *options):
        self.current.write_text(json.dumps(record))
        return subprocess.run([
            sys.executable, str(ROOT / "bin/check_perf.py"), str(self.current),
            "--reference", str(self.reference), *options,
        ], capture_output=True, text=True)

    def test_new_program_errors_fail_but_clean_new_programs_pass(self):
        for errors, status in ((1, 1), (0, 0)):
            result = self.check({"program": "new", "ipc": 1.2, "rvfi_errors": errors})
            self.assertEqual(result.returncode, status, result.stderr)
            self.assertIn(f"PERF GATE: {'FAIL' if errors else 'PASS'}", result.stdout)

    def test_ipc_drop_fails_and_improvement_passes_without_optional_counters(self):
        for ipc, status in ((0.9, 1), (1.1, 0)):
            result = self.check({"program": "known", "ipc": ipc})
            self.assertEqual(result.returncode, status, result.stderr)

    def test_invalid_tolerance_and_ipc_cannot_bypass_the_gate(self):
        record = {"program": "known", "ipc": 0.5}
        for tolerance in ("nan", "inf", "-0.1"):
            self.assertEqual(self.check(record, "--tol", tolerance).returncode, 2)
        for ipc in (None, 0, -1, float("nan"), float("inf")):
            self.assertEqual(self.check(dict(record, ipc=ipc)).returncode, 2)

    def test_failed_update_preserves_reference_and_clean_update_succeeds(self):
        before = self.reference.read_bytes()
        record = {"program": "new", "ipc": 1.2, "rvfi_errors": 1}
        self.assertEqual(self.check(record, "--update").returncode, 2)
        self.assertEqual(self.reference.read_bytes(), before)
        record["rvfi_errors"] = 0
        self.assertEqual(self.check(record, "--update").returncode, 0)
        self.assertEqual(json.loads(self.reference.read_text()), {"new": record})
