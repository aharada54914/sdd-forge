#!/usr/bin/env python3
"""Behavioral contracts for the executable verification catalog."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import shutil
from unittest.mock import patch
import tempfile
import unittest
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('verification', ROOT / 'tests/verification.py')
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'tests').mkdir()
        self.paths = ['tests/a.tests.py', 'tests/b.tests.py']
        for path in self.paths:
            (self.root / path).write_text('print("fixture")\n')
        self.catalog: dict[str, Any] = {
            'schema': 'verification-catalog/v1',
            'suites': [{'path': p, 'runtime': 'python'} for p in self.paths],
            'profiles': {'test': self.paths.copy()},
        }

    def load(self):
        path = self.root / 'tests/catalog.json'
        path.write_text(json.dumps(self.catalog))
        return V.load_catalog(path, self.root)

    def test_unknown_duplicate_and_missing_entries_fail(self):
        self.load()
        for mutate in (
            lambda: self.catalog['profiles']['test'].append('tests/missing.tests.py'),
            lambda: self.catalog['suites'].append(self.catalog['suites'][0].copy()),
            lambda: self.catalog['profiles']['test'].append(self.paths[0]),
        ):
            original = json.loads(json.dumps(self.catalog))
            mutate()
            with self.assertRaises(ValueError):
                self.load()
            self.catalog = original
        (self.root / self.paths[0]).unlink()
        with self.assertRaises(ValueError):
            self.load()

    def test_new_suite_requires_explicit_registration(self):
        (self.root / 'tests/new.tests.sh').write_text('exit 0\n')
        with self.assertRaisesRegex(ValueError, 'unregistered'):
            self.load()

    def test_unassigned_or_cyclic_delegation_fails(self):
        self.catalog['profiles']['test'] = []
        with self.assertRaises(ValueError):
            self.load()
        for a, b in zip(self.catalog['suites'], reversed(self.paths)):
            a['delegated_to'] = b
        with self.assertRaises(ValueError):
            self.load()

    def test_delegated_suite_requires_registered_executed_parent(self):
        self.catalog['profiles']['test'] = [self.paths[0]]
        self.catalog['suites'][1]['delegated_to'] = self.paths[0]
        self.load()
        self.catalog['suites'][1]['delegated_to'] = 'tests/missing.tests.py'
        with self.assertRaises(ValueError):
            self.load()

    def test_balanced_shards_are_deterministic_disjoint_complete(self):
        paths = ['a', 'b', 'c', 'd', 'e']
        weights = dict(zip(paths, [10, 8, 4, 3, 1]))
        shards = V.shard_suites(paths, 2, weights)
        self.assertEqual(shards, V.shard_suites(paths, 2, weights))
        self.assertEqual(sorted(sum(shards, [])), sorted(paths))
        self.assertFalse(set(shards[0]) & set(shards[1]))
        self.assertLessEqual(abs(sum(weights[p] for p in shards[0]) - sum(weights[p] for p in shards[1])), 2)
        with self.assertRaises(ValueError):
            V.shard_suites(paths, 0, weights)

    def test_failed_suite_does_not_hide_later_results_and_receipt(self):
        (self.root / self.paths[0]).write_text('raise SystemExit(7)\n')
        loaded = self.load()
        receipt, code = V.execute(loaded, self.paths, self.root, 'test')
        self.assertEqual(code, 1)
        self.assertEqual([r['exit_code'] for r in receipt['results']], [7, 0])
        self.assertEqual([r['status'] for r in receipt['results']], ['failed', 'passed'])
        self.assertNotIn(str(self.root), json.dumps(receipt))

    def test_missing_runtime_is_failure_unless_profile_explicitly_optional(self):
        self.catalog['suites'][0].update(runtime='powershell', optional_in=['optional'])
        self.catalog['profiles']['optional'] = self.paths.copy()
        loaded = self.load()
        for profile, expected in [('test', 'failed'), ('optional', 'skipped')]:
            receipt, code = V.execute(loaded, self.paths[:1], self.root, profile, powershell='missing-pwsh-fixture')
            self.assertEqual(receipt['results'][0]['status'], expected)
            self.assertEqual(code, int(profile == 'test'))

    def test_receipt_written_atomically(self):
        path = self.root / 'receipt.json'
        V.write_receipt(path, {'results': []})
        self.assertEqual(json.loads(path.read_text()), {'results': []})
        self.assertEqual(list(self.root.glob('receipt.json.*')), [])

    def test_malformed_runtime_arguments_rejected(self):
        self.catalog['suites'][0]['args'] = '--not-an-array'
        with self.assertRaises(ValueError):
            self.load()

    def test_runtime_metadata_unavailable_does_not_hide_execution(self):
        loaded = self.load()
        with patch.object(V, 'repository_state', return_value=(None, None)):
            receipt, code = V.execute(loaded, self.paths, self.root, 'test')
        self.assertEqual(code, 0)
        self.assertIsNone(receipt['revision'])
        self.assertIsNone(receipt['clean_before'])
        self.assertFalse(receipt['reusable'])

    def test_worktree_changes_are_recorded_without_claiming_reusable_evidence(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Fixture', '-c',
                        'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        self.assertTrue(V.repository_state(self.root)[1])
        (self.root / self.paths[0]).write_text('print("changed")\n')
        receipt, code = V.execute(self.load(), self.paths, self.root, 'test')
        self.assertEqual(code, 0)
        self.assertFalse(receipt['clean_before'])
        self.assertFalse(receipt['clean_after'])
        self.assertEqual(receipt['revision'], receipt['revision_after'])

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is unavailable')
    def test_native_powershell_failure_and_fresh_process_are_preserved(self):
        paths = ['tests/native-a.tests.ps1', 'tests/native-b.tests.ps1']
        (self.root / paths[0]).write_text('$global:FixtureState = 1; exit 7\n')
        (self.root / paths[1]).write_text('if (Get-Variable FixtureState -ErrorAction SilentlyContinue) { exit 9 }; exit 0\n')
        self.catalog['suites'] += [{'path': p, 'runtime': 'powershell'} for p in paths]
        self.catalog['profiles']['native'] = paths
        receipt, code = V.execute(self.load(), paths, self.root, 'native')
        self.assertEqual(code, 1)
        self.assertEqual([r['exit_code'] for r in receipt['results']], [7, 0])

    def test_cli_direct_suite_and_receipt_are_bound_to_selection(self):
        receipt = self.root / 'actual-receipt.json'
        command = [sys.executable, str(ROOT / 'tests/verification.py'), '--suite',
                   'tests/verification-impact.tests.py', '--run', '--receipt', str(receipt)]
        completed = subprocess.run(command, text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        actual = json.loads(receipt.read_text())
        self.assertEqual(actual['selected'], ['tests/verification-impact.tests.py'])
        self.assertEqual([row['status'] for row in actual['results']], ['passed'])
        self.assertNotIn(str(ROOT), json.dumps(actual))
        self.assertFalse(actual['reusable'])

    def test_wrapper_actions_are_position_independent_and_shards_cover_profile(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        combined = []
        for index in range(4):
            result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'),
                                     '--shard-index', str(index), '--shard-count', '4', '--list'],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            combined.extend(result.stdout.splitlines())
        self.assertEqual(len(combined), len(set(combined)))
        self.assertEqual(set(combined), set(catalog['profiles']['ci-posix-fallback']))
        result = subprocess.run(['bash', str(ROOT / 'tests/run-all.sh'), '--shard-count', '1', '--plan'],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['selected'], catalog['profiles']['local-posix'])
        result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'), '--shard-index', '4',
                                 '--shard-count', '4', '--list'], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_planner_is_registered_and_live_categories_are_inactive(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        suite = 'tests/verification-ci-plan.tests.py'
        self.assertIn(suite, catalog['profiles']['local-posix'])
        self.assertIn(suite, catalog['profiles']['ci-posix-fallback'])
        self.assertTrue(catalog['impact']['categories'])
        for category in catalog['impact']['categories']:
            self.assertIs(category['active'], False)
            self.assertIsNone(category['evidence'])
        spec = importlib.util.spec_from_file_location('planner', ROOT / 'tests/verification-impact.py')
        assert spec and spec.loader
        planner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(planner)
        workflow = planner.read_workflow(ROOT / '.github/workflows/test.yml')
        planner.rules(catalog, workflow)

    def test_real_catalog_and_wrappers_list_exact_same_suites(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        result = subprocess.run(['bash', str(ROOT / 'tests/run-all.sh'), '--list'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), catalog['profiles']['local-posix'])
        result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'), '--list'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(result.stdout.splitlines()), set(catalog['profiles']['ci-posix-fallback']))


if __name__ == '__main__':
    unittest.main()
