#!/usr/bin/env python3
"""Public contract diagnostics for malformed JSON and evidence paths."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
SPEC = importlib.util.spec_from_file_location('validate_path', SCRIPTS / 'validate_path.py')
PATHS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATHS)


class InputBoundaryTests(unittest.TestCase):
    def test_contract_invalid_shapes_have_failure_diagnostics(self):
        cases = [[], None, 1, {'schema': 1}, {'checks': [{'id': []}]},
                 {'checks': [{'id': 'lint', 'waiver_reason': 1}]},
                 {'required_workflow': 'tdd', 'checks': [{'id': 'unit-tests',
                  'required': True, 'red_evidence': 2}]}]
        with tempfile.TemporaryDirectory() as directory:
            contract = Path(directory) / 'contract.json'
            for value in cases:
                with self.subTest(value=value):
                    contract.write_text(json.dumps(value), encoding='utf-8')
                    result = subprocess.run([sys.executable, str(SCRIPTS / 'check-contract.py'),
                                             str(contract), directory], capture_output=True,
                                            text=True, encoding='utf-8', timeout=10, check=False)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('Verification contract FAILED', result.stdout)
                    self.assertNotIn('Traceback', result.stderr)
            contract.write_bytes(b'\xff')
            result = subprocess.run([sys.executable, str(SCRIPTS / 'check-contract.py'),
                                     str(contract), directory], capture_output=True,
                                    text=True, encoding='utf-8', timeout=10, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertIn('JSON parse error', result.stdout)
            self.assertNotIn('Traceback', result.stderr)

    def test_paths_do_not_coerce_external_values(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ('123', '日本語 "quoted"\n.txt'):
                (Path(directory) / name).write_text('evidence', encoding='utf-8')
                failures = []
                self.assertTrue(PATHS.validate_evidence_path('evidence', name, directory, failures))
                self.assertEqual(failures, [])
            for value in (123, [], {}, False, '', 'x\0y', '../outside'):
                with self.subTest(value=value):
                    failures = []
                    self.assertFalse(PATHS.validate_evidence_path('evidence', value, directory, failures))
                    self.assertTrue(failures)


if __name__ == '__main__':
    unittest.main()
