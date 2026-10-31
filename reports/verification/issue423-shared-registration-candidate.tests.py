#!/usr/bin/env python3
"""Disposable candidate checks; never apply the patch to the owner checkout."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LOOP = Path('plugins/sdd-quality-loop')
PATCH = Path(__file__).with_name('issue423-shared-registration-candidate-20261007.patch')
TARGETS = [
    'plugins/sdd-review-loop/scripts/launch-impl-review.py',
    'plugins/sdd-review-loop/scripts/preflight-host-review.py',
    'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py',
    'plugins/sdd-review-loop/scripts/probe-nontty-review.py',
    'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs',
    'plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py',
]


class RegistrationCandidate(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='issue423-registration-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / LOOP, self.root / LOOP)
        self.canonical = self.root / LOOP / 'references/guard-invariants.json'
        self.generator = self.root / LOOP / 'scripts/generate-guard-invariants.py'
        # Support verification both before and after owner application; reversal
        # is confined to this disposable copy, never the owner checkout.
        if self.run_command(['git', 'apply', '--check', str(PATCH)]).returncode:
            self.run_command(['git', 'apply', '--reverse', str(PATCH)], check=True)
        self.before_canonical = self.canonical.read_bytes()
        self.before_generator = self.generator.read_bytes()
        self.run_command(['git', 'apply', str(PATCH)], check=True)

    def run_command(self, command, *, check=False, payload=None):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
        if payload is not None:
            env['PAYLOAD'] = json.dumps(payload)
        return subprocess.run(['rtk', 'proxy', *command], cwd=self.root,
                              env=env, input=json.dumps(payload) if payload is not None else None,
                              text=True, capture_output=True, check=check)

    def test_exact_additive_inventory(self):
        before = json.loads(self.before_canonical)
        after = json.loads(self.canonical.read_bytes())
        self.assertEqual(set(after['protected_gate_suffixes']) -
                         set(before['protected_gate_suffixes']), set(TARGETS))
        self.assertEqual([p for p in after['protected_gate_suffixes'] if p not in TARGETS],
                         before['protected_gate_suffixes'])
        for key in before.keys() - {'protected_gate_suffixes'}:
            self.assertEqual(after[key], before[key])

    def test_generated_check_and_idempotence(self):
        self.run_command(['python3', '-B', str(self.generator), '--check'], check=True)
        outputs = sorted((self.generator.parent / 'generated').glob('guard*'))
        before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in outputs if p.is_file()}
        self.run_command(['python3', '-B', str(self.generator)], check=True)
        self.assertEqual(before, {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in before})
        self.run_command(['python3', '-B', str(self.generator), '--check'], check=True)
        output = self.generator.parent / 'generated/guard_invariants.py'
        output.write_bytes(output.read_bytes() + b'\n')
        self.assertNotEqual(self.run_command(['python3', '-B', str(self.generator), '--check']).returncode, 0)

    def test_generator_only_and_canonical_only_rejected(self):
        candidate_canonical = self.canonical.read_bytes()
        self.canonical.write_bytes(self.before_canonical)
        self.assertNotEqual(self.run_command(['python3', '-B', str(self.generator), '--check']).returncode, 0)
        self.canonical.write_bytes(candidate_canonical)
        self.generator.write_bytes(self.before_generator)
        self.assertNotEqual(self.run_command(['python3', '-B', str(self.generator), '--check']).returncode, 0)

    def test_four_runtime_write_denial_and_read_allowance(self):
        scripts = self.root / LOOP / 'scripts'
        runtimes = [('python3', '-B', str(scripts / 'sdd-hook-guard.py')),
                    ('node', str(scripts / 'sdd-hook-guard.js')),
                    ('bash', str(scripts / 'sdd-hook-guard.sh')),
                    ('pwsh', '-NoProfile', '-File', str(scripts / 'sdd-hook-guard.ps1'))]
        for runtime in runtimes:
            self.assertIsNotNone(shutil.which(runtime[0]), runtime[0] + ' is required')
            for path in TARGETS:
                with self.subTest(runtime=runtime[0], path=path):
                    denied = self.run_command([*runtime, '--emit', 'exit'], payload={
                        'tool_name': 'write', 'tool_input': {'file_path': path, 'content': 'x'}})
                    self.assertEqual(denied.returncode, 2, denied.stdout + denied.stderr)
                    allowed = self.run_command([*runtime, '--emit', 'exit'], payload={
                        'tool_name': 'bash', 'tool_input': {'command': 'cat ' + path}})
                    self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)


if __name__ == '__main__':
    unittest.main()
