#!/usr/bin/env python3
"""Shadow predictions cannot remove gates or mistake incomplete evidence for success."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('impact', Path(__file__).with_name('verification-impact.py'))
IMPACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPACT)


class ImpactTests(unittest.TestCase):
    def setUp(self):
        self.full = sorted(IMPACT.README_SUITES) + ['tests/guards.tests.sh']
        self.hashes = dict.fromkeys(self.full, 'source-digest')

    def receipt(self, statuses):
        return {'schema': 'verification-receipt/v1', 'revision': 'head',
                'revision_after': 'head', 'clean_before': True, 'clean_after': True,
                'catalog_sha256': 'catalog', 'results': [
                    {'suite': suite, 'status': status, 'exit_code': 0 if status == 'passed' else 1,
                     'source_sha256': 'source-digest'} for suite, status in statuses.items()]}

    def compare(self, receipts):
        return IMPACT.compare(receipts, self.full, sorted(IMPACT.README_SUITES),
                         'head', 'catalog', self.hashes, ('head', True))

    def test_unknown_sensitive_and_empty_changes_keep_full(self):
        for paths in (None, set(), {'scripts/helper.py'}, {'README.md', 'tests/a.py'},
                      {'.github/workflows/test.yml'}, {'skills/foo/SKILL.md'},
                      {'README.md', 'old.md'}, {'tests/verification-catalog.json'}):
            with self.subTest(paths=paths):
                self.assertEqual(IMPACT.propose(paths, self.full)[0], self.full)

    def test_readme_hypothesis_requires_all_contract_suites(self):
        selected, reason = IMPACT.propose({'README.md'}, self.full)
        self.assertEqual(set(selected), IMPACT.README_SUITES)
        self.assertEqual(reason, 'readme-only-hypothesis')
        reduced = self.full[1:]
        self.assertEqual(IMPACT.propose({'README.md'}, reduced)[0], reduced)

    def test_complete_receipts_expose_missed_failure(self):
        statuses = dict.fromkeys(self.full, 'passed')
        statuses['tests/guards.tests.sh'] = 'failed'
        result = self.compare([self.receipt(statuses)])
        self.assertEqual(result['status'], 'complete')
        self.assertEqual(result['missed_failures'], ['tests/guards.tests.sh'])
        rerun = self.receipt(dict.fromkeys(self.full, 'passed'))
        self.assertEqual(self.compare([self.receipt(statuses), rerun])['missed_failures'],
                         ['tests/guards.tests.sh'])

    def test_absent_skipped_wrong_revision_or_digest_never_completes(self):
        receipt = self.receipt(dict.fromkeys(self.full, 'passed'))
        self.assertEqual(self.compare([])['status'], 'incomplete')
        for key in ('revision', 'revision_after', 'catalog_sha256', 'clean_before', 'clean_after'):
            invalid = {**receipt, key: 'stale'}
            self.assertEqual(self.compare([invalid])['status'], 'incomplete')
            missing = {name: value for name, value in receipt.items() if name != key}
            self.assertEqual(self.compare([missing])['status'], 'incomplete')
        for field, value in (('status', 'skipped'), ('source_sha256', 'stale'), ('exit_code', 4)):
            invalid = self.receipt(dict.fromkeys(self.full, 'passed'))
            invalid['results'][0][field] = value
            self.assertEqual(self.compare([invalid])['status'], 'incomplete')
        self.assertEqual(self.compare([None])['rejected_receipts'], 1)

    def test_dirty_production_source_cannot_reuse_clean_receipt(self):
        from verification import repository_state
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', *args], cwd=root, check=True,
                                      capture_output=True, text=True).stdout.strip()
            git('init')
            git('config', 'user.name', 'Fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            (root / 'production.py').write_text('answer = 42\n')
            (root / 'test.py').write_text('assert True\n')
            git('add', '.')
            git('commit', '-m', 'fixture')
            head, clean = repository_state(root)
            self.assertIs(clean, True)
            receipt = self.receipt(dict.fromkeys(self.full, 'passed'))
            receipt.update(revision=head, revision_after=head)
            def compare():
                return IMPACT.compare([receipt], self.full, self.full, head, 'catalog',
                                 self.hashes, repository_state(root))
            self.assertEqual(compare()['status'], 'complete')
            (root / 'production.py').write_text('answer = 0\n')
            self.assertEqual(repository_state(root), (head, False))
            self.assertEqual((root / 'test.py').read_text(), 'assert True\n')
            self.assertEqual(compare()['status'], 'incomplete')
            git('restore', 'production.py')
            (root / 'untracked.py').write_text('answer = 0\n')
            self.assertEqual(compare()['status'], 'incomplete')
            (root / 'untracked.py').unlink()
            self.assertEqual(compare()['status'], 'complete')
            for state in ((None, None), (head, None), ('different-head', True)):
                self.assertEqual(IMPACT.compare([receipt], self.full, self.full, head, 'catalog',
                                           self.hashes, state)['status'], 'incomplete')

    def test_git_renames_deletes_and_invalid_base(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', *args], cwd=root, check=True,
                                      capture_output=True, text=True).stdout.strip()
            git('init')
            git('config', 'user.name', 'Fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            (root / 'old.md').write_text('content\n')
            (root / 'removed.py').write_text('print(1)\n')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'old.md').rename(root / 'README.md')
            (root / 'removed.py').unlink()
            git('add', '-A')
            git('commit', '-m', 'rename and delete')
            paths, status = IMPACT.changed_paths(root, base, 'HEAD')
            self.assertEqual(paths, {'old.md', 'README.md', 'removed.py'})
            self.assertEqual(status, 'diff-available')
            self.assertEqual(IMPACT.propose(paths, self.full)[0], self.full)
            self.assertIsNone(IMPACT.changed_paths(root, 'nonexistent', 'HEAD')[0])
            self.assertEqual(IMPACT.changed_paths(root, None, 'HEAD')[1], 'base-unavailable')
            self.assertEqual(IMPACT.changed_paths(root, 'HEAD', 'HEAD')[0], set())


if __name__ == '__main__':
    unittest.main()
