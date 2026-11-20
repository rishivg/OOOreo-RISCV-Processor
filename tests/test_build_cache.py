import concurrent.futures
import contextlib
import io
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
from build_cache import cached_build, cached_verilator, discard_native_objects, verilator_signature
from generate_rtl import configuration_environment


class BuildCacheTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.output = self.root / "binary"
        self.manifest = self.root / "receipt.json"
        self.source.write_text("first")
        self.builds = 0

    def build(self):
        self.builds += 1
        self.output.write_text("compiled " + self.source.read_text())

    def run_build(self, signature="default", build=None, **kwargs):
        return cached_build(self.manifest, [self.source], [self.output],
                            signature, build or self.build, **kwargs)

    def test_unchanged_products_are_reused(self):
        self.assertTrue(self.run_build())
        self.assertFalse(self.run_build())
        self.assertEqual(self.builds, 1)

    def test_source_hash_wins_over_size_and_timestamp(self):
        self.run_build()
        stat = self.source.stat()
        self.source.write_text("other")
        os.utime(self.source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        self.assertTrue(self.run_build())
        self.assertEqual(self.output.read_text(), "compiled other")

    def test_changed_flags_added_inputs_and_force_rebuild(self):
        self.run_build()
        self.assertTrue(self.run_build(signature="trace-enabled"))
        self.assertTrue(self.run_build(signature="trace-enabled", force=True))
        extra = self.root / "header"
        extra.write_text("include")
        self.assertTrue(cached_build(self.manifest, [self.source, extra], [self.output],
                                     "trace-enabled", self.build))

    def test_missing_or_corrupt_product_rebuilds(self):
        self.run_build()
        self.output.write_text("corrupt")
        self.assertTrue(self.run_build())
        self.output.unlink()
        self.assertTrue(self.run_build())

    def test_failed_build_never_leaves_a_reusable_receipt(self):
        self.run_build()

        def fail():
            self.output.write_text("partial output")
            raise RuntimeError("compiler failed")

        with self.assertRaisesRegex(RuntimeError, "compiler failed"):
            self.run_build(signature="changed", build=fail)
        self.assertFalse(self.manifest.exists())
        self.assertTrue(self.run_build())

    def test_input_changed_during_build_is_rejected(self):
        def edit_during_build():
            self.build()
            self.source.write_text("edited during build")

        with self.assertRaisesRegex(RuntimeError, "inputs changed"):
            self.run_build(build=edit_during_build)
        self.assertFalse(self.manifest.exists())

    def test_invalid_receipt_is_a_miss(self):
        for text in ("broken json", "[]", '{"schema_version": 1}'):
            self.manifest.write_text(text)
            self.assertTrue(self.run_build())

    def test_parallel_invocations_compile_once(self):
        def slow_build():
            time.sleep(0.03)
            self.build()

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.run_build(build=slow_build), range(2)))
        self.assertCountEqual(results, [True, False])
        self.assertEqual(self.builds, 1)

    def test_new_configuration_switch_is_automatically_fingerprinted(self):
        scala = self.root / "Config.scala"
        scala.write_text('envB("NEW_TIMING_OPTION", false)')
        first = configuration_environment([scala], {"NEW_TIMING_OPTION": "0", "TERM": "xterm"})
        second = configuration_environment([scala], {"NEW_TIMING_OPTION": "1", "TERM": "xterm"})
        self.assertNotEqual(first, second)
        self.assertNotIn("TERM", first)

    def test_worker_count_reuses_binary_but_trace_flags_do_not(self):
        with patch("build_cache.tool_identity", return_value={"version": "test"}):
            single = verilator_signature(["verilator", "--build", "-j", "1"])
            parallel = verilator_signature(["verilator", "--build", "-j", "4"])
            traced = verilator_signature(["verilator", "--build", "-j", "4", "--trace"])
        self.assertEqual(single, parallel)
        self.assertNotEqual(single, traced)

    def test_content_miss_discards_native_objects_but_keeps_sources_and_logs(self):
        for name in ("model.o", "model.a", "header.h.gch", "source.cpp", "compile.log"):
            (self.root / name).write_text(name)
        # A directory with an object suffix is not a compiler output file.
        (self.root / "preserved.o").mkdir()
        discard_native_objects(self.root)
        self.assertFalse(any((self.root / name).exists()
                             for name in ("model.o", "model.a", "header.h.gch")))
        self.assertTrue((self.root / "source.cpp").is_file())
        self.assertTrue((self.root / "compile.log").is_file())
        self.assertTrue((self.root / "preserved.o").is_dir())

    def simulator_build(self, script):
        with patch("build_cache.tool_identity", return_value={"version": "test"}):
            return cached_verilator(self.manifest, [self.source], self.output,
                [sys.executable, "-c", script], self.root / "compile.log", cwd=self.root)

    def test_simulator_cache_requires_an_executable_and_discards_stale_objects(self):
        script = "from pathlib import Path; p=Path('binary'); p.write_text('model'); p.chmod(0o700)"
        self.assertTrue(self.simulator_build(script))
        self.assertFalse(self.simulator_build(script))
        self.output.chmod(0o600)
        stale = self.root / "model.o"
        stale.write_text("stale native object")
        self.assertTrue(self.simulator_build(script))
        self.assertFalse(stale.exists())
        self.assertTrue(os.access(self.output, os.X_OK))

    def test_failed_simulator_compile_removes_old_binary_and_reports_its_log(self):
        self.simulator_build("from pathlib import Path; p=Path('binary'); p.write_text('old'); p.chmod(0o700)")
        diagnostics = io.StringIO()
        with contextlib.redirect_stderr(diagnostics):
            with self.assertRaises(subprocess.CalledProcessError):
                self.simulator_build("print('compile failed'); raise SystemExit(2)")
        self.assertIn("compile failed", diagnostics.getvalue())
        self.assertFalse(self.manifest.exists())
        self.assertFalse(self.output.exists())
