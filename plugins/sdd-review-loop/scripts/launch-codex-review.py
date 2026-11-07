#!/usr/bin/env python3
"""Allocate an idle Codex reviewer, reserve its identity, then run one bounded turn.

This transport emits a candidate, not a gate verdict. Canonical stage validators
still decide adoption. Named native permissions are required; no read-only fallback.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import tempfile
import time


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


launcher = module('codex_review_shared', 'launch-impl-review.py')
preflight = module('codex_review_preflight', 'preflight-host-review.py')
transport = launcher.transport
require = transport.require
sha = transport.sha
PROFILE = 'sdd_manifest_review'


class Rpc:
    """One global deadline, bounded frames, explicit rejection of host interaction."""
    def __init__(self, command, cwd, output, timeout):
        self.deadline = time.monotonic() + timeout
        self.last_notice = time.monotonic()
        self.log = output / 'native-events.jsonl'
        self.stderr = (output / 'native-stderr.log').open('wb')
        self.proc = subprocess.Popen(command, cwd=cwd, stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=self.stderr, bufsize=0,
                                     env={**os.environ, 'RUST_LOG': 'warn'})
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.proc.stdout, selectors.EVENT_READ)
        self.buffer = b''
        self.number = 0
        self.events = []

    def send(self, data):
        if time.monotonic() >= self.deadline:
            raise TimeoutError('Codex review deadline exceeded')
        self.proc.stdin.write((json.dumps(data) + '\n').encode())
        self.proc.stdin.flush()

    def receive(self, *, record=True):
        if time.monotonic() >= self.deadline:
            raise TimeoutError('Codex review deadline exceeded')
        while b'\n' not in self.buffer:
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError('Codex review deadline exceeded')
            if time.monotonic() - self.last_notice >= 20:
                print('CODEX_REVIEW_PROGRESS waiting for native host', file=sys.stderr, flush=True)
                self.last_notice = time.monotonic()
            if not self.selector.select(min(1, remaining)):
                continue
            chunk = os.read(self.proc.stdout.fileno(), 65536)
            require(bool(chunk), 'native host closed before completion')
            self.buffer += chunk
            require(len(self.buffer) <= 8 * 1024 * 1024, 'native frame limit exceeded')
        line, self.buffer = self.buffer.split(b'\n', 1)
        data = json.loads(line)
        if record:
            with self.log.open('ab') as stream:
                stream.write(line + b'\n')
        if 'id' in data and 'method' in data:
            self.send({'id': data['id'], 'error': {
                'code': -32000, 'message': 'Independent review cannot authorize host interaction'}})
            raise ValueError('native host requested interaction')
        return data

    def request(self, method, params, *, record=True):
        self.number += 1
        ident = self.number
        self.send({'id': ident, 'method': method, 'params': params})
        while True:
            data = self.receive(record=record)
            if data.get('id') == ident:
                require('error' not in data, 'native request rejected: ' + method)
                return data['result']
            self.events.append(data)
            require(len(self.events) <= 10000, 'native event limit exceeded')

    def close(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)
        self.selector.close()
        self.proc.stdin.close()
        self.proc.stdout.close()
        self.stderr.close()


def initialize(rpc):
    rpc.request('initialize', {'clientInfo': {'name': 'sdd-codex-review', 'version': '1'},
                              'capabilities': {'experimentalApi': True}})
    rpc.send({'method': 'initialized', 'params': {}})


def command_base(cli, scratch):
    profile = ('{network={enabled=false},filesystem={":minimal"="read",' +
               json.dumps(str(scratch)) + '="read",' +
               json.dumps(str(cli)) + '="read"}}')
    return [str(cli), 'app-server', '--stdio', '--strict-config',
            '-c', 'permissions.' + PROFILE + '=' + profile,
            '-c', 'default_permissions=' + json.dumps(PROFILE),
            '-c', 'web_search="disabled"', '-c', 'project_doc_max_bytes=0',
            '-c', 'shell_environment_policy.inherit="none"',
            '-c', 'features.plugins=false', '-c', 'features.apps=false',
            '-c', 'features.hooks=false', '-c', 'features.multi_agent=false']


def probe_permissions(rpc, scratch, outside):
    """Native command/exec probes do not start a model turn."""
    marker = scratch / '.permission-probe'
    marker.write_text('sdd-readable-input\n')
    commands = [
        ['/bin/cat', str(marker)], ['/bin/cat', str(outside)],
        ['/bin/sh', '-c', 'printf changed > .permission-probe'],
        ['/usr/bin/python3', '-I', '-c', 'import socket; socket.socket()'],
    ]
    results = [rpc.request('command/exec', {'command': cmd, 'cwd': str(scratch),
                'permissionProfile': PROFILE, 'timeoutMs': 5000}) for cmd in commands]
    require(results[0].get('exitCode') == 0 and
            results[0].get('stdout') == 'sdd-readable-input\n', 'native inside read failed')
    require(all(item.get('exitCode') != 0 for item in results[1:]),
            'native outside read, write, or network was not denied')
    require(marker.read_text() == 'sdd-readable-input\n', 'native probe changed input')
    # Runtime absence is not permission enforcement.
    require('Read-only file system' in results[2].get('stderr', '') and
            'Operation not permitted' in results[3].get('stderr', ''),
            'native denial reason did not establish enforcement')
    marker.unlink()
    return results


def check_result(result, data):
    require(isinstance(result, dict), 'reviewer output is not an object')
    expected = {key: data[key] for key in ('stage', 'role', 'run_id', 'host_session_id')}
    if data['role'] == 'task-reviewer-a':
        expected.update(stage='task-review', role='reviewer-a')
    for key, value in expected.items():
        require(result.get(key) == value, 'reviewer identity mismatch: ' + key)
    require(result.get('schema') == data['role'] + '/v1', 'reviewer schema mismatch')
    require(result.get('verdict') in ('PASS', 'NEEDS_WORK', 'BLOCKED'), 'reviewer verdict missing')
    require(isinstance(result.get('checks'), list) and result['checks'], 'review checks missing')
    entries = result.get('allowed_input_manifest')
    if data['stage'] == 'task':
        entries = result.get('manifest')
        if data['role'].endswith('-b') and isinstance(entries, dict):
            entries = entries.get('allowed_inputs')
    require(entries == data['allowed_input_manifest'], 'reviewer input manifest mismatch')


def launch(args):
    root = args.repository_root.resolve(strict=True)
    template = args.invocation.resolve(strict=True)
    require(sha(template) == args.manifest_sha256, 'caller invocation pin mismatch')
    data = transport.load(template)
    stage = data.get('stage')
    require(stage in ('spec', 'impl', 'task') and
            data.get('role') in transport.STAGE_ROLES[stage], 'unsupported Codex reviewer role')
    require(data.get('input_mode') == 'file-manifest' and data.get('fallback_mode') == 'none'
            and data.get('read_only') is True, 'unsupported review boundary')
    require(not any(key.startswith('model_') for key in data),
            'managed model routing requires its admitted managed transport')
    fixed = transport.fixed_input_binding(root, data, args.fixed_input_record, args.fixed_input_snapshot)
    launcher.checked_input_paths(root, data, fixed)
    hashes = transport.admitted_raw_hashes(root, data, fixed)
    output = args.output.absolute()
    require('..' not in output.parts, 'output contains parent traversal')
    require(output.is_relative_to(root) and not output.exists(), 'output must be new and inside repository')
    current = output.parent
    while current != root:
        require(not current.is_symlink(), 'output parent traverses symlink')
        current = current.parent
    output.mkdir(parents=True)
    cli = Path(shutil.which(args.codex) or args.codex).resolve(strict=True)
    require(cli.is_file(), 'Codex executable unavailable')
    selected = {e['path'] for e in fixed['inventory']['inputs']} if fixed else set()
    def source(name):
        return (Path(fixed['snapshot']) if name in selected else root) / name
    def unchanged():
        require(sha(template) == args.manifest_sha256, 'caller invocation changed')
        launcher.checked_input_paths(root, data, fixed)
        require(all(sha(source(name)) == digest for name, digest in hashes.items()), 'review inputs changed')
    def save(name, value):
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    with tempfile.TemporaryDirectory(prefix='sdd-codex-review-') as folder:
        parent = Path(folder)
        scratch = parent / 'inputs'
        scratch.mkdir()
        for name, digest in hashes.items():
            target = scratch / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source(name).read_bytes())
            require(sha(target) == digest, 'snapshot input changed')
        outside = parent / 'outside-denial-probe'
        outside.write_text('must-not-be-readable')
        command = command_base(cli, scratch)
        # Inspect only configuration; never log config/read (it can contain secrets).
        discovery = Rpc(command, scratch, output, min(args.timeout, 30))
        try:
            initialize(discovery)
            config = discovery.request('config/read', {'includeLayers': False}, record=False)['config']
            servers = config.get('mcp_servers') or {}
            require(isinstance(servers, dict), 'native MCP configuration is unknown')
            for name in servers:
                command.extend(['-c', 'mcp_servers.' + json.dumps(name) + '.enabled=false'])
        finally:
            discovery.close()
        rpc = Rpc(command, scratch, output, args.timeout)
        try:
            initialize(rpc)
            config = rpc.request('config/read', {'includeLayers': False}, record=False)['config']
            require(all(server.get('enabled') is False for server in (config.get('mcp_servers') or {}).values()),
                    'native external tools not disabled')
            require(all(config.get('features', {}).get(key) is False for key in
                        ('plugins', 'apps', 'hooks', 'multi_agent')) and
                    config.get('web_search') == 'disabled', 'native external capabilities not disabled')
            save('permission-probes.json', probe_permissions(rpc, scratch, outside))
            role = transport.plugin_file('plugins/sdd-review-loop/agents/' + data['role'] + '.md')
            allocation = rpc.request('thread/start', {
                'cwd': str(scratch), 'permissions': PROFILE, 'approvalPolicy': 'never',
                'selectedCapabilityRoots': [],
                'baseInstructions': 'Independent read-only review. Read only the invocation and its listed files. Return the role-required JSON. No changes, external tools, network, inherited history, or other reviewer reports.',
                'developerInstructions': role.read_text(), 'config': {'project_doc_max_bytes': 0}})
            save('idle-allocation.json', allocation)
            thread = allocation['thread']
            identity = thread['id']
            environments = thread.get('environments')
            require(isinstance(environments, list) and len(environments) == 1 and
                    environments[0].get('environmentId') == 'local' and
                    environments[0].get('cwd') == str(scratch),
                    'native reviewer environment is not the local projection')
            require(isinstance(identity, str) and identity.strip() and not thread.get('turns') and
                    thread.get('status', {}).get('type') == 'idle' and
                    allocation.get('activePermissionProfile', {}).get('id') == PROFILE,
                    'native idle identity or permissions not established')
            ledger = root / 'reports/review-context/identity-ledger.json'
            require(not ledger.is_symlink(), 'identity ledger is a symlink')
            history = transport.load(ledger)['records']
            require(isinstance(history, list) and history, 'initialize the canonical identity ledger before review')
            data.update(run_id=identity, host_session_id=identity,
                        identity_ledger_path='reports/review-context/identity-ledger.json',
                        identity_ledger_sha256=sha(ledger),
                        previous_record_sha256=history[-1]['record_sha256'],
                        sequence=history[-1]['sequence'] + 1)
            save('invocation.json', data)
            invocation = output / 'invocation.json'
            preflight.preflight(root, invocation, sha(invocation), runtime=args.runtime,
                                fixed_input_record=args.fixed_input_record,
                                fixed_input_snapshot=args.fixed_input_snapshot)
            validator = transport.plugin_file('plugins/sdd-quality-loop/scripts/validate-review-context-set.' +
                                              ('sh' if args.runtime == 'bash' else 'ps1'))
            reserve = (['bash', str(validator), str(invocation), str(root), '--reserve'] if args.runtime == 'bash' else
                       ['pwsh', '-NoProfile', '-File', str(validator), '-Manifest', str(invocation),
                        '-RepositoryRoot', str(root), '-Reserve'])
            if fixed:
                reserve += (['--fixed-input-record', fixed['record'], '--fixed-input-snapshot', fixed['snapshot']]
                            if args.runtime == 'bash' else ['-FixedInputRecord', fixed['record'], '-FixedInputSnapshot', fixed['snapshot']])
            unchanged()
            reserved = subprocess.run(reserve, cwd=root, capture_output=True, text=True, timeout=60)
            (output / 'reservation.stdout').write_text(reserved.stdout)
            (output / 'reservation.stderr').write_text(reserved.stderr)
            require(reserved.returncode == 0 and re.fullmatch(
                r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* previous_record_sha256=(?:-|[0-9a-f]{64}) pre_append_tip_sequence=[0-9]+ identity_unique=yes\n?',
                reserved.stdout), 'reservation failed; no reviewer turn started')
            transport.receipt_control(data, reserved.stdout)
            unchanged()
            (scratch / 'invocation.json').write_bytes(invocation.read_bytes())
            started = rpc.request('turn/start', {'threadId': identity, 'permissions': PROFILE,
                'approvalPolicy': 'never', 'input': [{'type': 'text', 'text_elements': [], 'text':
                'Read invocation.json and only its listed files. Verify your launch using this caller receipt and the manifest; do not read the ledger or reserve again.\n' + reserved.stdout +
                '\nReturn only the required JSON. Review findings honestly; do not assume PASS.'}]})
            turn_id = started['turn']['id']
            messages = []
            while True:
                event = rpc.events.pop(0) if rpc.events else rpc.receive()
                params = event.get('params', {})
                if event.get('method') in ('item/completed', 'turn/completed'):
                    require(params.get('threadId') == identity, 'native event thread mismatch')
                if event.get('method') == 'item/completed' and params['item'].get('type') == 'agentMessage':
                    require(params.get('turnId') == turn_id, 'native event turn mismatch')
                    messages.append(params['item']['text'])
                if event.get('method') == 'turn/completed':
                    require(params['turn'].get('id') == turn_id and params['turn'].get('status') == 'completed',
                            'native review turn failed')
                    break
            unchanged()
            (output / 'reviewer-raw.txt').write_text('\n'.join(messages) + '\n')
            require(bool(messages), 'reviewer response missing')
            result = json.loads(messages[-1])
            check_result(result, data)
            save('reviewer.json', result)
            save('delivery.json', {'schema': 'codex-review-delivery/v1', 'run_id': identity,
                'host_session_id': identity, 'invocation_sha256': sha(invocation),
                'reviewer_sha256': sha(output / 'reviewer.json'), 'raw_input_hashes': hashes,
                'permission_profile': PROFILE, 'adoption': 'requires-canonical-stage-validator'})
            return output / 'reviewer.json'
        finally:
            rpc.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('repository_root', type=Path)
    parser.add_argument('invocation', type=Path)
    parser.add_argument('--manifest-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--codex', default='codex')
    parser.add_argument('--runtime', choices=('bash', 'powershell'), default='bash')
    parser.add_argument('--fixed-input-record', type=Path)
    parser.add_argument('--fixed-input-snapshot', type=Path)
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    try:
        require(10 <= args.timeout <= 1800, 'timeout outside 10..1800 seconds')
        print('CODEX_REVIEW_CANDIDATE ' + str(launch(args)))
        return 0
    except (OSError, ValueError, KeyError, TypeError, TimeoutError, subprocess.SubprocessError) as error:
        print('CODEX_REVIEW_REJECTED: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
