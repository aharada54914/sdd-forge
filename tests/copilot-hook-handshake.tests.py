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


if __name__ == '__main__':
    unittest.main()
