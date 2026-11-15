#!/usr/bin/env python3
"""Project-private model preferences and explicit, session-bound confirmation.

Candidates are UI information, never launch observations or inference access proof.
All launch admission remains with the existing model policy and native adapters.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HOSTS = {'claude-code': 'claude', 'codex-cli': 'codex', 'gemini-cli': 'gemini'}
ROLES = ('implementer', 'investigator', 'spec-reviewer-a', 'spec-reviewer-b',
         'impl-reviewer-a', 'impl-reviewer-b', 'task-reviewer-a', 'task-reviewer-b',
         'evaluator', 'domain-reviewer-a', 'domain-reviewer-b', 'workflow-auditor-a',
         'workflow-auditor-b', 'diagnosis', 'self-improvement', 'panelist-gpt', 'panelist-gemini')
EFFORTS = ('low', 'medium', 'high', 'xhigh', 'max')
IDENTIFIER = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}')
HERE = Path(__file__).resolve().parent
MAX_BYTES = 2 * 1024 * 1024


class SelectionError(ValueError):
    pass


def now():
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def read_json(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_BYTES:
        raise SelectionError('設定ファイルが不正です。シンボリックリンクは利用できません。')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise SelectionError('JSONに重複キーがあります。')
            result[key] = value
        return result
    try:
        return json.loads(path.read_bytes(), object_pairs_hook=unique)
    except (ValueError, UnicodeError) as exc:
        raise SelectionError('設定JSONを読み取れません。') from exc


def private_directory(path):
    # Reject links in the application-owned subtree; never chmod the user's config root.
    if path.is_symlink():
        raise SelectionError('設定ディレクトリにシンボリックリンクは利用できません。')
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not path.is_dir():
        raise SelectionError('設定の保存先がディレクトリではありません。')
    if os.name != 'nt':
        if path.stat().st_uid != os.getuid():
            raise SelectionError('設定ディレクトリの所有者が一致しません。')
        path.chmod(0o700)
    return path


def write_json(path, value):
    if path.is_symlink():
        raise SelectionError('設定ファイルのリンクを上書きできません。')
    raw = canonical(value) + b'\n'
    if len(raw) > MAX_BYTES:
        raise SelectionError('設定のサイズ上限を超えました。')
    fd, name = tempfile.mkstemp(prefix='.model-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def choice(value):
    if (not isinstance(value, dict) or set(value) != {'host', 'model', 'effort'}
            or value['host'] not in HOSTS or not isinstance(value['model'], str)
            or not IDENTIFIER.fullmatch(value['model'])
            or value['effort'] is not None and value['effort'] not in EFFORTS):
        raise SelectionError('モデル設定の形式が不正です。')
    return value


def role_choice(role, value):
    if role != 'main' and value == {'disabled': True}:
        return value
    choice(value)
    if role == 'panelist-gpt' and value['host'] != 'codex-cli':
        raise SelectionError('panelist-gptはクロスモデル検証のためCodexを選択してください。')
    if role == 'panelist-gemini' and value['host'] != 'gemini-cli':
        raise SelectionError('panelist-geminiはクロスモデル検証のためGeminiを選択してください。')
    return value


class Store:
    def __init__(self, project, config_home=None):
        self.project = str(Path(project).resolve(strict=True))
        if not Path(self.project).is_dir():
            raise SelectionError('プロジェクトがディレクトリではありません。')
        self.project_id = hashlib.sha256(os.fsencode(os.path.normcase(self.project))).hexdigest()
        base = Path(config_home) if config_home else Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
        # Never store personal preferences in the working tree, even via an override.
        base = base.expanduser().absolute()
        resolved = base.resolve()
        if resolved == Path(self.project) or Path(self.project) in resolved.parents:
            raise SelectionError('個人設定の保存先にはプロジェクト外のディレクトリを指定してください。')
        app = private_directory(base / 'sdd-forge')
        profiles = private_directory(app / 'model-profiles')
        self.root = private_directory(profiles / self.project_id)
        self.sessions = private_directory(self.root / 'sessions')
        self.profile_path = self.root / 'preferences.json'

    @contextmanager
    def locked(self):
        target = self.root / 'lock'
        if target.is_symlink():
            raise SelectionError('ロックファイルが不正です。')
        fd = os.open(target, os.O_CREAT | os.O_RDWR | getattr(os, 'O_NOFOLLOW', 0), 0o600)
        with os.fdopen(fd, 'r+b') as stream:
            if os.name == 'nt':
                import msvcrt
                if not target.stat().st_size:
                    stream.write(b'0'); stream.flush()
                stream.seek(0)
                msvcrt.locking(stream.fileno(), msvcrt.LK_LOCK, 1)
            else:
                import fcntl
                fcntl.flock(stream, fcntl.LOCK_EX)
            try:
                yield
            finally:
                if os.name == 'nt':
                    stream.seek(0)
                    msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
                else:
                    fcntl.flock(stream, fcntl.LOCK_UN)

    def profile(self):
        if not self.profile_path.exists():
            return {'schema': 'session-model-preferences/v1', 'project_id': self.project_id, 'mains': {}, 'roles': {}}
        value = read_json(self.profile_path)
        if (not isinstance(value, dict) or set(value) != {'schema', 'project_id', 'mains', 'roles'}
                or value['schema'] != 'session-model-preferences/v1' or value['project_id'] != self.project_id
                or not isinstance(value['mains'], dict) or not isinstance(value['roles'], dict)
                or set(value['mains']) - HOSTS.keys() or set(value['roles']) - set(ROLES)):
            raise SelectionError('保存されたプロジェクト設定が不正です。')
        for host, item in value['mains'].items():
            if choice(item)['host'] != host:
                raise SelectionError('メインモデルのCLIが一致しません。')
        for role, item in value['roles'].items():
            role_choice(role, item)
        return value

    def path(self, session):
        if not isinstance(session, str) or not IDENTIFIER.fullmatch(session):
            raise SelectionError('セッションIDが不正です。')
        return self.sessions / (hashlib.sha256(session.encode()).hexdigest() + '.json')

    def state(self, session):
        value = read_json(self.path(session))
        if (not isinstance(value, dict)
                or set(value) != {'schema', 'project_id', 'session_id', 'host', 'status', 'catalog', 'main', 'roles', 'confirmed_at'}
                or value.get('schema') != 'session-model-selection/v1'
                or value.get('project_id') != self.project_id or value.get('session_id') != session
                or value.get('host') not in HOSTS or value.get('status') not in ('pending', 'confirmed', 'cancelled')):
            raise SelectionError('セッション設定が一致しません。')
        if value.get('main') is not None and choice(value['main'])['host'] != value['host']:
            raise SelectionError('メインモデルは起動したCLIから選択してください。')
        if not isinstance(value.get('roles'), dict) or set(value['roles']) != set(ROLES):
            raise SelectionError('役割設定が不足しています。')
        for role, item in value['roles'].items():
            if item is not None:
                role_choice(role, item)
        validate_catalog(value['catalog'])
        if value['status'] == 'confirmed' and (value['main'] is None or any(x is None for x in value['roles'].values())
                or not isinstance(value['confirmed_at'], str) or not value['confirmed_at']):
            raise SelectionError('確定済みセッションの確認記録が不足しています。')
        return value


def load_policy():
    path = HERE / 'model-policy.py'
    spec = importlib.util.spec_from_file_location('session_model_policy', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def claude_efforts():
    executable = shutil.which('claude')
    if executable is None:
        return []
    try:
        help_result = subprocess.run([executable, '--help'], capture_output=True, text=True, timeout=5)
        if help_result.returncode:
            return []
        match = re.search(r'--effort[^\n]*(?:\n[^\n]*)?', help_result.stdout)
        if match:
            return [e for e in ('low', 'medium', 'high') if re.search(r'\b' + e + r'\b', match[0])]
    except (OSError, subprocess.SubprocessError, UnicodeError):
        pass
    return []


def gemini_models():
    """Probe the public command before using it: older CLIs treat positional text as a prompt."""
    executable = shutil.which('gemini')
    if executable is None:
        return 'unverified', []
    try:
        help_result = subprocess.run([executable, '--help'], capture_output=True, text=True, timeout=10)
        if help_result.returncode:
            return 'unavailable', []
        if not re.search(r'(?m)^\s*gemini models(?:\s|$)', help_result.stdout):
            return 'unverified', []
        result = subprocess.run([executable, 'models', '--output-format', 'json'],
                                capture_output=True, text=True, timeout=15)
        if result.returncode or len(result.stdout.encode()) > MAX_BYTES:
            return 'unavailable', []
        data = json.loads(result.stdout)
        if not isinstance(data, list):
            return 'unavailable', []
        ids = []
        for row in data:
            name = row.get('modelId') if isinstance(row, dict) else None
            if not isinstance(name, str) or not IDENTIFIER.fullmatch(name) or name in ids:
                return 'unavailable', []
            ids.append(name)
        return 'listed', ids
    except (OSError, subprocess.SubprocessError, UnicodeError, ValueError):
        return 'unavailable', []


def discover():
    """Refresh all providers without login, credential writes, or inference probes."""
    result, providers = [], {}
    advertised_claude_efforts = claude_efforts()
    sources = {
        'claude-code': ('https://code.claude.com/docs/en/model-config', ['sonnet', 'opus', 'haiku']),
        'gemini-cli': ('https://geminicli.com/docs/cli/model/', ['auto', 'pro', 'flash', 'flash-lite']),
        'codex-cli': ('https://developers.openai.com/codex/models', []),
    }
    for host, executable in HOSTS.items():
        installed = shutil.which(executable) is not None
        providers[host] = {'installed': installed, 'status': 'unverified', 'reason':
                           '公式のCLI候補。現在の認証での利用可否は未確認です。' if installed else 'CLIが見つかりません。'}
        url, names = sources[host]
        for name in names:
            result.append({'host': host, 'model': name, 'efforts': advertised_claude_efforts if host == 'claude-code' and name in ('sonnet', 'opus') else [], 'source': url,
                           'verification': 'unverified', 'selectable': installed})
    if providers['gemini-cli']['installed']:
        status, ids = gemini_models()
        providers['gemini-cli']['status'] = status
        if status == 'listed':
            providers['gemini-cli']['reason'] = 'CLIの一覧に掲載。現在の認証での推論権限は未確認です。'
            listed = [{'host': 'gemini-cli', 'model': name, 'efforts': [],
                       'source': 'gemini models --output-format json', 'verification': 'listed',
                       'selectable': True} for name in ids]
            # The native listing supersedes the same alias, while unlisted aliases remain unverified.
            result = [x for x in result if x['host'] != 'gemini-cli' or x['model'] not in ids] + listed
        elif status == 'unavailable':
            providers['gemini-cli']['reason'] = 'CLIのモデル一覧を取得できません。未確認候補から選ぶか再取得してください。'
    if providers['codex-cli']['installed']:
        helper = load_policy()
        try:
            with helper.CodexClient('session-model-picker') as client:
                observed = client.capture(purpose='diagnostic').observation
                for model in observed['models']:
                    result.append({'host': 'codex-cli', 'model': model['native_id'],
                                   'efforts': model['efforts'], 'source': 'codex app-server model/list',
                                   'verification': 'listed', 'selectable': model['available']})
                providers['codex-cli'].update(status='listed', reason='CLIの一覧に掲載。推論の実行権限を保証するものではありません。')
        except (helper.PolicyError, OSError, ValueError):
            providers['codex-cli'].update(status='unavailable', reason='モデル一覧を取得できません。CLIの認証と接続を確認して再取得してください。')
    # Configured model names are candidates, not attestations; never inspect credential files.
    for host, key in [('claude-code', 'ANTHROPIC_MODEL'), ('gemini-cli', 'GEMINI_MODEL')]:
        name = os.environ.get(key, '')
        if IDENTIFIER.fullmatch(name) and not any(x['host'] == host and x['model'] == name for x in result):
            result.append({'host': host, 'model': name, 'efforts': [], 'source': key,
                           'verification': 'unverified', 'selectable': providers[host]['installed']})
    return {'observed_at': now(), 'providers': providers, 'models': result}


def validate_catalog(value):
    if (not isinstance(value, dict) or set(value) != {'observed_at', 'providers', 'models'}
            or not isinstance(value['observed_at'], str) or not isinstance(value['models'], list)
            or not isinstance(value['providers'], dict) or set(value['providers']) != set(HOSTS)):
        raise SelectionError('保存されたモデル一覧が不正です。一覧を再取得してください。')
    for provider in value['providers'].values():
        if (not isinstance(provider, dict) or set(provider) != {'installed', 'status', 'reason'}
                or type(provider['installed']) is not bool
                or provider['status'] not in ('listed', 'unverified', 'unavailable')
                or not isinstance(provider['reason'], str)):
            raise SelectionError('保存されたCLIの確認状態が不正です。')
    seen = set()
    for model in value['models']:
        if (not isinstance(model, dict) or set(model) != {'host', 'model', 'efforts', 'source', 'verification', 'selectable'}
                or not isinstance(model['efforts'], list) or any(e not in EFFORTS for e in model['efforts'])
                or len(set(model['efforts'])) != len(model['efforts'])
                or not isinstance(model['source'], str) or type(model['selectable']) is not bool
                or model['verification'] not in ('listed', 'unverified')):
            raise SelectionError('保存されたモデル候補が不正です。')
        choice({'host': model['host'], 'model': model['model'], 'effort': None})
        key = (model['host'], model['model'])
        if key in seen:
            raise SelectionError('保存されたモデル候補に重複があります。')
        seen.add(key)


def candidate(state, item):
    matches = [x for x in state['catalog']['models'] if x['host'] == item['host'] and x['model'] == item['model']]
    if not matches or not matches[0]['selectable']:
        raise SelectionError('選択したモデルは現在の候補にありません。一覧を更新して再選択してください。')
    if item['effort'] is not None and item['effort'] not in matches[0]['efforts']:
        raise SelectionError('この実行経路では指定の推論設定を確認できません。CLI既定を選択してください。')
    return matches[0]


def begin(store, host, session, refresh=False):
    with store.locked():
        if store.path(session).exists():
            state = store.state(session)
            if state['host'] != host:
                raise SelectionError('同じセッションIDを別のCLIで利用できません。')
            if not refresh:
                return state
        catalog = discover()
        previous = store.profile()
        state = {'schema': 'session-model-selection/v1', 'project_id': store.project_id,
                 'session_id': session, 'host': host, 'status': 'pending', 'catalog': catalog,
                 'main': previous['mains'].get(host),
                 'roles': {role: previous['roles'].get(role) for role in ROLES}, 'confirmed_at': None}
        write_json(store.path(session), state)
        return state


def add_candidate(store, session, host, model):
    item = choice({'host': host, 'model': model, 'effort': None})
    with store.locked():
        state = store.state(session)
        if state['status'] == 'cancelled':
            raise SelectionError('キャンセル済みです。begin --refreshで再開してください。')
        if not state['catalog']['providers'][host]['installed']:
            raise SelectionError('CLIが見つかりません。導入して一覧を再取得してください。')
        if not any(x['host'] == host and x['model'] == model for x in state['catalog']['models']):
            state['catalog']['models'].append({**{k: item[k] for k in ('host', 'model')},
                'efforts': [], 'source': 'user-supplied CLI model ID', 'verification': 'unverified', 'selectable': True})
            state.update(status='pending', confirmed_at=None)
            write_json(store.path(session), state)
        return state


def set_choice(store, session, role, host, model, effort):
    with store.locked():
        state = store.state(session)
        if state['status'] == 'cancelled':
            raise SelectionError('キャンセル済みです。begin --refreshで再開してください。')
        item = choice({'host': host, 'model': model, 'effort': effort})
        if role == 'main':
            if host != state['host']:
                raise SelectionError('メインモデルは起動したCLIから選択してください。')
            state['main'] = item
        else:
            role_choice(role, item)
            state['roles'][role] = item
        candidate(state, item)
        state.update(status='pending', confirmed_at=None)
        write_json(store.path(session), state)
        return state


def confirm(store, session, main_applied=False):
    with store.locked():
        state = store.state(session)
        if state['status'] == 'cancelled':
            raise SelectionError('キャンセル済みのセッションは確定できません。')
        if not main_applied:
            raise SelectionError('標準のモデル切替と推論設定の適用を確認してから --main-applied で確定してください。')
        if state['main'] is None or any(item is None for item in state['roles'].values()):
            raise SelectionError('メインと全役割を選択してから確定してください。')
        for item in [state['main'], *state['roles'].values()]:
            if item != {'disabled': True}:
                candidate(state, item)
        previous = store.profile()
        previous['mains'][state['host']] = state['main']
        previous['roles'] = state['roles']
        state.update(status='confirmed', confirmed_at=now())
        # Publish preferences first. A failed confirmation never creates an admitted session.
        write_json(store.profile_path, previous)
        write_json(store.path(session), state)
        return state


def selection(store, session, role):
    state = store.state(session)
    if state['status'] != 'confirmed':
        raise SelectionError('セッションのモデル選択が未確定です。ユーザーに確認してください。')
    item = state['main'] if role == 'main' else state['roles'][role]
    role_choice(role, item)
    if item == {'disabled': True}:
        raise SelectionError('この役割はユーザーが無効にしています。実行するにはモデルを再選択してください。')
    candidate(state, item)
    return {**item, 'role': role, 'session_id': session, 'selection_sha256': digest(state),
            'proof': 'configured-only', 'confirmed_at': state['confirmed_at']}


def policy_request(store, session, role, request):
    """Overlay an existing request; admission and fresh launch observations remain mandatory."""
    item = selection(store, session, role)
    helper = load_policy()
    helper._validate_policy_request(request)
    if request['role'] != role or request['host'] != item['host']:
        raise SelectionError('役割または起動CLIが選択設定と一致しません。対応する起動経路を選んでください。')
    policy_path = Path(request['policy_path'])
    policy = read_json(policy_path)
    matches = [m['id'] for m in policy['models'] if m.get('hosts', {}).get(item['host']) == item['model']]
    if len(matches) != 1:
        raise SelectionError('既存モデルポリシーにこのモデルの一意な登録がありません。未確認候補を検証済みに変換することはできません。')
    if request['cli']['model_id'] not in (None, matches[0]) or request['cli']['policy'] not in (None, 'pinned'):
        raise SelectionError('既存の明示モデル設定と競合しています。')
    if request['requested_effort'] not in (None, item['effort']):
        raise SelectionError('既存の明示推論設定と競合しています。')
    updated = {**request, 'cli': {'model_id': matches[0], 'policy': 'pinned'}, 'requested_effort': item['effort']}
    helper._validate_policy_request(updated)
    return updated


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--config-home', type=Path, help='プロジェクト外の個人設定ルート')
    sub = parser.add_subparsers(dest='command', required=True)
    start = sub.add_parser('begin')
    start.add_argument('--host', choices=HOSTS, required=True)
    start.add_argument('--session', required=True)
    start.add_argument('--refresh', action='store_true')
    for name in ('status', 'confirm', 'cancel', 'set', 'selection', 'request', 'add-candidate', 'disable'):
        cmd = sub.add_parser(name)
        cmd.add_argument('--session', required=True)
        if name in ('set', 'selection', 'request', 'disable'):
            cmd.add_argument('--role', choices=('main', *ROLES) if name in ('set', 'selection') else ROLES, required=True)
        if name in ('set', 'add-candidate'):
            cmd.add_argument('--host', choices=HOSTS, required=True)
            cmd.add_argument('--model', required=True)
        if name == 'set':
            cmd.add_argument('--effort', choices=('default', *EFFORTS), default='default')
        if name == 'confirm':
            cmd.add_argument('--main-applied', action='store_true')
        if name == 'request':
            cmd.add_argument('--input', type=Path, required=True)
    args = parser.parse_args()
    try:
        store = Store(args.project, args.config_home)
        if args.command == 'begin':
            result = begin(store, args.host, args.session, args.refresh)
        elif args.command == 'add-candidate':
            result = add_candidate(store, args.session, args.host, args.model)
        elif args.command == 'set':
            result = set_choice(store, args.session, args.role, args.host, args.model,
                                None if args.effort == 'default' else args.effort)
        elif args.command == 'confirm':
            result = confirm(store, args.session, args.main_applied)
        elif args.command == 'selection':
            result = selection(store, args.session, args.role)
        elif args.command == 'request':
            if Path(args.project).resolve() != Path.cwd().resolve():
                raise SelectionError('requestは対象プロジェクトを作業ディレクトリにして実行してください。')
            result = policy_request(store, args.session, args.role, read_json(args.input))
        elif args.command == 'disable':
            with store.locked():
                result = store.state(args.session)
                if result['status'] == 'cancelled':
                    raise SelectionError('キャンセル済みです。begin --refreshで再開してください。')
                result['roles'][args.role] = {'disabled': True}
                result.update(status='pending', confirmed_at=None)
                write_json(store.path(args.session), result)
        elif args.command == 'cancel':
            with store.locked():
                result = store.state(args.session)
                result.update(status='cancelled', confirmed_at=None)
                write_json(store.path(args.session), result)
        else:
            result = store.state(args.session)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (SelectionError, OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({'schema': 'session-model-error/v1', 'reason': 'selection-required',
                          'message': str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
