#!/usr/bin/env python3
"""Exercise real Claude hook dispatch against a local Anthropic API fixture.

This verifies the host's missing-executable behavior and actual Write side
effects, not live-provider/model quality, Windows behavior on Linux, or guard
activation. No user profile or provider credentials are used. Run in the
existing CLI hook lane: python3 tests/claude-hook-runtime.tests.py [--claude PATH].
"""
import argparse
import copy
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'plugins/sdd-quality-loop/hooks/claude-hooks.json'
CONTENT = 'SDD_RUNTIME_FAILURE_PROBE'
CALL_ID = 'toolu_sdd_runtime_probe'


class FixtureHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        if self.path.split('?')[0] != '/v1/messages':
            self.send_error(404)
            return
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        results = [item for message in body.get('messages', [])
                   for item in message.get('content', [])
                   if isinstance(item, dict) and item.get('type') == 'tool_result']
        self.server.records.append(results)
        if results:
            block = {'type': 'text', 'text': 'Probe finished.'}
            delta = {'type': 'text_delta', 'text': block['text']}
            empty = dict(block, text='')
        else:
            block = {'type': 'tool_use', 'id': CALL_ID, 'name': 'Write',
                     'input': {'file_path': str(self.server.target), 'content': CONTENT}}
            delta = {'type': 'input_json_delta', 'partial_json': json.dumps(block['input'])}
            empty = dict(block, input={})
        stop = 'end_turn' if results else 'tool_use'
        message = {'id': 'msg_sdd_fixture', 'type': 'message', 'role': 'assistant',
                   'model': body.get('model'), 'content': [], 'stop_reason': None,
                   'stop_sequence': None, 'usage': {'input_tokens': 100, 'output_tokens': 0}}
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        for event in (
            {'type': 'message_start', 'message': message},
            {'type': 'content_block_start', 'index': 0, 'content_block': empty},
            {'type': 'content_block_delta', 'index': 0, 'delta': delta},
            {'type': 'content_block_stop', 'index': 0},
            {'type': 'message_delta', 'delta': {'stop_reason': stop, 'stop_sequence': None},
             'usage': {'output_tokens': 30}},
            {'type': 'message_stop'},
        ):
            self.wfile.write(('event: ' + event['type'] + '\ndata: '
                              + json.dumps(event) + '\n\n').encode())


def isolated_environment(directory, port):
    # Retain only executable/OS essentials; never inherit provider credentials,
    # managed cloud routing, profile paths, MCP configuration, or proxy settings.
    names = {'PATH', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'PATHEXT', 'LANG', 'LC_ALL'}
    env = {key: value for key, value in os.environ.items() if key.upper() in names}
    for name in ('home', 'profile', 'tmp'):
        (directory / name).mkdir()
    env.update(HOME=str(directory / 'home'), USERPROFILE=str(directory / 'home'),
               APPDATA=str(directory / 'profile'), LOCALAPPDATA=str(directory / 'profile'),
               TMPDIR=str(directory / 'tmp'), TEMP=str(directory / 'tmp'), TMP=str(directory / 'tmp'),
               CLAUDE_CONFIG_DIR=str(directory / 'profile'),
               ANTHROPIC_API_KEY='fixture-local-only',
               ANTHROPIC_BASE_URL=f'http://127.0.0.1:{port}',
               CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1',
               DISABLE_TELEMETRY='1', DISABLE_ERROR_REPORTING='1',
               CLAUDE_CODE_DISABLE_AUTO_MEMORY='1')
    return env


