import importlib.util
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("regress", ROOT / "sim/regress.py")
regress = importlib.util.module_from_spec(spec)
spec.loader.exec_module(regress)


class RegressionRunnerTest(unittest.TestCase):
    def test_completion_never_overrides_a_failure_marker(self):
        for marker, expected in (("RVFI Monitor Error", "RVFI"),
                                 ("TB Error: Timed out", "TIMEOUT"),
                                 ("Assertion failed", "ERROR")):
            status, _ = regress.classify("Monitor: Total IPC: 1.2\n" + marker)
            self.assertEqual(status, expected)
        self.assertEqual(regress.classify("Monitor: Total IPC: 1.2")[0], "PASS")
        self.assertEqual(regress.classify("simulator stopped")[0], "NOFINISH")

    def test_total_ipc_takes_precedence_over_segment_ipc(self):
        self.assertEqual(regress.classify("Monitor: Segment IPC: 0.6\nMonitor: Total IPC: 1.2"),
                         ("PASS", "1.2"))

    def test_duplicate_paths_build_and_run_once_from_any_working_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            program = Path(temporary) / "test.elf"
            program.touch()
            directory = Path(temporary) / "custom/build"
            arguments = ["regress.py", str(program), str(program), "--build-dir", str(directory)]
            with patch.object(sys, "argv", arguments), patch.object(regress.subprocess, "run") as build:
                with patch.object(regress, "run_one", return_value=("PASS", "1")) as run:
                    self.assertEqual(regress.main(), 0)
                    self.assertEqual(run.call_count, 1)
                    self.assertEqual(build.call_count, 1)
                    self.assertIn(str(regress.SIM_ROOT), build.call_args.args[0])
                    self.assertIn(f"BUILD_DIR={directory}", build.call_args.args[0])

    def test_timeout_kills_the_process_group(self):
        with tempfile.TemporaryDirectory() as temporary:
            process = MagicMock()
            process.pid = 12345
            process.communicate.side_effect = [subprocess.TimeoutExpired("make", 1), ("", "")]
            manager = MagicMock()
            manager.__enter__.return_value = process
            with patch.object(regress.subprocess, "Popen", return_value=manager):
                with patch.object(regress.os, "killpg") as kill:
                    status, _ = regress.run_one("program.elf", 1, Path(temporary) / "build")
                    self.assertEqual(status, "TIMEOUT")
                    kill.assert_called_once_with(12345, signal.SIGKILL)

    def test_old_passing_log_is_removed_before_a_failed_run(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            log = directory / "build/run/simulation.log"
            log.parent.mkdir(parents=True)
            log.write_text("Monitor: Total IPC: 1.2")
            process = MagicMock()
            process.returncode = 2
            process.communicate.return_value = ("", "error: invalid ELF")
            manager = MagicMock()
            manager.__enter__.return_value = process
            with patch.object(regress.subprocess, "Popen", return_value=manager):
                status, _ = regress.run_one("program.elf", 1, directory / "build")
            self.assertEqual(status, "BUILD")
            self.assertFalse(log.exists())

    def test_nonzero_simulator_exit_rejects_a_passing_log(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            log = directory / "run/simulation.log"
            log.parent.mkdir()
            process = MagicMock()
            process.returncode = 2

            def complete(**kwargs):
                log.write_text("Monitor: Total IPC: 1.2\nCycles: 20\n")
                return "", ""

            process.communicate.side_effect = complete
            manager = MagicMock()
            manager.__enter__.return_value = process
            with patch.object(regress.subprocess, "Popen", return_value=manager):
                self.assertEqual(regress.run_one("program.elf", 1, directory),
                                 ("ERROR", "simulator exited with status 2"))
