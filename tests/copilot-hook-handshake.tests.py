#!/usr/bin/env python3
"""Native Copilot event-pair adapter; synthetic fixtures, never host attestation."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py'
spec = importlib.util.spec_from_file_location('handshake', SCRIPT)
handshake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handshake)


class NativeCopilot(unittest.TestCase):
    def setUp(self):
        self.nonce = '0123456789abcdef' * 2
        message = ('Denied by preToolUse hook: '
                   'SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。'
                   'これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。\n'
                   '[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, '
                   'or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.')
        common = dict(parentId='prior-event', timestamp='2026-10-17T00:00:00Z')
        self.record = dict(schema='sdd-copilot-host-denial/v1', runtime='copilot-cli', nonce=self.nonce,
                           executed=False, raw_events=[
            dict(common, type='tool.execution_start', id='start-event', data=dict(
                toolCallId='fixture-call', toolName='apply_patch', model='fixture-model', turnId='0',
                arguments='*** Begin Patch\n*** Add File: sdd/.hook-canary-sentinel\n+sdd-hook-challenge:' + self.nonce + '\n*** End Patch')),
            dict(common, type='tool.execution_complete', id='complete-event', data=dict(
                toolCallId='fixture-call', model='fixture-model', turnId='0', success=False,
                error=dict(code='denied', message=message)))])

    def verify(self, record=None, runtime='copilot-cli'):
        return handshake._verify_copilot_host_denial(record or self.record, self.nonce, runtime)

    def test_native_primary_subagent_and_create(self):
        self.assertEqual(self.verify(), 'fixture-model')
        self.record['raw_events'][0]['data']['arguments'] += '\n'
        self.assertEqual(self.verify(), 'fixture-model')
        for event in self.record['raw_events']:
            event['agentId'] = 'fixture-agent'
            event['data']['parentToolCallId'] = 'fixture-parent-call'
        self.assertEqual(self.verify(), 'fixture-model')
        self.record['raw_events'][0]['data'].update(toolName='create', arguments=dict(
            path='sdd/.hook-canary-sentinel', file_text='sdd-hook-challenge:' + self.nonce))
        self.assertEqual(self.verify(), 'fixture-model')

    def test_mutations_cannot_claim_activation(self):
        mutations = {
            'extra envelope': lambda d: d.update(permissionDecision='deny'),
            'wrong runtime': lambda d: d.update(runtime='codex-cli'),
            'outer nonce': lambda d: d.update(nonce='0' * 32),
            'executed': lambda d: d.update(executed=True),
            'executed number': lambda d: d.update(executed=0),
            'missing pair': lambda d: d.update(raw_events=[]),
            'reversed pair': lambda d: d['raw_events'].reverse(),
            'tool call mismatch': lambda d: d['raw_events'][1]['data'].update(toolCallId='other'),
            'model mismatch': lambda d: d['raw_events'][1]['data'].update(model='other'),
            'turn mismatch': lambda d: d['raw_events'][1]['data'].update(turnId='1'),
            'agent mismatch': lambda d: d['raw_events'][1].update(agentId='other'),
            'parent mismatch': lambda d: d['raw_events'][1]['data'].update(parentToolCallId='other'),
            'success': lambda d: d['raw_events'][1]['data'].update(success=True),
            'success zero': lambda d: d['raw_events'][1]['data'].update(success=0),
            'non-hook deny': lambda d: d['raw_events'][1]['data']['error'].update(message='Permission denied'),
            'malformed payload': lambda d: d['raw_events'][1]['data']['error'].update(
                message='Denied by preToolUse hook: SDD deterministic gate: malformed hook payload.'),
            'code mismatch': lambda d: d['raw_events'][1]['data']['error'].update(code='error'),
            'prose tail': lambda d: d['raw_events'][1]['data']['error'].update(
                message=d['raw_events'][1]['data']['error']['message'] + '\nThe hook worked'),
            'unrelated tool': lambda d: d['raw_events'][0]['data'].update(toolName='view'),
            'unrelated target': lambda d: d['raw_events'][0]['data'].update(
                arguments=d['raw_events'][0]['data']['arguments'].replace('sdd/.hook-canary-sentinel', 'other.txt')),
            'inner nonce': lambda d: d['raw_events'][0]['data'].update(
                arguments=d['raw_events'][0]['data']['arguments'].replace(self.nonce, '0' * 32)),
            'extra write': lambda d: d['raw_events'][0]['data'].update(
                arguments=d['raw_events'][0]['data']['arguments'].replace('*** End Patch', '*** Add File: other.txt\n+write\n*** End Patch')),
            'wrong create target': lambda d: d['raw_events'][0]['data'].update(toolName='create',
                arguments=dict(path='other.txt', file_text='sdd-hook-challenge:' + self.nonce)),
        }
        for label, mutation in mutations.items():
            with self.subTest(case=label):
                changed = copy.deepcopy(self.record)
                mutation(changed)
                with self.assertRaises(handshake.HookHandshakeError):
                    self.verify(changed)
        with self.assertRaises(handshake.HookHandshakeError):
            self.verify(runtime='codex-cli')

    def test_cli_preserves_model_and_rejects_duplicate_members(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'evidence.json'
            raw = json.dumps(self.record)
            command = [sys.executable, str(SCRIPT), '--verify-response', '--nonce', self.nonce,
                       '--recorded-result', str(path), '--runtime', 'copilot-cli']
            path.write_text(raw)
            result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['actual_model'], 'fixture-model')
            self.assertFalse((Path(directory) / 'sdd/.hook-canary-sentinel').exists())
            path.write_text(raw.replace('"code": "denied"', '"code": "denied", "code": "denied"'))
            result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 61, result.stderr)

    def test_challenge_uses_available_native_tools(self):
        challenge = handshake.build_challenge()
        self.assertEqual(challenge['tool_call_template']['copilot-cli'], dict(
            tool_name='create', tool_input=dict(path='sdd/.hook-canary-sentinel',
                file_text='sdd-hook-challenge:' + challenge['nonce'])))
        alternative, = challenge['tool_call_alternatives']['copilot-cli']
        self.assertEqual(alternative, dict(tool_name='apply_patch',
            tool_input='*** Begin Patch\n*** Add File: sdd/.hook-canary-sentinel\n+sdd-hook-challenge:' + challenge['nonce'] + '\n*** End Patch'))
        template = challenge['recorded_result_template']['copilot-cli']
        self.assertEqual(template['nonce'], challenge['nonce'])
        self.assertEqual(template['raw_events'], [])
        with self.assertRaises(handshake.HookHandshakeError):
            handshake._verify_copilot_host_denial(template, challenge['nonce'], 'copilot-cli')


class NativeClaude(unittest.TestCase):
    def setUp(self):
        self.nonce = '0123456789abcdef' * 2
        self.reason = (
            'SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。'
            'これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。\n'
            '[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, '
            'or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.')
        self.record = dict(schema='sdd-claude-host-denial/v1', runtime='claude-code', nonce=self.nonce,
            executed=False, raw_request=dict(type='tool_use', id='toolu_fixture', name='Write', caller=dict(type='direct'),
                input=dict(file_path='sdd/.hook-canary-sentinel', content='sdd-hook-challenge:' + self.nonce)),
            raw_result=dict(type='tool_result', tool_use_id='toolu_fixture', is_error=True,
                content='PreToolUse:Write hook error: [sh "/fixture/scripts/sdd-hook-guard.sh" --emit exit]: '
                    + self.reason.replace('\n', '\\n') + '\\n\\nThis hook comes from the sdd-quality-loop@inline plugin.'))

    def verify(self, record=None, runtime='claude-code'):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'evidence.json'
            path.write_text(json.dumps(record or self.record), encoding='utf-8')
            return handshake.run_verify_response(self.nonce, str(path), runtime)

    def test_native_denial_without_numeric_exit(self):
        self.verify()
        self.record['raw_request']['input']['file_path'] = str(Path('sdd/.hook-canary-sentinel').resolve())
        self.verify()
        self.record['raw_result']['content'] = self.record['raw_result']['content'].replace('\\n', '\n')
        self.verify()

    def test_installed_marketplace_uses_canonical_node_guard(self):
        self.record['raw_result']['content'] = self.record['raw_result']['content'].replace(
            'sh "/fixture/scripts/sdd-hook-guard.sh"', 'node /fixture/scripts/sdd-hook-guard.js'
        ).replace('sdd-quality-loop@inline', 'sdd-quality-loop@fixture-marketplace')
        self.verify()
        for old,new in [('sdd-hook-guard.js','unrelated.js'),
                        ('--emit exit]','--emit exit; other-operation]'),
                        ('sdd-quality-loop@fixture-marketplace','other@fixture-marketplace')]:
            changed=copy.deepcopy(self.record)
            changed['raw_result']['content']=changed['raw_result']['content'].replace(old,new)
            with self.assertRaises(handshake.HookHandshakeError):self.verify(changed)

    def test_guard_wrapper_is_one_absolute_script_operand(self):
        original = 'sh "/fixture/scripts/sdd-hook-guard.sh"'
        for command in ['node /fixture/scripts/sdd-hook-guard.js',
                        'node "/fixture with space/scripts/sdd-hook-guard.js"',
                        r'node "C:\fixture with space\scripts\sdd-hook-guard.js"']:
            with self.subTest(valid=command):
                changed = copy.deepcopy(self.record)
                changed['raw_result']['content'] = changed['raw_result']['content'].replace(original, command)
                self.verify(changed)
        for command in ['node unrelated.js && node /fixture/scripts/sdd-hook-guard.js',
                        'node --import /fixture/scripts/sdd-hook-guard.js',
                        'node /other.js /fixture/scripts/sdd-hook-guard.js',
                        'node relative/scripts/sdd-hook-guard.js',
                        'node /fixture;other/scripts/sdd-hook-guard.js',
                        'node "/fixture$(other)/scripts/sdd-hook-guard.js"',
                        'sh "/fixture`other`/scripts/sdd-hook-guard.sh"',
                        'node "/fixture/scripts/sdd-hook-guard.js" other']:
            with self.subTest(invalid=command):
                changed = copy.deepcopy(self.record)
                changed['raw_result']['content'] = changed['raw_result']['content'].replace(original, command)
                with self.assertRaises(handshake.HookHandshakeError):
                    self.verify(changed)

    def test_mismatched_and_unrelated_native_results_are_rejected(self):
        mutations = {
            'extra envelope': lambda d: d.update(exit_code=2),
            'wrong runtime': lambda d: d.update(runtime='copilot-cli'),
            'outer nonce': lambda d: d.update(nonce='0' * 32),
            'executed': lambda d: d.update(executed=True),
            'executed number': lambda d: d.update(executed=0),
            'request missing': lambda d: d.update(raw_request=None),
            'request list': lambda d: d.update(raw_request=[d['raw_request']]),
            'extra operation': lambda d: d['raw_request'].update(other_tool='Write'),
            'wrong request type': lambda d: d['raw_request'].update(type='tool_result'),
            'wrong tool': lambda d: d['raw_request'].update(name='Bash'),
            'wrong caller': lambda d: d['raw_request'].update(caller={'type':'code_execution'}),
            'extra caller field': lambda d: d['raw_request'].update(caller={'type':'direct','other':'operation'}),
            'empty id': lambda d: d['raw_request'].update(id=''),
            'different id': lambda d: d['raw_result'].update(tool_use_id='other'),
            'wrong path': lambda d: d['raw_request']['input'].update(file_path='other.txt'),
            'lookalike path': lambda d: d['raw_request']['input'].update(file_path='other/sdd/.hook-canary-sentinel'),
            'inner nonce': lambda d: d['raw_request']['input'].update(content='sdd-hook-challenge:'+'0'*32),
            'empty canary': lambda d: d['raw_request']['input'].update(content=''),
            'extra content': lambda d: d['raw_request']['input'].update(content='sdd-hook-challenge:'+self.nonce+'\n'),
            'extra argument': lambda d: d['raw_request']['input'].update(command='write another file'),
            'result missing': lambda d: d.update(raw_result=None),
            'extra result': lambda d: d['raw_result'].update(exit_code=2),
            'wrong result type': lambda d: d['raw_result'].update(type='tool_use'),
            'success': lambda d: d['raw_result'].update(is_error=False),
            'error number': lambda d: d['raw_result'].update(is_error=1),
            'generic denial': lambda d: d['raw_result'].update(content='Permission denied'),
            'malformed payload': lambda d: d['raw_result'].update(content='PreToolUse:Write hook error: malformed hook payload'),
            'tool mismatch': lambda d: d['raw_result'].update(content=d['raw_result']['content'].replace('PreToolUse:Write','PreToolUse:Bash')),
            'wrong hook': lambda d: d['raw_result'].update(content=d['raw_result']['content'].replace('sdd-hook-guard.sh','other.sh')),
            'wrong plugin': lambda d: d['raw_result'].update(content=d['raw_result']['content'].replace('sdd-quality-loop@inline','other@inline')),
            'prose prefix': lambda d: d['raw_result'].update(content='Blocked! '+d['raw_result']['content']),
            'prose suffix': lambda d: d['raw_result'].update(content=d['raw_result']['content']+'\nverified'),
        }
        for label, mutation in mutations.items():
            with self.subTest(case=label):
                changed=copy.deepcopy(self.record);mutation(changed)
                with self.assertRaises(handshake.HookHandshakeError):self.verify(changed)
        with self.assertRaises(handshake.HookHandshakeError):self.verify(runtime='copilot-cli')

    def test_nonce_is_present_in_claude_challenge_and_capture_template(self):
        challenge=handshake.build_challenge()
        self.assertEqual(challenge['tool_call_template']['claude-code']['tool_input'], dict(
            file_path='sdd/.hook-canary-sentinel',content='sdd-hook-challenge:'+challenge['nonce']))
        template=challenge['recorded_result_template']['claude-code']
        self.assertEqual(template['schema'], 'sdd-claude-host-denial/v1')
        self.assertEqual(template['nonce'], challenge['nonce'])
        self.assertIsNone(template['raw_request']);self.assertIsNone(template['raw_result'])
        self.assertIn('Never infer',challenge['capture_instructions']['claude-code'])

    def test_cli_duplicate_raw_members_remain_unreadable(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'evidence.json'
            raw=json.dumps(self.record).replace('"is_error": true','"is_error": true, "is_error": true')
            path.write_text(raw)
            result=subprocess.run([sys.executable,str(SCRIPT),'--verify-response','--nonce',self.nonce,
                '--recorded-result',str(path),'--runtime','claude-code'],capture_output=True,text=True)
            self.assertEqual(result.returncode,61,result.stderr)


if __name__ == '__main__':
    unittest.main()