def run_case(cli, base, server, entry, observation, control=False):
    label = observation['case']
    directory = base / label
    directory.mkdir()
    hook_entry = copy.deepcopy(entry)
    hook = hook_entry['hooks'][0]
    if control:
        hook.pop('onFailure', None)
    else:
        assert hook.get('onFailure') == 'block', f'{label}: repository hook must fail closed'
    # Keep the repository matcher/args/options; substitute only a nonexistent
    # executable. The host, rather than a fake hook evaluator, handles ENOENT.
    missing = directory / 'intentionally-missing-node'
    hook['command'] = str(missing)
    plugin = directory / 'plugin'
    (plugin / '.claude-plugin').mkdir(parents=True)
    (plugin / '.claude-plugin/plugin.json').write_text(json.dumps({
        'name': 'sdd-runtime-probe', 'version': '0.0.0', 'hooks': './hooks.json',
    }), encoding='utf-8')
    (plugin / 'hooks.json').write_text(
        json.dumps({'hooks': {'PreToolUse': [hook_entry]}}), encoding='utf-8')
    mcp_config = directory / 'mcp.json'
    mcp_config.write_text('{"mcpServers":{}}', encoding='utf-8')
    target = directory / 'sentinel.txt'
    server.target, server.records = target, []
    env = isolated_environment(directory, server.server_port)
    command = [cli, '-p', '--no-session-persistence', '--setting-sources', '',
               '--plugin-dir', str(plugin), '--strict-mcp-config', '--mcp-config', str(mcp_config),
               '--tools', 'Write', '--allowedTools', 'Write', '--output-format', 'stream-json',
               '--verbose', '--model', 'claude-haiku-4-5', '--max-turns', '2']
    result = subprocess.run(command, input='Use Write once to create sentinel.txt. Stop if denied.',
                            text=True, encoding='utf-8', cwd=directory, env=env,
                            capture_output=True, timeout=60)
    observation.update(exit_code=result.returncode, sentinel_exists=target.exists(),
                       command=command, api_tool_results=server.records, stderr=result.stderr,
                       stdout_sha256=hashlib.sha256(result.stdout.encode()).hexdigest())
    assert result.returncode == 0, f'{label}: Claude failed ({result.returncode}): {result.stderr}'
    events = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
    calls = [item for event in events if event.get('type') == 'assistant'
             for item in event.get('message', {}).get('content', [])
             if item.get('type') == 'tool_use']
    assert len(calls) == 1 and calls[0]['id'] == CALL_ID and calls[0]['name'] == 'Write', \
        f'{label}: expected one actual native Write dispatch'
    assert calls[0]['input'] == {'file_path': str(target), 'content': CONTENT}, \
        f'{label}: native tool arguments differ'
    endings = [event for event in events if event.get('type') == 'result']
    assert len(endings) == 1 and endings[0].get('is_error') is False, \
        f'{label}: missing or unsuccessful host completion'
    assert len(server.records) == 2 and server.records[0] == [] and len(server.records[1]) == 1, \
        f'{label}: missing/ambiguous native tool result'
    native = server.records[1][0]
    assert native.get('tool_use_id') == CALL_ID, f'{label}: unmatched native result'
    if control:
        assert native.get('is_error') is not True and target.read_text(encoding='utf-8') == CONTENT, \
            f'{label}: control must demonstrate the unprotected write'
    else:
        assert native.get('is_error') is True and not target.exists(), \
            f'{label}: missing runtime must block the write'
        assert isinstance(native.get('content'), str) and all(text in native['content'] for text in (
            'PreToolUse:Write hook error:', 'blocking because onFailure is "block"',
            str(missing), 'ENOENT')), \
            f'{label}: unrecognized startup-failure denial: {native}'
    observation.update(status='PASS', native_result=native)
    del observation['api_tool_results']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--claude', default='claude', help='Claude executable or command on PATH')
    parser.add_argument('--output', type=Path, help='Persist JSON evidence outside the temporary profile')
    args = parser.parse_args()
    proof = {'schema': 'sdd-claude-hook-runtime-test/v1',
             'scope': 'Real local host with fixture API; not live-provider/model acceptance',
             'platform': sys.platform, 'config_sha256': hashlib.sha256(CONFIG.read_bytes()).hexdigest(),
             'cases': []}
    try:
        cli = shutil.which(args.claude)
        assert cli, f'Claude executable not found: {args.claude}'
        version = subprocess.run([cli, '--version'], capture_output=True, text=True,
                                 encoding='utf-8', timeout=15, check=True).stdout.strip()
        proof['host_version'] = version
        proof['source_revision'] = subprocess.run(
            ['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True,
            check=True, timeout=10).stdout.strip()
        proof['test_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        proof['inputs_dirty'] = bool(subprocess.run(
            ['git', 'status', '--porcelain', '--', str(CONFIG), str(Path(__file__).resolve())],
            cwd=ROOT, capture_output=True, text=True, check=True, timeout=10).stdout.strip())
        match = re.search(r'\b(\d+)\.(\d+)\.(\d+)\b', version)
        assert match and tuple(map(int, match.groups())) >= (2, 1, 295), \
            'Claude >= 2.1.295 is required for onFailure:block'
        entries = json.loads(CONFIG.read_text(encoding='utf-8'))['hooks']['PreToolUse']
        selected = {}
        for name in ('kill-switch.js', 'sdd-hook-guard.js'):
            matches = [entry for entry in entries if len(entry.get('hooks', [])) == 1
                       and any(arg.endswith('/' + name) for arg in entry['hooks'][0].get('args', []))]
            assert len(matches) == 1, f'Expected one repository hook for {name}'
            selected[name] = matches[0]
        with tempfile.TemporaryDirectory(prefix='sdd-claude-hook-runtime-') as temporary:
            base = Path(temporary).resolve()
            with http.server.ThreadingHTTPServer(('127.0.0.1', 0), FixtureHandler) as server:
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    cases = [('control-unset', selected['sdd-hook-guard.js'], True)]
                    cases.extend((name, entry, False) for name, entry in selected.items())
                    for name, entry, control in cases:
                        observation = {'case': name, 'status': 'FAIL'}
                        proof['cases'].append(observation)
                        run_case(cli, base, server, entry, observation, control=control)
                finally:
                    server.shutdown()
                    thread.join(timeout=5)
        proof['status'] = 'PASS'
        return_code = 0
    except (AssertionError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        proof.update(status='FAIL', error=str(error))
        return_code = 1
    encoded = json.dumps(proof, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.write_text(encoded, encoding='utf-8')
    print(encoded, end='')
    return return_code


if __name__ == '__main__':
    sys.exit(main())
