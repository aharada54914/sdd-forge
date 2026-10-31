"""Disposable spec/impl transport regressions; no real reservation or launch."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
import uuid


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
spec = importlib.util.spec_from_file_location('nontty_transport', SOURCE)
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)


def digest(data):
    return hashlib.sha256(data.encode()).hexdigest()


class ImplTransportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'reports/review-context').mkdir(parents=True)
        (self.root / 'plugins/sdd-review-loop/references').mkdir(parents=True)
        (self.root / 'plugins/sdd-review-loop/references/review-context-boundary.md').write_text('boundary')
        self.ledger = self.root / 'reports/review-context/identity-ledger.json'
        self.ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1', 'records': []}))
        self.session = str(uuid.uuid4())
        self.data = {
            'schema': 'review-context-invocation/v2', 'stage': 'impl',
            'role': 'impl-reviewer-a', 'feature': 'fixture', 'sequence': 2,
            'run_id': self.session, 'host_session_id': self.session,
            'read_only': True, 'input_mode': 'file-manifest', 'fallback_mode': 'none',
            'identity_ledger_path': 'reports/review-context/identity-ledger.json',
            'identity_ledger_sha256': transport.sha(self.ledger),
            'previous_record_sha256': 'a' * 64,
            'allowed_input_manifest': [
                {'path': 'specs/fixture/design.md', 'sha256': 'b' * 64},
                {'path': 'specs/fixture/layer-a_2.md', 'sha256': 'c' * 64},
            ],
        }
        self.invocation = self.root / 'reports/review-context/impl-invocation.json'
        self.invocation.write_text(json.dumps(self.data))
        self.transcript = self.root / (self.session + '.jsonl')
        inputs = ('specs/fixture/design.md\t' + 'b' * 64 + '\n' +
                  'specs/fixture/layer-a_2.md\t' + 'c' * 64)
        record = '|'.join(('2', 'impl', 'impl-reviewer-a', self.session, self.session,
                           'a' * 64, 'allowed-inputs-v1', digest(inputs)))
        self.receipt = self.root / 'receipt.txt'
        self.receipt.write_text('REVIEW_CONTEXT_OK ' + digest(record) +
                                ' sequence=2 previous_record_sha256=' + 'a' * 64 +
                                ' pre_append_tip_sequence=1 identity_unique=yes\n')

    def test_cli_aliases_and_missing_flags(self):
        settings = self.root / 'settings.json'
        policy = self.root / 'policy.json'
        for entry in self.data['allowed_input_manifest']:
            path = self.root / entry['path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture')
            entry['sha256'] = transport.sha(path)
        self.invocation.write_text(json.dumps(self.data))
        inputs = '\n'.join(entry['path'] + '\t' + entry['sha256']
                           for entry in self.data['allowed_input_manifest'])
        record = '|'.join(('2', 'impl', 'impl-reviewer-a', self.session, self.session,
                           'a' * 64, 'allowed-inputs-v1', digest(inputs)))
        self.receipt.write_text('REVIEW_CONTEXT_OK ' + digest(record) +
                               ' sequence=2 previous_record_sha256=' + 'a' * 64 +
                               ' pre_append_tip_sequence=1 identity_unique=yes\n')
        guard = self.root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        guard.parent.mkdir(parents=True, exist_ok=True)
        guard.write_text('// fixture; not executed')
        policy_bytes, expected = transport.launch_policy(
            self.root, self.invocation, self.receipt, policy)
        policy.write_bytes(policy_bytes)
        settings.write_text(json.dumps(expected))
        permissions = transport.receipt_control(self.data, self.receipt.read_text())['exact_permission_rules']
        def build():
            return transport.claude_command(self.root, self.session, 'fixture', role,
                                            permissions, settings, self.invocation,
                                            self.receipt, policy)
        role = {'tools': ['Read', 'Bash'], 'model': 'sonnet',
                'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']}
        flags = ['-p, --print', '--session-id', '--model', '--permission-mode', '--tools',
                 '--disallowedTools, --disallowed-tools', '--allowedTools, --allowed-tools',
                 '--settings', '--plugin-dir', '--agents', '--agent', '--output-format']
        with mock.patch.object(transport.shutil, 'which', return_value='/fixture/claude'), \
                mock.patch.object(transport.subprocess, 'run') as run:
            run.return_value = subprocess.CompletedProcess([], 0, '\n'.join(flags), '')
            command = build()
            self.assertIn('--settings', command)
            for missing in flags:
                run.return_value.stdout = '\n'.join(flag for flag in flags if flag != missing)
                run.return_value.stdout += '\nDescription mentions ' + missing
                with self.subTest(missing=missing), self.assertRaisesRegex(ValueError, 'unsupported CLI'):
                    build()
            run.return_value.stdout = '\n'.join(flags)
            settings.write_text('{"hooks": {}}')
            with self.assertRaisesRegex(ValueError, 'settings or policy mismatch'):
                build()
            settings.write_text(json.dumps(expected))
            permissions.append('Bash(*)')
            with self.assertRaisesRegex(ValueError, 'permission rules mismatch'):
                build()
            permissions.pop()
            (self.root / self.data['allowed_input_manifest'][0]['path']).write_text('changed')
            with self.assertRaisesRegex(ValueError, 'input hash mismatch'):
                build()
            (self.root / self.data['allowed_input_manifest'][0]['path']).unlink()
            with self.assertRaisesRegex(ValueError, 'missing or symlinked'):
                build()

    def test_impl_preflight_and_complete_prompt(self):
        self.assertEqual(transport.preflight(self.root, self.invocation, self.transcript)['status'],
                         'PREFLIGHT_OK')
        prompt = transport.expected_prompt(self.root, self.invocation, self.receipt)
        self.assertTrue(prompt.startswith(b'SDD independent implementation-policy review;'))
        self.assertIn(b'Caller-provided digests alone are not reviewer proof', prompt)
        self.assertIn(b'first-Bash fact-forcing refusal may be retried once', prompt)
        control = transport.receipt_control(self.data, self.receipt.read_text())
        self.assertEqual(len(control['exact_permission_rules']), 7)
        self.assertTrue(all('*' not in rule for rule in control['exact_permission_rules']))
        self.assertIn('Bash(rtk proxy shasum -a 256 '
                      'plugins/sdd-review-loop/references/review-context-boundary.md)',
                      control['exact_permission_rules'])
        self.assertTrue(all(command.startswith('rtk proxy printf ') for command in
                            control['hash_commands']))
        for command, expected in zip(control['hash_commands'],
                                     (control['inputs_sha256'], control['record_sha256'])):
            result = subprocess.run(['rtk', 'proxy', 'bash', '-c', command],
                                    capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.split()[0], expected)
        spec_data = copy.deepcopy(self.data)
        spec_data.update(stage='spec', role='spec-reviewer-a')
        self.invocation.write_text(json.dumps(spec_data))
        self.assertEqual(transport.preflight(self.root, self.invocation, self.transcript)['status'],
                         'PREFLIGHT_OK')

    def test_session_local_pretool_guard(self):
        guard = self.root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        guard.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs',
                        guard)
        for entry in self.data['allowed_input_manifest']:
            target = self.root / entry['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('fixture')
        policy_path = self.root / 'policy.json'
        policy_bytes, settings = transport.launch_policy(self.root, self.invocation,
                                                         self.receipt, policy_path)
        policy_path.write_bytes(policy_bytes)
        policy = json.loads(policy_bytes)
        self.assertEqual([item['matcher'] for item in settings['hooks']['PreToolUse']],
                         ['*'])
        guard_command = settings['hooks']['PreToolUse'][0]['hooks'][0]['command']
        self.assertTrue(guard_command.endswith(' || exit 2'))
        def decision(event):
            result = subprocess.run(['rtk', 'proxy', 'bash', '-c', guard_command],
                                    input=json.dumps(event), text=True, capture_output=True,
                                    cwd=self.root)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout
        self.assertEqual(decision({'tool_name': 'Read', 'tool_input': {
            'file_path': str(self.root / self.data['allowed_input_manifest'][0]['path'])}}), '')
        self.assertIn('"permissionDecision":"deny"', decision({
            'tool_name': 'Read', 'tool_input': {'file_path': str(self.root / 'reviewer-a.json')}}))
        self.assertEqual(decision({'tool_name': 'Bash', 'tool_input': {
            'command': policy['bash_commands'][0]}}), '')
        self.assertIn('"permissionDecision":"deny"', decision({
            'tool_name': 'Bash', 'tool_input': {'command': policy['bash_commands'][0] + '; pwd'}}))
        self.assertIn('"permissionDecision":"deny"', decision({
            'tool_name': 'Grep', 'tool_input': {'pattern': 'secret'}}))
        alias = self.root / 'specs/fixture/reviewer-a-alias.md'
        (self.root / 'reviewer-a.json').write_text('denied fixture')
        alias.symlink_to(self.root / 'reviewer-a.json')
        self.assertIn('"permissionDecision":"deny"', decision({
            'tool_name': 'Read', 'tool_input': {'file_path': str(alias)}}))
        policy_path.write_bytes(policy_bytes + b' ')
        self.assertIn('"permissionDecision":"deny"', decision({
            'tool_name': 'Read', 'tool_input': {
                'file_path': str(self.root / self.data['allowed_input_manifest'][0]['path'])}}))
        guard.rename(guard.with_suffix('.disabled-fixture'))
        failed_start = subprocess.run(['rtk', 'proxy', 'bash', '-c', guard_command],
                                      input='{}', text=True, capture_output=True,
                                      cwd=self.root)
        self.assertEqual(failed_start.returncode, 2)

    def test_wrong_role_and_reused_identity_rejected(self):
        for change in ({'role': 'spec-reviewer-a'},
                       {'stage': 'spec'}, {'stage': 'unknown'},
                       {'read_only': False}, {'input_mode': 'other'},
                       {'fallback_mode': 'manual'}):
            bad = copy.deepcopy(self.data)
            bad.update(change)
            self.invocation.write_text(json.dumps(bad))
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, 'read-only spec/impl'):
                transport.preflight(self.root, self.invocation, self.transcript)
        bad = copy.deepcopy(self.data)
        bad['run_id'] = str(uuid.uuid4())
        self.invocation.write_text(json.dumps(bad))
        with self.assertRaisesRegex(ValueError, 'alias run_id'):
            transport.preflight(self.root, self.invocation, self.transcript)
        self.invocation.write_text(json.dumps(self.data))
        self.transcript.write_text('occupied')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            transport.preflight(self.root, self.invocation, self.transcript)
        self.transcript.unlink()
        native = self.root / '.claude/projects/another-project' / self.transcript.name
        native.parent.mkdir(parents=True)
        native.write_text('occupied native session')
        with mock.patch.object(Path, 'home', return_value=self.root):
            with self.assertRaisesRegex(ValueError, 'native transcript'):
                transport.preflight(self.root, self.invocation, self.transcript)

    def test_receipt_path_and_ledger_negatives(self):
        for path in ('specs/fixture/bad name.md', 'specs/fixture/a*b.md',
                     'specs/fixture/a)b.md', 'specs/fixture/../escape.md'):
            bad = copy.deepcopy(self.data)
            bad['allowed_input_manifest'][1]['path'] = path
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'invalid ordered'):
                transport.receipt_control(bad, self.receipt.read_text())
        bad = copy.deepcopy(self.data)
        bad['role'] = 'impl-reviewer-b'
        bad['allowed_input_manifest'][1]['path'] = 'reports/impl-review/fixture/attempt-1/round-1/reviewer-a.json'
        with self.assertRaisesRegex(ValueError, 'raw reviewer output'):
            transport.receipt_control(bad, self.receipt.read_text())
        receipt_text = self.receipt.read_text()
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            transport.receipt_control(self.data,
                                      receipt_text.replace(receipt_text.split()[1], '0' * 64))
        control = transport.receipt_control(self.data, self.receipt.read_text())
        record = {'sequence': 2, 'stage': 'impl', 'role': 'impl-reviewer-a',
                  'run_id': self.session, 'host_session_id': self.session,
                  'previous_record_sha256': 'a' * 64,
                  'record_sha256': control['record_sha256'],
                  'allowed_inputs_sha256': control['inputs_sha256']}
        self.ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1',
                                           'records': [record]}))
        with self.assertRaisesRegex(ValueError, 'already appears'):
            transport.preflight(self.root, self.invocation, self.transcript)

    def test_impl_postflight_and_negative_deliveries(self):
        prompt = self.root / 'prompt.txt'
        prompt.write_bytes(transport.expected_prompt(self.root, self.invocation, self.receipt))
        control = transport.receipt_control(self.data, self.receipt.read_text())
        record = {'sequence': 2, 'stage': 'impl', 'role': 'impl-reviewer-a',
                  'run_id': self.session, 'host_session_id': self.session,
                  'previous_record_sha256': 'a' * 64,
                  'record_sha256': control['record_sha256'],
                  'allowed_inputs_sha256': control['inputs_sha256']}
        self.ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1',
                                           'records': [record]}))
        output = {'stage': 'impl', 'role': 'impl-reviewer-a',
                  'run_id': self.session, 'host_session_id': self.session}
        wrapper = self.root / 'wrapper.json'
        wrapper.write_text(json.dumps({'type': 'result', 'is_error': False,
                                       'session_id': self.session, 'result': json.dumps(output)}))
        rows = [{'type': 'user', 'sessionId': self.session,
                 'message': {'content': prompt.read_text()}}]
        required = {'rtk proxy shasum -a 256 ' + entry['path']: entry['sha256']
                    for entry in self.data['allowed_input_manifest']}
        required['rtk proxy shasum -a 256 plugins/sdd-review-loop/references/review-context-boundary.md'] = transport.sha(
            self.root / 'plugins/sdd-review-loop/references/review-context-boundary.md')
        required.update(zip(control['hash_commands'],
                            (control['inputs_sha256'], control['record_sha256'])))
        for index, (command, expected) in enumerate(required.items()):
            tool_id = 'tool-' + str(index)
            rows.extend((
                {'type': 'assistant', 'sessionId': self.session,
                 'message': {'content': [{'type': 'tool_use', 'id': tool_id,
                                          'name': 'Bash', 'input': {'command': command}}]}},
                {'type': 'user', 'sessionId': self.session,
                 'message': {'content': [{'type': 'tool_result', 'tool_use_id': tool_id,
                                          'content': expected + '  -', 'is_error': False}]}}))
        self.transcript.write_text('\n'.join(json.dumps(row) for row in rows) + '\n')
        self.assertEqual(transport.postflight(self.root, self.invocation, self.transcript,
                                              prompt, wrapper, self.receipt)['status'], 'DELIVERY_OK')
        complete_transcript = self.transcript.read_text()
        retry_rows = copy.deepcopy(rows)
        refused = [
            {'type': 'assistant', 'sessionId': self.session,
             'message': {'content': [{'type': 'tool_use', 'id': 'fact-refusal',
                                      'name': 'Bash', 'input': {'command': next(iter(required))}}]}},
            {'type': 'user', 'sessionId': self.session,
             'message': {'content': [{'type': 'tool_result', 'tool_use_id': 'fact-refusal',
                                      'content': 'PreToolUse:Bash hook error: [Fact-Forcing Gate]',
                                      'is_error': True}]}}]
        retry_rows[1:1] = refused
        self.transcript.write_text('\n'.join(json.dumps(row) for row in retry_rows) + '\n')
        self.assertEqual(transport.postflight(self.root, self.invocation, self.transcript,
                                              prompt, wrapper, self.receipt)['status'], 'DELIVERY_OK')
        interposed = copy.deepcopy(retry_rows)
        interposed[3:3] = [
            {'type': 'assistant', 'sessionId': self.session,
             'message': {'content': [{'type': 'tool_use', 'id': 'interposed', 'name': 'Bash',
                                      'input': {'command': 'rtk proxy test -d domain'}}]}},
            {'type': 'user', 'sessionId': self.session,
             'message': {'content': [{'type': 'tool_result', 'tool_use_id': 'interposed',
                                      'content': 'Exit code 1', 'is_error': True}]}}]
        self.transcript.write_text('\n'.join(json.dumps(row) for row in interposed) + '\n')
        with self.assertRaisesRegex(ValueError, 'immediate and identical'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        retry_rows[3:3] = copy.deepcopy(refused)
        retry_rows[3]['message']['content'][0]['id'] = 'fact-refusal-2'
        retry_rows[4]['message']['content'][0]['tool_use_id'] = 'fact-refusal-2'
        self.transcript.write_text('\n'.join(json.dumps(row) for row in retry_rows) + '\n')
        with self.assertRaisesRegex(ValueError, 'one allowed first-Bash retry'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        self.transcript.write_text(complete_transcript)
        self.transcript.write_text('\n'.join(json.dumps(row) for row in rows[:-2]) + '\n')
        with self.assertRaisesRegex(ValueError, 'complete hash proof'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        wrong = copy.deepcopy(rows)
        wrong[-1]['message']['content'][0]['content'] = '0' * 64 + '  -'
        self.transcript.write_text('\n'.join(json.dumps(row) for row in wrong) + '\n')
        with self.assertRaisesRegex(ValueError, 'pinned digest'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        out_of_order = copy.deepcopy(rows)
        out_of_order[1:5] = out_of_order[3:5] + out_of_order[1:3]
        self.transcript.write_text('\n'.join(json.dumps(row) for row in out_of_order) + '\n')
        with self.assertRaisesRegex(ValueError, 'required order'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        early_read = copy.deepcopy(rows)
        read_use = {'type': 'assistant', 'sessionId': self.session,
                    'message': {'content': [{'type': 'tool_use', 'id': 'early-read',
                                             'name': 'Read', 'input': {'file_path': str(
                                                 self.root / self.data['allowed_input_manifest'][0]['path'])}}]}}
        read_result = {'type': 'user', 'sessionId': self.session,
                       'message': {'content': [{'type': 'tool_result',
                                                'tool_use_id': 'early-read',
                                                'content': 'fixture', 'is_error': False}]}}
        early_read[1:1] = [read_use, read_result]
        self.transcript.write_text('\n'.join(json.dumps(row) for row in early_read) + '\n')
        with self.assertRaisesRegex(ValueError, 'preceded required hash proof'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        failed_read = copy.deepcopy(rows) + [read_use, read_result]
        failed_read[-1]['message']['content'][0]['is_error'] = True
        self.transcript.write_text('\n'.join(json.dumps(row) for row in failed_read) + '\n')
        with self.assertRaisesRegex(ValueError, 'admitted Read failed'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        successful_read = copy.deepcopy(rows) + [read_use, read_result]
        del successful_read[-1]['message']['content'][0]['is_error']
        self.transcript.write_text('\n'.join(json.dumps(row) for row in successful_read) + '\n')
        self.assertEqual(transport.postflight(self.root, self.invocation, self.transcript,
                                              prompt, wrapper, self.receipt)['status'], 'DELIVERY_OK')
        self.transcript.write_text(complete_transcript)
        bad_record = dict(record, allowed_inputs_sha256='0' * 64)
        self.ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1',
                                           'records': [bad_record]}))
        with self.assertRaisesRegex(ValueError, 'ledger record differs'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        self.ledger.write_text(json.dumps({'schema': 'review-identity-ledger/v1',
                                           'records': [record]}))
        original_transcript = self.transcript.read_text()
        for name, tool_input in (
                ('Read', {'file_path': str(self.root / 'reports/impl-review/reviewer-a.json')}),
                ('Grep', {'pattern': 'secret', 'path': str(self.root)}),
                ('Bash', {'command': 'rtk proxy shasum -a 256 reports/review-context/identity-ledger.json'})):
            self.transcript.write_text(original_transcript + json.dumps({
                'type': 'assistant', 'sessionId': self.session,
                'message': {'content': [{'type': 'tool_use', 'name': name,
                                         'input': tool_input}]}}) + '\n')
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'impl'):
                transport.postflight(self.root, self.invocation, self.transcript,
                                     prompt, wrapper, self.receipt)
        self.transcript.write_text(original_transcript)
        prompt.write_bytes(prompt.read_bytes() + b'changed')
        with self.assertRaisesRegex(ValueError, 'complete canonical'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        prompt.write_bytes(transport.expected_prompt(self.root, self.invocation, self.receipt))
        wrapper_data = json.loads(wrapper.read_text())
        wrapper_data['is_error'] = True
        wrapper.write_text(json.dumps(wrapper_data))
        with self.assertRaisesRegex(ValueError, 'host result'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        wrapper_data['is_error'] = False
        wrapper.write_text(json.dumps(wrapper_data))
        output['role'] = 'impl-reviewer-b'
        wrapper.write_text(json.dumps({'type': 'result', 'is_error': False,
                                       'session_id': self.session, 'result': json.dumps(output)}))
        with self.assertRaisesRegex(ValueError, 'identity mismatch'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)
        output['role'] = 'impl-reviewer-a'
        wrapper.write_text(json.dumps({'type': 'result', 'is_error': False,
                                       'session_id': self.session, 'result': json.dumps(output)}))
        self.transcript.write_text(self.transcript.read_text() + json.dumps({
            'type': 'user', 'sessionId': self.session, 'message': {'content': 'extra turn'}}) + '\n')
        with self.assertRaisesRegex(ValueError, 'first-turn prompt'):
            transport.postflight(self.root, self.invocation, self.transcript,
                                 prompt, wrapper, self.receipt)


class ExistingSpecRegression(unittest.TestCase):
    def test_existing_spec_receipt_recipe_unchanged(self):
        invocation = ROOT / 'reports/review-context/epic-195-a7-compatibility-spec-a19r1-a-invocation.json'
        receipt = ROOT / ('reports/spec-review/epic-195-a7-compatibility/attempt-19/'
                          'round-1/reviewer-a-reservation-receipt.txt')
        data = json.loads(invocation.read_text())
        control = transport.receipt_control(data, receipt.read_text())
        self.assertEqual(control['record_sha256'],
                         '0599e72ba9a2382aad1b7540bfbc7f45b3424abaefc010fb686933e4d9964a95')
        self.assertTrue(all(command.startswith("printf '%s' ") for command in
                            control['hash_commands']))
        self.assertNotIn('exact_permission_rules', control)
        prompt = transport.expected_prompt(ROOT, invocation, receipt)
        self.assertTrue(prompt.startswith(b'SDD independent spec review; manifest-only, read-only.\n'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
