#!/usr/bin/env python3
"""Detached progress cannot grant task lifecycle or alter fixed inputs."""
import copy
import hashlib
import hmac
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'plugins/sdd-review-loop/scripts/fixed-review-state.py'


class StateTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('detached_state', SCRIPT)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Fixture')
        (self.repo / 'tasks.md').write_text('## T-001 Example\nApproval: Draft\nStatus: Planned\n')
        self.git('add', 'tasks.md')
        self.git('commit', '-qm', 'fixture')
        commit = self.git('rev-parse', 'HEAD').strip()
        data = (self.repo / 'tasks.md').read_bytes()
        self.inventory = {'commit': commit, 'inputs': [{'path': 'tasks.md', 'mode': '100644',
                          'sha256': hashlib.sha256(data).hexdigest()}]}
        self.key = b'synthetic-test-key-not-a-credential'
        self.scope = dict(feature='demo', stage='impl', task_id='T-001')
        self.trust = dict(key=self.key, registry_ids={'fixture-human'})
        self.approval = self.sign({'schema': 'sdd-fixed-review-approval/v1', **self.inventory,
            **self.scope, 'primary_approval': {'approver': 'fixture-human'},
            'effective_at': '2020-01-01T00:00:00Z'})

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)

    def sign(self, value):
        value.pop('hmac', None)
        value['hmac'] = hmac.new(self.key, self.module.auth._canonicalize_json_preimage(value),
                                 hashlib.sha256).hexdigest()
        return value

    def create(self, progress='prepared'):
        return self.module.create(self.repo, self.inventory, self.approval,
                                  progress=progress, **self.scope, **self.trust)

    def verify(self, value):
        return self.module.verify(value, self.repo, self.inventory, **self.scope, **self.trust)

    def test_roundtrip_preserves_historical_draft_and_records_progress(self):
        for progress in ('prepared', 'running', 'completed', 'blocked'):
            record = self.create(progress)
            self.verify(record)
            self.assertEqual(record['progress'], progress)
            self.assertIn('Approval: Draft', [f['text'] for f in record['source_state']['fields']])
        self.assertIn('Approval: Draft', (self.repo / 'tasks.md').read_text())

    def test_unsigned_tampering_and_signed_scope_schema_state_mutations_rejected(self):
        record = self.create()
        for field, value in [('schema', 'other'), ('feature', 'other'), ('stage', 'task'),
                             ('task_id', 'T-002'), ('source_state', {}), ('progress', 'Done'),
                             ('progress', 'PASS'), ('inventory', {'commit': 'a' * 40, 'inputs': []})]:
            for resign in (False, True):
                with self.subTest(field=field, value=value, resign=resign):
                    changed = copy.deepcopy(record)
                    changed[field] = value
                    if resign:
                        self.sign(changed)
                    with self.assertRaises(Exception):
                        self.verify(changed)

    def test_invalid_embedded_approval_rejected_even_with_valid_outer_hmac(self):
        for field, value in [('hmac', '0' * 64), ('primary_approval', {'approver': 'unknown'}),
                             ('effective_at', '2999-01-01T00:00:00Z')]:
            record = self.create()
            record['approval'][field] = value
            if field != 'hmac':
                self.sign(record['approval'])
            self.sign(record)
            with self.subTest(field=field), self.assertRaises(Exception):
                self.verify(record)

    def test_git_input_and_trusted_inventory_substitution_rejected(self):
        changed = copy.deepcopy(self.inventory)
        changed['inputs'][0]['sha256'] = 'b' * 64
        self.approval['inputs'] = changed['inputs']
        self.sign(self.approval)
        with self.assertRaises(ValueError):
            self.module.create(self.repo, changed, self.approval, progress='prepared',
                               **self.scope, **self.trust)

    def test_output_is_exclusive_and_outside_selected_source_paths(self):
        destination = self.repo / 'state.json'
        record = self.create()
        self.module.persist(destination, record, self.repo, self.inventory)
        original = destination.read_bytes()
        with self.assertRaises(FileExistsError):
            self.module.persist(destination, record, self.repo, self.inventory)
        self.assertEqual(destination.read_bytes(), original)
        with self.assertRaises(ValueError):
            self.module.persist(self.repo / 'tasks.md', record, self.repo, self.inventory)

    def test_cli_uses_canonical_key_registry_and_rejects_malformed_records(self):
        (self.repo / 'sdd').mkdir()
        (self.repo / 'sdd/approver-registry.yaml').write_text(
            'schema: sdd-approver-registry/v1\napprovers:\n'
            '  - id: fixture-human\n    name: Fixture Human\n')
        inventory_path = self.repo / 'inventory.json'
        approval_path = self.repo / 'approval.json'
        record_path = self.repo / 'record.json'
        inventory_path.write_text(json.dumps(self.inventory))
        approval_path.write_text(json.dumps(self.approval))
        common = ['--repo', str(self.repo), '--inventory', str(inventory_path),
                  '--record', str(record_path), '--feature', 'demo', '--stage', 'impl',
                  '--task-id', 'T-001']
        environment = {**os.environ, 'SDD_CONTEXT_KEY': self.key.decode()}
        def run(operation, *extra):
            return subprocess.run([sys.executable, str(SCRIPT), operation, *common, *extra],
                                  env=environment, capture_output=True, text=True)
        result = run('record', '--approval', str(approval_path), '--progress', 'running')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(run('verify').returncode, 0)
        self.assertNotEqual(run('record', '--approval', str(approval_path),
                                '--progress', 'running').returncode, 0)
        value = json.loads(record_path.read_text())
        value['approval']['hmac'] = '0' * 64
        record_path.write_text(json.dumps(self.sign(value)))
        result = run('verify')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('FIXED_STATE_STOPPED', result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        record_path.write_text('{"schema":"a","schema":"b"}')
        self.assertNotEqual(run('verify').returncode, 0)

    def test_cli_without_task_matches_feature_review_scope(self):
        (self.repo / 'sdd').mkdir()
        (self.repo / 'sdd/approver-registry.yaml').write_text(
            'schema: sdd-approver-registry/v1\napprovers:\n'
            '  - id: fixture-human\n    name: Fixture Human\n')
        self.approval['task_id'] = None
        self.sign(self.approval)
        for name, value in [('inventory', self.inventory), ('approval', self.approval)]:
            (self.repo / (name + '.json')).write_text(json.dumps(value))
        common = ['--repo', str(self.repo), '--inventory', str(self.repo / 'inventory.json'),
                  '--record', str(self.repo / 'record.json'), '--feature', 'demo', '--stage', 'impl']
        def run(operation, *extra):
            return subprocess.run([sys.executable, str(SCRIPT), operation, *common, *extra],
                                  env={**os.environ, 'SDD_CONTEXT_KEY': self.key.decode()},
                                  capture_output=True, text=True)
        result = run('record', '--approval', str(self.repo / 'approval.json'), '--progress', 'prepared')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(run('verify').returncode, 0)
        self.assertIsNone(json.loads((self.repo / 'record.json').read_text())['task_id'])
        self.assertNotEqual(run('verify', '--task-id', 'T-001').returncode, 0)


if __name__ == '__main__':
    unittest.main()
