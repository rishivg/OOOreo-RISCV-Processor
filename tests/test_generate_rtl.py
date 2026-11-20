import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
import generate_rtl


class GenerationProvenanceTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "Config.scala"
        self.source.write_text("// identical generator input across commits\n")
        root_override = patch.object(generate_rtl, "ROOT", self.root)
        root_override.start()
        self.addCleanup(root_override.stop)

    def commit(self, message):
        subprocess.run(["git", "-C", str(self.root), "-c", "core.hooksPath=/dev/null",
                        "-c", "commit.gpgsign=false", "-c", "user.name=Cache Test",
                        "-c", "user.email=cache@example.invalid", "commit", "--allow-empty",
                        "-q", "-m", message], check=True)

    def test_new_commit_invalidates_product_banner_even_with_identical_sources(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.commit("first")
        with patch.object(generate_rtl, "generator_inputs", return_value=[self.source]), \
             patch.object(generate_rtl, "tool_identity", return_value={"tool": "test"}), \
             patch.object(generate_rtl, "cached_build", return_value=False) as cache:
            generate_rtl.generate(self.root / "rtl", env={"PATH": os.environ["PATH"]})
            first = cache.call_args.args[3]
            self.commit("second")
            generate_rtl.generate(self.root / "rtl", env={"PATH": os.environ["PATH"]})
            second = cache.call_args.args[3]
        self.assertNotEqual(first["repository_revision"], second["repository_revision"])
        self.assertEqual(first["environment"], second["environment"])

    def test_exported_source_directory_has_no_git_revision(self):
        self.assertIsNone(generate_rtl.repository_revision())

    def test_commit_changed_during_elaboration_is_rejected(self):
        def build(manifest, inputs, outputs, signature, action, **kwargs):
            action()

        with patch.object(generate_rtl, "generator_inputs", return_value=[self.source]), \
             patch.object(generate_rtl, "tool_identity", return_value={"tool": "test"}), \
             patch.object(generate_rtl, "repository_revision", side_effect=["before", "after"]), \
             patch.object(generate_rtl.subprocess, "run"), \
             patch.object(generate_rtl, "cached_build", side_effect=build):
            with self.assertRaisesRegex(RuntimeError, "revision changed"):
                generate_rtl.generate(self.root / "rtl")
