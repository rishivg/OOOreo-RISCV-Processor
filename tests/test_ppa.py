import io
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
from contextlib import redirect_stdout
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from parse_ppa import checks_clean, parse
from compute_pd4 import compute
import ppa_index

class CheckSummaryTest(unittest.TestCase):
    def test_unlabelled_negative_clock_slack_fails(self):
        for slack in ["-0.039024007", "-3.9e-2"]:
            self.assertFalse(checks_clean("Group Slack\n------\ngated clock " + slack + "\n"))

    def test_labelled_violation_fails(self):
        self.assertFalse(checks_clean("endpoint -0.01 (VIOLATED)"))

    def test_clean_or_empty_summary_passes(self):
        self.assertTrue(checks_clean("gated clock 0.039024007\n"))
        self.assertTrue(checks_clean(""))



class PpaParserTest(unittest.TestCase):
    def test_post_repair_values_preserve_the_record_schema(self):
        report = ("Design area 200 um^2 42%\nTotal 1e-3 2e-3 3e-3 6e-3 100.0%\n"
                  "running clock_tree_synthesis\nrunning post-CTS repair_timing -setup\n"
                  "===== timing AFTER repair_design =====\nwns max 0.125\ntns max 0\n")
        record = parse(report, 2)
        self.assertEqual((record['wns_ns'], record['tns_ns'], record['area_um2']), (0.125, 0, 200))
        self.assertEqual(record['power_total_w'], 0.006)
        self.assertEqual(record['fmax_mhz'], 1000 / 1.875)
        self.assertTrue(record['cts'] and record['met_timing'])
        self.assertTrue(record['setup_only_fmax_not_qualified'])

    def test_scientific_slacks_cover_summary_paths_walls_and_guards(self):
        report = ("===== timing AFTER repair_design =====\nwns max -1.25e-2\ntns max -3.0E-2\n"
                  "===== critical paths =====\nStartpoint: core/a/q\nEndpoint: core/b/d\n-2.5e-3 slack\n"
                  "Startpoint: core/a/r\nEndpoint: core/b/e\n-1.5e-3 slack\n"
                  "===== wall: load_use =====\n-4.0e-4 slack\n"
                  "FINAL_CLOCK_CHECKS\ngated clock -3.9e-2\nFINAL_CLOCK_CHECKS_END\n")
        record = parse(report, 2)
        self.assertEqual((record['wns_ns'], record['tns_ns']), (-0.0125, -0.03))
        self.assertEqual(record['walls'], {'load_use': -0.0004})
        self.assertEqual(record['worst_families'], [{'from': 'core/a/q', 'to': 'core/b/d', 'slack_ns': -0.0025}])
        self.assertFalse(record['clock_checks_clean'] or record['met_timing'])

    def test_incomplete_or_invalid_timing_is_rejected(self):
        report = "timing AFTER repair_design\nwns max 0\n"
        for period in (0, -1, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                parse(report, period)
        for text in ("wns max 0", "timing AFTER repair_design", "timing AFTER repair_design\nwns max 3"):
            with self.assertRaises(ValueError):
                parse(text, 2)


class Pd4Test(unittest.TestCase):
    def test_units_zero_power_and_whole_run_fallback(self):
        record = compute({'program': 'bench', 'run_cycles': 1000}, {'fmax_mhz': 500, 'power_total_w': 0.25})
        self.assertEqual(record['delay_ns'], 2000)
        self.assertTrue(math.isclose(record['pd4'], 4e-24, rel_tol=1e-12))
        self.assertEqual(record['pd4_units'], 'W * s^4')
        self.assertEqual(compute({'segment_cycles': 1000}, {'fmax_mhz': 500, 'power_total_w': 0})['pd4'], 0)

    def test_invalid_measurements_and_overflow_cannot_produce_scores(self):
        performance = {'segment_cycles': 1000, 'run_cycles': 1200}
        ppa = {'fmax_mhz': 500, 'power_total_w': 0.25}
        for invalid in (None, 0, -1, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                compute(performance, dict(ppa, fmax_mhz=invalid))
        for invalid in (0, -1, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                compute(dict(performance, segment_cycles=invalid), ppa)
        for invalid in (None, -1, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                compute(performance, dict(ppa, power_total_w=invalid))
        with self.assertRaises(ValueError):
            compute(performance, dict(ppa, fmax_mhz=1e308))


class PpaIndexTest(unittest.TestCase):
    def test_unknown_power_is_distinct_from_a_measured_zero(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            ppa = root / 'ppa.json'
            index = root / 'runs.jsonl'
            for name, power in [('unknown', None), ('zero', 0)]:
                ppa.write_text(json.dumps({'clk_period_ns': 2, 'fmax_mhz': None, 'power_total_w': power}))
                ppa_index.cmd_append(SimpleNamespace(ppa=ppa, index=index, name=name, config=None))
            for name, expected in [('unknown', '-'), ('zero', '0')]:
                output = io.StringIO()
                with redirect_stdout(output):
                    ppa_index.cmd_table(SimpleNamespace(index=index, names=name, n=1))
                self.assertEqual(output.getvalue().splitlines()[-1].split()[-1], expected)
                self.assertIn('setup_MHz', output.getvalue())

    def test_filtering_keeps_the_last_matching_rows_and_selected_knobs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / 'config.env'
            config.write_text('PNR_DIE_UM=1000\nPNR_CTS=\nOTHER=ignored\n')
            self.assertEqual(ppa_index.load_knobs(config), {'die_um': '1000'})
            index = root / 'runs.jsonl'
            rows = [dict(ts='2026-11-19 10:00:00', name=name, clock_ps=2000) for name in ['keep1', 'skip', 'keep2']]
            index.write_text('\n'.join(map(json.dumps, rows)) + '\n')
            output = io.StringIO()
            with redirect_stdout(output):
                ppa_index.cmd_table(SimpleNamespace(index=index, names='keep1,keep2', n=1))
            self.assertIn('keep2', output.getvalue())
            self.assertNotIn('keep1', output.getvalue())

    def test_cli_rejects_a_nonpositive_table_limit(self):
        result = subprocess.run([sys.executable, str(ROOT / 'bin/ppa_index.py'), 'table', 'unused', '-n', '0'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
