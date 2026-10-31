#!/usr/bin/env python3
"""Unreserved quality transport contract checks; no native launch or ledger write."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
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

    def test_compact_command_verifies_all_640_inputs_and_rejects_mutations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            source = root / SOURCE.relative_to(ROOT)
            source.parent.mkdir(parents=True)
            shutil.copyfile(SOURCE, source)
            boundary = root / TRANSPORT.BOUNDARY_PATH
            boundary.parent.mkdir(parents=True, exist_ok=True)
            boundary.write_text('boundary\n')
            entries = []
            for index in range(640):
                path = root / f'input-{index}.md'
                path.write_text(str(index))
                entries.append({'path': path.name, 'sha256': TRANSPORT.sha(path)})
            session = str(uuid.uuid4())
            data = {'stage': 'quality', 'role': 'sdd-evaluator', 'feature': 'example',
                    'sequence': 2, 'run_id': session, 'host_session_id': session,
                    'previous_record_sha256': 'a' * 64,
                    'scratch_root': str(root / 'scratch'), 'allowed_input_manifest': entries}
            binding = hashlib.sha256(('example\n' + data['scratch_root']).encode()).hexdigest()
            record = '|'.join(('2', 'quality', 'sdd-evaluator', session, session,
                               'a' * 64, 'scratch-declaration-v1', binding))
            digest = hashlib.sha256(record.encode()).hexdigest()
            receipt = (f'REVIEW_CONTEXT_OK {digest} sequence=2 '
                       f'previous_record_sha256={"a" * 64} pre_append_tip_sequence=1 '
                       'identity_unique=yes\n')
            invocation = root / 'invocation.json'
            invocation.write_text(json.dumps(data))
            control = TRANSPORT.receipt_control(data, receipt, invocation.name, root=root)
            command = control['compact_command']
            self.assertLess(len(command), 4096)
            self.assertEqual(control['hash_commands'], [command])
            self.assertEqual(control['exact_permission_rules'], ['Bash(' + command + ')'])

            def run():
                return subprocess.run(command, shell=True, cwd=root, capture_output=True, text=True)

            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            TRANSPORT.require_compact_result(result.stdout, control['compact_output'])
            self.assertEqual(json.loads(result.stdout)['input_count'], 640)
            for target, replacement in ((root / entries[-1]['path'], b'changed'),
                                        (boundary, b'changed'), (invocation, b'{}'),
                                        (source, b'raise SystemExit(0)\n')):
                original = target.read_bytes()
                target.write_bytes(replacement)
                try:
                    self.assertNotEqual(run().returncode, 0, str(target))
                finally:
                    target.write_bytes(original)
            target = root / entries[-1]['path']
            original = target.read_bytes()
            target.unlink()
            self.assertNotEqual(run().returncode, 0)
            target.symlink_to(root / entries[0]['path'])
            self.assertNotEqual(run().returncode, 0)
            target.unlink()
            target.write_bytes(original)
            for changed in (entries[::-1], entries + [entries[0]]):
                data['allowed_input_manifest'] = changed
                invocation.write_text(json.dumps(data))
                self.assertNotEqual(run().returncode, 0)
            data['allowed_input_manifest'] = [{'path': '../outside', 'sha256': 'a' * 64}]
            invocation.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                TRANSPORT.receipt_control(data, receipt, invocation.name, root=root)
            with self.assertRaises(ValueError):
                TRANSPORT.require_compact_result(control['compact_output'] + '\nextra',
                                                 control['compact_output'])

    def test_shared_argv_rejects_model_permission_and_session_mismatches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            session = str(uuid.uuid4())
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            receipt = root / 'receipt.txt'
            receipt.write_text('receipt')
            policy = root / 'policy.json'
            policy.write_text('{}')
            settings = root / 'settings.json'
            settings.write_text('{}')
            guard = root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
            guard.parent.mkdir(parents=True)
            guard.write_text('// fixture\n')
            permissions = ['Read(source.md)']
            flags = ('-p --session-id --model --permission-mode --tools '
                     '--disallowedTools --settings --plugin-dir '
                     '--agents --agent --output-format --json-schema')
            for stage, roles in TRANSPORT.STAGE_ROLES.items():
                for role_name in roles:
                    data = {'stage': stage, 'host_session_id': session}
                    role = {'model': 'sonnet', 'tools': TRANSPORT.agent_tools(stage),
                            'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']}
                    with mock.patch.object(TRANSPORT, 'manifest', return_value=(data, {})), \
                            mock.patch.object(TRANSPORT, 'launch_policy', return_value=(b'{}', {})), \
                            mock.patch.object(TRANSPORT, 'receipt_control', return_value={
                                'exact_permission_rules': permissions}), \
                            mock.patch.object(TRANSPORT, 'admitted_raw_hashes', return_value={}), \
                            mock.patch.object(TRANSPORT.shutil, 'which', return_value='claude'), \
                            mock.patch.object(TRANSPORT.subprocess, 'run', return_value=
                                              subprocess.CompletedProcess([], 0, flags, '')):
                        def command(selected_role=role, selected_permissions=permissions,
                                    selected_session=session):
                            return TRANSPORT.claude_command(
                                root, selected_session, role_name, selected_role,
                                selected_permissions, settings, invocation, receipt, policy)
                        self.assertIn('--session-id', command())
                        for flag in flags.split():
                            if flag == '--json-schema' and stage == 'quality':
                                continue
                            with self.subTest(stage=stage, role=role_name, missing_flag=flag):
                                missing = ' '.join(item for item in flags.split() if item != flag)
                                with mock.patch.object(TRANSPORT.subprocess, 'run', return_value=
                                                       subprocess.CompletedProcess([], 0, missing, '')):
                                    with self.assertRaisesRegex(ValueError, 'unsupported CLI argument'):
                                        command()
                        for model in ('opus', 'haiku', 'Sonnet', '', None):
                            with self.subTest(stage=stage, role=role_name, model=model):
                                with self.assertRaisesRegex(ValueError, 'unsupported role permission profile'):
                                    command(dict(role, model=model))
                        with self.subTest(stage=stage, mismatch='permissions'):
                            with self.assertRaisesRegex(ValueError, 'permission rules mismatch'):
                                command(selected_permissions=permissions + ['Read(outside.md)'])
                        with self.subTest(stage=stage, mismatch='session'):
                            with self.assertRaisesRegex(ValueError, 'session differs'):
                                command(selected_session=str(uuid.uuid4()))
                        settings.write_text('{"permissions": {"allow": ["Read"]}}')
                        with self.subTest(stage=stage, mismatch='settings'):
                            with self.assertRaisesRegex(ValueError, 'settings or policy mismatch'):
                                command()
                        settings.write_text('{}')
    def test_shared_argv_accepts_real_claude_help_aliases_and_rejects_missing_flag(self):
        executable = shutil.which('claude')
        if executable is None:
            self.skipTest('Claude CLI is unavailable; no native session is launched')
        help_result = subprocess.run(['rtk', 'proxy', executable, '--help'],
                                     capture_output=True, text=True, timeout=30)
        self.assertEqual(help_result.returncode, 0)
        self.assertIn('--allowedTools, --allowed-tools', help_result.stdout)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            session = str(uuid.uuid4())
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            receipt = root / 'receipt.txt'
            receipt.write_text('receipt')
            policy = root / 'policy.json'
            policy.write_text('{}')
            settings = root / 'settings.json'
            settings.write_text('{}')
            guard = root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
            guard.parent.mkdir(parents=True)
            guard.write_text('// fixture\n')
            data = {'stage': 'quality', 'host_session_id': session}
            role = {'model': 'sonnet', 'tools': ['Read', 'Bash'],
                    'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']}
            permissions = ['Read(source.md)', 'Bash(rtk proxy shasum -a 256 source.md)']
            with mock.patch.object(TRANSPORT, 'manifest', return_value=(data, {})), \
                    mock.patch.object(TRANSPORT, 'launch_policy', return_value=(b'{}', {})), \
                    mock.patch.object(TRANSPORT, 'receipt_control', return_value={
                        'exact_permission_rules': permissions}), \
                    mock.patch.object(TRANSPORT, 'admitted_raw_hashes', return_value={}), \
                    mock.patch.object(TRANSPORT.shutil, 'which', return_value=executable):
                formal = TRANSPORT.claude_command(root, session, 'sdd-evaluator', role,
                                                  permissions, settings, invocation,
                                                  receipt, policy)
                diagnostic = TRANSPORT.claude_command(root, session, 'sdd-evaluator', role,
                                                      permissions, settings, invocation,
                                                      receipt, policy)
                self.assertEqual(formal, diagnostic)
                self.assertNotIn('--allowedTools', formal)
                for flag, value in (('--model', 'sonnet'),
                                    ('--permission-mode', 'dontAsk'),
                                    ('--tools', 'Read,Bash'),
                                    ('--settings', str(settings)),
                                    ('--plugin-dir', str(root / 'plugins/sdd-review-loop')),
                                    ('--agent', 'sdd-evaluator'),
                                    ('--output-format', 'json')):
                    self.assertEqual(formal[formal.index(flag) + 1], value)
                self.assertEqual(json.loads(formal[formal.index('--agents') + 1]),
                                 {'sdd-evaluator': role})
                self.assertNotIn('--json-schema', formal)
                missing = help_result.stdout.replace('--disallowedTools, --disallowed-tools',
                                                     '--removedTools, --removed-tools', 1)
                self.assertNotIn('--disallowedTools, --disallowed-tools', missing)
                with mock.patch.object(TRANSPORT.subprocess, 'run', return_value=
                                       subprocess.CompletedProcess([], 0, missing, '')):
                    with self.assertRaisesRegex(ValueError,
                                                'unsupported CLI argument: --disallowedTools'):
                        TRANSPORT.claude_command(root, session, 'sdd-evaluator', role,
                                                 permissions, settings, invocation,
                                                 receipt, policy)

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
                    'scratch_root': str(root / 'scratch'),
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
                    proof = {'admitted_read_executed': True,
                        'control_reads_executed': True,
                        'source_invocation_read_executed': True,
                        'source_invocation_sha256': TRANSPORT.sha(invocation),
                        'admitted_paths': [entry['path'] for entry in manifest],
                        'outside_read_pretool_denied': True,
                        'existing_session_collision_rejected': True,
                        'chained_bash_pretool_denied': True,
                        'ordered_hashes_verified': len(manifest) + 5}
                    if failure and failure.startswith('proof:'):
                        proof.pop(failure.split(':', 1)[1])
                    if failure == 'dependency-drift':
                        executable.write_text('changed binary')
                    return json.dumps(proof)
                destination.write_text(receipt)
                if destination.name == 'reserved.txt':
                    self.assertTrue(command[4].endswith('/preflight-evaluator-delivery.py'))
                    self.assertIn('--scratch-root', command)
                    self.assertEqual(command[-1], '--reserve')
                    return receipt + ('EVALUATOR_DELIVERY_OK inputs=' + str(len(manifest)) +
                                      '; reservation=performed\n')
                return receipt

            def preview(_command, **_kwargs):
                if len(_command) > 4 and str(_command[4]).endswith('/preflight-evaluator-delivery.py'):
                    events.append('scratch-delivery-preflight')
                    if failure == 'scratch-delivery-preflight':
                        raise ValueError('injected failure')
                    return SimpleNamespace(returncode=0, stdout=(
                        'EVALUATOR_DELIVERY_OK inputs=' + str(len(manifest)) +
                        '; reservation=not performed\n'), stderr='')
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
                        LAUNCH.launch(root, invocation, output, TRANSPORT.sha(invocation))
                elif failure:
                    reason = ('native permission proof incomplete' if failure.startswith('proof:')
                              else 'dependency changed' if failure == 'dependency-drift'
                              else 'injected failure')
                    with self.assertRaisesRegex(ValueError, reason):
                        LAUNCH.launch(root, invocation, output, TRANSPORT.sha(invocation))
                else:
                    self.assertEqual(LAUNCH.launch(root, invocation, output, TRANSPORT.sha(invocation)),
                                     {'status': 'DELIVERY_OK'})
            self.assertEqual(ledger.read_text(), 'unchanged')
            return events, output.exists()

    def test_quality_shared_tail_order_in_synthetic_role(self):
        events, output_exists = self.exercise_quality_launch()
        self.assertTrue(output_exists)
        self.assertEqual(events, ['common-input-preflight', 'scratch-delivery-preflight',
                                  'canonical-preview', 'preflight', 'preflight',
                                  'preview.txt', 'native.jsonl', 'preflight',
                                  'preview-after.txt', 'reserved.txt', 'wrapper.json'])

    def test_quality_model_conflict_stops_before_output_or_reservation(self):
        events, output_exists = self.exercise_quality_launch(model='opus')
        self.assertEqual(events, ['common-input-preflight', 'scratch-delivery-preflight',
                                  'canonical-preview', 'preflight'])
        self.assertFalse(output_exists)

    def test_quality_native_failure_never_reserves(self):
        events, _ = self.exercise_quality_launch(failure='native.jsonl')
        self.assertNotIn('reserved.txt', events)
        self.assertNotIn('wrapper.json', events)

    def test_quality_scratch_failure_precedes_output_and_reservation(self):
        events, output_exists = self.exercise_quality_launch(failure='scratch-delivery-preflight')
        self.assertFalse(output_exists)
        self.assertNotIn('reserved.txt', events)
        self.assertNotIn('native.jsonl', events)

    def test_quality_incomplete_native_proof_never_reserves(self):
        for field in ('admitted_read_executed', 'control_reads_executed',
                      'source_invocation_read_executed', 'source_invocation_sha256',
                      'admitted_paths', 'outside_read_pretool_denied',
                      'existing_session_collision_rejected', 'chained_bash_pretool_denied',
                      'ordered_hashes_verified'):
            with self.subTest(field=field):
                events, _ = self.exercise_quality_launch(failure='proof:' + field)
                self.assertNotIn('reserved.txt', events)
                self.assertNotIn('wrapper.json', events)

    def test_quality_dependency_drift_never_reserves(self):
        events, _ = self.exercise_quality_launch(failure='dependency-drift')
        self.assertNotIn('reserved.txt', events)
        self.assertNotIn('wrapper.json', events)

    def test_quality_stale_external_pin_precedes_manifest_read_and_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            output = root / 'output'
            with mock.patch.object(LAUNCH.transport, 'manifest') as read:
                with self.assertRaisesRegex(ValueError, 'caller invocation pin mismatch'):
                    LAUNCH.launch(root, invocation, output, '0' * 64)
                read.assert_not_called()
            self.assertFalse(output.exists())

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

    def test_invocation_raw_hash_is_required_by_formal_transport(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            invocation = root / 'reports/review-context/invocation.json'
            invocation.parent.mkdir(parents=True)
            invocation.write_text('{"invocation": true}\n')
            relative = invocation.relative_to(root).as_posix()
            data = {'stage': 'quality', 'role': 'sdd-evaluator', 'feature': 'example',
                    'sequence': 2, 'run_id': str(uuid.uuid4()),
                    'previous_record_sha256': 'a' * 64,
                    'scratch_root': '/tmp/evaluator-example',
                    'allowed_input_manifest': [{'path': 'source.md', 'sha256': 'b' * 64}]}
            data['host_session_id'] = data['run_id']
            binding = hashlib.sha256(b'example\n/tmp/evaluator-example').hexdigest()
            record = '|'.join(('2', 'quality', 'sdd-evaluator', data['run_id'],
                               data['host_session_id'], 'a' * 64,
                               'scratch-declaration-v1', binding))
            receipt = (f'REVIEW_CONTEXT_OK {hashlib.sha256(record.encode()).hexdigest()} '
                       f'sequence=2 previous_record_sha256={"a" * 64} '
                       'pre_append_tip_sequence=1 identity_unique=yes\n')
            command = ('rtk proxy shasum -a 256 ' + relative + ' source.md '
                       'plugins/sdd-review-loop/references/review-context-boundary.md')
            control = TRANSPORT.receipt_control(data, receipt, relative)
            self.assertIn('Bash(' + command + ')', control['exact_permission_rules'])
            for hash_command in control['hash_commands']:
                producer, consumer = hash_command.split(' | ', 1)
                self.assertIn('Bash(' + hash_command + ')',
                              control['exact_permission_rules'])
                self.assertIn('Bash(' + producer + ')',
                              control['exact_permission_rules'])
                self.assertIn('Bash(' + consumer + ')',
                              control['exact_permission_rules'])
                self.assertNotIn('Bash(' + producer + '; rtk proxy pwd)',
                                 control['exact_permission_rules'])
            self.assertEqual(sum('Bash(rtk proxy shasum -a 256 ' in rule for rule in
                                 control['exact_permission_rules']), 1)
            source = root / 'source.md'
            source.write_text('source\n')
            boundary = root / 'plugins/sdd-review-loop/references/review-context-boundary.md'
            boundary.parent.mkdir(parents=True)
            boundary.write_text('boundary\n')
            helper = root / SOURCE.relative_to(ROOT)
            helper.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE, helper)
            data['allowed_input_manifest'][0]['sha256'] = TRANSPORT.sha(source)
            invocation.write_text(json.dumps(data))
            control = TRANSPORT.receipt_control(data, receipt, relative, root=root)
            command = control['compact_command']
            receipt_path = root / 'receipt.txt'
            receipt_path.write_text(receipt)
            with mock.patch.object(TRANSPORT, 'manifest', return_value=(data, {})):
                policy, settings = TRANSPORT.launch_policy(root, invocation, receipt_path,
                                                    root / 'policy.json')
            self.assertEqual(settings['permissions']['allow'], control['exact_permission_rules'])
            self.assertIn(command, json.loads(policy)['bash_commands'])
            # Absolute tool targets must match the pinned scope, while identities stay relative.
            relative_reads = [relative, TRANSPORT.BOUNDARY_PATH, 'source.md']
            targets = TRANSPORT.canonical_read_paths(root, relative_reads)
            self.assertEqual(targets, json.loads(policy)['read_paths'])
            self.assertEqual(relative_reads, [relative, TRANSPORT.BOUNDARY_PATH, 'source.md'])
            sampled = TRANSPORT.diagnostic_read_paths(data['allowed_input_manifest'], relative)
            self.assertTrue(set(TRANSPORT.canonical_read_paths(root, sampled)).issubset(targets))
            with mock.patch.object(TRANSPORT, 'manifest', return_value=(data, {})):
                rendered = TRANSPORT.expected_prompt(root, invocation, receipt_path).decode()
            self.assertIn('Read tool file_path values (canonical absolute paths):\n' +
                          json.dumps(targets, ensure_ascii=True), rendered)
            self.assertIn('"invocation": "' + relative + '"', rendered)
            self.assertIn('read the admitted task, requirements, design, acceptance tests', rendered)
            self.assertIn('Hash verification proves identity, not review coverage', rendered)
            self.assertIn('return NEEDS_WORK and name the unread inputs or unchecked criteria', rendered)
            probe_source = (ROOT / 'plugins/sdd-review-loop/scripts/probe-nontty-review.py').read_text()
            self.assertIn('transport.canonical_read_paths(ROOT, read_paths)', probe_source)
            self.assertIn('transport.canonical_read_paths(ROOT, [outside])[0]', probe_source)
            self.assertEqual(set(control['hash_commands']),
                             set(json.loads(policy)['bash_commands']))
            policy_path = root / 'policy.json'
            policy_path.write_bytes(policy)
            guard = ROOT / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
            for candidate, denied in ((control['hash_commands'][0], False),
                                      ('rtk proxy python3 -B', True),
                                      ('rtk proxy shasum -a 256', True),
                                      (control['hash_commands'][0] + '; rtk proxy pwd', True),
                                      ('rtk proxy shasum -a 256 outside.txt', True)):
                result = subprocess.run(
                    ['node', str(guard), str(policy_path),
                     hashlib.sha256(policy).hexdigest()],
                    input=json.dumps({'tool_name': 'Bash',
                                      'tool_input': {'command': candidate}}),
                    text=True, capture_output=True, check=True)
                self.assertEqual(bool(result.stdout), denied)
            outside = root / 'outside.md'
            outside.write_text('not admitted')
            for requested, denied in ((source, False), (outside, True)):
                result = subprocess.run(
                    ['rtk', 'proxy', 'node', str(guard), str(policy_path),
                     hashlib.sha256(policy).hexdigest()],
                    input=json.dumps({'tool_name': 'Read',
                                      'tool_input': {'file_path': str(requested)}}),
                    text=True, capture_output=True, check=True)
                self.assertEqual(bool(result.stdout), denied)
            self.assertEqual(sum(item.startswith('rtk proxy python3 -B ') for item in
                                 json.loads(policy)['bash_commands']), 1)
            prompt = TRANSPORT.control_prompt(data, receipt, 'c' * 64,
                                              strict=True, invocation_path=relative,
                                              invocation_sha256=TRANSPORT.sha(invocation), root=root)
            self.assertIn('```sh\n' + command + '\n```', prompt)
            self.assertIn(TRANSPORT.sha(invocation), prompt)
            prompt_path = root / 'prompt.txt'
            with mock.patch.object(TRANSPORT, 'manifest', return_value=(data, {})):
                prompt_path.write_bytes(TRANSPORT.expected_prompt(root, invocation,
                                                                   receipt_path, strict=True))
            ledger = invocation.parent / 'identity-ledger.json'
            ledger.write_text('unchanged ledger')
            invocation.write_text('{"invocation": false}\n')
            with mock.patch.object(TRANSPORT, 'manifest', return_value=(data, {})):
                with self.assertRaisesRegex(ValueError, 'compact invocation differs from supplied manifest'):
                    TRANSPORT.native_delivery(root, invocation, root / 'transcript.jsonl',
                                              prompt_path, root / 'wrapper.json',
                                              receipt_path, strict=True)
            self.assertEqual(ledger.read_text(), 'unchanged ledger')

            spec_data = dict(data, stage='spec', role='spec-reviewer-a')
            inputs = 'source.md\t' + data['allowed_input_manifest'][0]['sha256']
            input_digest = hashlib.sha256(inputs.encode()).hexdigest()
            spec_record = '|'.join(('2', 'spec', 'spec-reviewer-a', data['run_id'],
                                    data['host_session_id'], 'a' * 64,
                                    'allowed-inputs-v1', input_digest))
            spec_receipt = (f'REVIEW_CONTEXT_OK {hashlib.sha256(spec_record.encode()).hexdigest()} '
                            f'sequence=2 previous_record_sha256={"a" * 64} '
                            'pre_append_tip_sequence=1 identity_unique=yes\n')
            self.assertEqual(TRANSPORT.control_prompt(spec_data, spec_receipt, 'c' * 64),
                             TRANSPORT.control_prompt(spec_data, spec_receipt, 'c' * 64,
                                                      invocation_path=relative,
                                                      invocation_sha256=TRANSPORT.sha(invocation)))

    def test_batch_hash_proof_requires_every_ordered_raw_digest(self):
        paths = ['reports/review-context/invocation.json'] + [
            f'specs/example/input-{index:03}.md' for index in range(101)] + [
            'plugins/sdd-review-loop/references/review-context-boundary.md']
        expected = [(path, f'{index:064x}') for index, path in enumerate(paths)]
        command = TRANSPORT.file_hash_batch_command(paths)
        self.assertEqual(command.count('rtk proxy shasum -a 256'), 1)
        self.assertEqual(len(command.split()), len(paths) + 5)
        output = ''.join(digest + '  ' + path + '\n' for path, digest in expected)
        TRANSPORT.require_hash_batch_result(output, expected)
        for bad in (output.replace(expected[0][1], 'f' * 64, 1),
                    output.replace(expected[2][0], 'specs/example/wrong.md', 1),
                    ''.join(digest + '  ' + path + '\n' for path, digest in expected[:-1]),
                    ''.join(digest + '  ' + path + '\n' for path, digest in expected[1:] + expected[:1])):
            with self.assertRaises(ValueError):
                TRANSPORT.require_hash_batch_result(bad, expected)

    def test_diagnostic_reads_are_representative_not_all_inputs(self):
        entries = [{'path': f'specs/example/input-{index:03}.md'}
                   for index in range(101)]
        entries.append({'path': 'reports/review-context/source.json'})
        selected = TRANSPORT.diagnostic_read_paths(
            entries, 'reports/review-context/diagnostic.json')
        self.assertEqual(selected, [entries[0]['path'], entries[51]['path'],
                                    entries[-1]['path'],
                                    'reports/review-context/diagnostic.json',
                                    TRANSPORT.BOUNDARY_PATH])
        self.assertEqual(len(selected), 5)
        self.assertEqual(TRANSPORT.diagnostic_read_paths(
            [entries[0]], 'reports/review-context/diagnostic.json'),
            [entries[0]['path'], 'reports/review-context/diagnostic.json',
             TRANSPORT.BOUNDARY_PATH])

    def test_large_quality_control_hash_pipeline_has_exact_permissions(self):
        session = str(uuid.uuid4())
        entries = [{'path': f'specs/example/input-{index:03}.md',
                    'sha256': f'{index:064x}'} for index in range(101)]
        data = {'stage': 'quality', 'role': 'sdd-evaluator', 'feature': 'example',
                'sequence': 2, 'run_id': session, 'host_session_id': session,
                'previous_record_sha256': 'a' * 64,
                'scratch_root': '/tmp/evaluator-example',
                'allowed_input_manifest': entries}
        binding = hashlib.sha256(b'example\n/tmp/evaluator-example').hexdigest()
        record = '|'.join(('2', 'quality', 'sdd-evaluator', session, session,
                           'a' * 64, 'scratch-declaration-v1', binding))
        digest = hashlib.sha256(record.encode()).hexdigest()
        receipt = (f'REVIEW_CONTEXT_OK {digest} sequence=2 '
                   f'previous_record_sha256={"a" * 64} pre_append_tip_sequence=1 '
                   'identity_unique=yes\n')
        control = TRANSPORT.receipt_control(data, receipt,
                                            'reports/review-context/invocation.json')
        self.assertGreater(len(control['hash_commands'][0]), 8000)
        inputs_producer = control['hash_commands'][0].split(' | ', 1)[0]
        produced = subprocess.run(['bash', '-c', inputs_producer], text=True,
                                  capture_output=True, check=True)
        self.assertEqual(produced.stdout, control['inputs_text'])
        for command in control['hash_commands']:
            producer, consumer = command.split(' | ', 1)
            self.assertIn('Bash(' + command + ')', control['exact_permission_rules'])
            self.assertIn('Bash(' + producer + ')', control['exact_permission_rules'])
            self.assertIn('Bash(' + consumer + ')', control['exact_permission_rules'])
            self.assertNotIn('Bash(' + producer + '; rtk proxy pwd)',
                             control['exact_permission_rules'])

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

    def test_task_normalized_input_allows_lifecycle_only_not_body_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scripts = root / 'plugins/sdd-review-loop/scripts'
            (scripts / 'lib').mkdir(parents=True)
            for relative in ('task-review-precheck.sh', 'lib/review-precheck-common.sh'):
                shutil.copyfile(ROOT / 'plugins/sdd-review-loop/scripts' / relative,
                                scripts / relative)
            registry = root / 'specs/workflow-state-registry.json'
            registry.parent.mkdir(parents=True)
            registry.write_text('{"entries": []}')
            spec_dir = root / 'specs/example'
            spec_dir.mkdir()
            for name in ('requirements.md', 'acceptance-tests.md', 'design.md'):
                (spec_dir / name).write_text(name + '\n')
            tasks = spec_dir / 'tasks.md'
            tasks.write_text('Task-Review-Status: Passed\nApproval: Approved\n'
                             'Status: Implementation Complete\nSecond Approval: yes\n'
                             'Body: fixed\n')
            normalized = ('Task-Review-Status: Pending\nApproval: Draft\n'
                          'Status: Planned\nBody: fixed\n')
            normalized_hash = hashlib.sha256(normalized.encode()).hexdigest()
            precheck_path = (root / 'reports/task-review/example/attempt-1/round-1/'
                             'precheck-result.json')
            precheck_path.parent.mkdir(parents=True)
            precheck_path.write_text(json.dumps({
                'schema': 'task-review-precheck/v1', 'feature': 'example',
                'attempt': 1, 'round': 1, 'tasks_sha256_form': 'normalized',
                'tasks_sha256': normalized_hash,
                'requirements_sha256': TRANSPORT.sha(spec_dir / 'requirements.md'),
                'acceptance_sha256': TRANSPORT.sha(spec_dir / 'acceptance-tests.md')}))
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            ledger.write_text('unchanged')
            entries = [{'path': 'specs/example/tasks.md', 'sha256': normalized_hash},
                       {'path': precheck_path.relative_to(root).as_posix(),
                        'sha256': TRANSPORT.sha(precheck_path)}]
            data = {'stage': 'task', 'feature': 'example',
                    'allowed_input_manifest': entries}
            self.assertEqual(TRANSPORT.admitted_raw_hashes(root, data)[entries[0]['path']],
                             TRANSPORT.sha(tasks))
            tasks.write_text('Task-Review-Status: Pending\nApproval: Draft\n'
                             'Status: Planned\nBody: fixed\n')
            TRANSPORT.admitted_raw_hashes(root, data)
            tasks.write_text('Task-Review-Status: Pending\nApproval: Draft\n'
                             'Status: Planned\nBody: changed\n')
            with self.assertRaisesRegex(ValueError,
                                        'canonical normalized task verification failed'):
                TRANSPORT.admitted_raw_hashes(root, data)
            self.assertEqual(ledger.read_text(), 'unchanged')

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

    def test_quality_case_alias_and_symlink_inputs_stop_before_reservation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = quality_core_manifest(root)
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            ledger.write_text('unchanged')
            source = root / manifest[0]['path']
            data = {'allowed_input_manifest': manifest}
            alias = source.with_name(source.name.capitalize())
            data['allowed_input_manifest'] = [dict(manifest[0], path=
                alias.relative_to(root).as_posix())] + manifest[1:]
            with self.assertRaisesRegex(ValueError, 'case alias'):
                LAUNCH.checked_input_paths(root, data)
            data['allowed_input_manifest'] = manifest
            target = source.with_name('real-requirements.md')
            source.rename(target)
            source.symlink_to(target)
            with self.assertRaisesRegex(ValueError, 'traverses a symlink'):
                LAUNCH.checked_input_paths(root, data)
            self.assertEqual(ledger.read_text(), 'unchanged')


if __name__ == '__main__':
    unittest.main()
