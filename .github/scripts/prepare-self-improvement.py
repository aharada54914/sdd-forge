#!/usr/bin/env python3
"""Workflow-only optional configured invocation capture, then unchanged managed Action preparation."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import selectors
import signal
import subprocess
import sys
import time
import uuid

PROBE_SECONDS = 60
STREAM_LIMIT = 1024 * 1024
EXPECTED_VERSION = '2.1.303 (Claude Code)'
# Approved typed trial summary; this is a reported label, never a backend attestation.
LABEL_SOURCE = 'specs/ci-model-modernization/verification/self-improvement-20261023/public-trial-summaries.json'
LABEL_SOURCE_SHA256 = '568171b8f2f03b495fae2212dfec835e460e52db8451bcd7b6070e2c85904aa5'
EXPECTED_LABEL = 'claude-opus-5-5'
KNOWN_CAPTURE_FAILURES = frozenset((
    'capture-configuration-unavailable capture-input-drift capture-label-evidence-drift '
    'capture-local-authority-conflict capture-native-env-shape capture-native-version-or-envelope '
    'capture-postprobe-authority-or-executable-drift capture-preprobe-drift capture-preprobe-input-drift '
    'capture-producer-source-drift capture-profile-not-supported '
    'capture-requires-explicit-self-improvement-pin capture-role-not-adopted capture-trusted-input-drift '
    'capture-validation-failed input-budget-exceeded invalid-capture-boolean probe-assistant-shape '
    'probe-configuration-mismatch probe-effort-mismatch probe-error-or-reroute probe-event-after-result '
    'probe-execution-error probe-hook-failed probe-incomplete-response probe-input-timeout '
    'probe-model-mismatch probe-native-error probe-nonzero-exit probe-output-limit '
    'probe-rejected-or-unknown-quota-event probe-session-mismatch probe-terminal-failure probe-text-shape '
    'probe-timeout probe-tool-advertisement-shape probe-tool-or-unknown-content '
    'probe-unexpected-model-usage-label probe-unknown-event '
).split())


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def utc():
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


def emit_summary(receipt, receipt_sha, failure=None):
    """Only closed diagnostic fields survive runner disposal; raw data remains private and ephemeral."""
    def hashed(value):
        return value if isinstance(value, str) and len(value) == 64 and all(c in '0123456789abcdef' for c in value) else None
    def instant(value):
        if not isinstance(value, str) or len(value) > 32 or not value.endswith('Z'):
            return None
        try:
            datetime.fromisoformat(value.replace('Z', '+00:00'))
            return value
        except ValueError:
            return None
    events = receipt.get('events', {})
    failure = failure if failure is None or failure in KNOWN_CAPTURE_FAILURES else 'capture-validation-failed'
    exit_code = receipt.get('exit_code')
    summary = {'capture_status': 'success' if failure is None else 'failed', 'failure_code': failure,
        'configured_model': 'opus' if receipt.get('configured_model') == 'opus' else None,
        'effort': 'medium' if receipt.get('effort') == 'medium' else None,
        'cli_version': EXPECTED_VERSION if receipt.get('cli_version') == EXPECTED_VERSION else None,
        'reported_model_label': EXPECTED_LABEL if events.get('observed_model_label') == EXPECTED_LABEL else None,
        'actual_tool_calls': 0 if type(events.get('actual_tool_calls')) is int and events['actual_tool_calls'] == 0 else None,
        'exit_code': exit_code if type(exit_code) is int and -255 <= exit_code <= 255 else None,
        'started_at': instant(receipt.get('started_at')), 'completed_at': instant(receipt.get('completed_at')),
        'stdout_sha256': hashed(receipt.get('stdout_sha256')), 'stderr_sha256': hashed(receipt.get('stderr_sha256')),
        'receipt_sha256': hashed(receipt_sha), 'backend_identity': 'unverified',
        'raw_evidence': 'private-runner-only-not-retained'}
    print(json.dumps({'configured_capture_summary': summary}, separators=(',', ':')), flush=True)


def load_entry(path):
    spec = importlib.util.spec_from_file_location('workflow_managed_entry', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def capture_process(helper, command, environment, payload, directory, entry, *, seconds=PROBE_SECONDS):
    """Keep bounded failure bytes too; installed _run_cli deliberately discards stderr/timeout bytes."""
    deadline = time.monotonic() + seconds
    streams = {'stdout': bytearray(), 'stderr': bytearray()}
    result = {'exit_code': None, 'failure': None, 'started_at': utc()}
    process = None
    try:
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=environment, start_new_session=True)
        if not helper._bounded(lambda: (process.stdin.write(payload), process.stdin.close()),
                               max(0, deadline - time.monotonic())):
            result['failure'] = 'probe-input-timeout'
        else:
            with selectors.DefaultSelector() as selector:
                for name in streams:
                    selector.register(getattr(process, name), selectors.EVENT_READ, name)
                while selector.get_map():
                    left = deadline - time.monotonic()
                    if left <= 0:
                        result['failure'] = 'probe-timeout'
                        break
                    for key, _ in selector.select(left):
                        data = os.read(key.fd, min(65536, STREAM_LIMIT + 1 - len(streams[key.data])))
                        streams[key.data].extend(data)
                        if not data:
                            selector.unregister(key.fileobj)
                        if len(streams[key.data]) > STREAM_LIMIT:
                            result['failure'] = 'probe-output-limit'
                            break
                    if result['failure']:
                        break
            if not result['failure']:
                try:
                    result['exit_code'] = process.wait(timeout=max(.001, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    result['failure'] = 'probe-timeout'
    except OSError:
        result['failure'] = 'probe-execution-error'
    finally:
        result['completed_at'] = utc()
        if process:
            helper._terminate(process)
            result['cleanup_exit_code'] = process.returncode
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            for name in ('stdin', 'stdout', 'stderr'):
                getattr(process, name).close()
        for name, raw in streams.items():
            entry._create(directory, name + '.log', bytes(raw), mode=0o600)
            result[name + '_sha256'] = digest(raw)
    return result, bytes(streams['stdout'])


def allowed_quota_event(event):
    """Quota metadata is incidental; only its primary status can contradict success."""
    if set(event) != {'type', 'rate_limit_info', 'uuid', 'session_id'}:
        return False
    if not isinstance(event['uuid'], str) or str(uuid.UUID(event['uuid'])) != event['uuid']:
        return False
    info = event['rate_limit_info']
    return (isinstance(info, dict) and isinstance(info.get('status'), str)
            and info['status'] in ('allowed', 'allowed_warning'))


def validate_events(helper, raw, session, native, effort, nonce, version):
    events = [helper.strict_json(line) for line in raw.split(b'\n') if line.strip()]
    init = terminal = None
    assistant_text = []
    hooks = rate_limits = 0
    for event in events:
        if not isinstance(event, dict) or event.get('session_id') != session:
            raise ValueError('probe-session-mismatch')
        if any(event.get(k) for k in ('error', 'fallback_model', 'fallbackModel', 'reroute', 'rerouted')):
            raise ValueError('probe-error-or-reroute')
        kind, sub = event.get('type'), event.get('subtype')
        if kind == 'rate_limit_event':
            if not allowed_quota_event(event):
                raise ValueError('probe-rejected-or-unknown-quota-event')
            rate_limits += 1
            continue
        if terminal is not None:
            raise ValueError('probe-event-after-result')
        if kind == 'system' and sub == 'init' and init is None:
            init = event
            if not isinstance(event.get('tools'), list) or not all(isinstance(tool, str) for tool in event['tools']):
                raise ValueError('probe-tool-advertisement-shape')
            if (event.get('model') != EXPECTED_LABEL or event.get('claude_code_version') != version.split()[0]
                    or event.get('cwd') != os.getcwd()):
                raise ValueError('probe-configuration-mismatch')
            if 'effort' in event and event['effort'] != effort:
                raise ValueError('probe-effort-mismatch')
        elif kind == 'system' and sub in ('hook_started', 'hook_progress', 'hook_response'):
            hooks += 1
            if event.get('exit_code', 0) != 0:
                raise ValueError('probe-hook-failed')
        elif kind == 'assistant' and init is not None:
            message = event.get('message')
            if not isinstance(message, dict) or not isinstance(message.get('content'), list):
                raise ValueError('probe-assistant-shape')
            if event.get('error') or message.get('error'):
                raise ValueError('probe-native-error')
            if message.get('model') != EXPECTED_LABEL:
                raise ValueError('probe-model-mismatch')
            for block in message['content']:
                if not isinstance(block, dict) or block.get('type') not in ('text', 'thinking', 'redacted_thinking'):
                    raise ValueError('probe-tool-or-unknown-content')
                if block['type'] == 'text':
                    if not isinstance(block.get('text'), str):
                        raise ValueError('probe-text-shape')
                    assistant_text.append(block['text'])
        elif kind == 'result' and init is not None:
            terminal = event
            if (sub != 'success' or event.get('is_error') is not False or event.get('result') != nonce
                    or type(event.get('num_turns')) is not int or event['num_turns'] != 1 or event.get('errors')):
                raise ValueError('probe-terminal-failure')
            if 'modelUsage' in event and (not isinstance(event['modelUsage'], dict) or set(event['modelUsage']) - {EXPECTED_LABEL}):
                raise ValueError('probe-unexpected-model-usage-label')
        else:
            raise ValueError('probe-unknown-event')
    if init is None or terminal is None or ''.join(assistant_text) != nonce:
        raise ValueError('probe-incomplete-response')
    return {'event_count': len(events), 'hook_events': hooks, 'rate_limit_events': rate_limits, 'actual_tool_calls': 0,
            'observed_model_label': init['model'], 'backend_identity': 'unverified',
            'advertised_tools': init['tools'], 'reported_permission_mode': init.get('permissionMode'),
            'tool_boundary': 'Observed zero model tool calls; configured MCP authority and hooks retained, not an isolation or prevention proof.'}


def capture(entry, helper, environment, template, registry_path, executable, launch_session, run_id, attempt):
    flags = helper._safe_open_flags()
    base = os.open('.', entry.DIRECTORY_FLAGS)
    parent = directory = held_fd = None
    receipt = None
    receipt_sha = None
    try:
        captured = {}
        def read(path):
            if path not in captured:
                captured[path] = helper._read_beneath(base, path, helper.MAX_OPERATION_BYTES, flags)
            if sum(map(len, captured.values())) > helper.MAX_OPERATION_BYTES:
                raise ValueError('input-budget-exceeded')
            return captured[path]
        request = helper.strict_json(read(template))
        # Only this workflow's explicit, non-resume pin is a supported producer input.
        if (request.get('role') != 'self-improvement' or request.get('host') != 'claude-code'
                or request.get('cli', {}).get('policy') != 'pinned'
                or not request.get('cli', {}).get('model_id') or not request.get('requested_effort')
                or request.get('risk') != 'medium' or request.get('budget') is not None
                or request.get('project_config_path') is not None or request.get('resume_selection_path') is not None):
            raise ValueError('capture-requires-explicit-self-improvement-pin')
        parent = entry._directory(base, ['.sdd-self-improvement'], create=True)
        # mkdir is exclusive; an existing output is never reused.
        os.mkdir(launch_session, 0o700, dir_fd=parent)
        directory = entry._directory(parent, [launch_session], create=False)
        output = '.sdd-self-improvement/' + launch_session
        request = dict(request, observation_path=output + '/observation.json')
        helper._validate_policy_request(request)
        policy = helper.strict_json(read(request['policy_path']))
        registry_raw = read(registry_path)
        registry, registered = helper._policy_registry(registry_path)
        for model in policy.get('models', []):
            for ref in model.get('adoption', []):
                read(ref['path'])
        models = helper._validate_role_policy(policy, registered, registry.get('role_defaults', {}))
        model = models[request['cli']['model_id']]
        if not any(ref['role'] == 'self-improvement' for ref in model['adoption']):
            raise ValueError('capture-role-not-adopted')
        native, effort = model['hosts']['claude-code'], request['requested_effort']
        if (native, effort) != ('opus', 'medium'):
            raise ValueError('capture-profile-not-supported')
        if model['lifecycle'] in ('historical', 'retired') or effort not in registered[model['id']]['supported_efforts']:
            raise ValueError('capture-configuration-unavailable')
        # Validate against the installed trust root too, before any paid work.
        trusted_root, trusted_paths = helper._trusted_inventory()
        trusted_base = os.open(trusted_root, entry.DIRECTORY_FLAGS)
        try:
            trusted = {p: helper._read_beneath(trusted_base, p, helper.MAX_OPERATION_BYTES, flags) for p in trusted_paths}
        finally:
            os.close(trusted_base)
        helper._launch_authority(registry_raw, policy, trusted['contracts/agent-model-capabilities.v2.json'],
                                 trusted['contracts/model-policy.v1.json'])
        source_root = Path(__file__).resolve().parents[2]
        source_base = os.open(source_root, entry.DIRECTORY_FLAGS)
        try:
            label_evidence = helper._read_beneath(source_base, LABEL_SOURCE, helper.MAX_OPERATION_BYTES, flags)
        finally:
            os.close(source_base)
        if digest(label_evidence) != LABEL_SOURCE_SHA256:
            raise ValueError('capture-label-evidence-drift')
        source_pins = {p: p.read_bytes() for p in (Path(__file__), Path(entry.__file__), entry.DRIVER)}
        driver = entry._load_driver()
        sources, unresolved = entry._local_sources(environment)
        authority = entry._collect_local_authority(helper, sources, unresolved_tiers=unresolved)
        verdict = entry._check_local_authority(authority, native, effort)
        if authority['reason'] or verdict['reason']:
            raise ValueError('capture-local-authority-conflict')
        overrides = driver.native_overrides(environment)
        for scope in [*(authority['tiers'].get(tier, {}) for tier in reversed(entry.DEVELOPER_RANK)), verdict['effective']['managed']]:
            for name, value in scope.get('env', {}).items():
                if name in overrides:
                    if not isinstance(value, str):
                        raise ValueError('capture-native-env-shape')
                    overrides[name] = value
        driver.require_native_precedence(native, effort, overrides)
        held_fd = entry._open_executable(executable)
        held = entry._held_state(executable, held_fd)
        help_code, help_raw = entry._cli_output(helper, executable, '--help', environment, entry.MAX_BYTES)
        version_code, version_raw = entry._cli_output(helper, executable, '--version', environment, helper.MAX_VERSION_BYTES)
        version = version_raw.decode('ascii').removesuffix('\n')
        required = {'--print', '--output-format', '--verbose', '--model', '--effort', '--session-id', '--tools', '--include-hook-events'}
        if (help_code != 0 or version_code != 0 or version != EXPECTED_VERSION
                or not required <= entry._declared_flags(help_raw.decode('utf-8'))):
            raise ValueError('capture-native-version-or-envelope')
        if entry._held_state(executable, held_fd) != held or entry._recheck_local_authority(helper, authority)['reason']:
            raise ValueError('capture-preprobe-drift')
        if any(helper._read_beneath(base, p, helper.MAX_OPERATION_BYTES, flags) != raw for p, raw in captured.items()):
            raise ValueError('capture-preprobe-input-drift')
        probe_session, nonce = str(uuid.uuid4()), secrets.token_hex(24)
        command = [executable, '--print', '--output-format', 'stream-json', '--verbose', '--model', native,
                   '--effort', effort, '--session-id', probe_session, '--tools', '', '--include-hook-events']
        receipt = {'configured_model': native, 'effort': effort, 'cli_version': version, 'executable_sha256': held[1],
                   'reported_label_evidence': {'path': LABEL_SOURCE, 'sha256': LABEL_SOURCE_SHA256},
                   'run_id': run_id, 'attempt': attempt, 'launch_session': launch_session, 'probe_session': probe_session,
                   'nonce': nonce, 'argv': command, 'input_sha256': {p: digest(v) for p, v in captured.items()},
                   'trusted_sha256': {p: digest(v) for p, v in trusted.items()},
                   'producer_source_sha256': {str(p): digest(v) for p, v in source_pins.items()},
                   'local_authority_sha256': digest(helper.canonical(authority)),
                   'effective_native_overrides_sha256': digest(helper.canonical(overrides)),
                   'unresolved_authority': verdict['unresolved'], 'status': 'failed', 'actual_backend_identity': 'unverified'}
        result, raw = capture_process(helper, command, environment,
                                     ('Return exactly the following nonce and do not invoke tools: ' + nonce).encode(),
                                     directory, entry)
        receipt.update(result)
        if result['failure'] or result['exit_code'] != 0:
            raise ValueError(result['failure'] or 'probe-nonzero-exit')
        receipt['events'] = validate_events(helper, raw, probe_session, native, effort, nonce, version)
        if entry._held_state(executable, held_fd) != held or entry._recheck_local_authority(helper, authority)['reason']:
            raise ValueError('capture-postprobe-authority-or-executable-drift')
        if any(helper._read_beneath(base, p, helper.MAX_OPERATION_BYTES, flags) != raw for p, raw in captured.items()):
            raise ValueError('capture-input-drift')
        trusted_base = os.open(trusted_root, entry.DIRECTORY_FLAGS)
        try:
            if any(helper._read_beneath(trusted_base, p, helper.MAX_OPERATION_BYTES, flags) != raw for p, raw in trusted.items()):
                raise ValueError('capture-trusted-input-drift')
        finally:
            os.close(trusted_base)
        if any(p.read_bytes() != raw for p, raw in source_pins.items()):
            raise ValueError('capture-producer-source-drift')
        source_base = os.open(source_root, entry.DIRECTORY_FLAGS)
        try:
            if helper._read_beneath(source_base, LABEL_SOURCE, helper.MAX_OPERATION_BYTES, flags) != label_evidence:
                raise ValueError('capture-label-evidence-drift')
        finally:
            os.close(source_base)
        receipt['status'] = 'configured-invocation-accepted'
        receipt_raw = helper.canonical(receipt)
        entry._create(directory, 'capture-receipt.json', receipt_raw, mode=0o600)
        receipt_sha = digest(receipt_raw)
        observation = helper._seal({'schema': 'model-observation/v1', 'host': 'claude-code', 'cli_version': version,
            'scope_id': 'weekly-' + probe_session, 'scope_kind': 'client', 'purpose': 'launch',
            'observed_at': result['completed_at'], 'source': 'verified-configuration', 'status': 'complete',
            'models': [{'native_id': native, 'efforts': [effort], 'available': True}],
            'reason': 'Configured invocation accepted; receipt sha256=' + digest(receipt_raw)
                      + '; native discovery and actual backend identity remain unverified.'})
        helper.validate_configuration(observation)
        entry._create(directory, 'observation.json', helper.canonical(observation), mode=0o600)
        entry._create(directory, 'request.json', helper.canonical(request), mode=0o600)
        emit_summary(receipt, receipt_sha)
        return output + '/request.json', output + '/managed'
    except Exception as exc:
        failure = str(exc) if isinstance(exc, ValueError) and str(exc) in KNOWN_CAPTURE_FAILURES else 'capture-validation-failed'
        try:
            if directory is not None and 'capture-receipt.json' not in os.listdir(directory):
                if receipt is None:
                    receipt = {'status': 'failed-before-probe', 'native_calls': 0}
                receipt['failure'] = failure
                receipt_raw = helper.canonical(receipt)
                entry._create(directory, 'capture-receipt.json', receipt_raw, mode=0o600)
                receipt_sha = digest(receipt_raw)
        finally:
            emit_summary(receipt or {}, receipt_sha, failure)
        raise
    finally:
        for descriptor in (held_fd, directory, parent, base):
            if descriptor is not None:
                os.close(descriptor)


def main():
    environment = dict(os.environ)
    session = str(uuid.uuid4())
    request = environment.get('SDD_SELF_IMPROVEMENT_REQUEST', '')
    registry = environment['SDD_SELF_IMPROVEMENT_REGISTRY']
    output = '.sdd-self-improvement/' + session
    capture_requested = environment.get('SDD_CAPTURE_CONFIGURATION', 'false')
    if capture_requested not in ('true', 'false'):
        raise ValueError('invalid-capture-boolean')
    if capture_requested == 'true':
        entry = load_entry(environment['SDD_MANAGED_ENTRY'])
        request, output = capture(entry, entry._load_helper(), environment,
            request or '.github/self-improvement-request.template.json', registry,
            environment['CLAUDE_NATIVE_EXECUTABLE'], session, environment['GITHUB_RUN_ID'], environment['GITHUB_RUN_ATTEMPT'])
    else:
        Path('.sdd-self-improvement').mkdir(exist_ok=True)
    command = [sys.executable, '-I', '-B', environment['SDD_MANAGED_ENTRY'], 'claude-action-prepare',
               '--request', request, '--registry', registry, '--role', 'self-improvement', '--host', 'claude-code',
               '--run-id', environment['GITHUB_RUN_ID'], '--session-id', session,
               '--attempt', environment['GITHUB_RUN_ATTEMPT'], '--output-dir', output,
               '--require-actual-id', 'false', '--executable', environment['CLAUDE_NATIVE_EXECUTABLE']]
    result = subprocess.run(command, stdout=subprocess.PIPE, check=False, env=environment)
    if result.returncode:
        return result.returncode
    selected = json.loads(result.stdout)['selection']['resolved']
    with open(environment['GITHUB_OUTPUT'], 'a') as stream:
        for name, value in dict(executable=str(Path(output, 'claude-sdk-entry').resolve()), model=selected['native_id'],
                               effort=selected['effort'], session_id=session, output_dir=output).items():
            print(name + '=' + value, file=stream)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        # Raw native bytes remain private in the per-run receipt directory, never workflow stdout/stderr.
        print(json.dumps({'schema': 'model-policy-error/v1', 'reason': 'model-unverified',
                          'message': 'Configured capture failed before audit launch; any started capture retains a private per-run receipt.'}), file=sys.stderr)
        raise SystemExit(2)
