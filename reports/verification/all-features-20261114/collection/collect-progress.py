#!/usr/bin/env python3
"""Read declared task roots and publish snapshots. No task files are modified."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

STATES = {'Planned', 'In Progress', 'Implementation Complete', 'Done', 'Blocked'}
ADAPTER = Path(__file__).with_name('read-workflow-metadata.mjs')
VERSION = hashlib.sha256(Path(__file__).read_bytes() + (ADAPTER.read_bytes() if ADAPTER.exists() else b'')).hexdigest()[:12]


def stamp():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def field(body, name, default=''):
    matches = re.findall(r'^' + re.escape(name) + r':\s*(.+)$', body, re.M)
    if len(matches) > 1:
        raise ValueError('duplicate-field')
    return matches[0].strip() if matches else default


def read_metadata(config):
    model = config.get('readModel')
    if not model:
        return {}
    request = {'server': model['server'], 'sources': config['sources']}
    environment = {'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8', 'TZ': 'UTC'}
    command = [model['node'], str(Path(__file__).with_name('read-workflow-metadata.mjs'))]
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, env=environment, start_new_session=True)
    try:
        output, _ = process.communicate(json.dumps(request), timeout=180)
    except BaseException:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
        raise
    if process.returncode:
        raise subprocess.CalledProcessError(process.returncode, command)
    if len(output.encode()) > 8 * 1024 * 1024:
        raise ValueError('metadata-too-large')
    response = json.loads(output)
    if response.get('schema') != 'sdd-sites-workflow-metadata/v1':
        raise ValueError('invalid-read-model')
    return {row['id']: {item['feature']: item for item in row['features']} for row in response['sources']}


def collect(config):
    metadata = read_metadata(config)
    features, tasks = [], []
    seen = set()
    feature_ids = set()
    for source in config['sources']:
        alias = source['id']
        namespace = source.get('namespace', alias)
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', alias) or alias in seen:
            raise ValueError('invalid-source-id')
        if namespace and not re.fullmatch(r'[a-z0-9][a-z0-9-]*', namespace):
            raise ValueError('invalid-namespace')
        seen.add(alias)
        root = Path(source['root']).resolve(strict=True)
        specs = root / 'specs'
        if not specs.is_dir():
            raise ValueError('missing-specs')
        workflow = metadata.get(alias)
        if config.get('readModel') and workflow is None:
            raise ValueError('missing-read-model-source')
        names = sorted(workflow) if workflow is not None else sorted(p.parent.name for p in specs.glob('*/tasks.md'))
        if not names:
            raise ValueError('missing-tasks')
        for name in names:
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name):
                raise ValueError('invalid-feature')
            path = specs / name / 'tasks.md'
            feature = namespace + '/' + name if namespace else name
            if feature in feature_ids:
                raise ValueError('duplicate-feature')
            feature_ids.add(feature)
            model = workflow[name] if workflow is not None else None
            warnings = []
            next_step = model['next'] if model else None
            phase = next_step['data']['phase'] if next_step and next_step.get('ok') else 'unknown'
            command = next_step['data']['nextCommand'] if next_step and next_step.get('ok') else ''
            if not model:
                warnings.append('タスク状態のみ収集。工程・次コマンド・品質検証は未収集です。')
            elif not next_step.get('ok'):
                warnings.append('MCPで工程を判定できません: ' + next_step['error']['code'])
            if not path.exists():
                if model is None:
                    raise ValueError('missing-tasks')
                warnings.append('タスクファイルは未作成です。')
                raw = ''
            else:
                if not path.resolve().is_relative_to(root):
                    raise ValueError('outside-source')
                raw = path.read_text(encoding='utf-8')
                if not raw.strip():
                    raise ValueError('empty-task-manifest')
            headings = list(re.finditer(r'^## (T-\d+)\b\s*(.*)$', raw, re.M))
            if raw and not headings:
                raise ValueError('unsupported-task-format')
            task_state = model['tasks'] if model else None
            canonical = {t['id']: t for t in task_state['data']['tasks']} if task_state and task_state.get('ok') else None
            failures = task_state['data']['failures'] if canonical is not None else []
            if model and raw and canonical is None:
                warnings.append('MCPでタスク状態を検証できません: ' + task_state['error']['code'])
            group = []
            for i, heading in enumerate(headings):
                body = raw[heading.end():headings[i + 1].start() if i + 1 < len(headings) else len(raw)].strip()
                task_id = heading[1]
                entry = canonical.get(task_id) if canonical is not None else None
                if canonical is not None and entry is None:
                    raise ValueError('read-model-task-mismatch')
                if entry and (entry['status'] != field(body, 'Status') or entry['approval'] != field(body, 'Approval')):
                    raise ValueError('source-changed-during-collection')
                status = entry['status'] if entry else field(body, 'Status')
                if status not in STATES:
                    raise ValueError('invalid-task-state')
                key = feature + '/' + task_id
                if any(t['key'] == key for t in group):
                    raise ValueError('duplicate-task')
                relative = str(path.relative_to(root))
                group.append({'key': key, 'id': task_id, 'feature': feature,
                              'title': heading[2].lstrip(': ').strip() or task_id,
                              'body': body, 'status': status,
                              'approval': entry['approval'] if entry else field(body, 'Approval', 'Unspecified'),
                              'risk': entry.get('risk', 'unknown') if entry else field(body, 'Risk', 'unknown'),
                              'release': field(body, 'Release') or None,
                              'source': namespace + '/' + relative if namespace else relative,
                              'failures': [f['message'] for f in failures if not f.get('taskId') or f['taskId'] == task_id]})
            if canonical is not None and len(canonical) != len(group):
                raise ValueError('read-model-task-mismatch')
            tasks.extend(group)
            features.append({'id': feature,
                             'displayName': source.get('displayNames', {}).get(name, source.get('label', alias) + ' / ' + name),
                             'phase': phase, 'nextCommand': command, 'warnings': warnings})
    data = {'project': config['project'], 'features': features, 'tasks': tasks}
    raw = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    return data, hashlib.sha256(raw).hexdigest()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(request.full_url, code, 'redirect-refused', headers, fp)


class Client:
    def __init__(self, endpoint):
        parsed = urllib.parse.urlsplit(endpoint)
        if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ('', '/'):
            raise ValueError('invalid-endpoint')
        if parsed.scheme != 'https' and not (parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', '::1', 'localhost')):
            raise ValueError('https-required')
        self.endpoint = endpoint.rstrip('/')
        token = os.environ.get('SDD_PUBLISHER_TOKEN')
        if not token:
            raise ValueError('publisher-credential-required')
        self.headers = {'X-SDD-Publisher': token, 'Content-Type': 'application/json'}
        service = os.environ.get('SDD_SITES_SERVICE_TOKEN')
        if service:
            self.headers['OAI-Sites-Authorization'] = 'Bearer ' + service
        self.opener = urllib.request.build_opener(NoRedirect())

    def call(self, path, value=None):
        raw = None if value is None else json.dumps(value, ensure_ascii=False).encode()
        if raw is not None and len(raw) > 2 * 1024 * 1024:
            raise ValueError('snapshot-too-large')
        request = urllib.request.Request(self.endpoint + path, data=raw, headers=self.headers,
                                         method='GET' if value is None else 'PUT')
        with self.opener.open(request, timeout=20) as response:
            return json.loads(response.read(3 * 1024 * 1024))


def run(config, client, cycles, interval):
    previous = client.call('/api/dashboard')
    if previous.get('data') and previous['data']['project'] != config['project']:
        raise ValueError('existing-project-mismatch')
    failures = 0
    last_publish = None
    count = 0
    while cycles is None or count < cycles:
        started = time.monotonic()
        at = stamp()
        collection_error = False
        try:
            data, revision = collect(config)
            snapshot = {'schema': 'sdd-dashboard/v1', 'attemptedAt': at, 'checkedAt': at,
                        'lastSuccessAt': at, 'changedAt': previous.get('changedAt') if previous.get('revision') == revision else at,
                        'revision': revision, 'error': None, 'data': data}
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
            collection_error = True
            snapshot = {k: previous.get(k) for k in ['checkedAt', 'lastSuccessAt', 'changedAt', 'revision', 'data']}
            snapshot.update(schema='sdd-dashboard/v1', attemptedAt=at, error='source-collection-failed')
            snapshot['revision'] = snapshot['revision'] or ''
        state = 'collection-failed' if collection_error else 'running'
        try:
            client.call('/api/snapshot', snapshot)
            last_publish = at
            previous = snapshot
            failures = failures + 1 if collection_error else 0
        except urllib.error.HTTPError as error:
            state = 'auth-failed' if error.code in (401, 403) else 'conflict' if error.code == 409 else 'data-rejected' if error.code in (400, 413) else 'http-failed'
            failures += 1
            if error.code == 409:
                recovered = client.call('/api/dashboard')
                if recovered.get('data') and recovered['data']['project'] != config['project']:
                    raise ValueError('existing-project-mismatch')
                previous = recovered
        except (OSError, ValueError, urllib.error.URLError):
            state = 'transport-failed'
            failures += 1
        health = {'schema': 'sdd-monitor/v1', 'observedAt': stamp(), 'state': state,
                  'publisherVersion': VERSION, 'collectorVersion': VERSION, 'lastPublishAt': last_publish,
                  'lastSourceAt': snapshot['checkedAt'], 'consecutiveFailures': failures, 'collectorRestarts': 0,
                  'collectionMs': round((time.monotonic() - started) * 1000), 'lastError': None if state == 'running' else state}
        try:
            client.call('/api/health', health)
            health_published = True
        except (OSError, ValueError, urllib.error.URLError):
            health_published = False
        print(json.dumps({'observedAt': health['observedAt'], 'state': state, 'healthPublished': health_published,
                          'revision': snapshot['revision'], 'taskCount': len((snapshot.get('data') or {}).get('tasks', []))}), flush=True)
        count += 1
        if state == 'auth-failed':
            break
        if cycles is None or count < cycles:
            time.sleep(max(0, interval - (time.monotonic() - started)))
    return 0 if failures == 0 and health_published else 1


def interrupted(_signum, _frame):
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, interrupted)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--endpoint', required=True)
    parser.add_argument('--interval', type=float, default=5)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--cycles', type=int, default=1)
    mode.add_argument('--watch', action='store_true')
    args = parser.parse_args()
    if args.interval < .1 or args.cycles < 1:
        parser.error('positive cycles and interval >= 0.1 required')
    try:
        config = json.loads(args.config.read_text())
        if not isinstance(config.get('project'), str) or not config['project'] or not config.get('sources'):
            raise ValueError('invalid-config')
        return run(config, Client(args.endpoint), None if args.watch else args.cycles, args.interval)
    except KeyboardInterrupt:
        return 130
    except (OSError, ValueError, KeyError, TypeError, urllib.error.URLError):
        print(json.dumps({'state': 'startup-failed', 'detail': 'Check endpoint, source configuration and credential availability; secrets are not logged.'}), flush=True)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
