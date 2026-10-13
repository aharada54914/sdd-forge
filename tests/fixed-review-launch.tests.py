#!/usr/bin/env python3
"""Fixed input transport admission and read-only permissions."""
import importlib.util
import ast
import hashlib
import hmac
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'plugins/sdd-review-loop/scripts'


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), SCRIPTS / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FixedLaunchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name).resolve()
        self.root = self.base / 'repo'
        self.root.mkdir()
        self.transport = load('validate-nontty-spec-launch')
        self.helper = load('fixed-review-inputs')
        self.selected = ['specs/demo/design.md', 'specs/demo/tasks.md']
        for name in self.selected:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('Approval: Approved\n')
        for args in [('init', '-q'), ('config', 'user.name', 'Fixture'),
                     ('config', 'user.email', 'fixture@example.invalid'), ('add', '.'),
                     ('commit', '-qm', 'fixture')]:
            subprocess.run(['git', '-C', str(self.root), *args], check=True, capture_output=True)
        commit = subprocess.check_output(['git', '-C', str(self.root), 'rev-parse', 'HEAD'], text=True).strip()
        self.snapshot = self.base / 'snapshot'
        self.inventory = self.helper.materialize(self.root, commit, self.selected, self.snapshot)
        self.record = self.base / 'record.json'
        self.record.write_text(json.dumps(self.inventory))
        self.data = {'stage': 'impl', 'role': 'impl-reviewer-a', 'feature': 'demo',
                     'allowed_input_manifest': [{'path': p, 'sha256': self.transport.sha(self.root / p)}
                                                for p in self.selected]}
        self.invocation = self.root / 'invocation.json'
        self.invocation.write_text('{}')
        boundary = self.root / self.transport.BOUNDARY_PATH
        boundary.parent.mkdir(parents=True, exist_ok=True)
        boundary.write_text('boundary')
        self.receipt = self.root / 'receipt.txt'
        self.receipt.write_text('REVIEW_CONTEXT_OK ' + 'a' * 64 +
                               ' sequence=1 previous_record_sha256=- pre_append_tip_sequence=- identity_unique=yes\n')

    def binding(self):
        return self.transport.fixed_input_binding(self.root, self.data, self.record, self.snapshot)

    def test_evaluator_preview_and_reservation_use_identical_fixed_binding(self):
        delivery = load('../../sdd-quality-loop/scripts/preflight-evaluator-delivery')
        document = dict(self.data, schema='review-context-invocation/v2',
                        stage='quality', role='sdd-evaluator', read_only=True)
        self.invocation.write_text(json.dumps(document))
        success = subprocess.CompletedProcess([], 0, '', '')
        with patch.object(delivery.subprocess, 'run', return_value=success) as run:
            count = delivery.check(self.invocation, delivery.digest(self.invocation.read_bytes()),
                                   self.root, reserve=True, fixed_input_record=self.record,
                                   fixed_input_snapshot=self.snapshot)
        self.assertEqual(count, 2)
        preview, reservation = [call.args[0] for call in run.call_args_list]
        self.assertEqual(reservation, preview + ['--reserve'])
        self.assertEqual(preview[-4:], ['--fixed-input-record', str(self.record),
                                      '--fixed-input-snapshot', str(self.snapshot)])

    def test_evaluator_rejection_never_reaches_reservation(self):
        delivery = load('../../sdd-quality-loop/scripts/preflight-evaluator-delivery')
        self.invocation.write_text(json.dumps(dict(self.data, schema='review-context-invocation/v2',
                                                  stage='quality', role='sdd-evaluator', read_only=True)))
        pinned = delivery.digest(self.invocation.read_bytes())
        with patch.object(delivery.subprocess, 'run') as run:
            with self.assertRaisesRegex(delivery.DeliveryError, 'fixed-input-pair-required'):
                delivery.check(self.invocation, pinned, self.root, reserve=True,
                               fixed_input_record=self.record)
            run.assert_not_called()
            run.return_value = subprocess.CompletedProcess([], 1, '', 'REVIEW_CONTEXT_HASH: rejected')
            with self.assertRaisesRegex(delivery.DeliveryError, 'canonical-hash'):
                delivery.check(self.invocation, pinned, self.root, reserve=True,
                               fixed_input_record=self.record, fixed_input_snapshot=self.snapshot)
            self.assertEqual(run.call_count, 1)
            self.assertNotIn('--reserve', run.call_args.args[0])

    def test_stage_admission_includes_only_verified_detached_references(self):
        launcher = load('launch-impl-review')
        precheck = self.root / 'precheck.json'
        precheck.write_text(json.dumps({'schema': 'impl-review-precheck/v1',
                                      'feature': 'demo', 'attempt': 1, 'round': 1}))
        binding = {'approval_reference': {'path': 'reports/review-context/fixed-approvals/a.json',
                                          'sha256': 'a' * 64},
                   'progress_reference': {'path': 'reports/review-context/fixed-states/s.json',
                                          'sha256': 'b' * 64}}
        self.data['allowed_input_manifest'].append({'path': 'reports/untrusted.json', 'sha256': 'c' * 64})
        with patch.object(launcher, 'required_dependencies', return_value={'inputs': []}):
            legacy = launcher.required_input_paths(self.root, self.data, precheck, 1, 1)
            fixed = launcher.required_input_paths(self.root, self.data, precheck, 1, 1, binding)
        self.assertEqual(fixed - legacy, {ref['path'] for ref in binding.values()})
        self.assertNotIn('reports/untrusted.json', fixed)

    def test_signed_approval_is_checked_on_actual_binding_path(self):
        source_root = SCRIPTS.parents[2]
        for name in ('plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py',
                     'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py',
                     'contracts/approver-registry.schema.json'):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source_root / name, target)
        registry = self.root / 'sdd/approver-registry.yaml'
        registry.parent.mkdir()
        registry.write_text('schema: sdd-approver-registry/v1\napprovers:\n'
                            '  - id: fixture-human\n    name: Fixture\n')
        name = 'reports/review-context/fixed-approvals/approval.json'
        target = self.root / name
        target.parent.mkdir(parents=True)
        document = {'schema': 'sdd-fixed-review-approval/v1', **self.inventory,
                    'feature': 'demo', 'stage': 'impl', 'task_id': None,
                    'primary_approval': {'approver': 'fixture-human'},
                    'effective_at': '2020-01-01T00:00:00Z'}
        spec = importlib.util.spec_from_file_location('fixture_auth',
            source_root / 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py')
        auth = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(auth)
        key = 'synthetic-fixed-approval-test-key'
        document['hmac'] = hmac.new(key.encode(), auth._canonicalize_json_preimage(document),
                                    hashlib.sha256).hexdigest()
        target.write_text(json.dumps(document))
        entry = {'path': name, 'sha256': self.transport.sha(target)}
        self.data['allowed_input_manifest'].append(entry)
        with patch.dict(os.environ, {'SDD_CONTEXT_KEY': key}):
            self.assertEqual(self.binding()['inventory'], self.inventory)
            self.assertEqual(self.binding()['approval_reference'], entry)
            state = load('fixed-review-state')
            state_document = state.create(self.root, self.inventory, document,
                feature='demo', stage='impl', task_id=None, progress='prepared',
                key=key.encode(), registry_ids={'fixture-human'})
            state_path = self.root / 'reports/review-context/fixed-states/prepared.json'
            state_path.parent.mkdir(parents=True)
            state_path.write_text(json.dumps(state_document))
            state_entry = {'path': state_path.relative_to(self.root).as_posix(),
                           'sha256': self.transport.sha(state_path)}
            self.data['allowed_input_manifest'].append(state_entry)
            self.assertEqual(self.binding()['progress_reference'], state_entry)
            state_path.write_text(json.dumps({**state_document, 'progress': 'completed'}))
            with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                self.binding()
            state_entry['sha256'] = self.transport.sha(state_path)
            with self.assertRaisesRegex(Exception, 'HMAC'):
                self.binding()
            state_path.write_text(json.dumps(state_document))
            state_entry['sha256'] = self.transport.sha(state_path)
            self.assertEqual(self.binding()['progress_reference'], state_entry)
            other_path = state_path.with_name('other.json')
            other_path.write_text(json.dumps(state_document))
            self.data['allowed_input_manifest'].append({
                'path': other_path.relative_to(self.root).as_posix(),
                'sha256': self.transport.sha(other_path)})
            with self.assertRaisesRegex(ValueError, 'multiple fixed states'):
                self.binding()
            self.data['allowed_input_manifest'].pop()
            self.data['allowed_input_manifest'].remove(state_entry)
            target.write_text(json.dumps({**document, 'feature': 'other'}))
            with self.assertRaisesRegex(ValueError, 'admitted input hash mismatch'):
                self.binding()
            entry['sha256'] = self.transport.sha(target)
            with self.assertRaisesRegex(ValueError, 'scope mismatch'):
                self.binding()
            target.write_text(json.dumps({**document, 'hmac': '0' * 64}))
            entry['sha256'] = self.transport.sha(target)
            with self.assertRaisesRegex(Exception, 'HMAC'):
                self.binding()
            target.write_text(json.dumps(document))
            entry['sha256'] = self.transport.sha(target)
            registry.unlink()
            with self.assertRaisesRegex(Exception, 'registered'):
                self.binding()

    def test_fixed_binding_rejects_manifest_hash_mismatch(self):
        self.data['allowed_input_manifest'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.binding()

    def test_fixed_binding_accepts_canonically_verified_normalized_task(self):
        self.data['stage'] = 'task'
        normalized = 'a' * 64
        self.data['allowed_input_manifest'][1]['sha256'] = normalized
        name = 'reports/task-review/demo/attempt-1/round-1/precheck-result.json'
        target = self.root / name
        target.parent.mkdir(parents=True)
        target.write_text(json.dumps(dict(schema='task-review-precheck/v1',
            feature='demo', attempt=1, round=1, tasks_sha256_form='normalized',
            tasks_sha256=normalized)))
        self.data['allowed_input_manifest'].append(dict(path=name, sha256=self.transport.sha(target)))
        real_run = subprocess.run
        def canonical_run(argv, **kwargs):
            if argv[:3] == ['rtk', 'proxy', 'bash']:
                return subprocess.CompletedProcess(argv, 0)
            return real_run(argv, **kwargs)
        with patch.object(self.transport.subprocess, 'run', side_effect=canonical_run):
            self.assertEqual(self.binding()['inventory'], self.inventory)
        with patch.object(self.transport.subprocess, 'run', side_effect=lambda argv, **kw:
                subprocess.CompletedProcess(argv, 1) if argv[:3] == ['rtk', 'proxy', 'bash']
                else real_run(argv, **kw)):
            with self.assertRaisesRegex(ValueError, 'canonical normalized task verification failed'):
                self.binding()

    def test_fixed_binding_rejects_malformed_inventory(self):
        for value in [None, [], {}, {'commit': self.inventory['commit'], 'inputs': [None]},
                      {'commit': self.inventory['commit'], 'inputs': [{}]}]:
            with self.subTest(value=value):
                self.record.write_text(json.dumps(value))
                with self.assertRaisesRegex(ValueError, 'invalid snapshot'):
                    self.binding()

    def test_fixed_binding_rejects_duplicate_manifest_path(self):
        self.data['allowed_input_manifest'].append(dict(self.data['allowed_input_manifest'][0]))
        with self.assertRaisesRegex(ValueError, 'duplicate manifest'):
            self.binding()

    def native_fixture(self, stage, omit=0, failed=False, empty=False, pages=None):
        if pages:
            self.invocation.write_text('{\n  "fixture": true\n}\n')
        session = str(uuid.uuid4())
        data = dict(self.data, stage=stage, role=stage + '-reviewer-a',
                    host_session_id=session, sequence=1, previous_record_sha256='-')
        control = dict(record_sha256='a' * 64, inputs_sha256='b' * 64)
        record = dict(data, run_id=session, record_sha256='a' * 64,
                      allowed_inputs_sha256='b' * 64)
        binding = self.binding()
        paths = self.transport.review_read_paths(self.root, self.invocation, data, binding)
        messages = []
        def turn(kind, content):
            messages.append(dict(type=kind, sessionId=session, message=dict(content=content)))
        turn('user', 'canonical')
        for index, target in enumerate(paths[:len(paths) - omit]):
            if pages:
                lines = target.read_text().splitlines()
                if pages == 'partial' and target == self.invocation:
                    lines = lines[:-1]
                for number, line in enumerate(lines, 1):
                    if pages == 'changed' and target == self.invocation and number == 1:
                        line += 'changed'
                    identity = f'{index}-{number}'
                    turn('assistant', [dict(type='tool_use', id=identity, name='Read',
                                            input=dict(file_path=str(target), offset=number, limit=1))])
                    turn('user', [dict(type='tool_result', tool_use_id=identity,
                                      content=f'{number}→{line}', is_error=False)])
                continue
            turn('assistant', [dict(type='tool_use', id=str(index), name='Read',
                                    input=dict(file_path=str(target)))])
            turn('user', [dict(type='tool_result', tool_use_id=str(index),
                               content='' if empty else target.read_text(), is_error=failed)])
        turn('assistant', [dict(type='tool_use', id='output', name='StructuredOutput', input={})])
        turn('user', [dict(type='tool_result', tool_use_id='output', content='ok', is_error=False)])
        transcript = self.base / (session + '.jsonl')
        transcript.write_text('\n'.join(json.dumps(item) for item in messages))
        prompt = self.base / 'prompt.txt'
        prompt.write_text('canonical')
        wrapper = self.base / 'wrapper.json'
        wrapper.write_text(json.dumps(dict(type='result', session_id=session, is_error=False)))
        with patch.object(self.transport, 'manifest', return_value=(data, {'records': [record]})), \
                patch.object(self.transport, 'receipt_control', return_value=control), \
                patch.object(self.transport, 'expected_prompt', return_value=b'canonical'):
            return self.transport.native_delivery(self.root, self.invocation, transcript, prompt,
                                                  wrapper, self.receipt, strict=True, fixed_inputs=binding)

    def test_fixed_delivery_requires_all_successful_reads(self):
        for stage in ('spec', 'impl', 'task'):
            for omit in (1, 4):
                with self.subTest(stage=stage, omit=omit), self.assertRaisesRegex(ValueError, 'Read'):
                    self.native_fixture(stage, omit=omit)
            with self.subTest(stage=stage, failed=True), self.assertRaisesRegex(ValueError, 'Read'):
                self.native_fixture(stage, failed=True)
            with self.subTest(stage=stage, complete=True):
                self.native_fixture(stage)

    def test_fixed_delivery_rejects_empty_success_results(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage), self.assertRaisesRegex(ValueError, 'Read'):
                self.native_fixture(stage, empty=True)

    def test_fixed_delivery_accepts_complete_paginated_reads(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage):
                self.native_fixture(stage, pages='complete')

    def test_fixed_delivery_rejects_partial_paginated_reads(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage), self.assertRaisesRegex(ValueError, 'Read'):
                self.native_fixture(stage, pages='partial')

    def test_fixed_delivery_rejects_substituted_paginated_content(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage), self.assertRaisesRegex(ValueError, 'Read'):
                self.native_fixture(stage, pages='changed')

    def test_legacy_and_unpaired_flags(self):
        self.assertIsNone(self.transport.fixed_input_binding(self.root, self.data))
        with self.assertRaisesRegex(ValueError, 'paired'):
            self.transport.fixed_input_binding(self.root, self.data, self.record)

    def test_detached_execution_binds_inputs_without_mutating_them(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        record = output / 'fixed-execution.json'
        self.assertEqual(digest, self.transport.sha(record))
        document = json.loads(record.read_text())
        self.assertEqual(document['inputs'], self.inventory)
        self.assertEqual(document['state_reference'],
                         self.helper.state_reference(self.root, self.inventory))
        self.assertEqual(document['invocation_sha256'], self.transport.sha(self.invocation))
        self.assertNotIn('approval', document)
        self.helper.verify(self.snapshot, self.inventory)
        with self.assertRaises(FileExistsError):
            self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())

    def test_detached_delivery_binds_exact_bytes_and_rejects_overwrite(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        (output / 'delivery.json').write_text('{"delivered":true}')
        self.transport.record_fixed_delivery(output, digest)
        document = json.loads((output / 'fixed-delivery.json').read_text())
        self.assertEqual(document['execution_sha256'], digest)
        self.assertEqual(document['delivery_sha256'], self.transport.sha(output / 'delivery.json'))
        self.assertNotIn('verdict', document)
        self.transport.verify_fixed_delivery(output, digest, self.invocation)
        self.helper.verify(self.snapshot, self.inventory)
        with self.assertRaises(FileExistsError):
            self.transport.record_fixed_delivery(output, digest)

    def test_detached_delivery_rejects_changed_execution(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        (output / 'fixed-execution.json').write_text('{}')
        (output / 'delivery.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'binding changed'):
            self.transport.record_fixed_delivery(output, digest)
        self.assertFalse((output / 'fixed-delivery.json').exists())

    def test_detached_delivery_consumer_rejects_substitution(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        (output / 'delivery.json').write_text('{"delivered":true}')
        self.transport.record_fixed_delivery(output, digest)
        for path in (output / 'fixed-execution.json', output / 'fixed-delivery.json',
                     output / 'delivery.json', self.invocation):
            with self.subTest(path=path.name):
                original = path.read_bytes()
                path.write_text('{"substituted":true}')
                with self.assertRaises(ValueError):
                    self.transport.verify_fixed_delivery(output, digest, self.invocation)
                path.write_bytes(original)
        self.transport.verify_fixed_delivery(output, digest, self.invocation)

    def test_detached_delivery_consumer_rejects_symlink_and_duplicate_keys(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        delivery = output / 'delivery.json'
        delivery.write_text('{}')
        self.transport.record_fixed_delivery(output, digest)
        delivery.unlink()
        delivery.symlink_to(self.invocation)
        with self.assertRaisesRegex(ValueError, 'symlinked'):
            self.transport.verify_fixed_delivery(output, digest, self.invocation)
        delivery.unlink()
        delivery.write_text('{}')
        record = output / 'fixed-delivery.json'
        record.write_text('{"schema":"duplicate",' + record.read_text()[1:])
        with self.assertRaisesRegex(ValueError, 'duplicate JSON key'):
            self.transport.verify_fixed_delivery(output, digest, self.invocation)

    def test_detached_delivery_requires_actual_delivery(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        with self.assertRaises(FileNotFoundError):
            self.transport.record_fixed_delivery(output, digest)
        self.assertFalse((output / 'fixed-delivery.json').exists())

    def test_detached_delivery_producer_rejects_symlinks(self):
        output = self.base / 'execution'
        output.mkdir()
        digest = self.transport.record_fixed_execution(output, self.invocation, self.data, self.binding())
        (output / 'delivery.json').write_text('{}')
        for name in ('fixed-execution.json', 'delivery.json'):
            with self.subTest(name=name):
                path = output / name
                saved = output / (name + '.saved')
                path.rename(saved)
                path.symlink_to(saved)
                try:
                    with self.assertRaisesRegex(ValueError, 'symlinked'):
                        self.transport.record_fixed_delivery(output, digest)
                    self.assertFalse((output / 'fixed-delivery.json').exists())
                finally:
                    path.unlink()
                    saved.rename(path)

    def test_legacy_delivery_does_not_create_record(self):
        self.transport.record_fixed_delivery(self.base, None)
        self.assertFalse((self.base / 'fixed-delivery.json').exists())

    def test_execution_inside_snapshot_rejected(self):
        with self.assertRaisesRegex(ValueError, 'outside fixed inputs'):
            self.transport.record_fixed_execution(self.snapshot, self.invocation, self.data, self.binding())

    def test_legacy_execution_does_not_create_record(self):
        self.assertIsNone(self.transport.record_fixed_execution(self.base, self.invocation, self.data, None))
        self.assertFalse((self.base / 'fixed-execution.json').exists())

    def test_sources_map_to_snapshot_generated_evidence_stays_live(self):
        summary = self.root / 'reports/summary.json'
        summary.parent.mkdir(parents=True, exist_ok=True)
        summary.write_text('{}\n')
        self.data['allowed_input_manifest'].append({'path': 'reports/summary.json', 'sha256': self.transport.sha(summary)})
        paths = self.transport.review_read_paths(self.root, self.invocation, self.data, self.binding())
        self.assertIn(self.snapshot / self.selected[0], paths)
        self.assertIn(self.root / 'reports/summary.json', paths)
        self.assertNotIn(self.root / self.selected[0], paths)

    def test_required_input_missing_rejected(self):
        self.data['allowed_input_manifest'].append({'path': 'contracts/missing.json', 'sha256': 'a' * 64})
        with self.assertRaisesRegex(ValueError, 'selection'):
            self.binding()

    def test_code_and_tests_are_delivered_from_fixed_revision(self):
        added = ['plugins/example.py', 'tests/example.py', 'mcp/example.ts', 'AGENTS.md']
        for name in added:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('fixed source\n')
        subprocess.run(['git', '-C', str(self.root), 'add', '--', *added], check=True)
        subprocess.run(['git', '-C', str(self.root), 'commit', '-qm', 'selected sources'], check=True)
        commit = subprocess.check_output(
            ['git', '-C', str(self.root), 'rev-parse', 'HEAD'], text=True).strip()
        self.selected.extend(added)
        self.snapshot = self.base / 'source-snapshot'
        self.inventory = self.helper.materialize(self.root, commit, self.selected, self.snapshot)
        self.record.write_text(json.dumps(self.inventory))
        self.data['allowed_input_manifest'] = [
            {'path': entry['path'], 'sha256': entry['sha256']}
            for entry in self.inventory['inputs']]
        paths = self.transport.review_read_paths(self.root, self.invocation, self.data, self.binding())
        for name in added:
            self.assertIn(self.snapshot / name, paths)
            self.assertNotIn(self.root / name, paths)

    def test_code_and_tests_cannot_remain_live_inputs(self):
        for name in ('plugins/example.py', 'tests/example.py', 'mcp/example.ts', 'AGENTS.md'):
            with self.subTest(path=name):
                self.data['allowed_input_manifest'].append({'path': name, 'sha256': 'a' * 64})
                try:
                    with self.assertRaisesRegex(ValueError, 'selection'):
                        self.binding()
                finally:
                    self.data['allowed_input_manifest'].pop()

    def test_extra_selection_rejected(self):
        self.data['allowed_input_manifest'].pop()
        with self.assertRaisesRegex(ValueError, 'selection'):
            self.binding()

    def test_duplicate_record_key_rejected(self):
        self.record.write_text('{"commit":"other",' + json.dumps(self.inventory)[1:])
        with self.assertRaisesRegex(ValueError, 'duplicate JSON key'):
            self.binding()

    def test_dirty_source_does_not_replace_fixed_approval(self):
        (self.root / self.selected[1]).write_text('Approval: Draft\n')
        self.assertEqual(self.binding()['inventory'], self.inventory)
        (self.root / self.selected[1]).unlink()
        self.assertEqual(self.binding()['inventory'], self.inventory)

    def test_fixed_probe_control_does_not_read_live_inputs(self):
        for relative in self.selected:
            (self.root / relative).unlink()
        binding = self.binding()
        names = {'control', 'batch_command', 'hash_commands', 'expected_hashes', 'chained_bash'}
        tree = ast.parse((SCRIPTS / 'probe-nontty-review.py').read_text())
        statements = [node for node in ast.walk(tree)
                      if isinstance(node, ast.Assign) and len(node.targets) == 1
                      and isinstance(node.targets[0], ast.Name)
                      and node.targets[0].id in names]
        self.assertEqual(len(statements), len(names))
        data = dict(self.data, sequence=1, previous_record_sha256='-',
                    run_id='probe-run', host_session_id='probe-session')
        inputs = '\n'.join(entry['path'] + '\t' + entry['sha256']
                           for entry in data['allowed_input_manifest'])
        record = '|'.join(['1', data['stage'], data['role'], 'probe-run',
                           'probe-session', '-']) + '|allowed-inputs-v1|' + hashlib.sha256(inputs.encode()).hexdigest()
        receipt = ('REVIEW_CONTEXT_OK ' + hashlib.sha256(record.encode()).hexdigest() + ' sequence=1 '
                   'previous_record_sha256=- pre_append_tip_sequence=0 identity_unique=yes\n')
        (self.root / 'invocation.json').write_text(json.dumps(data))
        scope = dict(transport=self.transport, data=data, receipt=receipt,
                     invocation_relative='invocation.json', ROOT=self.root, fixed_inputs=binding)
        exec(compile(ast.Module(body=statements, type_ignores=[]), 'probe-control', 'exec'), scope)
        self.assertEqual(scope['hash_commands'], [])
        self.assertEqual(scope['expected_hashes'], [])
        self.assertEqual(scope['chained_bash'], 'rtk proxy pwd; rtk proxy pwd')

    def test_committed_selected_content_change_rejected(self):
        (self.root / self.selected[1]).write_text('Approval: Draft\n')
        subprocess.run(['git', '-C', str(self.root), 'add', self.selected[1]], check=True)
        subprocess.run(['git', '-C', str(self.root), 'commit', '-qm', 'selected content'], check=True)
        with self.assertRaisesRegex(ValueError, 'selected inputs changed'):
            self.binding()

    def test_unrelated_commit_does_not_invalidate_fixed_inputs(self):
        (self.root / 'unrelated.txt').write_text('unrelated')
        subprocess.run(['git', '-C', str(self.root), 'add', 'unrelated.txt'], check=True)
        subprocess.run(['git', '-C', str(self.root), 'commit', '-qm', 'unrelated'], check=True)
        self.assertEqual(self.binding()['inventory'], self.inventory)

    def test_selected_committed_mode_change_rejected(self):
        subprocess.run(['git', '-C', str(self.root), 'update-index', '--chmod=+x',
                        self.selected[0]], check=True)
        subprocess.run(['git', '-C', str(self.root), 'commit', '-qm', 'selected mode'], check=True)
        with self.assertRaisesRegex(ValueError, 'selected inputs changed'):
            self.binding()

    def test_tampered_snapshot_rejected(self):
        target = self.snapshot / self.selected[0]
        target.chmod(0o600)
        target.write_text('changed')
        with self.assertRaises(ValueError):
            self.binding()

    def test_policy_is_exact_read_only_and_prompt_uses_snapshot(self):
        binding = self.binding()
        with patch.object(self.transport, 'manifest', return_value=(self.data, None)), \
             patch.object(self.transport, 'receipt_control', return_value={}):
            policy, settings = self.transport.launch_policy(
                self.root, self.invocation, self.receipt, self.root / 'policy.json', fixed_inputs=binding)
            prompt = self.transport.expected_prompt(self.root, self.invocation, self.receipt, fixed_inputs=binding)
        policy = json.loads(policy)
        self.assertEqual(policy['bash_commands'], [])
        self.assertEqual(settings['permissions']['allow'], ['Read'])
        self.assertIn(str(self.snapshot / self.selected[0]), policy['read_paths'])
        self.assertNotIn(str(self.root / self.selected[0]), policy['read_paths'])
        self.assertIn(str(self.snapshot / self.selected[0]).encode(), prompt)

    def test_fixed_task_prompt_does_not_repeat_live_hash_precheck(self):
        binding = self.binding()
        self.data['stage'] = 'task'
        self.data['role'] = 'task-reviewer-a'
        with patch.object(self.transport, 'manifest', return_value=(self.data, None)), \
             patch.object(self.transport, 'admitted_raw_hashes',
                          side_effect=AssertionError('unexpected live input verification')):
            prompt = self.transport.expected_prompt(
                self.root, self.invocation, self.receipt, fixed_inputs=binding)
        self.assertIn(str(self.snapshot / self.selected[0]).encode(), prompt)
        self.assertNotIn(b'Task transport raw SHA-256 observations', prompt)

    def test_invalid_selection_stops_before_launch_side_effects(self):
        launcher = load('launch-impl-review')
        self.data['allowed_input_manifest'].pop()
        output = self.root / 'output'
        actual_run = subprocess.run
        def git_only(argv, **kwargs):
            self.assertEqual(argv[0], 'git', 'launch must stop before non-Git execution')
            return actual_run(argv, **kwargs)
        with patch.object(launcher.transport, 'manifest', return_value=(self.data, None)), \
             patch.object(launcher.subprocess, 'run', side_effect=git_only):
            with self.assertRaisesRegex(ValueError, 'selection'):
                launcher.launch(self.root, self.invocation, output,
                                fixed_input_record=self.record, fixed_input_snapshot=self.snapshot)
        self.assertFalse(output.exists())

    def test_launcher_permission_assembly_preserves_receipt_without_live_hash_work(self):
        tree = ast.parse((SCRIPTS / 'launch-impl-review.py').read_text())
        launch = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                      and node.name == 'launch')
        start = next(i for i, node in enumerate(launch.body)
                     if isinstance(node, ast.Assign) and any(
                         isinstance(target, ast.Name) and target.id == 'permissions'
                         for target in node.targets))
        code = compile(ast.Module(body=launch.body[start:start + 2], type_ignores=[]),
                       'launch-permissions', 'exec')
        for fixed in (None, {'snapshot': '/fixture'}):
            scope = dict(transport=self.transport, data=self.data, preview='receipt',
                         invocation=self.invocation, root=self.root, fixed_inputs=fixed)
            with patch.object(self.transport, 'receipt_control', return_value={
                    'exact_permission_rules': ['Read', 'Bash(fixed-command)']}) as receipt:
                exec(code, scope)
            receipt.assert_called_once_with(
                self.data, 'receipt', self.invocation.relative_to(self.root).as_posix(),
                root=None if fixed else self.root)
            self.assertEqual(scope['permissions'], ['Read'] if fixed else
                             ['Read', 'Bash(fixed-command)'])

    def test_fixed_command_uses_the_same_read_only_policy(self):
        binding = self.binding()
        session = str(uuid.uuid4())
        self.data['host_session_id'] = session
        role = {'model': 'sonnet', 'tools': self.transport.agent_tools('impl'),
                'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']}
        policy_path = self.root / 'policy.json'
        settings_path = self.root / 'settings.json'
        guard = self.root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        guard.parent.mkdir(parents=True, exist_ok=True)
        guard.write_text('// fixture')
        flags = ['-p, --print', '--session-id', '--model', '--permission-mode', '--tools',
                 '--disallowedTools', '--settings', '--agents', '--agent',
                 '--output-format', '--json-schema']
        help_result = subprocess.CompletedProcess([], 0, '\n'.join(flags), '')
        with patch.object(self.transport, 'manifest', return_value=(self.data, None)), \
             patch.object(self.transport, 'receipt_control', return_value={}) as receipt_check, \
             patch.object(self.transport, 'admitted_raw_hashes', side_effect=AssertionError('legacy live hash check')), \
             patch.object(self.transport, 'fixed_input_binding', return_value=binding) as binding_check, \
             patch.object(self.transport.shutil, 'which', return_value='/fixture/claude'), \
             patch.object(self.transport.subprocess, 'run', return_value=help_result):
            policy, settings = self.transport.launch_policy(
                self.root, self.invocation, self.receipt, policy_path, fixed_inputs=binding)
            policy_path.write_bytes(policy)
            settings_path.write_text(json.dumps(settings))
            command = self.transport.claude_command(
                self.root, session, 'impl-reviewer-a', role, ['Read'], settings_path,
                self.invocation, self.receipt, policy_path, fixed_inputs=binding)
            self.assertEqual(command[command.index('--settings') + 1], str(settings_path))
            self.assertEqual(command[command.index('--permission-mode') + 1], 'dontAsk')
            self.assertNotIn('--plugin-dir', command)
            self.assertEqual(json.loads(command[command.index('--agents') + 1]),
                             {'impl-reviewer-a': role})
            self.assertEqual(json.loads(policy)['bash_commands'], [])
            self.assertTrue(all(call.kwargs['root'] is None for call in receipt_check.call_args_list))
            binding_check.assert_called_once_with(
                self.root, self.data, binding['record'], binding['snapshot'])
            binding_check.return_value = dict(binding, snapshot='/changed')
            with self.assertRaisesRegex(ValueError, 'fixed input binding changed'):
                self.transport.claude_command(
                    self.root, session, 'impl-reviewer-a', role, ['Read'], settings_path,
                    self.invocation, self.receipt, policy_path, fixed_inputs=binding)
            with self.assertRaisesRegex(ValueError, 'permission rules'):
                self.transport.claude_command(
                    self.root, session, 'impl-reviewer-a', role, ['Read', 'Bash'], settings_path,
                    self.invocation, self.receipt, policy_path, fixed_inputs=binding)

    def test_fixed_policy_enforced_by_real_session_guard(self):
        binding = self.binding()
        policy_path = self.base / 'guard-policy.json'
        with patch.object(self.transport, 'manifest', return_value=(self.data, None)), \
             patch.object(self.transport, 'receipt_control', return_value={}):
            policy, _ = self.transport.launch_policy(
                self.root, self.invocation, self.receipt, policy_path, fixed_inputs=binding)
        policy_path.write_bytes(policy)
        digest = self.transport.sha(policy_path)
        guard = SCRIPTS / 'nontty-impl-pretool-guard.mjs'
        selected = str(self.snapshot / self.selected[0])
        cases = [
            ('fixed input', 'Read', {'file_path': selected}, True),
            ('invocation', 'Read', {'file_path': str(self.invocation)}, True),
            ('live input', 'Read', {'file_path': str(self.root / self.selected[0])}, False),
            ('outside input', 'Read', {'file_path': str(self.record)}, False),
            ('hash command', 'Bash', {'command': 'shasum -a 256 ' + selected}, False),
            ('compound command', 'Bash', {'command': 'pwd; cat ' + selected}, False),
            ('write', 'Write', {'file_path': selected, 'content': 'changed'}, False),
            ('structured result', 'StructuredOutput', {'verdict': 'PASS'}, True),
        ]
        def check(event, pin, allowed):
            result = subprocess.run(['node', str(guard), str(policy_path), pin],
                                    input=json.dumps(event), text=True, capture_output=True,
                                    timeout=10, check=True)
            self.assertEqual(result.stderr, '')
            if allowed:
                self.assertEqual(result.stdout, '')
            else:
                self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']
                                 ['permissionDecision'], 'deny')
        for label, tool, arguments, allowed in cases:
            with self.subTest(label=label):
                check({'tool_name': tool, 'tool_input': arguments}, digest, allowed)
        check({'tool_name': 'Read', 'tool_input': {'file_path': selected}}, '0' * 64, False)
        check({}, digest, False)
        policy_path.write_bytes(policy + b'\n')
        check({'tool_name': 'Read', 'tool_input': {'file_path': selected}}, digest, False)
        self.helper.verify(self.snapshot, self.inventory)


class RuntimeFilesTests(unittest.TestCase):
    def test_stage_dependencies_exist_and_exclude_unrelated_plugins(self):
        launcher = load('launch-impl-review')
        root = SCRIPTS.parents[2]
        for stage in ('spec', 'impl', 'task', 'quality'):
            with self.subTest(stage=stage):
                files = launcher.runtime_files(root, stage, True)
                self.assertIn(SCRIPTS / 'fixed-review-inputs.py', files)
                self.assertIn(root / 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py', files)
                self.assertNotIn(root / 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py', files)
                self.assertEqual(root / 'contracts/domain-contract.v1.schema.json' in files,
                                 stage != 'task')
                self.assertEqual(SCRIPTS / 'validate-layer-traceability.py' in files, stage == 'task')

    def test_missing_and_symlink_dependencies_fail_closed(self):
        launcher = load('launch-impl-review')
        source = SCRIPTS.parents[2]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for original in launcher.runtime_files(source, 'impl', True):
                target = root / original.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(original.read_bytes())
            before = launcher.runtime_files(root, 'impl', True)
            extra = root / 'plugins/sdd-quality-loop/unrelated.txt'
            extra.write_text('unrelated')
            self.assertEqual(before, launcher.runtime_files(root, 'impl', True))
            self.assertIn(extra, launcher.runtime_files(root, 'impl', False))
            target = root / 'contracts/domain-contract.v1.schema.json'
            target.unlink()
            with self.assertRaisesRegex(ValueError, 'missing or unsafe runtime dependency'):
                launcher.runtime_files(root, 'impl', True)
            target.symlink_to(source / 'contracts/domain-contract.v1.schema.json')
            with self.assertRaisesRegex(ValueError, 'missing or unsafe runtime dependency'):
                launcher.runtime_files(root, 'impl', True)


class FixedBoundaryDependencyTests(unittest.TestCase):
    def probe(self, stage='impl', dependencies=None, omitted=None, live=None, reserve=False):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary).resolve()
            root = base / 'repo'
            root.mkdir()
            files = {'specs/demo/requirements.md': 'requirements\n',
                     'specs/demo/design.md': '# Design\n'}
            files.update(dependencies or {})
            for name, content in files.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content)
            for args in [('init', '-q'), ('config', 'user.name', 'Fixture'),
                         ('config', 'user.email', 'fixture@example.invalid'),
                         ('add', '.'), ('commit', '-qm', 'fixture')]:
                subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True)
            commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
            selected = sorted(set(files) - set(omitted or []))
            snapshot = base / 'snapshot'
            inventory = load('fixed-review-inputs').materialize(root, commit, selected, snapshot)
            record = base / 'record.json'
            record.write_text(json.dumps(inventory))
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            prior = hashlib.sha256(b'1|spec|spec-reviewer-a|fixture-1|session-1|').hexdigest()
            ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1', 'records': [{
                'sequence': 1, 'stage': 'spec', 'role': 'spec-reviewer-a', 'run_id': 'fixture-1',
                'host_session_id': 'session-1', 'previous_record_sha256': '', 'record_sha256': prior}]}))
            before = ledger.read_bytes()
            manifest = root / 'invocation.json'
            manifest.write_text(json.dumps({
                'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest',
                'fallback_mode': 'none', 'read_only': True, 'stage': stage,
                'role': stage + '-reviewer-a', 'feature': 'demo', 'run_id': 'fixture-2',
                'host_session_id': 'session-2', 'sequence': 2,
                'identity_ledger_path': 'reports/review-context/identity-ledger.json',
                'identity_ledger_sha256': hashlib.sha256(before).hexdigest(),
                'previous_record_sha256': prior,
                'allowed_input_manifest': [{'path': p, 'sha256': hashlib.sha256((snapshot / p).read_bytes()).hexdigest()}
                                           for p in selected]}))
            for name, content in (live or {}).items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                if content is None:
                    target.unlink()
                else:
                    target.write_text(content)
            command = ['bash', str(SCRIPTS.parent.parent / 'sdd-quality-loop/scripts/validate-review-context-set.sh'),
                       str(manifest), str(root), '--fixed-input-record', str(record),
                       '--fixed-input-snapshot', str(snapshot)]
            if reserve:
                command.append('--reserve')
            result = subprocess.run(command, text=True, capture_output=True)
            if result.returncode or not reserve:
                self.assertEqual(before, ledger.read_bytes(), 'preflight must not mutate the ledger')
            return result

    def test_untracked_conditional_inputs_do_not_change_fixed_selection(self):
        result = self.probe(live={'specs/demo/investigation.md': 'untracked\n',
                                  'domain/context-map.md': 'untracked\n',
                                  'design-system/design-system.md': 'untracked\n'})
        self.assertEqual(0, result.returncode, result.stderr)

    def test_dirty_and_deleted_conditional_inputs_use_fixed_bytes(self):
        dependencies = {'specs/demo/investigation.md': 'investigation\n',
                        'domain/context-map.md': 'Domain-Model-Status: Draft\n',
                        'design-system/design-tokens.json': '{}\n',
                        'design-system/design-system.md': 'system\n',
                        'design-system/ui-patterns.md': 'patterns\n'}
        result = self.probe(dependencies=dependencies,
                            live={p: None if 'investigation' in p else 'dirty\n' for p in dependencies})
        self.assertEqual(0, result.returncode, result.stderr)

    def test_missing_fixed_dependencies_refuse_before_reservation(self):
        for stage, path, content in [('spec', 'specs/demo/investigation.md', 'investigation\n'),
                                     ('impl', 'domain/context-map.md', 'Domain-Model-Status: Draft\n'),
                                     ('impl', 'design-system/design-system.md', 'system\n')]:
            with self.subTest(stage=stage, path=path):
                dependencies = {path: content}
                if path.startswith('design-system/'):
                    dependencies.update({'design-system/design-tokens.json': '{}\n',
                                         'design-system/ui-patterns.md': 'patterns\n'})
                result = self.probe(stage, dependencies, [path], {path: None}, reserve=True)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('REVIEW_CONTEXT_PATH', result.stderr)


if __name__ == '__main__':
    unittest.main()
