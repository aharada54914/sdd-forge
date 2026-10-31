"""Task-only structured-output transport contracts; no native Claude or reservation."""
import ast
import importlib.util
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import uuid


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
PROBE = ROOT / 'plugins/sdd-review-loop/scripts/probe-nontty-review.py'
spec = importlib.util.spec_from_file_location('task_structured_transport', SOURCE)
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)


class TaskStructuredOutputTests(unittest.TestCase):
    def test_enforced_control_prompt_numbers_every_exact_hash_in_required_order(self):
        entries = [{'path': 'specs/example/requirements.md', 'sha256': 'a' * 64},
                   {'path': 'specs/example/design.md', 'sha256': 'b' * 64}]
        commands = ['rtk proxy printf %s first | rtk proxy shasum -a 256',
                    'rtk proxy printf %s second | rtk proxy shasum -a 256']
        control = {'hash_commands': commands, 'exact_permission_rules': []}
        invocation_path = 'review/invocation.json'
        expected = [transport.file_hash_batch_command(
            [invocation_path] + [entry['path'] for entry in entries] +
            [transport.BOUNDARY_PATH])] + commands
        with mock.patch.object(transport, 'receipt_control', return_value=control):
            for stage in ('spec', 'impl', 'task', 'quality'):
                data = {'stage': stage, 'allowed_input_manifest': entries}
                prompt = transport.control_prompt(data, 'receipt', 'c' * 64, strict=True,
                                                  invocation_path=invocation_path,
                                                  invocation_sha256='d' * 64)
                positions = []
                for number, command in enumerate(expected, 1):
                    marker = f'{number}.\n```sh\n{command}\n```'
                    with self.subTest(stage=stage, number=number):
                        self.assertIn(marker, prompt)
                    positions.append(prompt.index(marker))
                self.assertEqual(positions, sorted(positions))
            legacy = transport.control_prompt({'stage': 'spec',
                                               'allowed_input_manifest': entries},
                                              'receipt', 'c' * 64, strict=False)
            self.assertNotIn('1.\n```sh', legacy)

    def test_probe_scratch_uses_existing_ledger_parent(self):
        parsed = ast.parse(PROBE.read_text())
        call = next(node for node in ast.walk(parsed)
                    if isinstance(node, ast.Call) and
                    isinstance(node.func, ast.Attribute) and
                    node.func.attr == 'TemporaryDirectory')
        directory = next(arg.value for arg in call.keywords if arg.arg == 'dir')
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            ledger = root / 'reports/review-context/identity-ledger.json'
            ledger.parent.mkdir(parents=True)
            ledger.write_text('{"records": []}')
            before = ledger.read_bytes()
            parent = eval(compile(ast.Expression(directory), str(PROBE), 'eval'),
                          {'ROOT': root, 'ledger': ledger})
            with tempfile.TemporaryDirectory(prefix='.review-read-guard-', dir=parent):
                self.assertFalse((root / 'reports/verification').exists())
            self.assertEqual(ledger.read_bytes(), before)
            self.assertEqual(list(ledger.parent.iterdir()), [ledger])

    def test_probe_output_result_matching_and_completion_order(self):
        # The probe is an executable entrypoint; isolate its pure check without launching it.
        parsed = ast.parse(PROBE.read_text())
        function = next(node for node in parsed.body
                        if isinstance(node, ast.FunctionDef) and
                        node.name == 'require_json_output_completion')
        namespace = {'transport': transport}
        exec(compile(ast.Module(body=[function], type_ignores=[]), str(PROBE), 'exec'),
             namespace)
        verify = namespace['require_json_output_completion']
        call = ('use', {'name': 'StructuredOutput', 'id': 'out-1'})
        success = ('result', {'tool_use_id': 'out-1', 'is_error': False})
        prior = [('use', {'name': 'Read', 'id': 'read-1'}),
                 ('result', {'tool_use_id': 'read-1', 'is_error': False})]
        for stage in transport.JSON_REVIEW_STAGES:
            verify(prior + [call, success], stage)
        verify(prior, 'quality')
        for events in (prior + [call],
                       prior + [call, ('result', {'tool_use_id': 'out-1',
                                                  'is_error': True})],
                       prior + [call, success, success],
                       prior + [success, call],
                       prior + [call, success, ('result', {'tool_use_id': 'read-1'})]):
            for stage in transport.JSON_REVIEW_STAGES:
                with self.subTest(events=events, stage=stage), self.assertRaises(SystemExit):
                    verify(events, stage)

    def command(self, stage, role_name, agent_tools, help_has_schema=True):
        session = str(uuid.uuid4())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            guard = root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
            guard.parent.mkdir(parents=True)
            guard.write_text('// fixture only')
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            receipt = root / 'receipt.txt'
            receipt.write_text('fixture receipt')
            policy = root / 'policy.json'
            policy.write_bytes(b'fixture policy')
            settings = root / 'settings.json'
            settings.write_text(json.dumps({'hooks': {}}))
            data = {'stage': stage, 'role': role_name, 'host_session_id': session}
            role = {'model': 'sonnet', 'tools': agent_tools,
                    'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']}
            flags = ['-p, --print', '--session-id', '--model', '--permission-mode',
                     '--tools', '--disallowedTools', '--settings',
                     '--plugin-dir', '--agents', '--agent', '--output-format']
            if help_has_schema:
                flags.append('--json-schema')
            with mock.patch.object(transport, 'manifest', return_value=(data, None)), \
                    mock.patch.object(transport, 'launch_policy',
                                      return_value=(b'fixture policy', {'hooks': {}})), \
                    mock.patch.object(transport, 'receipt_control',
                                      return_value={'exact_permission_rules': ['Read']}), \
                    mock.patch.object(transport, 'admitted_raw_hashes', return_value={}), \
                    mock.patch.object(transport.shutil, 'which', return_value='/fixture/claude'), \
                    mock.patch.object(transport.subprocess, 'run', return_value=
                                      subprocess.CompletedProcess([], 0, '\n'.join(flags), '')):
                return transport.claude_command(root, session, role_name, role,
                                                ['Read'], settings, invocation, receipt, policy)

    def test_json_review_schema_and_output_only_agent_capability(self):
        for stage, role_name in (('spec', 'spec-reviewer-a'),
                                 ('spec', 'spec-reviewer-b'),
                                 ('impl', 'impl-reviewer-a'),
                                 ('impl', 'impl-reviewer-b'),
                                 ('task', 'task-reviewer-a'),
                                 ('task', 'task-reviewer-b')):
            with self.subTest(stage=stage, role=role_name):
                command = self.command(stage, role_name,
                                       ['Read', 'Bash', 'StructuredOutput'])
                self.assertIn('--json-schema', command)
                schema = json.loads(command[command.index('--json-schema') + 1])
                self.assertEqual(schema['type'], 'object')
                agent = json.loads(command[command.index('--agents') + 1])[role_name]
                self.assertEqual(agent['tools'], ['Read', 'Bash', 'StructuredOutput'])
                self.assertEqual(command[command.index('--tools') + 1], 'Read,Bash')
                self.assertNotIn('--allowedTools', command)

    def test_output_schema_rejects_stringified_fields_without_fabricating_probe_verdict(self):
        cases = []
        for stage in transport.JSON_REVIEW_STAGES:
            for role in transport.STAGE_ROLES[stage]:
                command = self.command(stage, role, ['Read', 'Bash', 'StructuredOutput'])
                schema = json.loads(command[command.index('--json-schema') + 1])
                entries = [{'path': 'specs/example/design.md', 'sha256': 'a' * 64}]
                fields = {'checks': [{'id': 'EXAMPLE', 'result': 'PASS', 'status': 'PASS',
                                      'severity': 'Minor', 'finding': 'No issues found.'}]}
                if stage == 'task':
                    fields['manifest'] = entries if role.endswith('-a') else {'allowed_inputs': entries}
                    fields['findings'] = []
                else:
                    fields['allowed_input_manifest'] = entries
                if role == 'impl-reviewer-a':
                    fields.update(legacy_design=False, feature_type='bugfix')
                cases.extend([(schema, {}, True), (schema, fields, True)])
                for key, value in fields.items():
                    if not isinstance(value, str):
                        cases.append((schema, {**fields, key: json.dumps(value)}, False))
                manifest_key = 'manifest' if stage == 'task' else 'allowed_input_manifest'
                wrong_entries = [{'path': 42, 'sha256': False}]
                wrong_manifest = ({'allowed_inputs': wrong_entries} if role == 'task-reviewer-b'
                                  else wrong_entries)
                cases.append((schema, {**fields, manifest_key: wrong_manifest}, False))
        result = subprocess.run(['rtk', 'proxy', 'node', '-e', '''
const Ajv = require('./mcp/ci-mcp/node_modules/ajv');
const cases = JSON.parse(require('fs').readFileSync(0, 'utf8'));
const ajv = new Ajv({strict: false});
for (const [schema, value, expected] of cases) {
  const validate = ajv.compile(schema);
  if (validate(value) !== expected) throw Error(JSON.stringify({value, expected, errors: validate.errors}));
}
'''], input=json.dumps(cases), text=True, capture_output=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_json_review_missing_schema_capability_fails_closed(self):
        for stage, role in (('spec', 'spec-reviewer-a'), ('impl', 'impl-reviewer-a'),
                            ('task', 'task-reviewer-a')):
            with self.subTest(stage=stage), self.assertRaisesRegex(ValueError,
                                                                     'unsupported CLI argument'):
                self.command(stage, role, ['Read', 'Bash', 'StructuredOutput'],
                             help_has_schema=False)

    def test_quality_plaintext_command_profile_is_unchanged(self):
        command = self.command('quality', 'sdd-evaluator', ['Read', 'Bash'])
        self.assertNotIn('--json-schema', command)
        self.assertEqual(json.loads(command[command.index('--agents') + 1])
                         ['sdd-evaluator']['tools'], ['Read', 'Bash'])

    def test_json_stages_cannot_revert_to_read_bash_only_profile(self):
        for stage, role in (('spec', 'spec-reviewer-a'), ('impl', 'impl-reviewer-a')):
            with self.subTest(stage=stage), self.assertRaisesRegex(ValueError,
                                                                     'unsupported role permission'):
                self.command(stage, role, ['Read', 'Bash'], help_has_schema=False)

    def test_probe_order_accepts_only_final_task_output_call(self):
        expected = [('Bash', 'hash-one'), ('Read', 'admitted'),
                    ('Bash', 'denied-chain'), ('Read', 'denied-outside')]
        final = ('StructuredOutput', None)
        for stage in transport.JSON_REVIEW_STAGES:
            transport.require_probe_tool_sequence(expected + [final], expected, stage)
            for actual in (expected, expected[:1] + [final] + expected[1:],
                           expected + [final, final], expected + [('Bash', 'extra'), final]):
                with self.subTest(actual=actual, stage=stage), \
                        self.assertRaisesRegex(ValueError, 'probe tool sequence'):
                    transport.require_probe_tool_sequence(actual, expected, stage)
        with self.assertRaisesRegex(ValueError, 'probe tool sequence'):
            transport.require_probe_tool_sequence(expected + [final], expected, 'quality')

    def test_session_guard_output_tool_is_task_only(self):
        guard = ROOT / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        with tempfile.TemporaryDirectory() as temp:
            policy_path = Path(temp) / 'policy.json'
            def decision(policy, name, tool_input):
                data = json.dumps(policy, sort_keys=True, separators=(',', ':')).encode()
                policy_path.write_bytes(data)
                digest = hashlib.sha256(data).hexdigest()
                result = subprocess.run(['rtk', 'proxy', 'node', str(guard),
                                         str(policy_path), digest],
                                        input=json.dumps({'tool_name': name,
                                                          'tool_input': tool_input}),
                                        text=True, capture_output=True, check=True)
                return result.stdout
            base = {'schema': 'impl-nontty-pretool/v1', 'read_paths': [],
                    'bash_commands': []}
            task = dict(base, output_tool='StructuredOutput')
            self.assertEqual(decision(task, 'StructuredOutput', {'stage': 'task'}), '')
            for policy, name, tool_input in (
                    (base, 'StructuredOutput', {'stage': 'task'}),
                    (task, 'Grep', {'pattern': 'secret'}),
                    (task, 'Write', {'file_path': 'outside'})):
                with self.subTest(policy=policy, name=name):
                    self.assertIn('"permissionDecision":"deny"',
                                  decision(policy, name, tool_input))

    def test_generated_policy_admits_output_only_for_task(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            boundary = root / 'plugins/sdd-review-loop/references/review-context-boundary.md'
            boundary.parent.mkdir(parents=True)
            boundary.write_text('boundary')
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            receipt = root / 'receipt.txt'
            receipt.write_text('receipt')
            for stage in ('spec', 'impl', 'task', 'quality'):
                with self.subTest(stage=stage), \
                        mock.patch.object(transport, 'manifest', return_value=(
                            {'stage': stage, 'allowed_input_manifest': []}, None)), \
                        mock.patch.object(transport, 'receipt_control', return_value={
                            'hash_commands': [], 'exact_permission_rules': []}):
                    policy, _ = transport.launch_policy(root, invocation, receipt,
                                                        root / 'policy.json')
                    self.assertEqual(json.loads(policy).get('output_tool'),
                                     'StructuredOutput' if stage in transport.JSON_REVIEW_STAGES
                                     else None)

    def test_formal_transcript_requires_final_single_output_tool(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            session = str(uuid.uuid4())
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            receipt = root / 'receipt.txt'
            receipt.write_text('receipt')
            prompt = root / 'prompt.txt'
            prompt.write_text('first turn')
            wrapper = root / 'wrapper.json'
            wrapper.write_text(json.dumps({'type': 'result', 'session_id': session,
                                           'is_error': False, 'result': '{}'}))
            boundary = root / 'plugins/sdd-review-loop/references/review-context-boundary.md'
            boundary.parent.mkdir(parents=True)
            boundary.write_text('boundary')
            control = {'hash_commands': ['verify-all-inputs'],
                       'compact_command': 'verify-all-inputs',
                       'compact_output': '{"status":"REVIEW_INPUTS_OK"}',
                       'inputs_sha256': 'a' * 64, 'record_sha256': 'b' * 64}
            boundary_command = control['compact_command']
            hashes = [(boundary_command, control['compact_output'])]
            def transcript(events):
                rows = [{'type': 'user', 'sessionId': session,
                         'message': {'content': 'first turn'}}]
                for index, (name, value, digest) in enumerate(events):
                    if name == 'Meta':
                        rows.append({'type': 'user', 'sessionId': session,
                                     'isMeta': digest, 'message': {'content': value}})
                        continue
                    tool_id = 'tool-' + str(index)
                    tool_input = ({'command': value} if name == 'Bash' else
                                  {'file_path': value} if name == 'Read' else {'ok': True})
                    rows.append({'type': 'assistant', 'sessionId': session,
                                 'message': {'content': [{'type': 'tool_use', 'id': tool_id,
                                                          'name': name, 'input': tool_input}]}})
                    rows.append({'type': 'user', 'sessionId': session,
                                 'message': {'content': [{'type': 'tool_result',
                                                          'tool_use_id': tool_id,
                                                          'is_error': False,
                                                          'content': (digest if value == boundary_command else
                                                                      digest + '  -')
                                                          if digest else 'ok'}]}})
                path = root / (session + '.jsonl')
                path.write_text('\n'.join(json.dumps(row) for row in rows))
                return path
            hash_events = [('Bash', command, digest) for command, digest in hashes]
            output_event = ('StructuredOutput', None, None)
            meta_text = ('[structured-output-enforce] You MUST call the StructuredOutput '
                         'tool to complete this request. Call this tool now.')
            meta_event = ('Meta', meta_text, True)
            for stage, role in (('spec', 'spec-reviewer-a'), ('impl', 'impl-reviewer-a'),
                                ('task', 'task-reviewer-a')):
                data = {'stage': stage, 'role': role, 'host_session_id': session,
                        'sequence': 1, 'previous_record_sha256': '-',
                        'allowed_input_manifest': []}
                record = {'run_id': session, 'host_session_id': session,
                          'sequence': 1, 'stage': stage, 'role': role,
                          'previous_record_sha256': '-', 'record_sha256': 'b' * 64}
                if stage != 'task':
                    record['allowed_inputs_sha256'] = 'a' * 64
                with self.subTest(stage=stage), \
                        mock.patch.object(transport, 'manifest', return_value=(
                            data, {'records': [record]})), \
                        mock.patch.object(transport, 'expected_prompt', return_value=b'first turn'), \
                        mock.patch.object(transport, 'receipt_control', return_value=control), \
                        mock.patch.object(transport, 'admitted_raw_hashes', return_value={}):
                    good = transport.native_delivery(root, invocation,
                                                     transcript(hash_events + [output_event]),
                                                     prompt, wrapper, receipt, strict=True)
                    self.assertEqual(good[0]['stage'], stage)
                    pending_read = transcript(hash_events + [('Read', str(invocation), None),
                                                             output_event])
                    pending_rows = [json.loads(line) for line in pending_read.read_text().splitlines()]
                    pending_rows.pop(-3)  # Omit Read result while keeping StructuredOutput.
                    pending_read.write_text('\n'.join(json.dumps(row) for row in pending_rows))
                    with self.assertRaisesRegex(ValueError, 'StructuredOutput preceded hash proof or tool result'):
                        transport.native_delivery(root, invocation, pending_read,
                                                  prompt, wrapper, receipt, strict=True)
                    self.assertEqual(transport.native_delivery(
                        root, invocation, transcript(hash_events + [meta_event, output_event]),
                        prompt, wrapper, receipt, strict=True)[0]['stage'], stage)
                    for events in (hash_events, [output_event] + hash_events,
                                   hash_events + [output_event, output_event],
                                   hash_events + [output_event, ('Grep', None, None)],
                                   [meta_event] + hash_events + [output_event],
                                   hash_events + [output_event, meta_event],
                                   hash_events + [meta_event, meta_event, output_event],
                                   hash_events + [('Meta', meta_text, False), output_event],
                                   hash_events + [('Meta', 'ordinary extra user', True), output_event],
                                   hash_events + [('Meta', 'ordinary extra user', False), output_event]):
                        with self.subTest(events=events), self.assertRaises(ValueError):
                            transport.native_delivery(root, invocation, transcript(events),
                                                      prompt, wrapper, receipt, strict=True)
                    leading = transcript(hash_events + [meta_event, output_event])
                    rows = [json.loads(line) for line in leading.read_text().splitlines()]
                    rows.insert(0, rows.pop(-3))
                    leading.write_text('\n'.join(json.dumps(row) for row in rows))
                    with self.assertRaises(ValueError):
                        transport.native_delivery(root, invocation, leading, prompt,
                                                  wrapper, receipt, strict=True)
                    if stage == 'spec':
                        with self.assertRaises(ValueError):
                            transport.native_delivery(
                                root, invocation,
                                transcript(hash_events + [meta_event, output_event]),
                                prompt, wrapper, receipt, strict=False)
            quality_data = {'stage': 'quality', 'role': 'sdd-evaluator',
                            'host_session_id': session, 'sequence': 1,
                            'previous_record_sha256': '-', 'allowed_input_manifest': []}
            quality_record = {'run_id': session, 'host_session_id': session,
                              'sequence': 1, 'stage': 'quality', 'role': 'sdd-evaluator',
                              'previous_record_sha256': '-', 'record_sha256': 'b' * 64,
                              'scratch_declaration_sha256': 'c' * 64}
            quality_control = dict(control, scratch_declaration_sha256='c' * 64)
            with mock.patch.object(transport, 'manifest', return_value=(
                    quality_data, {'records': [quality_record]})), \
                    mock.patch.object(transport, 'expected_prompt', return_value=b'first turn'), \
                    mock.patch.object(transport, 'receipt_control', return_value=quality_control):
                with self.assertRaises(ValueError):
                    transport.native_delivery(root, invocation,
                                              transcript(hash_events + [meta_event]),
                                              prompt, wrapper, receipt, strict=True)

    def test_strict_postflight_keeps_raw_json_and_structured_field_bound(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            prompt, transcript, wrapper = (root / name for name in ('prompt', 'transcript', 'wrapper'))
            for path in (prompt, transcript, wrapper):
                path.write_text('fixture')
            for stage, role, output_stage, output_role in (
                    ('spec', 'spec-reviewer-a', 'spec', 'spec-reviewer-a'),
                    ('impl', 'impl-reviewer-a', 'impl', 'impl-reviewer-a'),
                    ('task', 'task-reviewer-a', 'task-review', 'reviewer-a')):
                data = {'stage': stage, 'role': role, 'host_session_id': 'session'}
                output = {'stage': output_stage, 'role': output_role,
                          'run_id': 'session', 'host_session_id': 'session'}
                for raw, structured, accepted in (
                        (json.dumps(output), output, True),
                        ('```json\n' + json.dumps(output) + '\n```', output, False),
                        (json.dumps(output), {'different': True}, False),
                        (json.dumps(output), None, False)):
                    with self.subTest(stage=stage, raw=raw[:20], structured=structured), \
                            mock.patch.object(transport, 'native_delivery', return_value=(
                                data, {'result': raw, 'structured_output': structured}, [])):
                        invoke = lambda: transport.postflight(root, root / 'invocation', transcript,
                                                              prompt, wrapper, root / 'receipt', strict=True)
                        if accepted:
                            self.assertEqual(invoke()['status'], 'DELIVERY_OK')
                        else:
                            with self.assertRaises((ValueError, json.JSONDecodeError)):
                                invoke()


if __name__ == '__main__':
    unittest.main()
