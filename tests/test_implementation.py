import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("implementation", ROOT / "synth/implementation/verify.py")
implementation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(implementation)


class ImplementationCheckTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.native = self.root / "native.tsv"
        self.native.write_text("C\tfirst\tCELL\nC\tsecond\tCELL\n")
        self.rows = [
            dict(name="first", internal=0.5, switching=0.25, leakage=0.125, total=0.875),
            dict(name="second", internal=0.25, switching=0.125, leakage=0.0, total=0.375),
        ]
        self.result = dict(physical_leaf_instances=2, power_w=1.25,
                           power_components_w=dict(internal=0.75, switching=0.375, leakage=0.125))
        root_patch = patch.object(implementation, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)

    def check_power(self, rows):
        with gzip.open(self.root / "leaf-power.json.gz", "wt") as stream:
            json.dump(rows, stream)
        return implementation.verify_power(self.native, self.result)

    def test_complete_power_export_matches_component_sum(self):
        self.assertEqual(self.check_power(self.rows), 1.25)

    def test_missing_duplicate_and_extra_instances_are_rejected(self):
        for rows in (self.rows[:1], [self.rows[0], self.rows[0]],
                     self.rows + [dict(self.rows[0], name="extra")]):
            with self.subTest(rows=rows), self.assertRaisesRegex(ValueError, "exactly once"):
                self.check_power(rows)

    def test_nonfinite_power_and_changed_sums_are_rejected(self):
        for value in (float("nan"), float("inf"), True, 1.0):
            rows = [dict(self.rows[0], internal=value), self.rows[1]]
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.check_power(rows)

    def test_manifest_rejects_changed_files(self):
        data = self.root / "sample.txt"
        data.write_bytes(b"original")
        checksum = hashlib.sha256(data.read_bytes()).hexdigest()
        (self.root / "files.json").write_text(json.dumps({"sample.txt": checksum}))
        implementation.verify_files()
        data.write_bytes(b"modified")
        with self.assertRaisesRegex(ValueError, "sample.txt"):
            implementation.verify_files()

    def test_timing_report_rejects_slack_area_and_electrical_failures(self):
        report = ("SETUP\nworst slack max 0.001\nHOLD\nworst slack min 0.051\n"
                  "ELECTRICAL\nELECTRICAL_END\nCLOCK\nNo paths found.\nCLOCK_END\n"
                  "Design area 100 um^2 50% utilization.\n")
        expected = dict(setup_slack_ns=0.001, hold_slack_ns=0.051, area_um2=100)
        implementation.verify_timing_report(report, expected)
        invalid = (report.replace("max 0.001", "max -0.001"),
                   report.replace("area 100", "area 101"),
                   report.replace("ELECTRICAL_END", "pin -0.01\nELECTRICAL_END"),
                   report.replace("No paths found.", "VIOLATED"))
        for text in invalid:
            with self.assertRaises(ValueError):
                implementation.verify_timing_report(text, expected)
