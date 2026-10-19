#!/usr/bin/env python3
"""T-004 discovery/observation contracts (TEST-083..088). Stdlib fakes only; never a native call."""
import contextlib
from datetime import datetime, timedelta, timezone
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
import threading
import time
import unittest
from unittest.mock import patch
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'plugins/sdd-implementation/scripts/model-policy.py'
NATIVE = ROOT / 'specs/ci-model-modernization/verification/T-004/native-schema'

HOSTS = {'claude-code', 'codex-cli', 'copilot-cli', 'gemini-cli'}
EFFORTS = ['low', 'medium', 'high', 'xhigh']
SOURCES = {'live-discovery', 'verified-configuration', 'unsupported'}
STATUSES = {'complete', 'incomplete', 'unavailable'}
SCOPE_KINDS = {'account', 'client'}
PURPOSES = {'diagnostic', 'launch'}
REASONS = {'config-invalid', 'config-conflict', 'native-precedence-conflict', 'discovery-unavailable',
           'discovery-incomplete', 'discovery-stale', 'scope-mismatch', 'model-unavailable', 'model-unverified',
           'model-tier-unavailable', 'effort-unavailable', 'budget-unverifiable', 'resume-conflict',
           'actual-id-unavailable', 'actual-id-mismatch', 'input-invalid'}
OBSERVATION_FIELDS = {'schema', 'host', 'cli_version', 'scope_id', 'scope_kind', 'purpose', 'observed_at',
                      'source', 'status', 'models', 'reason', 'observation_sha256'}
MODEL_FIELDS = {'native_id', 'efforts', 'available'}
ALLOWED_METHODS = {'initialize', 'initialized', 'account/read', 'model/list'}
MAX_TEXT = 512
ID_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}')
UTC_RE = re.compile(r'([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?Z')
T0 = datetime(2026, 10, 19, 18, 0, 0, tzinfo=timezone.utc)
CLI_VERSION = 'codex-cli 0.159.2'
NAMESPACE = 't004-namespace'
SECRET = 'sk-fixture-SECRET-7f3a'
EMAIL = 'person@example.invalid'
ACCOUNT_ID = 'acct-fixture-SECRET-91'
CODEX_HOME = '/home/fixture/.codex-private-home'
BAD_IDS = ['', '--flag', '-x', 'a b', 'a;b', 'a|b', 'a&b', '$(x)', 'a`b', 'x' * 129, 'café', '.hidden', 'a\nb']
HANG_LIMIT_SECONDS = 120
REAL_POPEN = subprocess.Popen


def load_helper():
    if not SCRIPT.is_file():
        return None, 'missing ' + SCRIPT.relative_to(ROOT).as_posix()
    try:
        spec = importlib.util.spec_from_file_location('t004_model_policy', SCRIPT)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module  # dataclasses resolve their module through sys.modules
        spec.loader.exec_module(module)
    except Exception as error:  # Red must fail per test, never as a zero-test import error.
        sys.modules.pop('t004_model_policy', None)
        return None, f'{type(error).__name__}: {error}'
    return module, ''


MP, MP_ERROR = load_helper()


def strict_load(data: bytes) -> Any:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('duplicate key ' + key)
            result[key] = value
        return result

    def nonfinite(value):
        raise ValueError('nonfinite ' + value)

    value = json.loads(data.decode('utf-8'), object_pairs_hook=unique, parse_constant=nonfinite)
    canonical(value)  # rejects 1e999 overflow
    return value


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode('utf-8')


def digest(record) -> str:
    return hashlib.sha256(canonical({k: v for k, v in record.items() if k != 'observation_sha256'})).hexdigest()


def seal(record):
    return {**record, 'observation_sha256': digest(record)}


def encode(value) -> bytes:
    return json.dumps(value).encode('utf-8')


def utc(moment: datetime) -> str:
    return moment.strftime('%Y-%m-%dT%H:%M:%SZ')


