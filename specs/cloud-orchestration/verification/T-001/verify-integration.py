#!/usr/bin/env python3
"""Read-only checks for the cloud-local maintenance evidence pin."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
PIN = HERE / 'current-inventory-reference-typefix.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_pin(pin):
    for key in ('inventory', 'runner', 'historical_failure'):
        row = pin[key]
        assert digest(ROOT / row['path']) == row['sha256'], key
    inventory = json.loads((ROOT / pin['inventory']['path']).read_text())
    source = next(row for row in inventory['entries']
                  if row['id'] == 'bootstrap-seven-layer-output')['source']
    assert source == [pin['required_source']], 'source assertion'


class IntegrationTests(unittest.TestCase):
    def test_current_pin_and_required_source(self):
        verify_pin(json.loads(PIN.read_text()))

    def test_changed_pin_is_rejected(self):
        for key in ('inventory', 'runner', 'historical_failure'):
            pin = json.loads(PIN.read_text())
            pin[key]['sha256'] = '0' * 64
            with self.subTest(key=key), self.assertRaises(AssertionError):
                verify_pin(pin)

    def test_historical_bytes_match_git_baseline_and_initial_snapshot(self):
        data = json.loads((HERE / 'historical-preservation.json').read_text())
        for row in data['files']:
            with self.subTest(path=row['path']):
                baseline = subprocess.check_output(['git', 'show', data['base_revision'] + ':' + row['path']], cwd=ROOT)
                self.assertEqual(hashlib.sha256(baseline).hexdigest(), row['baseline_sha256'])
                self.assertEqual(digest(ROOT / row['path']), row['baseline_sha256'])
                self.assertEqual(row['before_sha256'], row['baseline_sha256'])
        for row in data['retained_repair_evidence']:
            self.assertEqual(digest(ROOT / row['path']), row['sha256'])

    def test_normal_driver_registration(self):
        suite = 'tests/sdd-domain-multitarget-foundation.tests.py'
        bash = (ROOT / 'tests/run-all.sh').read_text()
        self.assertIn('if ! python3 -B ' + suite + '; then', bash)
        self.assertIn("failed+=('" + suite + "')", bash)
        powershell = (ROOT / 'tests/run-all.ps1').read_text()
        line = next(line for line in powershell.splitlines() if 'foreach ($testFile in @(' in line and suite in line)
        self.assertEqual(line.count(suite), 1)
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        native_job = workflow.split('\n  test:\n', 1)[1]
        self.assertIn('os: [windows-latest, macos-latest, ubuntu-latest]', native_job)
        self.assertIn('run: python -B ' + suite, native_job)


if __name__ == '__main__':
    unittest.main(verbosity=2)
