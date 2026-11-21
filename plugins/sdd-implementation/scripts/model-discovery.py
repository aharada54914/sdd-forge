#!/usr/bin/env python3
"""CLI-owned model catalog adapters. No prompts, credential copying or direct provider APIs."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import threading
import time

HOSTS = {'claude-code': 'claude', 'codex-cli': 'codex', 'gemini-cli': 'gemini'}
MODEL_ID = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/\[\]-]{0,127}')
EFFORT_ID = re.compile(r'[a-z][a-z0-9_-]{0,31}')
MAX_BYTES = 2 * 1024 * 1024
TIMEOUT = 30


class DiscoveryError(ValueError):
    """Only fixed, nonsecret error codes leave the adapters."""


class NativeClient:
    """Bounded JSON-lines transport for CLI control protocols; never sends a user turn."""
    def __init__(self, argv, project):
        self.argv, self.project = argv, project
        self.process = None
        self.lines = queue.Queue(maxsize=16)
        self.stop = threading.Event()
        self.deadline = time.monotonic() + TIMEOUT
        self.budget = MAX_BYTES

    def __enter__(self):
        self.process = subprocess.Popen(self.argv, cwd=self.project, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                        env=dict(os.environ, SDD_SESSION_NONINTERACTIVE='1'))
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()
        return self

    def _read(self):
        while not self.stop.is_set():
            line = self.process.stdout.readline(MAX_BYTES + 1)
            if len(line) > MAX_BYTES:
                line = b''
            while not self.stop.is_set():
                try:
                    self.lines.put(line, timeout=.1)
                    break
                except queue.Full:
                    continue
            if not line:
                break

    def __exit__(self, *_):
        self.stop.set()
        if self.process.poll() is None:
            self.process.terminate()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=2)
        self.reader.join(timeout=2)
        self.process.stdin.close()
        if not self.reader.is_alive():
            self.process.stdout.close()

    def send(self, value):
        done = threading.Event()
        failed = []
        def write():
            try:
                self.process.stdin.write(json.dumps(value).encode() + b'\n')
                self.process.stdin.flush()
            except (OSError, ValueError):
                failed.append(True)
            finally:
                done.set()
        threading.Thread(target=write, daemon=True).start()
        if not done.wait(max(0, self.deadline - time.monotonic())):
            raise DiscoveryError('timeout')
        if failed:
            raise DiscoveryError('cli-request-failed')

    def receive(self):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise DiscoveryError('timeout')
        try:
            line = self.lines.get(timeout=remaining)
        except queue.Empty:
            raise DiscoveryError('timeout') from None
        self.budget -= len(line)
        if not line or self.budget < 0:
            raise DiscoveryError('invalid-response')
        def unique(pairs):
            result = {}
            for key, item in pairs:
                if key in result:
                    raise ValueError('duplicate key')
                result[key] = item
            return result
        try:
            value = json.loads(line, object_pairs_hook=unique)
        except (ValueError, UnicodeError, RecursionError):
            raise DiscoveryError('invalid-response') from None
        if not isinstance(value, dict):
            raise DiscoveryError('invalid-response')
        return value

    def request(self, request_id, method, params):
        self.send({'jsonrpc': '2.0', 'id': request_id, 'method': method, 'params': params})
        while True:
            value = self.receive()
            if 'method' in value:
                if 'id' in value:
                    # Discovery cannot authorize tools, file access or login callbacks.
                    self.send({'jsonrpc': '2.0', 'id': value['id'],
                               'error': {'code': -32601, 'message': 'Discovery only'}})
                continue
            if value.get('id') != request_id or 'error' in value:
                raise DiscoveryError('cli-request-failed')
            if not isinstance(value.get('result'), dict):
                raise DiscoveryError('invalid-response')
            return value['result']


def model_row(host, model, efforts, source, display_name=None, default_effort=None):
    if not isinstance(model, str) or not MODEL_ID.fullmatch(model):
        raise DiscoveryError('invalid-model-id')
    if (not isinstance(efforts, list) or any(not isinstance(e, str) or not EFFORT_ID.fullmatch(e) or e == 'default' for e in efforts)
            or len(set(efforts)) != len(efforts)):
        raise DiscoveryError('unsupported-effort-values')
    if default_effort is not None and default_effort not in efforts:
        raise DiscoveryError('invalid-default-effort')
    label = display_name if display_name is not None else model
    if not isinstance(label, str) or not label or len(label) > 200 or any(ord(c) < 32 for c in label):
        raise DiscoveryError('invalid-display-name')
    return {'host': host, 'model': model, 'display_name': label, 'efforts': efforts,
            'default_effort': default_effort, 'source': source, 'verification': 'listed', 'selectable': True}


def claude(executable, project):
    source = 'claude control initialize.models'
    argv = [executable, '-p', '--input-format', 'stream-json', '--output-format', 'stream-json',
            '--verbose', '--no-session-persistence', '--strict-mcp-config', '--mcp-config',
            '{"mcpServers":{}}', '--tools', '']
    with NativeClient(argv, project) as client:
        client.send({'type': 'control_request', 'request_id': 'discovery', 'request': {'subtype': 'initialize'}})
        while True:
            value = client.receive()
            if value.get('type') == 'control_request':
                raise DiscoveryError('interactive-request-required')
            if value.get('type') != 'control_response':
                continue
            response = value.get('response', {})
            if response.get('request_id') != 'discovery' or response.get('subtype') != 'success':
                raise DiscoveryError('cli-request-failed')
            result = response.get('response', {})
            break
    account = result.get('account', {})
    provider = account.get('apiProvider')
    if provider in ('bedrock', 'vertex', 'foundry', 'anthropicAws', 'anthropicGoogleCloud', 'mantle', 'gateway'):
        auth = 'external'
    elif account.get('apiKeySource') not in (None, '', 'none'):
        auth = 'api-key'
    elif account.get('tokenSource') not in (None, '', 'none'):
        auth = 'oauth'
    else:
        raise DiscoveryError('authentication-unavailable')
    rows = [
        model_row(
            'claude-code',
            m['value'],
            m.get('supportedEffortLevels', []) if m.get('supportsEffort') is not False else [],
            source,
            m.get('displayName'),
            m.get('defaultEffort') if m.get('supportsEffort') is not False else None,
        )
        for m in result['models']
    ]
    return rows, auth


def codex(executable, project):
    source = 'codex app-server model/list'
    with NativeClient([executable, 'app-server'], project) as client:
        client.request(1, 'initialize', {'clientInfo': {'name': 'sdd-model-discovery', 'version': '1.0.0'}})
        client.send({'method': 'initialized', 'params': {}})
        account = client.request(2, 'account/read', {'refreshToken': False}).get('account')
        if not isinstance(account, dict):
            raise DiscoveryError('authentication-unavailable')
        auth = {'chatgpt': 'subscription', 'apiKey': 'api-key'}.get(account.get('type'), 'cli-managed')
        rows, cursors, cursor = [], set(), None
        for page in range(100):
            params = {'limit': 100, 'includeHidden': False}
            if cursor is not None:
                params['cursor'] = cursor
            result = client.request(page + 3, 'model/list', params)
            for m in result['data']:
                rows.append(model_row('codex-cli', m['model'],
                                      [x['reasoningEffort'] for x in m['supportedReasoningEfforts']],
                                      source, m.get('displayName'), m.get('defaultReasoningEffort')))
            cursor = result.get('nextCursor')
            if cursor is None:
                current = client.request(page + 1003, 'account/read', {'refreshToken': False}).get('account')
                if current != account:
                    raise DiscoveryError('authentication-changed')
                return rows, auth
            if not isinstance(cursor, str) or not cursor or cursor in cursors:
                raise DiscoveryError('invalid-pagination')
            cursors.add(cursor)
        raise DiscoveryError('incomplete-pagination')


def gemini(executable, project):
    source = 'gemini ACP session/new.models.availableModels'
    with NativeClient([executable, '--acp'], project) as client:
        client.request(1, 'initialize', {'protocolVersion': 1, 'clientCapabilities': {},
                                        'clientInfo': {'name': 'sdd-model-discovery', 'version': '1.0.0'}})
        # The CLI resolves its existing selected auth type, OAuth session or API-key environment.
        # Do not call authenticate or fall back to an API endpoint on an auth error.
        result = client.request(2, 'session/new', {'cwd': str(Path(project).resolve()), 'mcpServers': []})
    # Read per-model efforts if exposed by newer Gemini ACP versions; otherwise empty (CLI default).
    rows = []
    for m in result['models']['availableModels']:
        raw_efforts = m.get('supportedEffortLevels') or m.get('supportedReasoningEfforts') or []
        efforts = [e['reasoningEffort'] if isinstance(e, dict) and 'reasoningEffort' in e else e for e in raw_efforts]
        default_effort = m.get('defaultEffort') or m.get('defaultReasoningEffort')
        if default_effort not in efforts:
            default_effort = None
        rows.append(model_row('gemini-cli', m['modelId'], efforts, source, m.get('name'), default_effort))
    return rows, 'cli-managed'


ADAPTERS = {'claude-code': claude, 'codex-cli': codex, 'gemini-cli': gemini}


def discover(project=None):
    project = str(Path(project or Path.cwd()).resolve())
    catalog = {'observed_at': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
               'providers': {}, 'models': []}
    for host, name in HOSTS.items():
        executable = shutil.which(name)
        provider = {'installed': executable is not None, 'status': 'unavailable',
                    'reason': 'CLIが見つかりません。', 'auth_mode': 'unknown'}
        catalog['providers'][host] = provider
        if executable is None:
            continue
        try:
            rows, auth = ADAPTERS[host](executable, project)
            if not rows or len({r['model'] for r in rows}) != len(rows):
                raise DiscoveryError('empty-or-duplicate-model-list')
            catalog['models'].extend(rows)
            provider.update(status='listed', auth_mode=auth,
                            reason='既存CLIの認証経路から取得。掲載は推論成功の保証ではありません。')
            if host == 'gemini-cli' and not any(r['efforts'] for r in rows):
                provider['reason'] += 'この取得経路はモデル別の推論強度を公開していません。CLI既定のみ選択できます。'
        except DiscoveryError as error:
            provider['reason'] = '一覧取得に失敗しました（' + str(error) + '）。CLIの認証・対応版を確認して更新してください。'
        except (OSError, ValueError, TypeError, KeyError, AttributeError, subprocess.SubprocessError):
            # Never surface raw CLI output, exception messages, accounts or credentials.
            provider['reason'] = '一覧取得に失敗しました（cli-unavailable-or-invalid-response）。CLIの認証・対応版を確認して更新してください。'
    return catalog
