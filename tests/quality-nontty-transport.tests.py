#!/usr/bin/env python3
"""Unreserved quality transport contract checks; no native launch or ledger write."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import uuid
from unittest import mock
import subprocess
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
SPEC = importlib.util.spec_from_file_location('quality_transport', SOURCE)
TRANSPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRANSPORT)
LAUNCH_SPEC = importlib.util.spec_from_file_location(
    'quality_launcher', ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py')
LAUNCH = importlib.util.module_from_spec(LAUNCH_SPEC)
LAUNCH_SPEC.loader.exec_module(LAUNCH)


def quality_core_manifest(root):
    paths = ['specs/example/' + name for name in (
        'requirements.md', 'design.md', 'acceptance-tests.md', 'tasks.md',
        'traceability.md')]
    paths.extend(('plugins/sdd-quality-loop/references/quality-gate-calibration.md',
                  'reports/implementation/example/T-001.md'))
    manifest = []
    for relative in paths:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(relative + '\n')
        manifest.append({'path': relative, 'sha256': TRANSPORT.sha(path)})
    return manifest


class QualityTransport(unittest.TestCase):
    def exercise_quality_launch(self, model='sonnet', failure=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            session = str(uuid.uuid4())
            manifest = quality_core_manifest(root)
            invocation = root / 'reports/review-context/invocation.json'
            invocation.parent.mkdir(parents=True)
            invocation.write_text('{}')
            ledger = invocation.parent / 'identity-ledger.json'
            ledger.write_text('unchanged')
            role = root / 'plugins/sdd-quality-loop/agents/evaluator.md'
            role.parent.mkdir(parents=True)
            role.write_text('---\nmodel: ' + model + '\n---\nInspect admitted inputs.\n')
            probe = root / 'plugins/sdd-review-loop/scripts/probe-nontty-review.py'
            probe.parent.mkdir(parents=True)
            probe.write_text('probe')
            executable = root / 'bin'
            executable.write_text('binary')
            quality_dir = root / 'reports/quality-gate'
            quality_dir.mkdir(parents=True)
            output = quality_dir / ('launch-' + session)
            transcript = root / '.claude/projects' / (session + '.jsonl')
            transcript.parent.mkdir(parents=True)
            transcript.write_text('{}')
            data = {'stage': 'quality', 'role': 'sdd-evaluator', 'feature': 'example',
                    'task_id': 'T-001', 'host_session_id': session,
                    'allowed_input_manifest': manifest}
            receipt = ('REVIEW_CONTEXT_OK ' + 'b' * 64 + ' sequence=2 '
                       'previous_record_sha256=' + 'a' * 64 +
                       ' pre_append_tip_sequence=1 identity_unique=yes\n')
            events = []

            def preflight(*_args):
                events.append('preflight')
                return {'status': 'PREFLIGHT_OK', 'session_id': session,
                        'invocation_sha256': TRANSPORT.sha(invocation)}

            def run(_root, command, destination, prompt=None):
                events.append(destination.name)
                if failure == destination.name:
                    raise ValueError('injected failure')
                if destination.name == 'native.jsonl':
                    return json.dumps({'admitted_read_executed': True,
                        'control_reads_executed': True,
                        'source_invocation_read_executed': True,
                        'source_invocation_sha256': TRANSPORT.sha(invocation),
                        'admitted_paths': [entry['path'] for entry in manifest],
                        'outside_read_pretool_denied': True,
                        'existing_session_collision_rejected': True,
                        'chained_bash_pretool_denied': True,
                        'ordered_hashes_verified': len(manifest) + 4})
                destination.write_text(receipt)
                return receipt

            def preview(_command, **_kwargs):
                if str(_command[3]).endswith('/preflight-host-review.py'):
                    events.append('common-input-preflight')
                    return SimpleNamespace(returncode=0, stdout=(
                        'HOST_REVIEW_PREFLIGHT_OK inputs=1 '
                        'permission-proof=not-established reservation=not-performed\n'), stderr='')
                events.append('canonical-preview')
                return SimpleNamespace(returncode=0, stdout=receipt, stderr='')

            with mock.patch.object(LAUNCH.transport, 'manifest', return_value=(data, {})), \
                    mock.patch.object(LAUNCH.transport, 'preflight', side_effect=preflight), \
                    mock.patch.object(LAUNCH.transport, 'launch_policy', return_value=(b'{}', {})), \
                    mock.patch.object(LAUNCH.transport, 'receipt_control',
                                      return_value={'exact_permission_rules': []}), \
                    mock.patch.object(LAUNCH.transport, 'claude_command', return_value=['fake-claude']), \
                    mock.patch.object(LAUNCH.transport, 'expected_prompt', return_value=b'prompt'), \
                    mock.patch.object(LAUNCH.transport, 'postflight',
                                      return_value={'status': 'DELIVERY_OK'}), \
                    mock.patch.object(LAUNCH.shutil, 'which', return_value=str(executable)), \
                    mock.patch.object(LAUNCH.subprocess, 'run', side_effect=preview), \
                    mock.patch.object(LAUNCH, 'run', side_effect=run), \
                    mock.patch.object(Path, 'home', return_value=root):
                if model == 'opus':
                    with self.assertRaisesRegex(ValueError, 'Sonnet-only'):
                        LAUNCH.launch(root, invocation, output)
                elif failure:
                    with self.assertRaisesRegex(ValueError, 'injected failure'):
                        LAUNCH.launch(root, invocation, output)
                else:
                    self.assertEqual(LAUNCH.launch(root, invocation, output),
                                     {'status': 'DELIVERY_OK'})
            self.assertEqual(ledger.read_text(), 'unchanged')
            return events, output.exists()

    def test_quality_shared_tail_order_in_synthetic_role(self):
        events, output_exists = self.exercise_quality_launch()
        self.assertTrue(output_exists)
        self.assertEqual(events, ['common-input-preflight', 'canonical-preview', 'preflight', 'preflight',
                                  'preview.txt', 'native.jsonl', 'preflight',
                                  'preview-after.txt', 'reserved.txt', 'wrapper.json'])

    def test_quality_model_conflict_stops_before_output_or_reservation(self):
        events, output_exists = self.exercise_quality_launch(model='opus')
        self.assertEqual(events, ['common-input-preflight', 'canonical-preview', 'preflight'])
        self.assertFalse(output_exists)

    def test_quality_native_failure_never_reserves(self):
        events, _ = self.exercise_quality_launch(failure='native.jsonl')
        self.assertNotIn('reserved.txt', events)
        self.assertNotIn('wrapper.json', events)

    def test_quality_plaintext_postflight_requires_identity_and_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            session = str(uuid.uuid4())
            files = [root / name for name in ('invocation.json', 'transcript.jsonl',
                                              'prompt.txt', 'wrapper.json', 'receipt.txt')]
            for path in files:
                path.write_text('{}')
            invocation, transcript, prompt, wrapper, receipt = files
            header = (f'RUN_ID: {session}\nHOST_SESSION_ID: {session}\n'
                      f'ALLOWED_INPUT_MANIFEST: invocation.json {TRANSPORT.sha(invocation)}\n')
            good = (header + 'VERDICT: NEEDS_WORK\nFINDINGS:\n'
                    '- [Major] test not rerun — missing execution evidence\n'
                    'CHECKED:\n- source:1 inspected; task tests not rerun\n')
            data = {'stage': 'quality', 'host_session_id': session}
            with mock.patch.object(TRANSPORT, 'native_delivery',
                                   return_value=(data, {'result': good}, [])):
                self.assertEqual(TRANSPORT.postflight(root, invocation, transcript,
                                                       prompt, wrapper, receipt)['status'],
                                 'DELIVERY_OK')
            for raw in (good.replace(session, str(uuid.uuid4()), 1),
                        good + 'RUN_ID: WRONG\n',
                        good + 'HOST_SESSION_ID: WRONG\n',
                        good + 'ALLOWED_INPUT_MANIFEST: wrong.json ' + '0' * 64 + '\n',
                        good.replace('CHECKED:\n- source:1 inspected; task tests not rerun',
                                     'CHECKED:'),
                        good.replace('VERDICT: NEEDS_WORK', 'VERDICT: PASS')):
                with self.subTest(raw=raw[:40]), mock.patch.object(
                        TRANSPORT, 'native_delivery', return_value=(data, {'result': raw}, [])):
                    with self.assertRaisesRegex(ValueError, 'plaintext verdict contract|blocking findings'):
                        TRANSPORT.postflight(root, invocation, transcript,
                                             prompt, wrapper, receipt)
            clean_pass = (header + 'VERDICT: PASS\nFINDINGS:\nCHECKED:\n'
                          '- source:1 inspected; task tests not rerun\n')
            input_path = root / 'source.md'
            input_path.write_text('source\n')
            data['allowed_input_manifest'] = [{'path': 'source.md',
                                               'sha256': TRANSPORT.sha(input_path)}]
            with mock.patch.object(TRANSPORT, 'native_delivery',
                                   return_value=(data, {'result': clean_pass}, [])):
                with self.assertRaisesRegex(ValueError, 'lacks observed admitted input inspection'):
                    TRANSPORT.postflight(root, invocation, transcript,
                                         prompt, wrapper, receipt)
            reads = [{'message': {'content': [{'type': 'tool_use', 'name': 'Read',
                                               'input': {'file_path': str(input_path)}}]}}]
            with mock.patch.object(TRANSPORT, 'native_delivery',
                                   return_value=(data, {'result': clean_pass}, reads)):
                self.assertEqual(TRANSPORT.postflight(root, invocation, transcript,
                                                       prompt, wrapper, receipt)['status'],
                                 'DELIVERY_OK')

    def test_scratch_record_and_read_hash_only_permissions(self):
        session = str(uuid.uuid4())
        data = {'stage': 'quality', 'role': 'sdd-evaluator', 'feature': 'example',
                'task_id': 'T-001', 'sequence': 2, 'run_id': session,
                'host_session_id': session, 'previous_record_sha256': 'a' * 64,
                'scratch_root': '/tmp/evaluator-example',
                'allowed_input_manifest': [{'path': 'specs/example/tasks.md',
                                            'sha256': 'b' * 64}]}
        binding = hashlib.sha256(b'example\n/tmp/evaluator-example').hexdigest()
        record = '|'.join(('2', 'quality', 'sdd-evaluator', session, session,
                           'a' * 64, 'scratch-declaration-v1', binding))
        digest = hashlib.sha256(record.encode()).hexdigest()
        receipt = (f'REVIEW_CONTEXT_OK {digest} sequence=2 '
                   f'previous_record_sha256={"a" * 64} pre_append_tip_sequence=1 '
                   'identity_unique=yes\n')
        control = TRANSPORT.receipt_control(data, receipt)
        self.assertEqual(control['record_sha256'], digest)
        self.assertEqual(control['scratch_declaration_sha256'], binding)
        self.assertTrue(all('test -d domain' not in rule for rule in
                            control['exact_permission_rules']))
        self.assertTrue(all('bash tests/' not in rule for rule in
                            control['exact_permission_rules']))
        changed = dict(data, scratch_root='/tmp/another-evaluator')
        with self.assertRaisesRegex(ValueError, 'receipt record hash mismatch'):
            TRANSPORT.receipt_control(changed, receipt)

    def test_quality_identity_requires_task_and_scratch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1',
                                          'records': []}))
            invocation = root / 'invocation.json'
            data = {'schema': 'review-context-invocation/v2', 'stage': 'quality',
                    'role': 'sdd-evaluator', 'feature': 'example',
                    'run_id': str(uuid.uuid4()), 'read_only': True,
                    'input_mode': 'file-manifest', 'fallback_mode': 'none',
                    'identity_ledger_path': 'reports/review-context/identity-ledger.json',
                    'allowed_input_manifest': []}
            data['host_session_id'] = data['run_id']
            invocation.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'quality task identity'):
                TRANSPORT.manifest(root, invocation)
            data.update(task_id='T-001', scratch_root='/tmp/evaluator-example')
            invocation.write_text(json.dumps(data))
            self.assertEqual(TRANSPORT.manifest(root, invocation)[0]['task_id'], 'T-001')

    def test_quality_preview_and_preflight_leave_ledger_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = quality_core_manifest(root)
            session = str(uuid.uuid4())
            invocation = root / 'reports/review-context/invocation.json'
            invocation.parent.mkdir(parents=True)
            invocation.write_text('{}')
            ledger = invocation.parent / 'identity-ledger.json'
            ledger.write_text('unchanged ledger')
            output = root / 'reports/quality-gate' / ('launch-' + session)
            data = {'feature': 'example', 'task_id': 'T-001', 'host_session_id': session,
                    'allowed_input_manifest': manifest}
            receipt = ('REVIEW_CONTEXT_OK ' + 'b' * 64 + ' sequence=2 '
                       'previous_record_sha256=' + 'a' * 64 +
                       ' pre_append_tip_sequence=1 identity_unique=yes\n')
            with mock.patch.object(LAUNCH.transport, 'preflight', return_value={
                    'status': 'PREFLIGHT_OK', 'session_id': session,
                    'invocation_sha256': TRANSPORT.sha(invocation)}) as preflight, \
                    mock.patch.object(LAUNCH.subprocess, 'run', return_value=
                                      subprocess.CompletedProcess([], 0, receipt, '')) as called:
                self.assertEqual(LAUNCH.quality_input_precheck(root, invocation, output, data),
                                 receipt)
            self.assertNotIn('--reserve', called.call_args.args[0])
            preflight.assert_called_once()
            self.assertEqual(ledger.read_text(), 'unchanged ledger')
            self.assertFalse(output.exists())
            for missing in manifest:
                reduced = dict(data, allowed_input_manifest=[entry for entry in manifest
                               if entry['path'] != missing['path']])
                with self.subTest(missing=missing['path']), mock.patch.object(
                        LAUNCH.subprocess, 'run') as preview:
                    with self.assertRaisesRegex(ValueError, 'omits required'):
                        LAUNCH.quality_input_precheck(root, invocation, output, reduced)
                    preview.assert_not_called()
                self.assertEqual(ledger.read_text(), 'unchanged ledger')
                self.assertFalse(output.exists())
            data['allowed_input_manifest'].append({'path': '../outside', 'sha256': '0' * 64})
            with mock.patch.object(LAUNCH.subprocess, 'run') as called:
                with self.assertRaisesRegex(ValueError, 'unsafe or duplicate'):
                    LAUNCH.quality_input_precheck(root, invocation, output, data)
            called.assert_not_called()


if __name__ == '__main__':
    unittest.main()
