import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("fpga_flow", ROOT / "fpga/scripts/flow.py")
flow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(flow)


class FpgaSnapshotTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.out = self.root / "prepared"
        self.out.mkdir()
        self.source = self.root / "Generator.scala"
        self.source.write_text("original generator")
        self.cpu = self.out / "cpu.v"
        self.cpu.write_text("module cpu; endmodule\n")
        self.configuration = self.out / "configuration.json"
        self.configuration.write_text(json.dumps({"config": {
            "implementation": {"memory": "macro", "divider": "iterative"},
            "zicsr": False, "lowPower": False, "mmio": False,
        }}))
        source_list = patch.object(flow, "generator_inputs",
                                   side_effect=lambda: sorted(self.root.glob("*.scala")))
        source_list.start()
        self.addCleanup(source_list.stop)
        with patch.object(flow, "generate"):
            flow.prepare(self.out)

    def test_configuration_changes_invalidate_the_snapshot(self):
        flow.verify_inputs(self.out)
        data = json.loads(self.configuration.read_text())
        data["config"]["implementation"]["divider"] = "mock"
        self.configuration.write_text(json.dumps(data))
        with self.assertRaisesRegex(SystemExit, "configuration.json"):
            flow.verify_inputs(self.out)

    def test_new_generator_file_is_detected(self):
        (self.root / "NewModule.scala").write_text("new elaboration input")
        with self.assertRaisesRegex(SystemExit, "NewModule.scala"):
            flow.verify_inputs(self.out)

    def test_deleted_generator_file_is_detected(self):
        self.source.unlink()
        with self.assertRaisesRegex(SystemExit, "Generator.scala"):
            flow.verify_inputs(self.out)

    def test_restored_bytes_are_reusable_without_trusting_timestamps(self):
        original = self.cpu.read_bytes()
        self.cpu.write_text("changed generated RTL")
        with self.assertRaisesRegex(SystemExit, "cpu.v"):
            flow.verify_inputs(self.out)
        self.cpu.write_bytes(original)
        flow.verify_inputs(self.out)

    def test_path_resolved_pnr_tool_has_a_real_digest(self):
        chipdb = self.root / "chipdb"
        chipdb.write_bytes(b"database")
        netlist = self.out / "netlist.json"
        netlist.write_text("{}")
        (self.out / "area.json").write_text(json.dumps({"netlist_sha256": flow.sha(netlist)}))
        with patch.dict("os.environ", {"CHIPDB": str(chipdb), "NEXTPNR": "python3"}), \
             patch.object(flow, "command"):
            flow.pnr(self.out)
        request = json.loads((self.out / "pnr-request.json").read_text())
        self.assertEqual(request["nextpnr_sha256"], flow.sha(Path(shutil.which("python3"))))

    @unittest.skipUnless(shutil.which("yosys"), "Yosys required")
    def test_yosys_paths_preserve_spaces_quotes_backslashes_and_unicode(self):
        source = self.root / 'quoted "back\\slash-é.v'
        source.write_text("module quoted_path; endmodule\n")
        result = subprocess.run([
            "yosys", "-Q", "-T", "-p",
            f"read_verilog {flow.quote(source)}; hierarchy -check -top quoted_path",
        ], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
