#!/usr/bin/env python3
"""Native discovery contracts, credential boundaries and bounded transport."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('discovery', ROOT / 'plugins/sdd-implementation/scripts/model-discovery.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class Discovery(unittest.TestCase):
    def client(self):
        p = patch.object(d, 'NativeClient')
        factory = p.start(); self.addCleanup(p.stop)
        return factory.return_value.__enter__.return_value

    def test_codex_uses_existing_subscription_and_paginates_visible_models(self):
        client = self.client()
        def page(name, cursor):
            return {'data': [{'model': name, 'displayName': 'Display ' + name,
                'supportedReasoningEfforts': [{'reasoningEffort': 'medium'}, {'reasoningEffort': 'ultra'}],
                'defaultReasoningEffort': 'medium'}], 'nextCursor': cursor}
        client.request.side_effect = [{}, {'account': {'type': 'chatgpt', 'email': 'PRIVATE'}},
                                      page('first', 'page2'), page('second', None),
                                      {'account': {'type': 'chatgpt', 'email': 'PRIVATE'}}]
        rows, auth = d.codex('/cli/codex', '.')
        self.assertEqual(auth, 'subscription')
        self.assertEqual([r['model'] for r in rows], ['first', 'second'])
        self.assertEqual(rows[0]['efforts'], ['medium', 'ultra'])
        self.assertEqual(rows[0]['default_effort'], 'medium')
        self.assertEqual(client.request.call_args_list[2].args[2], {'limit': 100, 'includeHidden': False})
        self.assertEqual(client.request.call_args_list[3].args[2]['cursor'], 'page2')
        self.assertNotIn('PRIVATE', json.dumps(rows))

    def test_codex_auth_failure_and_cursor_cycle_do_not_return_partial_list(self):
        client = self.client(); client.request.side_effect = [{}, {'account': None}]
        with self.assertRaisesRegex(d.DiscoveryError, 'authentication'):
            d.codex('codex', '.')
        client.request.side_effect = [{}, {'account': {'type': 'apiKey'}},
                                      {'data': [], 'nextCursor': 'same'}, {'data': [], 'nextCursor': 'same'}]
        with self.assertRaisesRegex(d.DiscoveryError, 'pagination'):
            d.codex('codex', '.')

    def test_codex_account_change_during_listing_invalidates_catalog(self):
        client = self.client()
        client.request.side_effect = [{}, {'account': {'type': 'chatgpt', 'email': 'first'}},
                                      {'data': [], 'nextCursor': None},
                                      {'account': {'type': 'chatgpt', 'email': 'second'}}]
        with self.assertRaisesRegex(d.DiscoveryError, 'authentication-changed'):
            d.codex('codex', '.')

    def test_claude_uses_native_per_model_efforts_instead_of_help_or_fixed_aliases(self):
        client = self.client()
        client.receive.return_value = {'type': 'control_response', 'response': {'request_id': 'discovery',
            'subtype': 'success', 'response': {'account': {'tokenSource': 'oauth', 'apiKeySource': 'none'},
            'models': [{'value': 'new[1m]', 'displayName': 'New', 'supportsEffort': True,
                        'supportedEffortLevels': ['high', 'ultra']},
                       {'value': 'small', 'displayName': 'Small', 'supportsEffort': False}]}}}
        rows, auth = d.claude('claude', '.')
        self.assertEqual(auth, 'oauth')
        self.assertEqual(rows[0]['efforts'], ['high', 'ultra'])
        self.assertEqual(rows[1]['efforts'], [])
        self.assertEqual(client.send.call_args.args[0]['request'], {'subtype': 'initialize'})
        self.assertEqual(client.send.call_count, 1)

    def test_claude_no_auth_or_interactive_request_fails_without_login(self):
        client = self.client()
        client.receive.return_value = {'type': 'control_request', 'request_id': 'login'}
        with self.assertRaises(d.DiscoveryError):
            d.claude('claude', '.')
        client.receive.return_value = {'type': 'control_response', 'response': {'request_id': 'discovery',
            'subtype': 'success', 'response': {'account': {}, 'models': []}}}
        with self.assertRaisesRegex(d.DiscoveryError, 'authentication'):
            d.claude('claude', '.')

    def test_gemini_reads_authenticated_session_not_static_command_or_permission_modes(self):
        client = self.client()
        client.request.side_effect = [{'protocolVersion': 1}, {'sessionId': 'private-session',
            'modes': {'availableModes': [{'id': 'yolo'}, {'id': 'plan'}]},
            'models': {'availableModels': [{'modelId': 'fresh-model', 'name': 'Fresh'}]}}]
        rows, auth = d.gemini('gemini', '.')
        self.assertEqual(auth, 'cli-managed')
        self.assertEqual(rows[0]['model'], 'fresh-model')
        self.assertEqual(rows[0]['efforts'], [])
        self.assertEqual([c.args[1] for c in client.request.call_args_list], ['initialize', 'session/new'])
        self.assertEqual(client.request.call_args.args[2]['mcpServers'], [])

    def test_failed_provider_is_explicit_and_never_falls_back_or_leaks_errors(self):
        good = d.model_row('codex-cli', 'live', ['medium'], 'fixture')
        # The real protocols wrap remote errors; malformed local responses are also sanitized.
        def invalid(*_): raise ValueError('PRIVATE credential')
        with patch.object(d.shutil, 'which', return_value='/cli'), patch.dict(d.ADAPTERS, {
            'claude-code': invalid, 'codex-cli': lambda *_: ([good], 'subscription'), 'gemini-cli': invalid}):
            result = d.discover('.')
        self.assertEqual(result['models'], [good])
        self.assertEqual(result['providers']['gemini-cli']['status'], 'unavailable')
        self.assertNotIn('PRIVATE', json.dumps(result))

    def test_missing_cli_does_not_supply_example_or_environment_models(self):
        with patch.object(d.shutil, 'which', return_value=None), patch.dict(d.os.environ, {'ANTHROPIC_MODEL': 'invented'}):
            result = d.discover('.')
        self.assertEqual(result['models'], [])
        self.assertTrue(all(not p['installed'] for p in result['providers'].values()))

    def test_invalid_identifiers_efforts_and_duplicate_rows_are_rejected(self):
        for model, efforts in [('--option', []), ('x\nsecret', []), ('okay', ['high;cmd']), ('okay', ['high', 'high'])]:
            with self.subTest(model=model, efforts=efforts), self.assertRaises(d.DiscoveryError):
                d.model_row('claude-code', model, efforts, 'fixture')
        row = d.model_row('claude-code', 'native', [], 'fixture')
        with patch.object(d.shutil, 'which', return_value='/cli'), patch.dict(d.ADAPTERS, {
            host: lambda *_: ([row, row], 'cli-managed') for host in d.HOSTS}):
            result = d.discover('.')
        self.assertEqual(result['models'], [])


class Transport(unittest.TestCase):
    def test_real_pipe_correlates_and_rejects_server_tool_requests(self):
        program = '''import json,sys
request=json.loads(input())
print(json.dumps({'jsonrpc':'2.0','id':'tool','method':'session/request_permission','params':{}}),flush=True)
reply=json.loads(input())
print(json.dumps({'id':request['id'],'result':{'tool_denied':reply['error']['code']==-32601}}),flush=True)
'''
        with tempfile.TemporaryDirectory() as cwd:
            with d.NativeClient([sys.executable, '-c', program], cwd) as client:
                self.assertEqual(client.request(1, 'initialize', {}), {'tool_denied': True})
            self.assertIsNotNone(client.process.poll())

    def test_hung_or_malformed_cli_is_bounded_and_reaped(self):
        with tempfile.TemporaryDirectory() as cwd:
            for program in ['import time;time.sleep(10)', 'print("not-json",flush=True)',
                            'print(\'{"id":1,"id":2}\',flush=True)']:
                with self.subTest(program=program), patch.object(d, 'TIMEOUT', .2):
                    with self.assertRaises(d.DiscoveryError):
                        with d.NativeClient([sys.executable, '-c', program], cwd) as client:
                            client.receive()
                    self.assertIsNotNone(client.process.poll())


if __name__ == '__main__':
    unittest.main()
