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

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('verification', ROOT / 'tests/verification.py')
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
        self.catalog = {
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

    def test_python_runtime_prefers_dispatcher_name_without_changing_fallback(self):
        alias = self.root / 'python3'
        sibling = self.root / 'python'
        try:
            alias.symlink_to(sys.executable)
            sibling.symlink_to(sys.executable)
        except OSError:
            self.skipTest('interpreter symlink unavailable')
        with patch.object(V.shutil, 'which', return_value=str(alias)), patch.object(V.sys, 'executable', str(sibling)):
            self.assertEqual(V.runtime_command('python'), [str(alias), '-B'])
        with patch.object(V.shutil, 'which', return_value=str(alias)):
            self.assertEqual(V.runtime_command('python'), [sys.executable, '-B'])
        with patch.object(V.shutil, 'which', return_value=None):
            self.assertEqual(V.runtime_command('python'), [sys.executable, '-B'])
        sibling.unlink()
        sibling.write_bytes(b'different runtime')
        with patch.object(V.shutil, 'which', return_value=str(alias)), patch.object(V.sys, 'executable', str(sibling)):
            self.assertEqual(V.runtime_command('python'), [str(sibling), '-B'])

    def retention(self, text):
        path = self.root / 'retention.md'
        path.write_text(text, encoding='utf-8')
        return V.retention_checks(path, self.load())

    def test_retention_runs_registered_regression_and_reports_real_failure(self):
        entries = self.retention('| Source WFI | Regression Suites | Judgment Reason |\n|---|---|---|\n| WFI-001 | tests/a.tests.py tests/b.tests.py | |\n')
        (self.root / self.paths[0]).write_text('raise SystemExit(7)\n')
        receipt, code = V.execute(self.load(), entries[0]['suites'], self.root)
        self.assertEqual(code, 1)
        result = V.retention_result(entries, receipt['results'])
        self.assertFalse(result['complete'])
        self.assertEqual(result['entries'][0]['status'], 'failed')
        (self.root / self.paths[0]).write_text('print("fixed")\n')
        receipt, code = V.execute(self.load(), entries[0]['suites'], self.root)
        self.assertEqual(code, 0)
        self.assertTrue(V.retention_result(entries, receipt['results'])['complete'])

    def test_retention_judgment_legacy_and_skipped_are_not_success(self):
        entries = self.retention('| Source WFI | Regression Suites | Judgment Reason |\n|---|---|---|\n| WFI-001 | tests/a.tests.py | |\n| WFI-002 | | requires context |\n| WFI-003 | | |\n')
        result = V.retention_result(entries, [{'suite': self.paths[0], 'status': 'skipped'}])
        self.assertEqual([row['status'] for row in result['entries']], ['not-run', 'judgment-required', 'unlinked'])
        self.assertFalse(result['complete'])
        legacy = self.retention('| Source WFI | Condition |\n|---|---|\n| WFI-004 | older format |\n')
        self.assertEqual(legacy[0]['status'], 'unlinked')

    def test_retention_rejects_injection_duplicates_unknown_and_malformed_rows(self):
        header = '| Source WFI | Regression Suites | Judgment Reason |\n|---|---|---|\n'
        for body in (
            '| WFI-001 | tests/missing.tests.py | |\n',
            '| WFI-001 | $(touch marker) | |\n',
            '| WFI-001 | ../outside | |\n',
            '| WFI-001 | tests/a.tests.py | conflicting reason |\n',
            '| WFI-001 | tests/a.tests.py tests/a.tests.py | |\n',
            '| WFI-001 | | |\n| WFI-001 | | |\n',
            '| WFI-001 | |\n',
            '',
        ):
            with self.subTest(body=body), self.assertRaises(ValueError):
                self.retention(header + body)

    def test_retention_cli_exit_codes_and_pinned_receipt(self):
        path = self.root / 'retention-cli.md'
        receipt = self.root / 'retention-receipt.json'
        header = '| Source WFI | Regression Suites | Judgment Reason |\n|---|---|---|\n'
        command = [sys.executable, str(ROOT / 'tests/verification.py'), '--retention', '--checklist', str(path), '--run', '--receipt', str(receipt)]
        linked = header + '| WFI-001 | tests/verification-impact.tests.py | |\n'
        for body, code in [(linked, 0), (linked + '| WFI-002 | | needs report review |\n', 1)]:
            path.write_text(body, encoding='utf-8')
            result = subprocess.run(command, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, code, result.stderr)
            actual = json.loads(receipt.read_text())
            self.assertEqual(actual['selected'], ['tests/verification-impact.tests.py'])
            self.assertEqual(actual['retention']['complete'], code == 0)
            self.assertEqual(actual['retention']['checklist_sha256'], V.hashlib.sha256(path.read_bytes()).hexdigest())
        for extra in (['--shard-count', '2'], []):
            path.write_text(header + '| WFI-001 | $(touch marker) | |\n', encoding='utf-8')
            result = subprocess.run(command + extra, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 2)
            self.assertFalse((ROOT / 'marker').exists())

    def test_retention_indentation_cannot_hide_pending_or_failed_rows(self):
        header = '| Source WFI | Regression Suites | Judgment Reason |\n|---|---|---|\n'
        linked = '| WFI-001 | tests/a.tests.py | |\n'
        pending = '| WFI-002 | | requires context |\n'
        for spaces in range(4):
            prefix = ' ' * spaces
            with self.subTest(spaces=spaces):
                for text in (header + linked + prefix + pending,
                             '\n'.join(prefix + line for line in (header + linked + pending).splitlines()) + '\n'):
                    entries = self.retention(text)
                    result = V.retention_result(entries, [{'suite': self.paths[0], 'status': 'passed'}])
                    self.assertFalse(result['complete'])
                    self.assertEqual([row['status'] for row in result['entries']], ['passed', 'judgment-required'])
        for prefix in ('    ', '\t', ' \t', '\u00a0'):
            with self.subTest(prefix=repr(prefix)), self.assertRaises(ValueError):
                self.retention(header + linked + prefix + pending)
        with self.assertRaises(ValueError):
            self.retention(header + linked + '\n' + pending)

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

    def test_real_catalog_and_wrappers_list_exact_same_suites(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        result = subprocess.run(['bash', str(ROOT / 'tests/run-all.sh'), '--list'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), catalog['profiles']['local-posix'])
        result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'), '--list'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(result.stdout.splitlines()), set(catalog['profiles']['ci-posix-fallback']))

    def test_parallel_jobs_preserves_deterministic_receipt_order_and_failure(self):
        (self.root / self.paths[0]).write_text('import sys; print("fail-a"); sys.exit(3)\n')
        (self.root / self.paths[1]).write_text('print("pass-b")\n')
        loaded = self.load()
        receipt, code = V.execute(
            loaded,
            self.paths,
            self.root,
            'test',
            jobs=2,
            weights={self.paths[1]: 100, self.paths[0]: 1},
        )
        self.assertEqual(code, 1)
        self.assertEqual([r['suite'] for r in receipt['results']], self.paths)
        self.assertEqual([r['status'] for r in receipt['results']], ['failed', 'passed'])
        self.assertEqual([r['exit_code'] for r in receipt['results']], [3, 0])

        bad = subprocess.run(
            [sys.executable, str(ROOT / 'tests/verification.py'), '--suite',
             'tests/verification-impact.tests.py', '--run', '--jobs', '0'],
            text=True,
            capture_output=True,
        )
        self.assertEqual(bad.returncode, 2)


if __name__ == '__main__':
    unittest.main()
