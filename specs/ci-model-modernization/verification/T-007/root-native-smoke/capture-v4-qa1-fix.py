#!/usr/bin/env python3
"""Actual selected-config smoke; no turn, inference, provider identity or adoption claim.

Uses the product's genuine active Capture and unchanged selector. Only the native
executable resolution is redirected to the documented separate verify profile.
All native responses are genuine; no response fixture or mock is installed.
"""
import datetime
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
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
VERIFY = Path('/workspace/.tools/sdd-forge-dev/verify-codex')
HELPER = 'plugins/sdd-implementation/scripts/model-policy.py'
RUNTIME = [HELPER, 'plugins/sdd-implementation/scripts/select-agent-model.sh',
           'plugins/sdd-implementation/scripts/select-agent-model.ps1',
           'contracts/agent-model-capabilities.v2.json', 'contracts/model-policy.v1.json',
           'contracts/model-launch-controls.schema.json',
           'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py',
           'plugins/sdd-review-loop/scripts/launch-impl-review.py',
           'plugins/sdd-quality-loop/scripts/emit-run-record.sh',
           'plugins/sdd-quality-loop/scripts/emit-run-record.ps1',
           'plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh',
           'plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1',
           'plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh',
           'plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1']
SCHEMAS = ROOT / 'specs/ci-model-modernization/verification/T-004/quality-cycle1-fix/final/native-readonly/generated-schema/v2'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode()


def save(out, name, value):
    path = out / name
    with path.open('xb') as stream:
        stream.write(canonical(value))
    return {'path': str(path.relative_to(ROOT)), 'sha256': sha(path.read_bytes())}


