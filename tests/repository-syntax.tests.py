"""Behavioral tests for .github/scripts/check-repository-syntax.py (issue #620).

Fixture repositories are temporary `git init` trees that are staged, never
committed. Each fixture copies the exact bytes of every legacy-BOM record and
intentional negative fixture, because the checker requires all of them.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / '.github/scripts/check-repository-syntax.py'
# CI provisions the pinned parser in a venv; locally the current interpreter is used.
PYTHON = os.environ.get('SDD_SYNTAX_PYTHON') or sys.executable
NEGATIVE = 'tests/fixtures/capability-resolver/resolve-project-context-block/contract-discovery-failed-governing-schema-'
EXPECTED_NEGATIVE = {
    NEGATIVE + 'malformed/resolver-evidence.schema.json':
        '54dcf34a93a6f8f1c7b9132fd8dfa9cf9f9789fe2e63d83075202d5955e92c4f',
    NEGATIVE + 'invalid-utf8/resolver-evidence.schema.json':
        '919024a80c6fa2b10274aa97b72c380f4c001c01504aca6851d5ee3ed3e1262a',
}
LEGACY_BOM = {
    'reports/runs/RUN-20260711T012801Z-epic-136-phase1-rce.json':
        'e3c6fe0c8cee2ca073206b8ca1620d6ea31c69daf95be8e956580457f0ca446e',
    'reports/task-review/epic-136-phase2-gates/attempt-2/round-3/reviewer-a.json':
        '4a44ec7f94b763de9e8d88c02b3bb72567c52bb656a8e19e9f2178322474e647',
    'reports/task-review/epic-136-phase2-gates/attempt-2/round-3/reviewer-b.json':
        '832876531f8b739c43583eaf8eaf86e3c240e4624edb6b7d69ec983fdd12c4fe',
    'reports/task-review/epic-136-phase2-gates/attempt-2/round-3/task-review-contract.json':
        'a6ae90890b0ebb0531ef719526121844c33b4c96ee2fd64963cabb5e7e82f698',
    'specs/epic-136-phase2-gates/verification/T-005.cross-model.json':
        'e74e3713fb36415856686f1f1124d6e21f6d24c905eaa00e90b8783ef438ca1d',
    'specs/epic-136-phase2-gates/verification/T-006.cross-model.json':
        'd203f801e050f544d20368a9ed82004887af30964cc4615bf65cac8216d46de7',
}
EXCEPTIONS = {**EXPECTED_NEGATIVE, **LEGACY_BOM}
CANARY = 'PRIVATE-' + 'SYNTAX-CANARY'
# Shape of the weekly workflow's managed prepare output directory (self-improvement.yml).
RUNTIME = '.sdd-self-improvement/0b6c1f6e-2f1d-4c84-9a52-3d1f5b7f9e10'
RUNTIME_OUTPUTS = {'selection.json': 'model-selection/v1', 'controls.json': 'model-launch-controls/v1',
                   'validation.json': 'model-launch-validation/v1'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_digest(root):
    """Digest every regular file outside .git so any checker write is detected."""
    digest = {}
    for path in sorted(root.rglob('*')):
        if '.git' in path.relative_to(root).parts or path.is_symlink() or not path.is_file():
            continue
        digest[path.relative_to(root).as_posix()] = (sha(path) if os.access(path, os.R_OK)
                                                     else os.stat(path).st_mtime_ns)
    return digest


def git(root, *args):
    subprocess.run(['git', '-C', str(root), *args], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class Fixture:
    def __init__(self, base):
        self.root = Path(base) / 'repo'
        self.root.mkdir()
        git(self.root, 'init', '-q')
        for rel in EXCEPTIONS:
            self.write(rel, (ROOT / rel).read_bytes())
        self.write('good.json', b'{"a": [1, 2]}\n')
        self.write('config/good.yaml', b'a: 1\nb: [x, y]\n')
        self.write('config/multi.yml', b'---\na: 1\n---\nb: 2\n')

    def write(self, rel, data):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def stage(self):
        git(self.root, 'add', '-A')


class RepositorySyntaxTests(unittest.TestCase):
    def run_checker(self, root=None, *args, python_args=('-I', '-B')):
        before = tree_digest(root) if root else None
        command = [PYTHON, *python_args, str(SCRIPT)]
        if root:
            command += ['--root', str(root)]
        result = subprocess.run([*command, *args], capture_output=True, text=True, check=False)
        if root:
            self.assertEqual(before, tree_digest(root), 'checker modified its inputs')
        self.assertNotIn(CANARY, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        return result.returncode, json.loads(result.stdout)

    def fixture(self):
        folder = tempfile.TemporaryDirectory(prefix='repository-syntax-')
        self.addCleanup(folder.cleanup)
        return Fixture(folder.name)

    def assert_only_failure(self, fixture, path, category):
        rc, report = self.run_checker(fixture.root)
        self.assertEqual(rc, 1, report)
        self.assertEqual(report['result'], 'fail')
        self.assertEqual(report['failures'], [{'path': path, 'category': category}])
        return report

    def test_repository_scan_passes_with_exact_exceptions_and_no_writes(self):
        before = {rel: sha(ROOT / rel) for rel in EXCEPTIONS}
        self.assertEqual(before, EXCEPTIONS)
        rc, report = self.run_checker()
        self.assertEqual((rc, report['result'], report['failures']), (0, 'pass', []), report)
        self.assertEqual(report['legacy_bom'], sorted(LEGACY_BOM))
        self.assertEqual(report['expected_negative'], sorted(EXPECTED_NEGATIVE))
        self.assertGreater(report['counts']['json'], 0)
        self.assertGreater(report['counts']['yaml'], 0)
        self.assertEqual({rel: sha(ROOT / rel) for rel in EXCEPTIONS}, before)

    def test_fixture_baseline_passes(self):
        fixture = self.fixture()
        fixture.stage()
        rc, report = self.run_checker(fixture.root)
        self.assertEqual(rc, 0, report)
        self.assertEqual(report['counts'], {'json': 9, 'yaml': 2, 'explicit': 0, 'untracked_unchecked': 0})
        self.assertTrue(report['complete_candidate_coverage'])
        self.assertEqual(report['legacy_bom'], sorted(LEGACY_BOM))
        self.assertEqual(report['expected_negative'], sorted(EXPECTED_NEGATIVE))

    def test_content_failures_fail_and_keep_allowed_history(self):
        cases = {
            'malformed JSON': ('bad.json', ('{"' + CANARY).encode(), 'invalid_json'),
            'invalid UTF-8 JSON': ('bad.json', b'{"a": "\xff"}', 'invalid_utf8'),
            'non-standard JSON constant': ('bad.json', b'{"a": NaN}', 'invalid_json'),
            'YAML-only text in JSON is not retried as YAML': ('bad.json', b'a: 1\n', 'invalid_json'),
            'malformed YAML': ('bad.yaml', ('a: [' + CANARY).encode(), 'invalid_yaml'),
            'invalid UTF-8 YAML': ('bad.yml', b'a: "\xff"\n', 'invalid_utf8'),
            'new BOM JSON': ('bad.json', b'\xef\xbb\xbf{}', 'bom'),
            'legacy BOM bytes at another path': (
                'copy.json', (ROOT / sorted(LEGACY_BOM)[0]).read_bytes(), 'bom'),
        }
        for name, (rel, data, category) in cases.items():
            with self.subTest(name):
                fixture = self.fixture()
                fixture.write(rel, data)
                fixture.stage()
                report = self.assert_only_failure(fixture, rel, category)
                self.assertEqual(report['legacy_bom'], sorted(LEGACY_BOM))
                self.assertEqual(report['expected_negative'], sorted(EXPECTED_NEGATIVE))

    def test_bom_yaml_is_valid_yaml(self):
        # A leading UTF-8 BOM is legal YAML syntax; only JSON is strict no-BOM.
        fixture = self.fixture()
        fixture.write('config/bom.yaml', b'\xef\xbb\xbfa: 1\nb: [x]\n')
        fixture.stage()
        rc, report = self.run_checker(fixture.root)
        self.assertEqual((rc, report['result'], report['failures']), (0, 'pass', []), report)
        self.assertEqual(report['counts']['yaml'], 3)
        fixture.write('config/bom.yaml', b'\xef\xbb\xbfa: [\n')
        self.assert_only_failure(fixture, 'config/bom.yaml', 'invalid_yaml')

    def test_exception_drift_fails(self):
        legacy, negative = sorted(LEGACY_BOM)[0], sorted(EXPECTED_NEGATIVE)[0]
        mutations = {
            'stale legacy BOM digest': (legacy, lambda f: f.write(legacy, (ROOT / legacy).read_bytes() + b' ')),
            'stale negative digest': (negative, lambda f: f.write(negative, (ROOT / negative).read_bytes() + b' ')),
            'accidentally repaired negative': (negative, lambda f: f.write(negative, b'{}')),
            'missing legacy record': (legacy, lambda f: (f.root / legacy).unlink()),
            'missing negative fixture': (negative, lambda f: (f.root / negative).unlink()),
        }
        for name, (rel, mutate) in mutations.items():
            with self.subTest(name):
                fixture = self.fixture()
                mutate(fixture)
                fixture.stage()
                category = 'missing_exception' if name.startswith('missing') else 'stale_exception'
                self.assert_only_failure(fixture, rel, category)

    def test_tracked_input_read_failures(self):
        fixture = self.fixture()
        fixture.stage()
        (fixture.root / 'good.json').unlink()
        self.assert_only_failure(fixture, 'good.json', 'missing')

        fixture = self.fixture()
        fixture.stage()
        (fixture.root / 'good.json').unlink()
        (fixture.root / 'good.json').mkdir()
        self.assert_only_failure(fixture, 'good.json', 'not_regular')

        fixture = self.fixture()
        outside = Path(fixture.root.parent) / 'outside.json'
        outside.write_bytes(b'{}')
        (fixture.root / 'link.json').symlink_to(outside)
        fixture.stage()
        self.assert_only_failure(fixture, 'link.json', 'symlink')

    def test_unreadable_tracked_input_fails(self):
        fixture = self.fixture()
        fixture.stage()
        unreadable = fixture.root / 'good.json'
        unreadable.chmod(0)
        self.addCleanup(unreadable.chmod, 0o644)
        if os.access(unreadable, os.R_OK):
            self.skipTest('privileged user can read mode 000 files')
        self.assert_only_failure(fixture, 'good.json', 'unreadable')

    def test_unvalidated_untracked_candidates_fail_without_disclosure(self):
        # Neither content nor path of an unvalidated untracked file may appear.
        secret = f'new/{CANARY}.json'
        fixture = self.fixture()
        fixture.stage()
        fixture.write(secret, ('{"' + CANARY).encode())
        fixture.write(f'new/{CANARY}.yaml', b'a: 1\n')
        rc, report = self.run_checker(fixture.root)
        self.assertEqual((rc, report['result']), (1, 'fail'), report)
        self.assertEqual(report['failures'], [])
        self.assertEqual(report['counts']['untracked_unchecked'], 2)
        self.assertFalse(report['complete_candidate_coverage'])
        self.assertEqual((report['counts']['json'], report['counts']['yaml']), (9, 2))

        # Explicitly naming only one of them still leaves coverage incomplete.
        rc, report = self.run_checker(fixture.root, '--path', f'new/{CANARY}.yaml')
        self.assertEqual((rc, report['result'], report['counts']['untracked_unchecked']), (1, 'fail', 1), report)
        self.assertFalse(report['complete_candidate_coverage'])

    def test_untracked_candidates_validated_by_path_or_staging(self):
        fixture = self.fixture()
        fixture.stage()
        fixture.write('new/bad.json', b'{')
        rc, report = self.run_checker(fixture.root, '--path', 'new/bad.json')
        self.assertEqual(rc, 1, report)
        self.assertEqual(report['failures'], [{'path': 'new/bad.json', 'category': 'invalid_json'}])
        self.assertEqual((report['counts']['explicit'], report['counts']['untracked_unchecked']), (1, 0))
        self.assertTrue(report['complete_candidate_coverage'])

        git(fixture.root, 'add', 'new/bad.json')
        self.assert_only_failure(fixture, 'new/bad.json', 'invalid_json')

        fixture.write('new/bad.json', b'{"ok": true}')
        rc, report = self.run_checker(fixture.root, '--path', 'new/bad.json')
        self.assertEqual((rc, report['counts']['json'], report['counts']['explicit']), (0, 10, 0), report)

        fixture.write('config/new.yaml', b'a: 1\n')
        rc, report = self.run_checker(fixture.root, '--path', 'config/new.yaml')
        self.assertEqual((rc, report['result'], report['counts']['explicit']), (0, 'pass', 1), report)
        self.assertTrue(report['complete_candidate_coverage'])

    def runtime_fixture(self):
        """Fixture with the repository's real .gitignore, staged before the weekly prepare writes its outputs."""
        fixture = self.fixture()
        fixture.write('.gitignore', (ROOT / '.gitignore').read_bytes())
        fixture.stage()
        for name, schema in RUNTIME_OUTPUTS.items():
            fixture.write(f'{RUNTIME}/{name}', json.dumps({'schema': schema}).encode())
        fixture.write(f'{RUNTIME}/claude-sdk-entry', b'#!/usr/bin/env python3\n')
        return fixture

    def git_list(self, root, *args):
        out = subprocess.run(['git', '-C', str(root), 'ls-files', *args],
                             capture_output=True, text=True, check=True).stdout
        return set(out.splitlines())

    def test_root_runtime_outputs_are_ignored_and_coverage_passes(self):
        fixture = self.runtime_fixture()
        runtime = {f'{RUNTIME}/{name}' for name in (*RUNTIME_OUTPUTS, 'claude-sdk-entry')}
        rc, report = self.run_checker(fixture.root)
        self.assertEqual((rc, report['result'], report['failures']), (0, 'pass', []), report)
        self.assertEqual(report['counts'], {'json': 9, 'yaml': 2, 'explicit': 0, 'untracked_unchecked': 0})
        self.assertTrue(report['complete_candidate_coverage'])
        fixture.stage()  # the normal staging command must not pick up runtime controls either
        self.assertFalse(runtime & self.git_list(fixture.root, '--cached'))
        self.assertEqual(runtime, self.git_list(fixture.root, '--others', '--ignored', '--exclude-standard')
                         & runtime)

    def test_runtime_ignore_does_not_hide_other_candidates(self):
        unrelated = 'notes.json'
        similar = ('docs/.sdd-self-improvement/a.json', 'plugins/x/.sdd-self-improvement/b.yaml',
                   '.sdd-self-improvement-notes/c.json', 'sdd-self-improvement/d.json')
        for paths in ((unrelated,), similar):
            with self.subTest(paths=paths):
                fixture = self.runtime_fixture()
                for rel in paths:
                    fixture.write(rel, b'{}')
                self.assertEqual(set(paths), self.git_list(fixture.root, '--others', '--exclude-standard'))
                rc, report = self.run_checker(fixture.root)
                self.assertEqual((rc, report['result'], report['failures']), (1, 'fail', []), report)
                self.assertEqual(report['counts']['untracked_unchecked'], len(paths))
                self.assertFalse(report['complete_candidate_coverage'])

    def test_force_added_malformed_runtime_json_still_fails(self):
        fixture = self.runtime_fixture()
        rel = f'{RUNTIME}/controls.json'
        fixture.write(rel, b'{')
        git(fixture.root, 'add', '-f', rel)
        self.assertIn(rel, self.git_list(fixture.root, '--cached'))
        report = self.assert_only_failure(fixture, rel, 'invalid_json')
        self.assertEqual(report['counts']['untracked_unchecked'], 0)

    def test_usage_and_dependency_errors(self):
        fixture = self.fixture()
        fixture.stage()
        # Non-portable spellings are rejected lexically even when a same-named file
        # exists on this platform, so a Windows drive or UNC path cannot escape --root.
        for name in ('C:/x.json', 'C:x.json', 'sub\\good.json'):
            fixture.write(name, b'{}')
        for path in ('/abs.json', '../x.json', 'a/../good.json', 'notes.txt', 'absent.json', '',
                     'C:/x.json', 'C:x.json', 'c:\\x.json', 'sub\\good.json', '\\\\server\\share\\x.json',
                     '//server/share/x.json', '/C:/x.json', './good.json', 'config//good.yaml',
                     'config/./good.yaml', 'config/good.yaml/'):
            with self.subTest(path):
                rc, report = self.run_checker(fixture.root, '--path', path)
                self.assertEqual((rc, report['result'], report['category']), (2, 'error', 'usage'), report)
        rc, report = self.run_checker(fixture.root.parent)
        self.assertEqual((rc, report['category']), (2, 'usage'), report)
        # -S hides site-packages, so the general YAML parser is unavailable.
        rc, report = self.run_checker(fixture.root, python_args=('-I', '-B', '-S'))
        self.assertEqual((rc, report['result'], report['category']), (2, 'error', 'dependency_missing'), report)

    def test_argument_errors_use_the_json_envelope_without_echo(self):
        fixture = self.fixture()
        fixture.stage()
        cases = {
            'unknown option': (fixture.root, '--' + CANARY),
            'unknown option value': (fixture.root, '--exclude=' + CANARY),
            'stray positional': (fixture.root, CANARY),
            'missing --path value': (fixture.root, '--path'),
            'missing --root value': (None, '--root'),
        }
        for name, (root, *args) in cases.items():
            with self.subTest(name):
                rc, report = self.run_checker(root, *args)
                self.assertEqual((rc, report), (2, {'schema': 'repository-syntax-check/v1',
                                                    'result': 'error', 'category': 'usage'}))
        # --help keeps argparse's normal text and success exit.
        result = subprocess.run([PYTHON, '-I', '-B', str(SCRIPT), '--help'],
                                capture_output=True, text=True, check=False)
        self.assertEqual((result.returncode, result.stderr), (0, ''))
        self.assertTrue(result.stdout.startswith('usage:'), result.stdout)


if __name__ == '__main__':
    unittest.main()