def parse_utc(value: str) -> datetime:
    match = UTC_RE.fullmatch(value)
    assert match, value
    fraction = (match[2] or '.0')[1:]
    moment = datetime.strptime(match[1], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
    return moment + timedelta(microseconds=int((fraction + '000000')[:6]))


def record(**changes):
    base = {'schema': 'model-observation/v1', 'host': 'codex-cli', 'cli_version': CLI_VERSION,
            'scope_id': 'client-0123abcd', 'scope_kind': 'client', 'purpose': 'diagnostic', 'observed_at': utc(T0),
            'source': 'live-discovery', 'status': 'complete', 'reason': 'All documented model/list pages were read.',
            'models': [{'native_id': 'gpt-5.5-codex', 'efforts': ['low', 'medium', 'high', 'xhigh'], 'available': True},
                       {'native_id': 'gpt-5.5-mini', 'efforts': [], 'available': True}]}
    base.update(changes)
    return seal(base)


def configuration(**changes):
    return record(host='claude-code', cli_version='2.1.3 (Claude Code)', source='verified-configuration',
                  reason='Verified from documented Claude Code model configuration settings.', **changes)


# Native fixtures follow the pinned generated v1/v2 schemas (checked in NativeFixtureSchemaTests).
INIT_RESULT = {'codexHome': CODEX_HOME, 'platformFamily': 'unix', 'platformOs': 'linux',
               'userAgent': 'codex_cli_rs/0.159.2'}
ACCOUNT_NONE = {'requiresOpenaiAuth': True, 'account': None, 'workspaceRouting': None}
ACCOUNT_OMITTED = {'requiresOpenaiAuth': False}
ACCOUNT_API_KEY = {'requiresOpenaiAuth': True, 'account': {'type': 'apiKey'}}
ACCOUNT_BEDROCK = {'requiresOpenaiAuth': False, 'account': {'type': 'amazonBedrock'}}
ACCOUNT_CHATGPT: dict[str, Any] = {
    'requiresOpenaiAuth': True, 'account': {'type': 'chatgpt', 'email': EMAIL, 'planType': 'team'},
    'workspaceRouting': {'accountRoutingOverride': 'NO_CONSTRAINT', 'backendOrigin': 'https://backend.example.invalid',
                         'chatgptAccountId': ACCOUNT_ID}}
OMIT = object()


def native_model(model_id, model=None, efforts=('low', 'medium', 'high'), hidden=False, **changes):
    value = {'id': model_id, 'model': model_id if model is None else model, 'displayName': model_id,
             'description': 'Fixture model.', 'hidden': hidden, 'isDefault': False,
             'defaultReasoningEffort': efforts[0] if efforts else 'medium',
             'supportedReasoningEfforts': [{'reasoningEffort': e, 'description': e + ' effort'} for e in efforts]}
    value.update(changes)
    return value


def page(models, cursor=OMIT):
    result = {'data': list(models)} if cursor is OMIT else {'data': list(models), 'nextCursor': cursor}
    return {'result': result}


# Real child process speaking JSONL JSON-RPC (no jsonrpc header). Script items: {'result'}, {'result',
# 'wrong_id'}, {'error'}, {'raw'} (latin-1 text, %ID% = request id), {'eof'}, {'hang'}.
FAKE_SERVER = r'''
import json, sys, time
scenario_path, log_path, account_path = sys.argv[1:4]
scenario = json.load(open(scenario_path, encoding='utf-8'))
log = open(log_path, 'a', encoding='utf-8')
calls = 0
def write(data):
    sys.stdout.buffer.write(data + b'\n')
    sys.stdout.buffer.flush()
for raw in sys.stdin.buffer:
    try:
        message = json.loads(raw)
    except ValueError:
        message = {'invalid': raw.decode('utf-8', 'replace')}
    log.write(json.dumps(message) + '\n')
    log.flush()
    if not isinstance(message, dict) or 'id' not in message:
        continue
    method, rid = message.get('method'), message['id']
    if method == 'initialize':
        item = scenario['init']
    elif method == 'account/read':
        item = json.load(open(account_path, encoding='utf-8'))
    elif method == 'model/list':
        for note in scenario['before'].get(str(calls), []):
            write(note.encode('latin-1'))
        pages = scenario['pages']
        item = pages[calls] if calls < len(pages) else {'error': 'fixture has no page'}
        calls += 1
        if scenario.get('account_after_list') is not None:
            json.dump(scenario['account_after_list'], open(account_path, 'w', encoding='utf-8'))
    else:
        item = {'error': 'method not found'}
    if 'hang' in item:
        time.sleep(3600)
    if 'eof' in item:
        sys.exit(0)
    if 'raw' in item:
        write(item['raw'].replace('%ID%', json.dumps(rid)).encode('latin-1'))
    elif 'error' in item:
        write(json.dumps({'id': rid, 'error': {'code': -32603, 'message': item['error']}}).encode())
    else:
        write(json.dumps({'id': 'not-' + str(rid) if item.get('wrong_id') else rid, 'result': item['result']}).encode())
'''


class NativeFake:
    """Reroutes the product's own codex argv to stdlib fixture children; product keeps its real transport."""

    def __init__(self, case, pages, account: Any = ACCOUNT_NONE, init: Any = None, before=None,
                 version=CLI_VERSION, account_after_list=None):
        temp = tempfile.mkdtemp(prefix='t004-native-')
        case.addCleanup(shutil.rmtree, temp, True)
        self.dir = Path(temp)
        self.scenario, self.log, self.account = self.dir / 'scenario.json', self.dir / 'log.jsonl', self.dir / 'acct.json'
        self.scenario.write_text(json.dumps({'pages': pages, 'init': {'result': INIT_RESULT} if init is None else init,
                                             'before': before or {}, 'account_after_list': account_after_list}),
                                 encoding='utf-8')
        self.log.write_text('', encoding='utf-8')
        self.set_account(account)
        self.version = version
        self.argvs: list[tuple[list[str], Any]] = []
        self.servers: list[Any] = []
        self.case = case

    def set_account(self, account):
        self.account.write_text(json.dumps(account if isinstance(account, dict) and 'error' in account
                                           else {'result': account}), encoding='utf-8')

    def popen(self, args, *rest, **options):
        argv = [os.fsdecode(a) for a in ([args] if isinstance(args, (str, bytes, os.PathLike)) else args)]
        self.argvs.append((argv, options.get('shell', False)))
        options.pop('shell', None)
        options.pop('executable', None)
        if 'app-server' in argv:
            command = [sys.executable, '-I', '-c', FAKE_SERVER, str(self.scenario), str(self.log), str(self.account)]
        elif '--version' in argv:
            command = [sys.executable, '-I', '-c', 'print(' + repr(self.version) + ')']
        else:
            command = [sys.executable, '-I', '-c', 'import sys; sys.exit(3)']
        process = REAL_POPEN(command, *rest, **options)
        if 'app-server' in argv:
            self.servers.append(process)
            self.case.addCleanup(self.reap, process)
        return process

    @staticmethod
    def reap(process):
        if process.poll() is None:
            process.kill()
        process.wait(timeout=30)

    def start(self):
        for patcher in (patch.object(subprocess, 'Popen', self.popen),
                        patch('shutil.which', lambda name, *a, **k: sys.executable if 'codex' in str(name) else None)):
            patcher.start()
            self.case.addCleanup(patcher.stop)
        return self

    def sent(self):
        return [json.loads(line) for line in self.log.read_text(encoding='utf-8').splitlines()]

    def methods(self):
        return [m.get('method') for m in self.sent() if isinstance(m, dict)]

    def params(self, method):
        return [m.get('params') for m in self.sent() if isinstance(m, dict) and m.get('method') == method]

    def list_calls(self):
        return self.methods().count('model/list')


class HelperCase(unittest.TestCase):
    def mp(self) -> Any:
        if MP is None:
            self.fail('model-policy helper unavailable: ' + MP_ERROR)
        return MP

    def assertReason(self, reason, func, *args, **kwargs):
        with self.assertRaises(self.mp().PolicyError) as caught:
            func(*args, **kwargs)
        if reason is None:
            self.assertIn(caught.exception.reason, REASONS)
        else:
            self.assertEqual(caught.exception.reason, reason)
        return caught.exception

    def native(self, pages, **options):
        return NativeFake(self, pages, **options).start()

    def open_client(self, fake, namespace=NAMESPACE):
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        return stack.enter_context(self.mp().CodexClient(namespace))

    def capture(self, fake, purpose='diagnostic', client=None):
        client = client or self.open_client(fake)
        result = client.capture(purpose=purpose)
        self.assertEqual([m for m in fake.sent() if 'invalid' in m], [])
        self.mp().validate_observation_record(result.observation)
        return client, result

    def failed_capture(self, fake, reason):
        client = self.open_client(fake)
        error = self.assertReason(reason, client.capture)
        self.assertNotIn('observation', error.as_dict())
        self.assertIsInstance(error.observation, dict)
        self.mp().validate_observation_record(error.observation)
        return client, error.observation

    def live(self, value, result, purpose='diagnostic', **options):
        return self.mp().validate_observation(value, capture=result, purpose=purpose, **options)

    def assertNoLeak(self, *values, markers=(SECRET, EMAIL, ACCOUNT_ID, CODEX_HOME, 'backend.example.invalid')):
        text = json.dumps(values, ensure_ascii=False, default=repr)
        for marker in markers:
            self.assertNotIn(marker, text)


def resolve(node, schema):
    while '$ref' in node:
        target: Any = schema
        for part in node['$ref'].removeprefix('#/').split('/'):
            target = target[part]
        node = target
    return node


class SchemaContractTests(HelperCase):
    def load(self, name):
        path = ROOT / 'contracts' / name
        self.assertTrue(path.is_file(), 'missing published contract ' + name)
        return strict_load(path.read_bytes())

    def assertClosed(self, node, fields):
        self.assertEqual(node.get('type'), 'object')
        self.assertIs(node.get('additionalProperties'), False)
        self.assertEqual(set(node.get('required', [])), fields)
        self.assertEqual(set(node.get('properties', {})), fields)

    def assertPattern(self, node, good, bad):
        pattern = re.compile(node['pattern'])
        for value in good:
            self.assertTrue(pattern.search(value) and len(value) <= node.get('maxLength', len(value)), value)
        for value in bad:
            self.assertFalse(pattern.search(value) and len(value) <= node.get('maxLength', len(value))
                             and len(value) >= node.get('minLength', 0), value)

    def test_observation_schema_fields_enums_and_bounds_match_contract(self):
        schema = self.load('model-observation.schema.json')
        self.assertClosed(schema, OBSERVATION_FIELDS)
        props = {k: resolve(v, schema) for k, v in schema['properties'].items()}
        self.assertEqual(props['schema'].get('const'), 'model-observation/v1')
        for field, values in (('host', HOSTS), ('source', SOURCES), ('status', STATUSES),
                              ('scope_kind', SCOPE_KINDS), ('purpose', PURPOSES)):
            self.assertEqual(set(props[field]['enum']), values, field)
        self.assertEqual((props['scope_id']['minLength'], props['scope_id']['maxLength']), (1, 128))
        self.assertPattern(props['scope_id'], ['client-0123abcd', 'a', 'A9._:/-z'], BAD_IDS)
        self.assertEqual((props['cli_version']['minLength'], props['cli_version']['maxLength']), (1, 128))
        self.assertEqual((props['reason']['minLength'], props['reason']['maxLength']), (1, MAX_TEXT))
        self.assertPattern(props['observed_at'], [utc(T0), '2026-10-19T18:00:00.5Z', '2026-10-19T18:00:00.123456Z'],
                           ['2026-10-19T18:00:00+00:00', '2026-10-19 18:00:00Z', '2026-10-19T18:00:00z',
                            '2026-10-19T18:00:00.Z', ''])
        self.assertPattern(props['observation_sha256'], ['0' * 64, 'a' * 64], ['A' * 64, '0' * 63, '0' * 65, 'g' * 64])
        self.assertEqual(props['models']['type'], 'array')
        model = resolve(props['models']['items'], schema)
        self.assertClosed(model, MODEL_FIELDS)
        mprops = {k: resolve(v, schema) for k, v in model['properties'].items()}
        self.assertEqual((mprops['native_id']['minLength'], mprops['native_id']['maxLength']), (1, 128))
        self.assertPattern(mprops['native_id'], ['gpt-5.5-codex', 'o4.1:research/preview'], BAD_IDS)
        self.assertEqual(mprops['efforts']['type'], 'array')
        self.assertIs(mprops['efforts']['uniqueItems'], True)
        self.assertEqual(set(resolve(mprops['efforts']['items'], schema)['enum']), set(EFFORTS))
        self.assertEqual(mprops['available']['type'], 'boolean')

    def test_error_schema_fields_and_closed_reason_vocabulary(self):
        schema = self.load('model-policy-error.schema.json')
        self.assertClosed(schema, {'schema', 'reason', 'message'})
        props = {k: resolve(v, schema) for k, v in schema['properties'].items()}
        self.assertEqual(props['schema'].get('const'), 'model-policy-error/v1')
        self.assertEqual(set(props['reason']['enum']), REASONS)
        self.assertEqual(len(props['reason']['enum']), 16)
        self.assertEqual((props['message']['type'], props['message']['minLength'], props['message']['maxLength']),
                         ('string', 1, MAX_TEXT))

    def test_producer_record_shape_matches_published_schema(self):
        schema = self.load('model-observation.schema.json')
        fake = self.native([page([native_model('gpt-5.5-codex', efforts=('low', 'xhigh', 'max'))])])
        _, result = self.capture(fake)
        observation = result.observation
        self.assertEqual(set(observation), set(schema['properties']))
        model = resolve(schema['properties']['models']['items'], schema)
        for item in observation['models']:
            self.assertEqual(set(item), set(model['properties']))
        for field in ('host', 'source', 'status', 'scope_kind', 'purpose'):
            self.assertIn(observation[field], resolve(schema['properties'][field], schema)['enum'])
        for field in ('observed_at', 'observation_sha256', 'scope_id'):
            self.assertTrue(re.search(resolve(schema['properties'][field], schema)['pattern'], observation[field]))


class ErrorContractTests(HelperCase):
    def test_every_initial_reason_round_trips_through_envelope_and_consumer(self):
        mp = self.mp()
        self.assertTrue(issubclass(mp.PolicyError, ValueError))
        for reason in sorted(REASONS):
            with self.subTest(reason=reason):
                error = mp.PolicyError(reason, 'Rerun discovery for codex-cli.')
                self.assertEqual((error.reason, error.message), (reason, 'Rerun discovery for codex-cli.'))
                envelope = error.as_dict()
                self.assertEqual(envelope, {'schema': 'model-policy-error/v1', 'reason': reason,
                                            'message': 'Rerun discovery for codex-cli.'})
                mp.validate_error_record(mp.strict_json(canonical(envelope)))
        carried = mp.PolicyError('discovery-incomplete', 'Retry discovery.', observation=record(status='incomplete'))
        self.assertEqual(set(carried.as_dict()), {'schema', 'reason', 'message'})
        self.assertEqual(carried.observation['status'], 'incomplete')

    def test_unknown_reason_and_invalid_message_are_rejected(self):
        mp = self.mp()
        for reason in ('Input-Invalid', 'input_invalid', 'unknown', '', None, 'discovery-unavailable '):
            with self.subTest(reason=reason), self.assertRaises(ValueError):
                mp.PolicyError(reason, 'message')
        for message in ('', '   ', None, 5, 'x' * (MAX_TEXT + 1)):
            with self.subTest(message=message), self.assertRaises(ValueError):
                mp.PolicyError('input-invalid', message)

    def test_error_consumer_rejects_wrong_missing_extra_and_malformed_fields(self):
        mp = self.mp()
        good = {'schema': 'model-policy-error/v1', 'reason': 'input-invalid', 'message': 'Fix the argument.'}
        bad = [encode({**good, 'schema': 'model-policy-error/v2'}), encode({**good, 'schema': 'Model-Policy-Error/v1'}),
               encode({k: v for k, v in good.items() if k != 'message'}), encode({**good, 'detail': 'raw'}),
               encode({**good, 'reason': 'Input-Invalid'}), encode({**good, 'message': ''}),
               encode({**good, 'message': 7}), encode({**good, 'message': 'x' * (MAX_TEXT + 1)}), encode([good]),
               b'null', b'{"schema":"model-policy-error/v1","reason":"input-invalid","reason":"scope-mismatch",'
               b'"message":"m"}', b'\xff', b'{']
        for data in bad:
            with self.subTest(data=data[:60]), self.assertRaises(ValueError):
                mp.validate_error_record(mp.strict_json(data))


class ObservationRecordTests(HelperCase):
    """Record syntax/consistency only; never native provenance."""

    def test_valid_records_and_codec_match_independent_canonical_digest(self):
        mp = self.mp()
        value = record()
        self.assertEqual(mp.canonical(value), canonical(value))
        self.assertEqual(mp.observation_digest(value), digest(value))
        self.assertEqual(mp.strict_json(encode(value)), value)
        self.assertEqual(mp.strict_json(encode(value).decode()), value)
        for valid in (value, record(models=[]), record(status='incomplete'),
                      record(source='unsupported', status='unavailable', models=[]), configuration(),
                      record(scope_kind='account', purpose='launch')):
            with self.subTest(valid=valid['source'] + '/' + valid['status']):
                self.assertIsNone(mp.validate_observation_record(valid))

    def test_fractional_utc_z_is_valid(self):
        for stamp in ('2026-10-19T18:00:00.5Z', '2026-10-19T18:00:00.123456Z'):
            with self.subTest(stamp=stamp):
                self.mp().validate_observation_record(record(observed_at=stamp))
                self.mp().validate_configuration(configuration(observed_at=stamp), now=T0 + timedelta(seconds=300))

    def test_every_field_mutation_without_rehash_fails_digest(self):
        validate = self.mp().validate_observation_record
        changes = {'schema': 'model-observation/v2', 'host': 'claude-code', 'cli_version': 'codex-cli 0.159.3',
                   'scope_id': 'client-other', 'scope_kind': 'account', 'purpose': 'launch',
                   'observed_at': '2026-10-19T17:59:59Z', 'source': 'verified-configuration', 'status': 'incomplete',
                   'models': [], 'reason': 'Different reason.'}
        self.assertEqual(set(changes) | {'observation_sha256'}, OBSERVATION_FIELDS)
        for field, value in changes.items():
            with self.subTest(field=field):
                self.assertReason('input-invalid', validate, {**record(), field: value})
        flipped = record()
        flipped['models'][0]['available'] = False
        self.assertReason('input-invalid', validate, flipped)
        for value in ('A' * 64, digest(record())[:63], 'g' * 64, None, 5, digest(record()).upper()):
            with self.subTest(sha=value):
                self.assertReason('input-invalid', validate, {**record(), 'observation_sha256': value})
        self.assertReason('input-invalid', validate, {k: v for k, v in record().items() if k != 'observation_sha256'})

    def test_rehashed_structural_mismatches_are_input_invalid(self):
        validate = self.mp().validate_observation_record
        model = record()['models'][0]
        cases: list[tuple[str, Any]] = [
            ('schema', 'Model-Observation/v1'), ('schema', 'model-observation/v1 '), ('schema', None),
            ('host', 'Codex-CLI'), ('host', 'codex'), ('host', ''), ('host', None),
            ('cli_version', ''), ('cli_version', ' 0.1'), ('cli_version', '0.1 '), ('cli_version', '0.1\n'),
            ('cli_version', '0.1\t'), ('cli_version', 'x' * 129), ('cli_version', 'café 1'), ('cli_version', 5),
            ('scope_kind', 'Client'), ('scope_kind', 'user'), ('purpose', 'Diagnostic'), ('purpose', 'launch-x'),
            ('source', 'Live-Discovery'), ('source', 'live'), ('status', 'Complete'), ('status', 'partial'),
            ('observed_at', '2026-10-19T18:00:00+00:00'), ('observed_at', '2026-10-19 18:00:00Z'),
            ('observed_at', '2026-10-19T18:00:00z'), ('observed_at', '2026-02-30T00:00:00Z'),
            ('observed_at', '2026-10-19T18:00:00.Z'), ('observed_at', 5),
            ('reason', ''), ('reason', '   '), ('reason', 5), ('reason', None), ('reason', 'x' * (MAX_TEXT + 1)),
            ('models', None), ('models', {}), ('models', 'gpt'), ('models', [None]), ('models', [[]]),
            ('models', [model, model]),
            ('models', [{k: v for k, v in model.items() if k != 'available'}]),
            ('models', [{**model, 'display_name': 'raw'}]),
            ('models', [{**model, 'efforts': ['low', 'low']}]), ('models', [{**model, 'efforts': ['High']}]),
            ('models', [{**model, 'efforts': ['max']}]), ('models', [{**model, 'efforts': ['ultra']}]),
            ('models', [{**model, 'efforts': 'low'}]), ('models', [{**model, 'efforts': None}]),
            ('models', [{**model, 'available': 1}]), ('models', [{**model, 'available': 'true'}]),
            ('models', [{**model, 'available': None}]),
        ]
        cases += [('scope_id', bad) for bad in BAD_IDS] + [('models', [{**model, 'native_id': bad}]) for bad in BAD_IDS]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                self.assertReason('input-invalid', validate, record(**{field: value}))
        self.assertReason('input-invalid', validate, seal({**record(), 'provider': 'openai'}))
        for field in OBSERVATION_FIELDS - {'observation_sha256'}:
            with self.subTest(missing=field):
                self.assertReason('input-invalid', validate,
                                  seal({k: v for k, v in record().items() if k not in (field, 'observation_sha256')}))
        for value in (None, [], 'record', encode(record())):
            with self.subTest(top=type(value).__name__), self.assertRaises(ValueError):
                validate(value)

    def test_valid_digest_with_incoherent_source_status_is_rejected(self):
        for changes in ({'source': 'unsupported', 'status': 'complete'},
                        {'source': 'unsupported', 'status': 'unavailable'},
                        {'status': 'unavailable'}):
            with self.subTest(changes=changes):
                self.assertReason('input-invalid', self.mp().validate_observation_record, record(**changes))

    def test_strict_json_rejects_duplicates_nonfinite_utf8_and_non_objects(self):
        good = encode(record())
        bad = [good.replace(b'"host": "codex-cli"', b'"host": "codex-cli", "host": "codex-cli"'),
               good.replace(b'"available": true', b'"available": true, "available": true', 1),
               good.replace(b'"available": true', b'"available": NaN', 1),
               good.replace(b'"available": true', b'"available": Infinity', 1),
               good.replace(b'"available": true', b'"available": -Infinity', 1),
               good.replace(b'"available": true', b'"available": 1e999', 1),
               good.replace(b'"codex-cli"', b'"codex-cli\xff"', 1), b'\xef\xbb\xbf' + good,
               good[:-1], b'', b'null', b'[]', b'"model-observation/v1"']
        self.assertNotIn(good, bad)
        for data in bad:
            with self.subTest(data=data[:60]), self.assertRaises(ValueError):
                self.mp().strict_json(data)

    def test_configuration_is_distinct_and_cannot_become_live_proof(self):
        mp = self.mp()
        mp.validate_configuration(configuration(), now=T0)
        for value in (record(), seal({**configuration(), 'source': 'live-discovery'}),
                      record(source='unsupported', status='unavailable', models=[])):
            with self.subTest(source=value['source']):
                self.assertReason(None, mp.validate_configuration, value, now=T0)
        fake = self.native([page([native_model('gpt-a')])])
        _, result = self.capture(fake)
        relabelled = seal({**configuration(), 'host': 'codex-cli', 'cli_version': result.observation['cli_version'],
                           'scope_id': result.observation['scope_id'], 'observed_at': result.observation['observed_at']})
        for value in (configuration(), relabelled, seal({**relabelled, 'source': 'live-discovery'})):
            with self.subTest(value=value['source']):
                self.assertReason(None, self.live, value, result)

    def test_TEST087_stale_or_future_configuration_cannot_establish_fresh_availability(self):
        check = self.mp().validate_configuration
        check(configuration(), now=T0 + timedelta(seconds=300))
        self.assertReason('discovery-stale', check, configuration(), now=T0 + timedelta(seconds=301))
        self.assertReason('discovery-stale', check, configuration(), now=T0 + timedelta(seconds=11), max_age_seconds=10)
        self.assertReason('discovery-stale', check, configuration(), now=T0 - timedelta(seconds=1))
        for max_age in (0, -1, True, 1.5, '300', None):
            with self.subTest(max_age=max_age), self.assertRaises(ValueError):
                check(configuration(), now=T0, max_age_seconds=max_age)
        with self.assertRaises(ValueError):
            check(configuration(), now=T0.replace(tzinfo=None))


class CodexDiscoveryTests(HelperCase):
    CURSOR = 'opaque cursor/+=é; $(touch x) --flag'

    def three_pages(self, last=OMIT):
        return [page([native_model('picker-alias', 'gpt-5.5-codex', ('low', 'medium', 'high', 'xhigh', 'max'))],
                     self.CURSOR),
                page([native_model('gpt-5.5-mini', efforts=('minimal', 'High', 'ultra'), hidden=True)], 'c2'),
                page([native_model('o-research', 'o4.1:research/preview', ('xhigh', 'low'))], last)]

    def test_TEST083_all_pages_are_read_before_complete_snapshot(self):
        for last in (OMIT, None):
            with self.subTest(next_cursor='omitted' if last is OMIT else 'null'):
                fake = self.native(self.three_pages(last))
                started = datetime.now(timezone.utc) - timedelta(seconds=1)
                _, result = self.capture(fake)
                observation = result.observation
                self.assertEqual(fake.list_calls(), 3)
                self.assertEqual(observation['models'], [
                    {'native_id': 'gpt-5.5-codex', 'efforts': EFFORTS, 'available': True},
                    {'native_id': 'gpt-5.5-mini', 'efforts': [], 'available': True},
                    {'native_id': 'o4.1:research/preview', 'efforts': ['low', 'xhigh'], 'available': True}])
                self.assertEqual({k: observation[k] for k in ('schema', 'host', 'cli_version', 'scope_kind',
                                                              'purpose', 'source', 'status')},
                                 {'schema': 'model-observation/v1', 'host': 'codex-cli', 'cli_version': CLI_VERSION,
                                  'scope_kind': 'client', 'purpose': 'diagnostic', 'source': 'live-discovery',
                                  'status': 'complete'})
                self.assertTrue(started <= parse_utc(observation['observed_at'])
                                <= datetime.now(timezone.utc) + timedelta(seconds=1))
                self.assertEqual(set(observation), OBSERVATION_FIELDS)
                self.assertEqual(observation['observation_sha256'], digest(observation))
                self.assertTrue(ID_RE.fullmatch(observation['scope_id']))
                self.assertNotEqual(observation['scope_id'], NAMESPACE)
                self.assertTrue(isinstance(observation['reason'], str) and observation['reason'].strip()
                                and len(observation['reason']) <= MAX_TEXT)
                self.assertIsNone(self.live(observation, result))
                self.assertIsNone(self.live(json.loads(json.dumps(observation)), result))

    def test_continuation_requests_include_hidden_and_preserve_opaque_cursor(self):
        fake = self.native(self.three_pages())
        self.capture(fake)
        params = fake.params('model/list')
        self.assertEqual(len(params), 3)
        for value in params:
            self.assertIsInstance(value, dict)
            self.assertIs(value.get('includeHidden'), True)
            self.assertLessEqual(set(value), {'cursor', 'includeHidden', 'limit'})
        self.assertIsNone(params[0].get('cursor'))
        self.assertEqual([params[1].get('cursor'), params[2].get('cursor')], [self.CURSOR, 'c2'])

    def test_TEST088_discovery_uses_only_read_methods_and_never_starts_a_turn(self):
        fake = self.native(self.three_pages() + self.three_pages(), account=ACCOUNT_CHATGPT)
        client, result = self.capture(fake)
        self.live(result.observation, result)
        self.capture(fake, client=client)
        methods = fake.methods()
        self.assertEqual(methods[0], 'initialize')
        self.assertLessEqual(set(methods), ALLOWED_METHODS)
        self.assertFalse(any(isinstance(m, str) and ('login' in m or 'refresh' in m or m.startswith(('thread/', 'turn/')))
                             for m in methods))
        self.assertEqual((methods.count('initialize'), methods.count('initialized')), (1, 1))
        initialized = next(m for m in fake.sent() if m.get('method') == 'initialized')
        self.assertNotIn('id', initialized)
        self.assertLess(methods.index('initialized'), methods.index('model/list'))
        client_info = fake.sent()[0]['params']['clientInfo']
        self.assertTrue(isinstance(client_info['name'], str) and isinstance(client_info['version'], str))
        accounts = fake.params('account/read')
        self.assertTrue(accounts)
        for value in accounts:
            self.assertEqual(value, {'refreshToken': False})
            self.assertIs(value['refreshToken'], False)
        for argv, shell in fake.argvs:
            self.assertFalse(shell)
            self.assertFalse(any(word in ('exec', 'login', 'logout', 'resume') for word in argv), argv)

    def test_effort_intersection_never_promotes_max_or_ultra_and_keeps_empty_models(self):
        fake = self.native([page([native_model('only-max', efforts=('max', 'ultra', 'minimal', 'XHIGH')),
                                  native_model('mixed', efforts=('ultra', 'high', 'low', 'max'))])])
        _, result = self.capture(fake)
        self.assertEqual(result.observation['models'],
                         [{'native_id': 'only-max', 'efforts': [], 'available': True},
                          {'native_id': 'mixed', 'efforts': ['low', 'high'], 'available': True}])
        self.assertEqual(result.observation['status'], 'complete')

    def test_empty_listing_is_complete_without_invented_models(self):
        fake = self.native([page([])])
        _, result = self.capture(fake)
        self.assertEqual((result.observation['status'], result.observation['models'], fake.list_calls()),
                         ('complete', [], 1))
        self.assertIsNone(self.live(result.observation, result))

    def test_unsolicited_notifications_are_ignored(self):
        fake = self.native(self.three_pages(), before={
            '0': [json.dumps({'method': 'fixture/notice', 'params': {'text': SECRET}})],
            '1': [json.dumps({'method': 'fixture/notice'})]})
        _, result = self.capture(fake)
        self.assertEqual((result.observation['status'], len(result.observation['models'])), ('complete', 3))
        self.assertNoLeak(result.observation)

    def test_TEST084_later_page_failures_are_incomplete_not_complete(self):
        first = page([native_model('gpt-a')], 'c1')
        good = native_model('gpt-b')
        duplicate_key = json.dumps({'id': 0, 'result': {'data': [good]}}).replace(
            '"model": "gpt-b"', '"model": "gpt-b", "model": "gpt-c"').replace('"id": 0', '"id": %ID%', 1)
        failures: dict[str, Any] = {
            'rpc-error': {'error': 'denied ' + SECRET + ' ' + EMAIL}, 'eof': {'eof': True},
            'wrong-id': {**page([good]), 'wrong_id': True},
            'no-result': {'raw': '{"id":%ID%}'}, 'malformed-json': {'raw': '{"id":%ID%,"result":'},
            'invalid-utf8': {'raw': '{"id":%ID%,"result":{"data":[],"nextCursor":"\xff"}}'},
            'nan': {'raw': '{"id":%ID%,"result":{"data":[],"nextCursor":NaN}}'},
            'infinity': {'raw': '{"id":%ID%,"result":{"data":[],"limit":Infinity}}'},
            'overflow': {'raw': '{"id":%ID%,"result":{"data":[],"limit":1e999}}'},
            'duplicate-result-key': {'raw': '{"id":%ID%,"result":{"data":[],"data":[]}}'},
            'duplicate-model-key': {'raw': duplicate_key},
            'result-null': {'result': None}, 'missing-data': {'result': {}}, 'data-object': {'result': {'data': {}}},
            'missing-display-name': page([{k: v for k, v in good.items() if k != 'displayName'}]),
            'missing-model': page([{k: v for k, v in good.items() if k != 'model'}]),
            'hidden-string': page([{**good, 'hidden': 'false'}]),
            'efforts-strings': page([{**good, 'supportedReasoningEfforts': ['low']}]),
            'empty-effort': page([native_model('gpt-b', efforts=('',))]),
            'effort-not-string': page([{**good, 'supportedReasoningEfforts': [{'reasoningEffort': 3,
                                                                              'description': 'x'}]}]),
            'duplicate-picker-id': page([native_model('gpt-a', 'gpt-z')]),
            'duplicate-native-model': page([native_model('gpt-z', 'gpt-a')]),
            'duplicate-within-page': page([good, good]),
            'cursor-loop': page([good], 'c1'), 'cursor-empty': page([good], ''), 'cursor-number': page([good], 7),
        }
        failures.update({'native-id ' + repr(bad): page([native_model('picker', bad)]) for bad in BAD_IDS})
        for name, failure in failures.items():
            with self.subTest(failure=name):
                fake = self.native([first, failure, page([native_model('gpt-late')])])
                _, observation = self.failed_capture(fake, 'discovery-incomplete')
                self.assertEqual((observation['status'], observation['source']), ('incomplete', 'live-discovery'))
                self.assertNoLeak(observation)
                self.assertEqual(fake.list_calls(), 2, 'no request after a failed or terminal later page')

    def test_first_page_failures_are_unavailable_and_partial_ones_incomplete(self):
        scripts = {'first-cursor-empty': ([page([native_model('a')], '')], 'discovery-incomplete'),
                   'first-cursor-number': ([page([native_model('a')], 3)], 'discovery-incomplete'),
                   'loop-after-two': ([page([native_model('a')], 'c1'), page([native_model('b')], 'c2'),
                                       page([native_model('c')], 'c1'), page([native_model('d')])],
                                      'discovery-incomplete'),
                   'first-page-error': ([{'error': SECRET}], 'discovery-unavailable'),
                   'first-page-malformed': ([{'raw': '{"id":%ID%,"result":[]}'}], 'discovery-unavailable')}
        for name, (pages, reason) in scripts.items():
            with self.subTest(script=name):
                _, observation = self.failed_capture(self.native(pages), reason)
                self.assertEqual(observation['status'], reason.removeprefix('discovery-'))
                if reason == 'discovery-unavailable':
                    self.assertEqual(observation['models'], [])
                self.assertNoLeak(observation)

    def test_initialize_failure_is_unavailable_and_lists_nothing(self):
        for init in ({'error': SECRET}, {'eof': True}, {'raw': '{"id":%ID%,"result":{"codexHome":1}}'},
                     {'result': {k: v for k, v in INIT_RESULT.items() if k != 'userAgent'}}):
            with self.subTest(init=str(init)[:40]):
                fake = self.native([page([native_model('a')])], init=init)
                _, observation = self.failed_capture(fake, 'discovery-unavailable')
                self.assertEqual((observation['status'], observation['models']), ('unavailable', []))
                self.assertEqual(fake.list_calls(), 0)
                self.assertNoLeak(observation)

    def test_bounded_pages_line_bytes_and_timeout(self):
        chain = [page([native_model(f'm{i}')], f'c{i}') for i in range(1001)] + [page([])]
        fake = self.native(chain)
        self.failed_capture(fake, 'discovery-incomplete')
        self.assertLessEqual(fake.list_calls(), 1000)
        big = self.native([page([native_model('a')], 'c1'),
                           page([native_model('big', description='x' * (9 * 1024 * 1024))])])
        self.failed_capture(big, 'discovery-incomplete')
        hung = self.native([page([native_model('a')], 'c1'), {'hang': True}])
        started = time.monotonic()
        client, _ = self.failed_capture(hung, 'discovery-incomplete')
        self.assertLess(time.monotonic() - started, HANG_LIMIT_SECONDS)
        client.close()
        for process in hung.servers:
            process.wait(timeout=30)

    def test_close_terminates_owned_child_is_idempotent_and_blocks_reuse(self):
        fake = self.native([page([native_model('a')])] * 2)
        client, result = self.capture(fake)
        self.assertTrue(fake.servers and all(p.poll() is None for p in fake.servers))
        client.close()
        client.close()
        for process in fake.servers:
            process.wait(timeout=30)
        with self.assertRaises(ValueError):
            client.capture()
        self.assertReason(None, self.live, result.observation, result)

    def test_native_prose_paths_and_shell_shaped_metadata_are_not_persisted_or_executed(self):
        with tempfile.TemporaryDirectory() as temp:
            marker = Path(temp) / 'executed'
            shell = f'$(touch {marker}) `touch {marker}`; touch {marker}'
            fake = self.native([page([native_model('gpt-a', description=shell, displayName=shell,
                                                   upgrade=shell, availabilityNux={'message': SECRET})])])
            _, result = self.capture(fake)
            self.assertFalse(marker.exists())
            self.assertNotIn('touch', json.dumps(result.observation))
            self.assertNoLeak(result.observation)

    def test_constructor_and_capture_reject_invalid_namespace_purpose_and_overrides(self):
        mp = self.mp()
        fake = self.native([page([])])
        for namespace in BAD_IDS + [EMAIL, None]:
            with self.subTest(namespace=namespace), self.assertRaises(ValueError):
                with mp.CodexClient(namespace):
                    pass
        self.assertEqual(fake.argvs, [])
        for override in ({'cli_version': 'x'}, {'purpose': 'launch'}, {'transport': object()}, {'provider': 'x'}):
            with self.subTest(override=override), self.assertRaises(TypeError):
                mp.CodexClient(NAMESPACE, **override)
        client = self.open_client(fake)
        for purpose in ('Launch', 'launch-x', '', None):
            with self.subTest(purpose=purpose), self.assertRaises(ValueError):
                client.capture(purpose=purpose)


class ScopeContextTests(HelperCase):
    PAGES = [page([native_model('gpt-a')])] * 3

    def test_TEST085_new_client_with_same_namespace_gets_non_reusable_scope(self):
        for account in (ACCOUNT_NONE, ACCOUNT_CHATGPT):
            with self.subTest(account=account.get('account')):
                _, a = self.capture(self.native(self.PAGES, account=account))
                _, b = self.capture(self.native(self.PAGES, account=account))
                self.assertNotEqual(a.observation['scope_id'], b.observation['scope_id'])
                self.assertReason(None, self.live, a.observation, b)
                self.assertReason(None, self.live, seal({**a.observation, 'scope_id': b.observation['scope_id']}), b)
                self.assertIsNone(self.live(a.observation, a))

    def test_TEST085_changed_cli_version_does_not_reuse_snapshot(self):
        _, old = self.capture(self.native(self.PAGES))
        _, new = self.capture(self.native(self.PAGES, version='codex-cli 0.160.0'))
        self.assertEqual((old.observation['cli_version'], new.observation['cli_version']),
                         (CLI_VERSION, 'codex-cli 0.160.0'))
        self.assertReason(None, self.live, old.observation, new)
        self.assertReason(None, self.live, seal({**old.observation, 'cli_version': 'codex-cli 0.160.0'}), new)

    def test_TEST085_same_client_account_or_provider_change_invalidates_context(self):
        changes = {'none-to-api-key': (ACCOUNT_NONE, ACCOUNT_API_KEY),
                   'api-key-to-bedrock': (ACCOUNT_API_KEY, ACCOUNT_BEDROCK),
                   'chatgpt-account-id': (ACCOUNT_CHATGPT, {**ACCOUNT_CHATGPT, 'workspaceRouting': {
                       **ACCOUNT_CHATGPT['workspaceRouting'], 'chatgptAccountId': 'acct-other'}}),
                   'backend-origin': (ACCOUNT_CHATGPT, {**ACCOUNT_CHATGPT, 'workspaceRouting': {
                       **ACCOUNT_CHATGPT['workspaceRouting'], 'backendOrigin': 'https://other.example.invalid'}}),
                   'email': (ACCOUNT_CHATGPT, {**ACCOUNT_CHATGPT, 'account': {
                       **ACCOUNT_CHATGPT['account'], 'email': 'other@example.invalid'}}),
                   'routing-removed': (ACCOUNT_CHATGPT, {**ACCOUNT_CHATGPT, 'workspaceRouting': None})}
        for name, (before, after) in changes.items():
            with self.subTest(change=name):
                fake = self.native(self.PAGES, account=before)
                client, old = self.capture(fake)
                self.assertIsNone(self.live(old.observation, old))
                fake.set_account(after)
                self.assertReason(None, self.live, old.observation, old)
                _, new = self.capture(fake, client=client)
                self.assertEqual(fake.methods().count('initialize'), 1)
                self.assertNotEqual(new.observation['scope_id'], old.observation['scope_id'])
                self.assertIsNone(self.live(new.observation, new))
                self.assertNoLeak(old.observation, new.observation,
                                  markers=(EMAIL, ACCOUNT_ID, 'other@example.invalid', 'acct-other'))

    def test_context_change_during_capture_prevents_complete_success(self):
        fake = self.native(self.PAGES, account=ACCOUNT_API_KEY, account_after_list=ACCOUNT_BEDROCK)
        client = self.open_client(fake)
        error = self.assertReason(None, client.capture)
        if error.observation is not None:
            self.assertNotEqual(error.observation['status'], 'complete')

    def test_same_client_unchanged_context_keeps_scope_and_honest_client_kind(self):
        for account in (ACCOUNT_NONE, ACCOUNT_OMITTED, ACCOUNT_API_KEY, ACCOUNT_BEDROCK, {'error': SECRET}):
            with self.subTest(account=str(account)[:50]):
                fake = self.native(self.PAGES, account=account)
                client, first = self.capture(fake)
                _, second = self.capture(fake, client=client)
                self.assertEqual(first.observation['scope_id'], second.observation['scope_id'])
                self.assertEqual((first.observation['scope_kind'], first.observation['status']), ('client', 'complete'))
                self.assertIsNone(self.live(second.observation, second))
                self.assertNoLeak(first.observation)

    def test_full_account_metadata_is_bound_without_persisting_raw_identity(self):
        _, result = self.capture(self.native(self.PAGES, account=ACCOUNT_CHATGPT))
        self.assertNoLeak(result.observation, repr(result))
        self.assertTrue(ID_RE.fullmatch(result.observation['scope_id']))

    def test_diagnostic_record_relabelled_and_rehashed_is_not_a_launch_observation(self):
        _, diagnostic = self.capture(self.native(self.PAGES))
        _, launch = self.capture(self.native(self.PAGES), purpose='launch')
        self.assertEqual(launch.observation['purpose'], 'launch')
        self.assertIsNone(self.live(launch.observation, launch, purpose='launch'))
        relabelled = seal({**diagnostic.observation, 'purpose': 'launch'})
        for value, result in ((relabelled, diagnostic), (relabelled, launch), (diagnostic.observation, launch),
                              (seal({**relabelled, 'scope_id': launch.observation['scope_id']}), launch)):
            with self.subTest(origin=value['scope_id'] == launch.observation['scope_id']):
                self.assertReason(None, self.live, value, result, purpose='launch')
        self.assertReason(None, self.live, diagnostic.observation, diagnostic, purpose='launch')
        self.assertReason(None, self.live, launch.observation, launch, purpose='diagnostic')

    def test_rehashed_modification_of_genuine_capture_is_rejected(self):
        _, result = self.capture(self.native([page([native_model('gpt-a'), native_model('gpt-b')])]))
        observation = result.observation
        for value in (seal({**observation, 'models': observation['models'][:1]}),
                      seal({**observation, 'reason': 'Rehashed copy.'}),
                      seal({**observation, 'scope_kind': 'account'}),
                      seal({**observation, 'source': 'verified-configuration'})):
            with self.subTest(value=value['observation_sha256'][:8]):
                self.assertReason(None, self.live, value, result)

    def test_TEST087_live_freshness_boundary_future_and_age_limits(self):
        _, result = self.capture(self.native(self.PAGES))
        observed = parse_utc(result.observation['observed_at'])
        self.assertIsNone(self.live(result.observation, result, now=observed + timedelta(seconds=300)))
        self.assertIsNone(self.live(result.observation, result, now=observed + timedelta(seconds=9),
                                    max_age_seconds=10))
        self.assertReason('discovery-stale', self.live, result.observation, result,
                          now=observed + timedelta(seconds=301))
        self.assertReason('discovery-stale', self.live, result.observation, result, now=observed - timedelta(seconds=1))
        for max_age in (0, -1, True, 1.5, '300', None):
            with self.subTest(max_age=max_age), self.assertRaises(ValueError):
                self.live(result.observation, result, max_age_seconds=max_age)
        with self.assertRaises(ValueError):
            self.live(result.observation, result, now=observed.replace(tzinfo=None))
        with self.assertRaises(ValueError):
            self.live(result.observation, result, purpose='Diagnostic')


class DiscoverCliTests(HelperCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name) / 'work'
        self.work.mkdir()

    def run_cli(self, *args, env=None):
        return subprocess.run([sys.executable, '-B', str(SCRIPT), *args], cwd=self.work, env=env,
                              capture_output=True, timeout=120)

    def assertError(self, result, reason):
        self.assertEqual(result.returncode, 2, result.stderr)
        stderr = result.stderr.decode('utf-8', 'replace')
        self.assertNotIn('Traceback', stderr)
        try:
            error = strict_load(result.stderr.strip())
        except ValueError as exc:
            self.fail(f'stderr is not one model-policy-error/v1 object ({exc}): {stderr[:300]}')
        self.assertIsInstance(error, dict)
        self.assertEqual(set(error), {'schema', 'reason', 'message'})
        self.assertEqual((error['schema'], error['reason']), ('model-policy-error/v1', reason))
        self.assertTrue(isinstance(error['message'], str) and error['message'].strip()
                        and len(error['message']) <= MAX_TEXT)
        return error

    def read_unavailable(self, name, host, source):
        observation = strict_load((self.work / name).read_bytes())
        self.assertEqual(set(observation), OBSERVATION_FIELDS)
        self.assertEqual({k: observation[k] for k in ('schema', 'host', 'scope_kind', 'purpose', 'source',
                                                      'status', 'models')},
                         {'schema': 'model-observation/v1', 'host': host, 'scope_kind': 'client',
                          'purpose': 'diagnostic', 'source': source, 'status': 'unavailable', 'models': []})
        self.assertEqual(observation['observation_sha256'], digest(observation))
        self.assertTrue(ID_RE.fullmatch(observation['scope_id']) and observation['scope_id'] != NAMESPACE)
        self.assertTrue(UTC_RE.fullmatch(observation['observed_at']))
        version = observation['cli_version']
        self.assertTrue(isinstance(version, str) and 0 < len(version) <= 128 and version == version.strip()
                        and all(' ' <= c <= '~' for c in version), version)
        self.mp().validate_observation_record(observation)
        return observation

    def test_TEST086_unsupported_hosts_write_unavailable_observation_and_typed_error(self):
        for host in ('claude-code', 'copilot-cli', 'gemini-cli'):
            with self.subTest(host=host):
                scopes = []
                for name in (host + '-1.json', host + '-2.json'):
                    result = self.run_cli('discover', '--host', host, '--scope-id', NAMESPACE, '--output', name)
                    self.assertError(result, 'discovery-unavailable')
                    scopes.append(self.read_unavailable(name, host, 'unsupported')['scope_id'])
                self.assertNotEqual(scopes[0], scopes[1], 'a new process must not reuse scope for one namespace')

    def test_codex_host_without_installed_cli_is_unavailable_not_complete(self):
        empty = Path(self.temp.name) / 'empty-path'
        empty.mkdir()
        env = {**os.environ, 'PATH': str(empty)}
        result = self.run_cli('discover', '--host', 'codex-cli', '--scope-id', NAMESPACE, '--output', 'obs.json',
                              env=env)
        self.assertError(result, 'discovery-unavailable')
        self.read_unavailable('obs.json', 'codex-cli', 'live-discovery')

    def test_unknown_command_argument_host_and_purpose_override_are_rejected(self):
        base = ['--scope-id', NAMESPACE, '--output', 'obs.json']
        cases = [['discover', '--host', 'codex', *base], ['discover', '--host', 'Codex-CLI', *base],
                 ['discover', '--host', '', *base], ['list', '--host', 'gemini-cli', *base], [],
                 ['discover', '--host', 'gemini-cli', '--scope-id', NAMESPACE],
                 ['discover', '--host', 'gemini-cli', '--output', 'obs.json'],
                 ['discover', '--host', 'gemini-cli', *base, '--purpose', 'launch'],
                 ['discover', '--host', 'gemini-cli', *base, '--purpose=launch'],
                 ['discover', '--host', 'gemini-cli', '--host', 'gemini-cli', *base],
                 ['discover', '--host', 'gemini-cli', *base, '--endpoint', 'https://example.invalid'],
                 ['discover', '--host', 'gemini-cli', *base, 'extra']]
        cases += [['discover', '--host', 'gemini-cli', '--scope-id', bad, '--output', 'obs.json']
                  for bad in ('a b', EMAIL, 'a;b', '', 'x' * 129, '$(x)')]
        for argv in cases:
            with self.subTest(argv=argv):
                self.assertError(self.run_cli(*argv), 'input-invalid')
                self.assertFalse((self.work / 'obs.json').exists())

    def test_unsafe_or_unwritable_output_paths_are_rejected_without_escape(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        (self.work / 'directory').mkdir()
        targets = ['../escape.json', str(outside / 'absolute.json'), 'directory']
        try:
            os.symlink(outside, self.work / 'link', target_is_directory=True)
            targets.append('link/linked.json')
        except OSError:
            self.assertEqual(os.name, 'nt', 'symlink creation is only tolerated to fail on Windows')
        for target in targets:
            with self.subTest(target=target):
                result = self.run_cli('discover', '--host', 'gemini-cli', '--scope-id', NAMESPACE, '--output', target)
                self.assertError(result, 'input-invalid')
        self.assertFalse((Path(self.temp.name) / 'escape.json').exists())
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(list((self.work / 'directory').iterdir()), [])


class SupplementalReviewTests(HelperCase):
    """Concrete local review findings; original 43 methods remain unchanged."""

    def test_fractional_utc_z_has_no_invented_nine_digit_limit(self):
        stamp = '2026-10-19T18:00:00.12345678901234567890Z'
        self.mp().validate_observation_record(record(observed_at=stamp))
        self.mp().validate_configuration(configuration(observed_at=stamp), now=T0 + timedelta(seconds=1))
        schema = strict_load((ROOT / 'contracts/model-observation.schema.json').read_bytes())
        pattern = resolve(schema['properties']['observed_at'], schema)['pattern']
        self.assertIsNotNone(re.search(pattern, stamp))

    def test_future_submicrosecond_timestamp_is_not_rounded_into_present(self):
        for fraction in ('0000001', '0000000001', '00000000000000000001'):
            with self.subTest(fraction=fraction):
                self.assertReason('discovery-stale', self.mp().validate_configuration,
                                  configuration(observed_at='2026-10-19T18:00:00.' + fraction + 'Z'), now=T0)

    def test_native_account_required_closed_enums_reject_unknown_values(self):
        variants = [
            {**ACCOUNT_CHATGPT, 'account': {**ACCOUNT_CHATGPT['account'], 'planType': 'invented-plan'}},
            {**ACCOUNT_CHATGPT, 'workspaceRouting': {
                **ACCOUNT_CHATGPT['workspaceRouting'], 'accountRoutingOverride': 'invented-region'}},
        ]
        for account in variants:
            with self.subTest(account=account):
                fake = self.native([page([native_model('a')])], account=account)
                self.failed_capture(fake, 'discovery-unavailable')
                self.assertEqual(fake.list_calls(), 0)

    def test_no_native_refresh_still_rejects_closed_or_exited_originating_client(self):
        for state in ('closed', 'exited'):
            with self.subTest(state=state):
                fake = self.native([page([native_model('a')])])
                client, result = self.capture(fake)
                self.assertIsNone(self.live(result.observation, result, require_live=False))
                if state == 'closed':
                    client.close()
                else:
                    for process in fake.servers:
                        process.terminate()
                        process.wait(timeout=5)
                self.assertReason(None, self.live, result.observation, result, require_live=False)

    def test_blocked_outbound_write_and_close_have_deadlines_and_reap_owned_child(self):
        mp = self.mp()
        for stage in ('write', 'close'):
            with self.subTest(stage=stage):
                fake = self.native([page([native_model('a')])])
                blocked, released = threading.Event(), threading.Event()
                errors: list[Exception] = []
                original_fake_popen = fake.popen

                class BlockingInput:
                    def __init__(self, stream):
                        self.stream = stream

                    def __getattr__(self, name):
                        return getattr(self.stream, name)

                    def write(self, data):
                        if stage == 'write':
                            blocked.set()
                            released.wait()  # only termination releases the simulated full native pipe
                            raise BrokenPipeError('fixture child terminated')
                        return self.stream.write(data)

                    def close(self):
                        if stage == 'close':
                            blocked.set()
                            released.wait()  # buffered close must not precede child termination
                        return self.stream.close()

                def popen(argv, *positional, **options):
                    process = original_fake_popen(argv, *positional, **options)
                    if 'app-server' in argv:
                        original_terminate = process.terminate

                        def terminate():
                            try:
                                return original_terminate()
                            finally:
                                released.set()

                        process.terminate = terminate
                        process.stdin = BlockingInput(process.stdin)
                    return process

                def work():
                    try:
                        with mp.CodexClient(NAMESPACE) as client:
                            client.capture()
                    except Exception as error:
                        errors.append(error)

                with patch.object(subprocess, 'Popen', popen), \
                     patch.object(mp, 'REQUEST_TIMEOUT_SECONDS', 0.1), \
                     patch.object(mp, 'OPERATION_TIMEOUT_SECONDS', 0.3), \
                     patch.object(mp, 'CLEANUP_WAIT_SECONDS', 0.1):
                    worker = threading.Thread(target=work, daemon=True)
                    worker.start()
                    try:
                        self.assertTrue(blocked.wait(2), 'controlled native stdin never reached blocking point')
                        worker.join(timeout=1.5)
                        finished_without_rescue = not worker.is_alive()
                        reaped_without_rescue = bool(fake.servers) and all(p.poll() is not None for p in fake.servers)
                    finally:
                        for process in fake.servers:
                            if process.poll() is None:
                                process.terminate()  # safety rescue only; never counted as product cleanup
                        released.set()
                        worker.join(timeout=3)
                    self.assertTrue(finished_without_rescue, 'native stdin blocked past the operation deadline')
                    self.assertTrue(reaped_without_rescue, 'owned native child was not reaped before rescue')
                    if stage == 'write':
                        self.assertTrue(errors and isinstance(errors[0], mp.PolicyError), errors)


class NativeFixtureSchemaTests(unittest.TestCase):
    """Fakes must stay inside the pinned generated Codex 0.159.2 schemas; structural, not a schema engine."""
    ACQUISITIONS = {'acquisition.json': '43a5c6cd13e74665d8afd7f2a7a7b84a215b48a0e868be758a292815c2b84326',
                    'account-schema-acquisition.json':
                        'b9aef0b787389a2aeb66be188c4d4a7f4df1f34ff344cfb8d04ff7f3d30ee34b'}

    def schema(self, name):
        return strict_load((NATIVE / name).read_bytes())

    def test_pinned_acquisitions_and_schema_hashes_match(self):
        for name, expected in self.ACQUISITIONS.items():
            # shortcut: CRLF normalization tolerates Windows autocrlf checkouts; drop if .gitattributes pins LF.
            raw = (NATIVE / name).read_bytes().replace(b'\r\n', b'\n')
            self.assertEqual(hashlib.sha256(raw).hexdigest(), expected, name)
            acquisition = strict_load(raw)
            self.assertEqual(acquisition['cli_version'], CLI_VERSION)
            self.assertIs(acquisition['inference_executed'], False)
            for item in acquisition['files']:
                data = (ROOT / item['path']).read_bytes().replace(b'\r\n', b'\n')
                self.assertEqual(hashlib.sha256(data).hexdigest(), item['sha256'], item['path'])

    def test_model_list_fixtures_cover_required_fields_and_terminal_cursor_forms(self):
        schema = self.schema('v2/ModelListResponse.json')
        model = schema['definitions']['Model']
        option = schema['definitions']['ReasoningEffortOption']
        fixture = native_model('gpt-a', 'gpt-b', hidden=True)
        self.assertLessEqual(set(model['required']), set(fixture))
        self.assertLessEqual(set(fixture) | {'upgrade', 'availabilityNux'}, set(model['properties']))
        self.assertLessEqual(set(option['required']), set(fixture['supportedReasoningEfforts'][0]))
        self.assertEqual(schema['required'], ['data'])
        self.assertEqual(set(schema['properties']['nextCursor']['type']), {'string', 'null'})
        effort = schema['definitions']['ReasoningEffort']
        self.assertEqual((effort['type'], effort['minLength']), ('string', 1))
        self.assertNotIn('enum', effort, 'native efforts are arbitrary non-empty strings')
        params = self.schema('v2/ModelListParams.json')['properties']
        self.assertEqual(set(params['cursor']['type']), {'string', 'null'})
        self.assertEqual(set(params['includeHidden']['type']), {'boolean', 'null'})

    def test_initialize_and_account_fixtures_match_generated_shapes(self):
        response = self.schema('v1/InitializeResponse.json')
        self.assertEqual(set(response['required']), set(INIT_RESULT))
        self.assertEqual(self.schema('v1/InitializeParams.json')['definitions']['ClientInfo']['required'],
                         ['name', 'version'])
        self.assertEqual(self.schema('v2/GetAccountParams.json')['properties']['refreshToken']['type'], 'boolean')
        account = self.schema('v2/GetAccountResponse.json')
        self.assertEqual(account['required'], ['requiresOpenaiAuth'])
        routing = account['definitions']['WorkspaceRouting']
        self.assertEqual(set(routing['required']), set(ACCOUNT_CHATGPT['workspaceRouting']))
        variants = {v['properties']['type']['enum'][0]: v for v in account['definitions']['Account']['oneOf']}
        self.assertEqual(set(variants), {'apiKey', 'chatgpt', 'amazonBedrock'})
        for fixture in (ACCOUNT_API_KEY, ACCOUNT_BEDROCK, ACCOUNT_CHATGPT):
            body = fixture['account']
            self.assertLessEqual(set(variants[body['type']]['required']), set(body))
            self.assertLessEqual(set(body), set(variants[body['type']]['properties']))
        self.assertIn(ACCOUNT_CHATGPT['account']['planType'], account['definitions']['PlanType']['enum'])
        self.assertIn(ACCOUNT_CHATGPT['workspaceRouting']['accountRoutingOverride'],
                      account['definitions']['AccountRoutingOverride']['enum'])
        self.assertNotIn('account', ACCOUNT_OMITTED)


if __name__ == '__main__':
    unittest.main()