def main():
    import jsonschema
    assert ROOT == Path('/workspace/sdd-forge')
    assert VERIFY.is_file()
    out = HERE / 'actual-qa1-fix-final'
    out.mkdir(exist_ok=False)
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    inputs = [{'path': str((ROOT / p).relative_to(ROOT)), 'sha256': sha((ROOT / p).read_bytes())} for p in RUNTIME]
    inputs += [{'path': str(SCHEMAS / (n + '.json')), 'sha256': sha((SCHEMAS / (n + '.json')).read_bytes())}
               for n in ('ThreadStartParams', 'ThreadStartResponse')]
    inputs += [{'path': str(VERIFY), 'sha256': sha(VERIFY.read_bytes())}]
    source_pin = sha(Path(__file__).read_bytes())
    original_popen, original_which = subprocess.Popen, shutil.which
    calls, outputs, checks = [], [], []
    allowed = {'initialize', 'initialized', 'account/read', 'model/list', 'thread/start'}
    with tempfile.TemporaryDirectory(prefix='ci-t007-native-fixture-') as td:
        fixture = Path(td)
        for name in RUNTIME:
            target = fixture / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        spec = importlib.util.spec_from_file_location('t007_actual_native', fixture / HELPER)
        assert spec is not None and spec.loader is not None
        mod = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = mod
        spec.loader.exec_module(mod)
        original_send = mod.CodexClient._send
        original_request = mod.CodexClient._request

        def send(client, message):
            method = message.get('method')
            assert method in allowed, 'Unadmitted native method blocked before write'
            params = message.get('params', {})
            if method == 'account/read':
                assert params == {'refreshToken': False}
            if method == 'thread/start':
                assert params['ephemeral'] is True and params['approvalPolicy'] == 'never'
                assert params['sandbox'] == 'read-only' and params['allowProviderModelFallback'] is False
                assert params['cwd'] == '/workspace/.tools/sdd-forge-dev/verification-workspace'
                jsonschema.validate(params, json.loads((SCHEMAS / 'ThreadStartParams.json').read_bytes()))
            calls.append({'method': method, 'request_id': message.get('id'),
                          'params': params if method == 'thread/start' else None,
                          'account_refresh': False if method == 'account/read' else None})
            return original_send(client, message)

        def request(client, method, params):
            response = original_request(client, method, params)
            if method == 'thread/start':
                jsonschema.validate(response, json.loads((SCHEMAS / 'ThreadStartResponse.json').read_bytes()))
                thread = response['thread']
                assert isinstance(thread['id'], str) and re.fullmatch(r'[A-Za-z0-9_-]+', thread['id'])
                outputs.append({'native_thread_id': thread['id'], 'configured_model': response['model'],
                                'configured_effort': response.get('reasoningEffort'),
                                'configured_provider': response['modelProvider'],
                                'cwd': response['cwd'], 'actual_id': None, 'proof': 'unverified'})
            return response

        def which(name, *args, **kwargs):
            return str(VERIFY) if name == 'codex' else original_which(name, *args, **kwargs)

        def popen(argv, *args, **kwargs):
            assert isinstance(argv, (list, tuple)) and not kwargs.get('shell')
            if argv[0] == str(VERIFY):
                assert list(argv[1:]) in [['--version'], ['app-server']]
            return original_popen(argv, *args, **kwargs)

        cwd = Path.cwd()
        try:
            os.chdir(fixture)
            with patch.object(shutil, 'which', which), patch.object(subprocess, 'Popen', popen), \
                 patch.object(mod.CodexClient, '_send', send), patch.object(mod.CodexClient, '_request', request):
                with mod.CodexClient('t007-selected-config-smoke') as client:
                    capture = client.capture(purpose='launch')
                    mod.validate_observation(capture.observation, capture=capture, purpose='launch')
                    checks.append('genuine-active-launch-capture-accepted')
                    assert capture.observation['status'] == 'complete'
                    policy = json.loads((fixture / 'contracts/model-policy.v1.json').read_bytes())
                    model = next(m for m in policy['models'] if m['id'] == 'gpt-6-astra')
                    assert model['hosts'] == {'codex-cli': 'gpt-6-astra'}
                    adoption = {'fixture_only': True, 'purpose': 'native-configuration-transport-reachability',
                                'model_quality_claim': False, 'production_adoption_claim': False}
                    (fixture / 'fixture-adoption.json').write_bytes(canonical(adoption))
                    model['lifecycle'] = 'current'
                    model['adoption'] = [{'role': 'panelist-gpt', 'path': 'fixture-adoption.json',
                                          'sha256': sha(canonical(adoption))}]
                    req = {'schema': 'model-policy-request/v1', 'role': 'panelist-gpt', 'risk': 'high',
                           'host': 'codex-cli', 'policy_path': 'policy.json', 'observation_path': 'observation.json',
                           'project_config_path': None, 'cli': {'model_id': 'gpt-6-astra', 'policy': 'pinned'},
                           'budget': None, 'requested_effort': 'high', 'resume_selection_path': None}
                    for name, value in [('policy.json', policy), ('observation.json', capture.observation), ('request.json', req)]:
                        (fixture / name).write_bytes(canonical(value))
                    registry = 'contracts/agent-model-capabilities.v2.json'
                    selection = mod._scoped_selection(fixture, {}, 'request.json',
                                                       str(fixture / registry), capture, None)
                    (fixture / 'selection.json').write_bytes(canonical(selection))
                    def ref(name):
                        return {'path': name, 'sha256': sha((fixture / name).read_bytes())}
                    paths = sorted({'policy.json', 'observation.json', 'fixture-adoption.json'})
                    controls = {'schema': 'model-launch-controls/v1', 'role': 'panelist-gpt', 'host': 'codex-cli',
                                'attempt': 1, 'require_actual_id': False, 'selection': ref('selection.json'),
                                'request': ref('request.json'), 'registry': ref(registry), 'inputs': [ref(n) for n in paths]}
                    raw = canonical(controls)
                    (fixture / 'controls.json').write_bytes(raw)
                    validation = mod.validate_launch_controls('controls.json', sha(raw), role='panelist-gpt',
                        host='codex-cli', run_id='t007-native-smoke', session_id='t007-local-correlation',
                        capture=capture, environment={})
                    checks.append('same-active-capture-trusted-controls-recomputed')
                    selected = validation['selection']['resolved']
                    assert selected['native_id'] == 'gpt-6-astra' and selected['effort'] == 'high'
                    blocked = dict(controls, require_actual_id=True)
                    (fixture / 'actual-required.json').write_bytes(canonical(blocked))
                    before = len(calls)
                    try:
                        mod.validate_launch_controls('actual-required.json', sha(canonical(blocked)), role='panelist-gpt',
                            host='codex-cli', run_id='t007-native-smoke', session_id='t007-local-correlation',
                            capture=capture, environment={})
                    except mod.PolicyError as error:
                        assert error.reason == 'actual-id-unavailable'
                        assert len(calls) == before
                        checks.append('required-actual-id-blocked-before-native-send')
                    else:
                        raise AssertionError('required actual ID unexpectedly accepted')
                    client._begin_operation()
                    params = {'model': selected['native_id'], 'config': {'model_reasoning_effort': selected['effort']},
                              'cwd': '/workspace/.tools/sdd-forge-dev/verification-workspace',
                              'ephemeral': True, 'approvalPolicy': 'never', 'sandbox': 'read-only',
                              'allowProviderModelFallback': False}
                    native = client._request('thread/start', params)
                    assert native['model'] == selected['native_id'] and native.get('reasoningEffort') == selected['effort']
                    checks.append('actual-thread-start-explicit-model-effort-match')
                    assert sum(c['method'] == 'thread/start' for c in calls) == 1
                    assert all(c['method'] != 'turn/start' for c in calls)
                    pins = []
                    for name in ['request.json', 'policy.json', 'observation.json', 'selection.json', 'controls.json', 'fixture-adoption.json']:
                        pins.append(save(out, name, json.loads((fixture / name).read_bytes())))
                    pins.append(save(out, 'validation.json', validation))
        finally:
            os.chdir(cwd)
            sys.modules.pop('t007_actual_native', None)
    for row in inputs:
        path = Path(row['path'])
        if not path.is_absolute():
            path = ROOT / path
        assert sha(path.read_bytes()) == row['sha256']
    result = {'status': 'PASS', 'started_at': started,
              'finished_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'controller_sha256': source_pin, 'inputs': inputs, 'outputs': pins,
              'checks': checks, 'sent_messages': calls, 'native_configuration': outputs,
              'model_turn_started': False, 'inference_access_proven': False, 'actual_id': None, 'proof': 'unverified',
              'scope': 'Actual native selected model/effort configuration; task-local fixture adoption only; no T010 adoption',
              'profile': str(VERIFY), 'product_boundary': 'Real product Capture, selector and controls; dedicated driver issues thread/start'}
    save(out, 'result.json', result)
    print('PASS actual selected configuration; no model turn or backend identity claim')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        out = HERE / 'actual-qa1-fix-final'
        if out.is_dir() and not (out / 'result.json').exists():
            reason = getattr(error, 'reason', 'native-operation-failed')
            if not isinstance(reason, str) or re.fullmatch(r'[a-z-]{1,64}', reason) is None:
                reason = 'native-operation-failed'
            save(out, 'failure.json', {'status': 'FAIL', 'error_type': type(error).__name__,
                                     'reason': reason, 'model_turn_started': False,
                                     'note': 'No raw native/account response or credential content persisted'})
        print('FAIL native smoke; sanitized failure record saved, no raw exception emitted', file=sys.stderr)
        raise SystemExit(1)
