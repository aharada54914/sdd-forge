#!/usr/bin/env python3
"""T-005 immutable selection binding and delivery identity (TEST-100/101/102/107/108/131/132/133).

Stdlib fixtures only: never a native CLI, discover call, inference or network access. Digests and expected delivery
records are recomputed independently here, never taken from product output. Full JSON Schema and native DTO
validation runs separately with installed jsonschema in the task-local proof driver.
"""
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'plugins/sdd-implementation/scripts/model-policy.py'
CONTRACTS = ROOT / 'contracts'

SELECTION_SCHEMA = 'model-selection/v1'
DELIVERY_SCHEMA = 'model-delivery/v1'
ERROR_SCHEMA = 'model-policy-error/v1'
HOSTS = ('claude-code', 'codex-cli', 'copilot-cli', 'gemini-cli')
UNSUPPORTED_HOSTS = ('claude-code', 'copilot-cli', 'gemini-cli')
HOST_VERSIONS = {'claude-code': '2.1.3 (Claude Code)', 'codex-cli': 'codex-cli 0.159.2',
                 'copilot-cli': '1.0.4', 'gemini-cli': '0.9.1'}
EFFORTS = ('low', 'medium', 'high', 'xhigh')
RISKS = ('low', 'medium', 'high', 'critical')
POLICIES = ('latest-compatible', 'pinned')
PROVENANCE = ('cli', 'environment', 'project-role', 'project-default', 'shipped')
PROOFS = ('host-reported', 'unverified')
DELIVERY_STATUSES = ('accepted', 'blocked')
DELIVERY_REASONS = ('identity-unverified', 'reroute-observed', 'actual-id-unavailable', 'actual-id-mismatch')
DELIVERY_SOURCES = {'codex-cli': 'codex-app-server', 'claude-code': 'unsupported', 'copilot-cli': 'unsupported',
                    'gemini-cli': 'unsupported'}
REROUTE_REASON = 'highRiskCyberActivity'
REASONS = {'config-invalid', 'config-conflict', 'native-precedence-conflict', 'discovery-unavailable',
           'discovery-incomplete', 'discovery-stale', 'scope-mismatch', 'model-unavailable', 'model-unverified',
           'model-tier-unavailable', 'effort-unavailable', 'budget-unverifiable', 'resume-conflict',
           'actual-id-unavailable', 'actual-id-mismatch', 'input-invalid'}

SELECTION_FIELDS = {'schema', 'role', 'risk', 'host', 'cli_version', 'scope_id', 'requested', 'resolved',
                    'policy_sha256', 'catalog_sha256', 'observation_sha256', 'observed_at', 'source_date', 'reason',
                    'update_candidates', 'binding', 'budget', 'estimate', 'selection_sha256'}
REQUESTED_FIELDS = {'policy', 'model_id', 'policy_source', 'model_source'}
RESOLVED_FIELDS = {'catalog_id', 'native_id', 'effort', 'effort_control'}
BINDING_FIELDS = {'run_id', 'session_id', 'attempt'}
BUDGET_FIELDS = {'amount', 'unit'}
ESTIMATE_FIELDS = {'catalog_id', 'amount', 'unit', 'source_url', 'source_date'}
DELIVERY_FIELDS = {'schema', 'selection_sha256', 'run_id', 'session_id', 'turn_id', 'configured_id', 'actual_id',
                   'proof', 'source', 'reroutes', 'status', 'reason'}
REROUTE_FIELDS = {'thread_id', 'turn_id', 'from_model', 'to_model', 'reason'}
EVENTS_FIELDS = {'host', 'cli_version', 'selection_sha256', 'run_id', 'session_id', 'thread_id', 'turn_id',
                 'thread_read', 'turn_start', 'notifications'}
NESTED_OBJECTS = {'requested': REQUESTED_FIELDS, 'resolved': RESOLVED_FIELDS, 'binding': BINDING_FIELDS,
                  'budget': BUDGET_FIELDS, 'estimate': ESTIMATE_FIELDS}

# Accepted reason labels. Exact where the API note fixes one; a small documented set where it leaves the label open.
INVALID = {'input-invalid'}
BUDGET = {'budget-unverifiable'}
BUDGET_OR_INVALID = {'budget-unverifiable', 'input-invalid'}
CONFLICT = {'resume-conflict'}
REQUESTED_CONFLICT = {'input-invalid', 'config-conflict'}
EVIDENCE_MISMATCH = {'input-invalid', 'scope-mismatch'}
EFFORT_CONFLICT = {'config-conflict', 'native-precedence-conflict'}
CONSUMER_REJECT = {'input-invalid', 'scope-mismatch', 'actual-id-unavailable', 'actual-id-mismatch'}
UNBOUND_ORIGINAL = {'input-invalid', 'resume-conflict'}

MAX_TEXT = 512
MAX_INPUT_BYTES = 16 * 1024 * 1024
ID_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}')
BAD_IDS = ['', '--flag', '-x', 'a b', 'a;b', 'a|b', '$(x)', 'x' * 129, 'café', '.hidden', 'a\nb']

# Fake, clean fixture identities: no account, token or personal data.
RUN = 'run-t005-fixture-0001'
SESSION = 'session-t005-fixture-0001'
OTHER_RUN = 'run-t005-fixture-0002'
OTHER_SESSION = 'session-t005-fixture-0002'
THREAD = '0199f0a0-0000-7000-8000-00000000a001'
OTHER_THREAD = '0199f0a0-0000-7000-8000-00000000a002'
TURN = '0199f0a0-0000-7000-8000-00000000b001'
OTHER_TURN = '0199f0a0-0000-7000-8000-00000000b002'
HOST_THREAD = 'host-thread-fixture-1'
HOST_TURN = 'host-turn-fixture-1'
NATIVE_ID = 'gpt-fixture-5-codex'
ALT_ID = 'gpt-fixture-5-mini'
THIRD_ID = 'gpt-fixture-4-codex'
ALIAS = 'gpt-fixture-latest'
CATALOG_ID = 'openai/gpt-fixture-5-codex'
ALT_CATALOG_ID = 'openai/gpt-fixture-5-mini'
CODEX_VERSION = HOST_VERSIONS['codex-cli']
THREAD_CREATED_VERSION = '0.150.0'
NATIVE_CWD = '/work/t005-fixture-private-cwd'
# Secret-shaped marker assembled at runtime so no contiguous token-like literal appears in the source.
SECRET = '-'.join(('sk', 'fixture', 'SECRET', '7f3a'))
CLAIMED_ID = 'gpt-fixture-claimed-by-text'
SELF_CLAIM = 'As the assistant I am running on ' + CLAIMED_ID + '.'
OMIT = object()


def load_helper():
    if not SCRIPT.is_file():
        return None, 'missing ' + SCRIPT.relative_to(ROOT).as_posix()
    try:
        spec = importlib.util.spec_from_file_location('t005_model_policy', SCRIPT)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
    except Exception as error:  # Red must fail per test, never as a zero-test import error.
        sys.modules.pop('t005_model_policy', None)
        return None, f'{type(error).__name__}: {error}'
    return module, ''


MP, MP_ERROR = load_helper()


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode('utf-8')


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
    canonical(value)
    return value


def sha(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def digest(record) -> str:
    """Independent oracle: canonical record minus selection_sha256 only."""
    return hashlib.sha256(canonical({k: v for k, v in record.items() if k != 'selection_sha256'})).hexdigest()


def seal(record):
    body = {k: copy.deepcopy(v) for k, v in record.items() if k != 'selection_sha256'}
    return {**body, 'selection_sha256': digest(body)}


def put(record, path, value):
    """Deep copy with dotted path set (OMIT deletes); never mutates the argument."""
    result = copy.deepcopy(record)
    *parents, leaf = path.split('.')
    node = result
    for part in parents:
        node = node[part]
    if value is OMIT:
        del node[leaf]
    else:
        node[leaf] = copy.deepcopy(value)
    return result


def changed(record, changes, *, reseal=True):
    result = record
    for path, value in changes.items():
        result = put(result, path, value)
    return seal(result) if reseal else result


def pinned_selection():
    return seal({
        'schema': SELECTION_SCHEMA, 'role': 'implementer', 'risk': 'high', 'host': 'codex-cli',
        'cli_version': CODEX_VERSION, 'scope_id': 'client-t005fixture',
        'requested': {'policy': 'pinned', 'model_id': ALIAS, 'policy_source': 'cli', 'model_source': 'cli'},
        'resolved': {'catalog_id': CATALOG_ID, 'native_id': NATIVE_ID, 'effort': 'high', 'effort_control': 'flag'},
        'policy_sha256': sha('t005 policy fixture'), 'catalog_sha256': sha('t005 catalog fixture'),
        'observation_sha256': sha('t005 observation fixture'),
        'observed_at': '2026-10-19T18:00:00.123456Z', 'source_date': '2026-10-18T00:00:00Z',
        'reason': 'Fixture pinned alias resolved to its catalog native identity.',
        'update_candidates': ['gpt-fixture-6-codex', 'gpt-fixture-6-mini'],
        'binding': None,
        'budget': {'amount': 2.5, 'unit': 'USD'},
        'estimate': {'catalog_id': CATALOG_ID, 'amount': 0.75, 'unit': 'USD',
                     'source_url': 'https://pricing.example.invalid/gpt-fixture-5', 'source_date': '2026-10-01T00:00:00Z'},
    })


def latest_selection():
    return changed(pinned_selection(), {
        'role': 'evaluator', 'risk': 'medium',
        'requested': {'policy': 'latest-compatible', 'model_id': None, 'policy_source': 'shipped', 'model_source': None},
        'resolved.effort': 'medium', 'resolved.effort_control': 'none',
        'reason': 'Fixture latest-compatible selection; no budget configured.',
        'update_candidates': [], 'budget': None, 'estimate': None})


KINDS = {'pinned': pinned_selection, 'latest': latest_selection}


def unbound(record):
    return changed(record, {'binding': None})


def bound(record, run_id=RUN, session_id=SESSION, attempt=1):
    return changed(record, {'binding': {'run_id': run_id, 'session_id': session_id, 'attempt': attempt}})


def for_host(record, host):
    return changed(record, {'host': host, 'cli_version': HOST_VERSIONS[host]})


# ---- Native Codex fixtures (shapes checked against the pinned generated schemas below) ----------------------

def native_thread(**changes):
    thread = {'cliVersion': THREAD_CREATED_VERSION, 'createdAt': 1792000000, 'cwd': NATIVE_CWD, 'ephemeral': False,
              'id': THREAD, 'modelProvider': 'openai', 'preview': 'Fixture preview ' + SECRET, 'projectId': None,
              'sessionId': SESSION, 'source': 'appServer', 'status': {'type': 'idle'}, 'turns': [],
              'updatedAt': 1792000100}
    for key, value in changes.items():
        if value is OMIT:
            thread.pop(key, None)
        else:
            thread[key] = value
    return thread


def native_turn(turn_id=TURN, items=(), status='inProgress', **changes):
    turn = {'id': turn_id, 'items': list(items) if isinstance(items, tuple) else items, 'status': status, **changes}
    return {key: copy.deepcopy(value) for key, value in turn.items() if value is not OMIT}


def agent_message(text=SELF_CLAIM, item_id='item-fixture-1'):
    return {'id': item_id, 'text': text, 'type': 'agentMessage'}


def rerouted(from_model, to_model, thread_id=THREAD, turn_id=TURN, reason=REROUTE_REASON):
    return {'method': 'model/rerouted', 'params': {'threadId': thread_id, 'turnId': turn_id, 'fromModel': from_model,
                                                  'toModel': to_model, 'reason': reason}}


def completed(turn_id=TURN, thread_id=THREAD, **turn_changes):
    return {'method': 'turn/completed',
            'params': {'threadId': thread_id, 'turn': native_turn(turn_id, **{'status': 'completed', **turn_changes})}}


def codex_events(selection, *, notifications=(), thread=None, turn=None, **changes):
    binding = selection.get('binding') or {}
    events = {'host': selection['host'], 'cli_version': selection['cli_version'],
              'selection_sha256': selection['selection_sha256'], 'run_id': binding.get('run_id', RUN),
              'session_id': binding.get('session_id', SESSION), 'thread_id': THREAD, 'turn_id': TURN,
              'thread_read': {'thread': native_thread(model=selection['resolved']['native_id'])
                              if thread is None else thread},
              'turn_start': {'turn': native_turn() if turn is None else turn},
              'notifications': [copy.deepcopy(n) for n in notifications]}
    events.update(changes)
    return events


def unsupported_events(selection, **changes):
    binding = selection.get('binding') or {}
    events = {'host': selection['host'], 'cli_version': selection['cli_version'],
              'selection_sha256': selection['selection_sha256'], 'run_id': binding.get('run_id', RUN),
              'session_id': binding.get('session_id', SESSION), 'thread_id': HOST_THREAD, 'turn_id': HOST_TURN,
              'thread_read': None, 'turn_start': None, 'notifications': []}
    events.update(changes)
    return events


def expected_delivery(selection, events, require, reroutes=()):
    """Independent oracle for the frozen model-delivery/v1 decision precedence."""
    rows = [{'thread_id': n['params']['threadId'], 'turn_id': n['params']['turnId'],
             'from_model': n['params']['fromModel'], 'to_model': n['params']['toModel'],
             'reason': n['params']['reason']} for n in reroutes]
    if rows and selection['requested']['policy'] == 'pinned':
        status, reason = 'blocked', 'actual-id-mismatch'
    elif require:
        status, reason = 'blocked', 'actual-id-unavailable'
    else:
        status, reason = 'accepted', 'reroute-observed' if rows else 'identity-unverified'
    return {'schema': DELIVERY_SCHEMA, 'selection_sha256': selection['selection_sha256'],
            'run_id': selection['binding']['run_id'], 'session_id': selection['binding']['session_id'],
            'turn_id': events['turn_id'], 'configured_id': selection['resolved']['native_id'], 'actual_id': None,
            'proof': 'unverified', 'source': DELIVERY_SOURCES[selection['host']], 'reroutes': rows,
            'status': status, 'reason': reason}





# ---- Shared test base ----------------------------------------------------------------------------------------

class IdentityCase(unittest.TestCase):
    maxDiff = None

    def mp(self) -> Any:
        if MP is None:
            self.fail('model-policy helper unavailable: ' + MP_ERROR)
        return MP

    def fn(self, name):
        function = getattr(self.mp(), name, None)
        if not callable(function):
            self.fail('model-policy.py does not expose %s(); T-005 API seam is missing' % name)
        return function

    def assertRejects(self, reasons, func, *args, **kwargs):
        allowed = {reasons} if isinstance(reasons, str) else set(reasons)
        policy_error = self.mp().PolicyError
        try:
            func(*args, **kwargs)
        except policy_error as error:
            self.assertIn(error.reason, allowed, 'unexpected typed reason: ' + str(error))
            envelope = error.as_dict()
            self.assertEqual(set(envelope), {'schema', 'reason', 'message'})
            self.assertEqual(envelope['schema'], ERROR_SCHEMA)
            self.assertTrue(isinstance(envelope['message'], str) and envelope['message'].strip()
                            and len(envelope['message']) <= MAX_TEXT)
            return error
        except Exception as error:  # untyped failures are not the model-policy-error contract
            self.fail('expected model-policy-error %s, got untyped %s: %s' % (sorted(allowed), type(error).__name__,
                                                                             error))
        self.fail('accepted input that must be rejected with %s' % sorted(allowed))

    def validate(self, record, **options):
        return self.fn('validate_selection_record')(record, **options)

    def bind(self, record, run_id=RUN, session_id=SESSION, attempt=1):
        return self.fn('bind_selection')(record, run_id=run_id, session_id=session_id, attempt=attempt)

    def resume(self, original, candidate):
        return self.fn('validate_resume_selection')(original, candidate)

    def verify(self, selection, events, require):
        return self.fn('verify_delivery')(selection, events, require_actual_id=require)

    def consume(self, record, selection, events, require):
        return self.fn('validate_delivery_record')(record, selection=selection, events=events,
                                                    require_actual_id=require)

    def assertDelivery(self, selection, events, require, reroutes=()):
        expected = expected_delivery(selection, events, require, reroutes)
        before = (copy.deepcopy(selection), copy.deepcopy(events))
        actual = self.verify(selection, events, require)
        self.assertEqual((selection, events), before, 'verify_delivery mutated caller data')
        self.assertEqual(actual, expected)
        self.assertIsNone(actual['actual_id'])
        self.assertEqual(actual['proof'], 'unverified')
        self.consume(copy.deepcopy(actual), selection, events, require)
        return actual

    def assertNoLeak(self, *values, markers=(SECRET, NATIVE_CWD, CLAIMED_ID, SELF_CLAIM, 'Traceback')):
        text = json.dumps(values, ensure_ascii=False, default=repr)
        for marker in markers:
            self.assertNotIn(marker, text)


# ---- TEST-100: selection record identity ---------------------------------------------------------------------

# (path, valid re-sealed alternates -> resume-conflict, invalid re-sealed values -> typed rejection)
SELECTION_COUNTERPARTS: list[tuple[str, list[dict], list[tuple[dict, set]]]] = [
    ('schema', [], [({'schema': 'model-selection/v2'}, INVALID), ({'schema': 'Model-Selection/v1'}, INVALID),
                    ({'schema': 'model-observation/v1'}, INVALID), ({'schema': None}, INVALID)]),
    ('role', [{'role': 'evaluator'}], [({'role': v}, INVALID) for v in ('', 'a b', 'x' * 129, None, 7)]),
    ('risk', [{'risk': 'critical'}, {'risk': 'low'}],
     [({'risk': v}, INVALID) for v in ('High', 'severe', '', None)]),
    ('host', [{'host': 'claude-code'}], [({'host': v}, INVALID) for v in ('codex', 'Codex-CLI', '', None)]),
    ('cli_version', [{'cli_version': 'codex-cli 0.160.0'}],
     [({'cli_version': v}, INVALID) for v in ('', ' codex', 'codex\n', 'x' * 129, 159, None)]),
    ('scope_id', [{'scope_id': 'client-t005other'}], [({'scope_id': v}, INVALID) for v in BAD_IDS + [None]]),
    ('requested.policy', [{'requested.policy': 'latest-compatible', 'requested.model_id': None,
                           'requested.model_source': None}],
     [({'requested.policy': 'Pinned'}, INVALID), ({'requested.policy': None}, INVALID),
      ({'requested.policy': 'latest-compatible'}, REQUESTED_CONFLICT)]),
    ('requested.model_id', [{'requested.model_id': NATIVE_ID}, {'requested.model_id': 'gpt-fixture-5'}],
     [({'requested.model_id': None}, REQUESTED_CONFLICT), ({'requested.model_id': 'a b'}, INVALID),
      ({'requested.model_id': ''}, INVALID), ({'requested.model_id': 5}, INVALID)]),
    ('requested.policy_source', [{'requested.policy_source': 'environment'},
                                 {'requested.policy_source': 'project-default'}],
     [({'requested.policy_source': v}, INVALID) for v in ('CLI', 'user', 'env', None)]),
    ('requested.model_source', [{'requested.model_source': 'project-role'}, {'requested.model_source': 'shipped'}],
     [({'requested.model_source': None}, REQUESTED_CONFLICT), ({'requested.model_source': 'Shipped'}, INVALID),
      ({'requested.model_source': 'environment-claim'}, INVALID)]),
    ('resolved.catalog_id', [{'resolved.catalog_id': ALT_CATALOG_ID, 'estimate.catalog_id': ALT_CATALOG_ID}],
     [({'resolved.catalog_id': ALT_CATALOG_ID}, BUDGET_OR_INVALID), ({'resolved.catalog_id': ''}, INVALID),
      ({'resolved.catalog_id': None}, INVALID)]),
    ('resolved.native_id', [{'resolved.native_id': ALT_ID}],
     [({'resolved.native_id': v}, INVALID) for v in ('', 'gpt fixture', '-gpt', None, 3)]),
    ('resolved.effort', [{'resolved.effort': 'xhigh'}, {'resolved.effort': 'low'}, {'resolved.effort': 'medium'}],
     [({'resolved.effort': v}, INVALID) for v in ('max', 'ultra', 'High', '', None)]),
    ('resolved.effort_control', [{'resolved.effort_control': 'none'}, {'resolved.effort_control': 'frontmatter'}],
     [({'resolved.effort_control': v}, INVALID) for v in ('', '   ', None, 'x' * 513, True)]),
    ('policy_sha256', [{'policy_sha256': sha('alternate policy')}],
     [({'policy_sha256': v}, INVALID) for v in ('A' * 64, '0' * 63, '0' * 65, 'g' * 64, sha('p') + '\n', None)]),
    ('catalog_sha256', [{'catalog_sha256': sha('alternate catalog')}],
     [({'catalog_sha256': v}, INVALID) for v in ('A' * 64, '0' * 63, sha('c') + '\n', None)]),
    ('observation_sha256', [{'observation_sha256': sha('alternate observation')}],
     [({'observation_sha256': v}, INVALID) for v in ('A' * 64, '0' * 63, sha('o') + '\n', None)]),
    ('observed_at', [{'observed_at': '2026-10-19T18:00:01Z'}],
     [({'observed_at': v}, INVALID) for v in ('2026-02-30T00:00:00Z', '2026-10-19T24:00:00Z', '2026-13-01T00:00:00Z',
                                              '2026-10-19T18:00:00+00:00', '2026-10-19 18:00:00Z',
                                              '2026-10-19T18:00:00z', '2026-10-19T18:00:00.Z',
                                              '2026-10-19T18:00:00Z\n', 1792000000, None)]),
    ('source_date', [{'source_date': '2026-10-17T00:00:00Z'}],
     [({'source_date': v}, INVALID) for v in ('2026-02-29T00:00:00Z', '2026-10-18', '2026-10-18T00:00:00Z\n', None)]),
    ('reason', [{'reason': 'A different fixture selection reason.'}],
     [({'reason': v}, INVALID) for v in ('', '   ', 'x' * 513, None)]),
    ('update_candidates', [{'update_candidates': ['gpt-fixture-6-codex', 'gpt-fixture-6-mini', 'gpt-fixture-7']},
                           {'update_candidates': ['gpt-fixture-6-codex']},
                           {'update_candidates': ['gpt-fixture-6-mini', 'gpt-fixture-6-codex']},
                           {'update_candidates': ['gpt-fixture-6-codex', 'gpt-fixture-6-max']},
                           {'update_candidates': []}],
     [({'update_candidates': v}, INVALID) for v in (['gpt-fixture-6-codex', 'gpt-fixture-6-codex'], ['bad id'],
                                                    'gpt-fixture-6-codex', None, [1], [None])]),
    ('budget', [{'budget': None}],
     [({'budget': {'amount': 2.5}}, INVALID), ({'budget': 2.5}, INVALID),
      ({'budget': {'amount': 2.5, 'unit': 'USD', 'cap': True}}, INVALID)]),
    ('budget.amount', [{'budget.amount': 3.0}, {'budget.amount': 0.75}, {'budget.amount': 4}],
     [({'budget.amount': 0.5}, BUDGET), ({'budget.amount': -1}, BUDGET_OR_INVALID), ({'budget.amount': True}, INVALID),
      ({'budget.amount': '2.5'}, INVALID), ({'budget.amount': None}, INVALID)]),
    ('budget.unit', [], [({'budget.unit': v}, BUDGET_OR_INVALID) for v in ('usd', 'EUR', 'credits')]
     + [({'budget.unit': None}, INVALID)]),
    ('estimate', [], [({'estimate': None}, BUDGET), ({'estimate': 0.75}, INVALID),
                      ({'estimate.source_url': OMIT}, INVALID), ({'estimate.extra': 'x'}, INVALID)]),
    ('estimate.catalog_id', [], [({'estimate.catalog_id': 'openai/gpt-fixture-other'}, BUDGET_OR_INVALID),
                                 ({'estimate.catalog_id': ''}, INVALID)]),
    ('estimate.amount', [{'estimate.amount': 1.0}, {'estimate.amount': 0}, {'estimate.amount': 2.5}],
     [({'estimate.amount': 3.0}, BUDGET), ({'estimate.amount': -0.01}, BUDGET_OR_INVALID),
      ({'estimate.amount': False}, INVALID), ({'estimate.amount': None}, INVALID)]),
    ('estimate.unit', [], [({'estimate.unit': v}, BUDGET_OR_INVALID) for v in ('Usd', 'EUR')]
     + [({'estimate.unit': None}, INVALID)]),
    ('estimate.source_url', [{'estimate.source_url': 'https://pricing.example.invalid/other'}],
     [({'estimate.source_url': v}, INVALID) for v in ('http://pricing.example.invalid/x', 'pricing.example.invalid/x',
                                                      'ftp://pricing.example.invalid/x', '',
                                                      'https://pricing.example.invalid/x\n', None)]),
    ('estimate.source_date', [{'estimate.source_date': '2026-09-30T00:00:00Z'}],
     [({'estimate.source_date': v}, INVALID) for v in ('2026-13-01T00:00:00Z', '2026-09-31T00:00:00Z', None)]),
]


class SelectionRecordTests(IdentityCase):
    def test_TEST100_independent_digest_matches_and_excludes_only_selection_sha256(self):
        for kind, make in KINDS.items():
            for record in (make(), bound(make()), bound(make(), OTHER_RUN, OTHER_SESSION, 7)):
                with self.subTest(kind=kind, binding=record['binding']):
                    snapshot = copy.deepcopy(record)
                    self.assertEqual(self.fn('selection_digest')(record), digest(record))
                    self.assertEqual(record, snapshot, 'selection_digest mutated its argument')
                    self.assertEqual(self.fn('selection_digest')({**record, 'selection_sha256': '0' * 64}),
                                     digest(record), 'digest must ignore only selection_sha256')
                    self.validate(record)
        self.assertNotEqual(digest(bound(pinned_selection())), digest(bound(pinned_selection(), attempt=2)))

    def test_TEST100_require_bound_rejects_unbound_and_accepts_bound(self):
        for kind, make in KINDS.items():
            with self.subTest(kind=kind):
                self.validate(make(), require_bound=False)
                self.validate(bound(make()), require_bound=True)
                self.assertRejects(INVALID, self.validate, make(), require_bound=True)

    def test_TEST100_bind_returns_new_bound_record_preserving_every_field(self):
        for kind, make in KINDS.items():
            with self.subTest(kind=kind):
                record = make()
                snapshot = copy.deepcopy(record)
                result = self.bind(record, RUN, SESSION, 3)
                self.assertEqual(record, snapshot, 'bind_selection mutated caller data')
                self.assertIsNone(record['binding'])
                expected = bound(record, RUN, SESSION, 3)
                self.assertEqual(result, expected)
                self.assertEqual(result['selection_sha256'], digest(result))
                self.assertNotEqual(result['selection_sha256'], record['selection_sha256'])
                for field in SELECTION_FIELDS - {'binding', 'selection_sha256'}:
                    self.assertEqual(result[field], record[field], field)
                self.assertEqual(result['binding'], {'run_id': RUN, 'session_id': SESSION, 'attempt': 3})
                for field in ('requested', 'resolved', 'update_candidates', 'budget', 'estimate'):
                    if isinstance(record[field], (dict, list)):
                        self.assertIsNot(result[field], record[field], field + ' aliases caller data')
                result['resolved']['native_id'] = 'tampered-after-return'
                self.assertEqual(record, snapshot, 'returned record shares nested state with caller')
                self.validate(expected, require_bound=True)

    def test_TEST100_bound_selection_is_required_by_delivery(self):
        selection = bound(pinned_selection())
        self.assertDelivery(selection, codex_events(selection), False)
        loose = pinned_selection()
        self.assertRejects(INVALID, self.verify, loose, codex_events(loose), False)
        self.assertRejects(INVALID, self.verify, loose, codex_events(loose), True)

    def test_selection_field_counterparts(self):
        """Mismatch-map rows selection.*: every valid re-sealed change is a resume-conflict, never silent reuse."""
        base = pinned_selection()
        original = bound(base)
        covered = set()
        for path, alternates, _invalid in SELECTION_COUNTERPARTS:
            covered.add(path)
            for alternate in alternates:
                with self.subTest(field=path, change=alternate):
                    candidate = changed(base, alternate)
                    self.validate(candidate)
                    self.assertNotEqual(candidate['selection_sha256'], base['selection_sha256'])
                    self.assertRejects(CONFLICT, self.resume, original, candidate)
                    self.assertRejects(CONFLICT, self.resume, original, bound(candidate))
                    stale = changed(base, alternate, reseal=False)
                    self.assertRejects(INVALID, self.validate, stale)
        self.assertEqual(covered, {p for p, _a, _i in SELECTION_COUNTERPARTS})
        self.assertLessEqual({'requested.' + f for f in REQUESTED_FIELDS} | {'resolved.' + f for f in RESOLVED_FIELDS}
                             | {'budget.' + f for f in BUDGET_FIELDS} | {'estimate.' + f for f in ESTIMATE_FIELDS}
                             | (SELECTION_FIELDS - {'requested', 'resolved', 'binding', 'selection_sha256'}), covered)

    def test_selection_invalid_values_are_typed_rejections_even_when_resealed(self):
        base = pinned_selection()
        for path, _alternates, invalid in SELECTION_COUNTERPARTS:
            for change, reasons in invalid:
                with self.subTest(field=path, change=repr(change)[:80]):
                    bad = changed(base, change)
                    self.assertRejects(reasons, self.validate, bad)
                    self.assertRejects(reasons, self.bind, bad)
                    self.assertRejects(reasons | CONFLICT, self.resume, bound(base), bad)

    def test_selection_binding_counterparts(self):
        value: Any
        base = pinned_selection()
        original = bound(base)
        self.resume(original, base)
        self.resume(original, original)
        for field, value in (('run_id', OTHER_RUN), ('session_id', OTHER_SESSION), ('attempt', 2)):
            with self.subTest(field='binding.' + field):
                moved = changed(original, {'binding.' + field: value})
                self.validate(moved, require_bound=True)
                self.assertRejects(CONFLICT, self.resume, original, moved)
                arguments = {'run_id': RUN, 'session_id': SESSION, 'attempt': 1, field: value}
                self.assertRejects(CONFLICT, self.fn('bind_selection'), original, **arguments)
        for value in (0, -1, True, False, 1.0, '1', None):
            with self.subTest(attempt=value):
                self.assertRejects(INVALID, self.validate, changed(original, {'binding.attempt': value}))
        for field in ('run_id', 'session_id'):
            for value in BAD_IDS + [None, 5]:
                with self.subTest(field=field, value=value):
                    self.assertRejects(INVALID, self.validate, changed(original, {'binding.' + field: value}))
        self.assertRejects(INVALID, self.validate, changed(original, {'binding': {'run_id': RUN, 'attempt': 1}}))
        self.assertRejects(INVALID, self.validate, changed(original, {'binding.extra': 'x'}))
        self.assertRejects(INVALID, self.validate, changed(original, {'binding': 'run-t005-fixture-0001'}))

    def test_selection_sha256_counterpart_and_stale_body(self):
        record = bound(pinned_selection())
        for value in (sha('other'), record['selection_sha256'].upper(), record['selection_sha256'][:-1],
                      record['selection_sha256'] + '\n', None, ''):
            with self.subTest(selection_sha256=value):
                self.assertRejects(INVALID, self.validate, {**record, 'selection_sha256': value})
        stale = put(record, 'resolved.native_id', ALT_ID)
        self.assertRejects(INVALID, self.validate, stale)
        self.assertRejects(INVALID, self.bind, put(pinned_selection(), 'resolved.effort', 'low'))

    def test_selection_missing_and_extra_fields_at_every_level(self):
        value: Any
        record = bound(pinned_selection())
        for field in SELECTION_FIELDS - {'selection_sha256'}:
            with self.subTest(missing=field):
                self.assertRejects(INVALID, self.validate, changed(record, {field: OMIT}))
        self.assertRejects(INVALID, self.validate, {k: v for k, v in record.items() if k != 'selection_sha256'})
        for nested, fields in NESTED_OBJECTS.items():
            for field in fields:
                with self.subTest(missing=nested + '.' + field):
                    self.assertRejects(INVALID | BUDGET, self.validate, changed(record, {nested + '.' + field: OMIT}))
            with self.subTest(extra=nested):
                self.assertRejects(INVALID, self.validate, changed(record, {nested + '.unexpected': 'x'}))
        for extra in ('actual_id', 'proof', 'source', 'scope_kind', 'purpose', 'policy_path', 'unexpected'):
            with self.subTest(extra=extra):
                self.assertRejects(INVALID, self.validate, changed(record, {extra: 'x'}))
        for value in (None, [], 'record', 5):
            with self.subTest(top=value):
                self.assertRejects(INVALID, self.validate, value)

    def test_selection_budget_estimate_consistency(self):
        pinned = pinned_selection()
        self.validate(changed(pinned, {'budget': None}))
        self.validate(changed(pinned, {'budget': None, 'estimate': None}))
        self.validate(changed(pinned, {'budget.amount': 0, 'estimate.amount': 0}))
        self.validate(changed(pinned, {'budget.amount': 0.75}))
        self.validate(latest_selection())
        self.assertRejects(BUDGET, self.validate, changed(pinned, {'estimate': None}))
        self.assertRejects(BUDGET, self.validate, changed(pinned, {'budget.amount': 0.7499}))
        self.assertRejects(BUDGET, self.validate, changed(latest_selection(), {'budget': {'amount': 1, 'unit': 'USD'}}))
        self.assertRejects(BUDGET_OR_INVALID, self.validate, changed(pinned, {'estimate.catalog_id': ALT_CATALOG_ID}))
        self.assertRejects(BUDGET_OR_INVALID, self.validate,
                           changed(pinned, {'budget': None, 'estimate.catalog_id': ALT_CATALOG_ID}))
        for path in ('budget.amount', 'estimate.amount'):
            for value in (float('inf'), float('-inf'), float('nan')):
                with self.subTest(path=path, value=value):
                    bad = put(pinned, path, value)  # nonfinite cannot be canonically sealed
                    self.assertRejects(INVALID | BUDGET, self.validate, bad)
                    self.assertRejects(INVALID | BUDGET, self.bind, bad)
            with self.subTest(path=path, value='overflow'):
                self.assertRejects(INVALID | BUDGET, self.validate, put(pinned, path, 10.0 ** 308 * 10))

    def test_selection_utc_fraction_precision_and_calendar(self):
        base = pinned_selection()
        for path in ('observed_at', 'source_date', 'estimate.source_date'):
            for value in ('2026-10-19T18:00:00Z', '2026-10-19T18:00:00.5Z', '2026-10-19T18:00:00.123456789012Z',
                          '2024-02-29T23:59:59.000000000Z'):
                with self.subTest(path=path, valid=value):
                    self.validate(changed(base, {path: value}))
            for value in ('2026-02-29T00:00:00Z', '2026-04-31T00:00:00Z', '2026-10-19T18:60:00Z',
                          '2026-10-19T18:00:61Z', '2026-10-19T18:00:00Z\n', '2026-10-19T18:00:00.Z',
                          '2026-10-19T18:00:00.5', '２０２６-10-19T18:00:00Z'):
                with self.subTest(path=path, invalid=value):
                    self.assertRejects(INVALID, self.validate, changed(base, {path: value}))

    def test_selection_requested_policy_conditions(self):
        pinned, latest = pinned_selection(), latest_selection()
        self.validate(pinned)
        self.validate(latest)
        for record, change in ((pinned, {'requested.model_id': None}), (pinned, {'requested.model_source': None}),
                               (latest, {'requested.model_id': ALIAS}), (latest, {'requested.model_source': 'cli'}),
                               (latest, {'requested.model_id': ALIAS, 'requested.model_source': 'cli'}),
                               (pinned, {'requested.policy': 'latest-compatible'})):
            with self.subTest(policy=record['requested']['policy'], change=change):
                self.assertRejects(REQUESTED_CONFLICT, self.validate, changed(record, change))
        # A pinned alias need not equal the native/catalog ID; no blind prefix stripping is applied.
        aliased = changed(pinned, {'requested.model_id': 'openai/' + NATIVE_ID})
        self.validate(aliased)
        self.assertEqual(self.bind(aliased)['resolved']['native_id'], NATIVE_ID)
        self.assertEqual(self.bind(aliased)['requested']['model_id'], 'openai/' + NATIVE_ID)

    def test_selection_effort_control_none_is_preserved_not_upgraded(self):
        record = changed(pinned_selection(), {'resolved.effort_control': 'none'})
        result = self.bind(record)
        self.assertEqual(result['resolved'], {**record['resolved'], 'effort_control': 'none'})
        self.assertEqual(result, bound(record))

    def test_selection_duplicate_candidate_ids_fail(self):
        record = changed(pinned_selection(), {'update_candidates': [ALT_ID, THIRD_ID, ALT_ID]})
        self.assertRejects(INVALID, self.validate, record)
        self.assertRejects(INVALID, self.bind, record)


# ---- TEST-101 / TEST-102: immutable resume ----------------------------------------------------------------------

class ResumeTests(IdentityCase):
    def test_TEST101_rebinding_identical_binding_is_idempotent(self):
        for kind, make in KINDS.items():
            with self.subTest(kind=kind):
                first = self.bind(make())
                snapshot = copy.deepcopy(first)
                again = self.bind(first)
                self.assertEqual(again, first)
                self.assertEqual(first, snapshot)
                self.assertEqual(self.bind(make()), first, 'same record and binding must give identical bytes')
                self.assertEqual(canonical(again), canonical(bound(make())))

    def test_TEST101_resume_accepts_exact_unbound_and_bound_counterparts(self):
        for kind, make in KINDS.items():
            with self.subTest(kind=kind):
                original = bound(make())
                snapshots = (copy.deepcopy(original), make())
                self.assertIsNone(self.resume(original, make()))
                self.assertIsNone(self.resume(original, copy.deepcopy(original)))
                self.assertEqual((original, make()), snapshots)

    def test_TEST101_resume_requires_bound_valid_original(self):
        value: Any
        record = pinned_selection()
        self.resume(bound(record), record)
        self.assertRejects(UNBOUND_ORIGINAL, self.resume, record, record)
        self.assertRejects(INVALID, self.resume, put(bound(record), 'reason', 'stale digest'), record)
        self.assertRejects(INVALID, self.resume, bound(record), put(record, 'reason', 'stale digest'))
        for value in (None, [], 'record'):
            with self.subTest(value=value):
                self.assertRejects(INVALID, self.resume, value, record)
                self.assertRejects(INVALID, self.resume, bound(record), value)

    def test_TEST102_changed_model_or_effort_rejects_same_attempt_resume(self):
        base = pinned_selection()
        original = bound(base)
        evidence = copy.deepcopy(original)
        for name, change in (('native_id', {'resolved.native_id': ALT_ID}),
                             ('catalog_id', {'resolved.catalog_id': ALT_CATALOG_ID,
                                             'estimate.catalog_id': ALT_CATALOG_ID}),
                             ('effort', {'resolved.effort': 'xhigh'}),
                             ('effort_control', {'resolved.effort_control': 'none'})):
            with self.subTest(changed=name):
                candidate = changed(base, change)
                self.validate(candidate)
                self.assertRejects(CONFLICT, self.resume, original, candidate)
                self.assertRejects(CONFLICT, self.resume, original, bound(candidate))
                self.assertEqual(original, evidence, 'rejection must preserve original evidence')

    def test_TEST102_binding_disagreement_is_resume_conflict(self):
        original = self.bind(pinned_selection())
        for arguments in ({'run_id': OTHER_RUN}, {'session_id': OTHER_SESSION}, {'attempt': 2}):
            with self.subTest(**arguments):
                options = {'run_id': RUN, 'session_id': SESSION, 'attempt': 1, **arguments}
                self.assertRejects(CONFLICT, self.fn('bind_selection'), original, **options)
                self.assertRejects(CONFLICT, self.resume, original, bound(pinned_selection(), **options))

    def test_TEST102_changed_selection_with_new_attempt_is_a_new_record(self):
        original = self.bind(pinned_selection())
        evidence = canonical(original)
        replacement = changed(pinned_selection(), {'resolved.native_id': ALT_ID, 'resolved.effort': 'medium'})
        second = self.bind(replacement, RUN, SESSION, 2)
        self.assertEqual(second, bound(replacement, RUN, SESSION, 2))
        self.assertNotEqual(second['selection_sha256'], original['selection_sha256'])
        self.assertEqual(canonical(original), evidence)
        self.assertRejects(CONFLICT, self.resume, original, second)
        self.assertRejects(CONFLICT, self.resume, original, replacement)

    def test_bind_argument_types_and_values(self):
        value: Any
        record = pinned_selection()
        self.bind(record, attempt=1)
        self.assertEqual(self.bind(record, attempt=999)['binding']['attempt'], 999)
        for value in (0, -1, True, False, 1.0, '1', None, [1]):
            with self.subTest(attempt=value):
                self.assertRejects(INVALID, self.bind, record, attempt=value)
        for field in ('run_id', 'session_id'):
            for value in BAD_IDS + [None, 7, True]:
                with self.subTest(field=field, value=value):
                    options = {'run_id': RUN, 'session_id': SESSION, 'attempt': 1, field: value}
                    self.assertRejects(INVALID, self.fn('bind_selection'), record, **options)
        for value in (None, [], 'record', {}):
            with self.subTest(record=value):
                self.assertRejects(INVALID, self.bind, value)


# ---- Delivery: TEST-107/108/131/132/133 ------------------------------------------------------------------------

def selected(kind='pinned', host='codex-cli'):
    record = KINDS[kind]()
    return bound(record if host == 'codex-cli' else for_host(record, host))


class DeliveryIdentityTests(IdentityCase):
    def test_TEST107_codex_configured_only_evidence_cannot_satisfy_required_actual_id(self):
        for kind in KINDS:
            with self.subTest(kind=kind):
                selection = selected(kind)
                events = codex_events(selection)
                blocked = self.assertDelivery(selection, events, True)
                self.assertEqual((blocked['status'], blocked['reason']), ('blocked', 'actual-id-unavailable'))
                accepted = self.assertDelivery(selection, events, False)
                self.assertEqual((accepted['status'], accepted['reason'], accepted['source']),
                                 ('accepted', 'identity-unverified', 'codex-app-server'))
                self.assertEqual(accepted['configured_id'], selection['resolved']['native_id'])

    def test_TEST107_each_unsupported_host_is_unverified_and_blocks_a_requiring_gate(self):
        for host in UNSUPPORTED_HOSTS:
            for kind in KINDS:
                with self.subTest(host=host, kind=kind):
                    selection = selected(kind, host)
                    events = unsupported_events(selection)
                    self.assertEqual(self.assertDelivery(selection, events, True)['reason'], 'actual-id-unavailable')
                    accepted = self.assertDelivery(selection, events, False)
                    self.assertEqual((accepted['status'], accepted['source']), ('accepted', 'unsupported'))

    def test_TEST107_caller_authored_identity_claims_in_evidence_are_rejected(self):
        selection = selected()
        clean = codex_events(selection)
        self.assertDelivery(selection, clean, False)
        for field, value in (('actual_id', NATIVE_ID), ('proof', 'host-reported'), ('source', 'codex-app-server'),
                             ('status', 'accepted'), ('reason', 'identity-unverified'), ('reroutes', [])):
            for require in (True, False):
                with self.subTest(extra=field, require=require):
                    self.assertRejects(INVALID, self.verify, selection, {**clean, field: value}, require)
        for host in UNSUPPORTED_HOSTS:
            with self.subTest(host=host):
                other = selected('pinned', host)
                events = {**unsupported_events(other), 'actual_id': other['resolved']['native_id']}
                self.assertRejects(INVALID, self.verify, other, events, False)

    def test_TEST107_forged_host_reported_delivery_is_rejected_by_consumer(self):
        for host in HOSTS:
            selection = selected('pinned', host)
            events = codex_events(selection) if host == 'codex-cli' else unsupported_events(selection)
            for require in (True, False):
                genuine = expected_delivery(selection, events, require)
                self.consume(genuine, selection, events, require)
                for forged_id in (selection['resolved']['native_id'], ALIAS, CLAIMED_ID):
                    forged = {**genuine, 'actual_id': forged_id, 'proof': 'host-reported', 'status': 'accepted',
                              'reason': 'identity-unverified'}
                    with self.subTest(host=host, require=require, actual_id=forged_id):
                        self.assertRejects(CONSUMER_REJECT, self.consume, forged, selection, events, require)

    def test_TEST108_configured_thread_model_mismatch_is_native_precedence_conflict(self):
        for kind in KINDS:
            selection = selected(kind)
            for model in (ALT_ID, ALIAS, NATIVE_ID.upper(), 'openai/' + NATIVE_ID):
                events = codex_events(selection, thread=native_thread(model=model))
                for require in (True, False):
                    with self.subTest(kind=kind, model=model, require=require):
                        self.assertRejects('native-precedence-conflict', self.verify, selection, events, require)
                        accepted = expected_delivery(selection, codex_events(selection), False)
                        self.assertRejects(CONSUMER_REJECT | {'native-precedence-conflict'}, self.consume,
                                           accepted, selection, events, require)

    def test_TEST108_known_thread_effort_mismatch_is_a_configuration_conflict(self):
        selection = selected()
        self.assertDelivery(selection, codex_events(selection, thread=native_thread(
            model=NATIVE_ID, reasoningEffort='high')), False)
        for effort in ('low', 'medium', 'xhigh'):
            with self.subTest(effort=effort):
                events = codex_events(selection, thread=native_thread(model=NATIVE_ID, reasoningEffort=effort))
                self.assertRejects(EFFORT_CONFLICT, self.verify, selection, events, False)

    def test_TEST108_pinned_reroute_blocks_with_recorded_mismatch_even_without_required_proof(self):
        selection = selected('pinned')
        change = rerouted(NATIVE_ID, ALT_ID)
        events = codex_events(selection, notifications=[change])
        for require in (False, True):
            with self.subTest(require=require):
                delivery = self.assertDelivery(selection, events, require, [change])
                self.assertEqual((delivery['status'], delivery['reason']), ('blocked', 'actual-id-mismatch'))
                self.assertEqual(delivery['reroutes'], [{'thread_id': THREAD, 'turn_id': TURN, 'from_model': NATIVE_ID,
                                                         'to_model': ALT_ID, 'reason': REROUTE_REASON}])
                self.assertIsNone(delivery['actual_id'], 'toModel must never become a positive actual ID')
                self.assertEqual(delivery['source'], 'codex-app-server')

    def test_TEST131_thread_model_omitted_null_or_matching_never_fills_actual_id(self):
        selection = selected()
        baseline = expected_delivery(selection, codex_events(selection), False)
        for label, thread in (('omitted', native_thread(model=OMIT)), ('null', native_thread(model=None)),
                              ('matching', native_thread(model=NATIVE_ID)),
                              ('effort-null', native_thread(model=NATIVE_ID, reasoningEffort=None)),
                              ('effort-matching', native_thread(model=NATIVE_ID, reasoningEffort='high'))):
            with self.subTest(thread_model=label):
                delivery = self.assertDelivery(selection, codex_events(selection, thread=thread), False)
                self.assertEqual(delivery, baseline)
                self.assertEqual(delivery['configured_id'], NATIVE_ID)

    def test_TEST131_turn_items_and_assistant_text_are_not_identity_sources(self):
        selection = selected('latest')
        text_turn = native_turn(items=[agent_message(), agent_message('model: ' + CLAIMED_ID, 'item-fixture-2')])
        thread = native_thread(model=NATIVE_ID, turns=[native_turn(OTHER_TURN, items=[agent_message()],
                                                                   status='completed')],
                               preview=SELF_CLAIM, name=CLAIMED_ID)
        events = codex_events(selection, thread=thread, turn=text_turn,
                              notifications=[completed(items=[agent_message()])])
        for require in (False, True):
            with self.subTest(require=require):
                delivery = self.assertDelivery(selection, events, require)
                self.assertNoLeak(delivery)

    def test_TEST131_thread_cli_version_is_creation_metadata(self):
        selection = selected()
        for version in (THREAD_CREATED_VERSION, CODEX_VERSION, '0.1.0-alpha', 'unrelated creation build'):
            with self.subTest(thread_cli_version=version):
                self.assertDelivery(selection, codex_events(selection, thread=native_thread(
                    model=NATIVE_ID, cliVersion=version)), False)
        for value in (159, None, ['0.150.0']):
            with self.subTest(thread_cli_version=value):
                events = codex_events(selection, thread=native_thread(model=NATIVE_ID, cliVersion=value))
                self.assertRejects(INVALID, self.verify, selection, events, False)

    def test_TEST131_thread_and_turn_identity_must_match_evidence_context(self):
        selection = selected()
        self.assertDelivery(selection, codex_events(selection), False)
        mismatches = {
            'turn_start.turn.id': codex_events(selection, turn=native_turn(OTHER_TURN)),
            'thread.id': codex_events(selection, thread=native_thread(model=NATIVE_ID, id=OTHER_THREAD)),
            'thread.sessionId': codex_events(selection, thread=native_thread(model=NATIVE_ID,
                                                                             sessionId=OTHER_SESSION)),
            'events.turn_id': codex_events(selection, turn_id=OTHER_TURN),
            'events.thread_id': codex_events(selection, thread_id=OTHER_THREAD),
        }
        for label, events in mismatches.items():
            for require in (False, True):
                with self.subTest(mismatch=label, require=require):
                    self.assertRejects(INVALID | {'scope-mismatch'}, self.verify, selection, events, require)

    def test_TEST131_native_required_fields_and_optionality_are_respected(self):
        selection = selected()
        for field in ('model', 'reasoningEffort', 'name', 'agentRole', 'gitInfo', 'path', 'historyMode'):
            with self.subTest(optional_absent=field):
                self.assertDelivery(selection, codex_events(selection, thread=native_thread(
                    **{'model': NATIVE_ID, field: OMIT})), False)
        self.assertDelivery(selection, codex_events(selection, thread=native_thread(
            model=NATIVE_ID, gitInfo={'branch': None, 'originUrl': None, 'sha': None}, name='Fixture thread',
            extra={'fixture': True})), False)
        broken = {
            'thread_read null': codex_events(selection, thread_read=None),
            'turn_start null': codex_events(selection, turn_start=None),
            'thread_read without thread': codex_events(selection, thread_read={}),
            'turn_start without turn': codex_events(selection, turn_start={}),
            'thread.id missing': codex_events(selection, thread=native_thread(model=NATIVE_ID, id=OMIT)),
            'thread.sessionId missing': codex_events(selection, thread=native_thread(model=NATIVE_ID,
                                                                                    sessionId=OMIT)),
            'thread.cliVersion missing': codex_events(selection, thread=native_thread(model=NATIVE_ID,
                                                                                     cliVersion=OMIT)),
            'thread.model wrong type': codex_events(selection, thread=native_thread(model=5)),
            'thread.id wrong type': codex_events(selection, thread=native_thread(model=NATIVE_ID, id=1)),
            'turn.id missing': codex_events(selection, turn=native_turn(id=OMIT)),
            'turn.id wrong type': codex_events(selection, turn=native_turn(id=7)),
            'thread not object': codex_events(selection, thread_read={'thread': []}),
            'notifications not array': {**codex_events(selection), 'notifications': {'method': 'model/rerouted'}},
            'notification not object': {**codex_events(selection), 'notifications': ['model/rerouted']},
        }
        for label, events in broken.items():
            with self.subTest(broken=label):
                self.assertRejects(INVALID, self.verify, selection, events, False)

    def test_TEST132_matching_reroute_records_change_and_blocks_pinned(self):
        selection = selected('pinned')
        change = rerouted(NATIVE_ID, ALT_ID)
        delivery = self.assertDelivery(selection, codex_events(selection, notifications=[change]), False, [change])
        self.assertEqual(delivery['reason'], 'actual-id-mismatch')

    def test_TEST132_unrelated_thread_or_turn_events_leave_the_clean_baseline(self):
        unrelated = {'other-thread': rerouted(NATIVE_ID, ALT_ID, thread_id=OTHER_THREAD),
                     'other-turn': rerouted(NATIVE_ID, ALT_ID, turn_id=OTHER_TURN),
                     'both': rerouted(NATIVE_ID, ALT_ID, OTHER_THREAD, OTHER_TURN),
                     'other-thread-completion': completed(OTHER_TURN, OTHER_THREAD)}
        for kind in KINDS:
            selection = selected(kind)
            for require in (False, True):
                baseline = self.verify(selection, codex_events(selection), require)
                self.assertEqual(baseline, expected_delivery(selection, codex_events(selection), require))
                for label, event in unrelated.items():
                    with self.subTest(kind=kind, require=require, event=label):
                        events = codex_events(selection, notifications=[event])
                        self.assertEqual(self.verify(selection, events, require), baseline)
                        self.consume(baseline, selection, events, require)
                with self.subTest(kind=kind, require=require, event='all-unrelated'):
                    events = codex_events(selection, notifications=list(unrelated.values()))
                    self.assertEqual(self.verify(selection, events, require), baseline)

    def test_TEST132_matching_completion_does_not_attest_identity(self):
        selection = selected('latest')
        for require in (False, True):
            with self.subTest(require=require):
                self.assertDelivery(selection, codex_events(selection, notifications=[completed()]), require)
        for label, event in (('turn missing items', completed(items=OMIT)),
                             ('turn missing status', completed(status=OMIT)),
                             ('turn status invalid', completed(status='done')),
                             ('turn not object', {'method': 'turn/completed',
                                                  'params': {'threadId': THREAD, 'turn': TURN}}),
                             ('missing params', {'method': 'turn/completed'})):
            with self.subTest(malformed=label):
                self.assertRejects(INVALID, self.verify, selection,
                                   codex_events(selection, notifications=[event]), False)

    def test_TEST132_chained_reroutes_retained_in_order_and_excursion_back_still_blocks(self):
        selection = selected('pinned')
        chain = [rerouted(NATIVE_ID, ALT_ID), rerouted(ALT_ID, THIRD_ID)]
        noise = rerouted(NATIVE_ID, ALT_ID, thread_id=OTHER_THREAD)
        delivery = self.assertDelivery(selection, codex_events(selection, notifications=[chain[0], noise, chain[1]]),
                                       False, chain)
        self.assertEqual([r['to_model'] for r in delivery['reroutes']], [ALT_ID, THIRD_ID])
        excursion = [rerouted(NATIVE_ID, ALT_ID), rerouted(ALT_ID, NATIVE_ID)]
        back = self.assertDelivery(selection, codex_events(selection, notifications=excursion), False, excursion)
        self.assertEqual((back['status'], back['reason']), ('blocked', 'actual-id-mismatch'))
        self.assertIsNone(back['actual_id'])

    def test_TEST132_duplicate_disconnected_or_malformed_matching_reroutes_fail(self):
        for kind in KINDS:
            selection = selected(kind)
            cases = {
                'duplicate': [rerouted(NATIVE_ID, ALT_ID), rerouted(NATIVE_ID, ALT_ID)],
                'disconnected': [rerouted(NATIVE_ID, ALT_ID), rerouted(THIRD_ID, NATIVE_ID)],
                'wrong-origin': [rerouted(THIRD_ID, ALT_ID)],
                'alias-origin': [rerouted(ALIAS, ALT_ID)],
            }
            for reason in ('fallback', 'overload', 'HighRiskCyberActivity', 'highriskcyberactivity', '', None, 1):
                cases['reason=%r' % (reason,)] = [rerouted(NATIVE_ID, ALT_ID, reason=reason)]
            for field in ('threadId', 'turnId', 'fromModel', 'toModel', 'reason'):
                missing = rerouted(NATIVE_ID, ALT_ID)
                del missing['params'][field]
                if field not in ('threadId', 'turnId'):
                    cases['missing ' + field] = [missing]
                for value in (5, None, ['x']):
                    typed = rerouted(NATIVE_ID, ALT_ID)
                    typed['params'][field] = value
                    if field in ('fromModel', 'toModel', 'reason'):
                        cases['%s=%r' % (field, value)] = [typed]
            cases['empty toModel'] = [rerouted(NATIVE_ID, '')]
            cases['params not object'] = [{'method': 'model/rerouted', 'params': [NATIVE_ID, ALT_ID]}]
            for label, notifications in cases.items():
                with self.subTest(kind=kind, case=label):
                    self.assertRejects(INVALID, self.verify, selection,
                                       codex_events(selection, notifications=notifications), False)

    def test_TEST132_latest_compatible_retains_reroutes_without_unchanged_claim(self):
        selection = selected('latest')
        chain = [rerouted(NATIVE_ID, ALT_ID), rerouted(ALT_ID, THIRD_ID)]
        events = codex_events(selection, notifications=chain)
        ordinary = self.assertDelivery(selection, events, False, chain)
        self.assertEqual((ordinary['status'], ordinary['reason']), ('accepted', 'reroute-observed'))
        self.assertEqual(len(ordinary['reroutes']), 2)
        required = self.assertDelivery(selection, events, True, chain)
        self.assertEqual((required['status'], required['reason']), ('blocked', 'actual-id-unavailable'))
        self.assertEqual(required['reroutes'], ordinary['reroutes'])

    def test_TEST133_true_and_false_contract_branches_for_every_host(self):
        for host in HOSTS:
            for kind in KINDS:
                selection = selected(kind, host)
                events = codex_events(selection) if host == 'codex-cli' else unsupported_events(selection)
                for require, outcome in ((True, ('blocked', 'actual-id-unavailable')),
                                         (False, ('accepted', 'identity-unverified'))):
                    with self.subTest(host=host, kind=kind, require=require):
                        delivery = self.assertDelivery(selection, events, require)
                        self.assertEqual((delivery['status'], delivery['reason']), outcome)
                        self.assertEqual(delivery['reroutes'], [])
                        self.assertNotEqual(delivery['proof'], 'host-reported',
                                            'absence of reroute is not positive execution proof')

    def test_TEST133_unsupported_hosts_cannot_supply_pseudo_positive_native_events(self):
        for host in UNSUPPORTED_HOSTS:
            selection = selected('pinned', host)
            clean = unsupported_events(selection)
            self.assertDelivery(selection, clean, False)
            native = codex_events(selection)
            cases = {'thread_read': {**clean, 'thread_read': native['thread_read']},
                     'turn_start': {**clean, 'turn_start': native['turn_start']},
                     'reroute': {**clean, 'notifications': [rerouted(NATIVE_ID, ALT_ID, HOST_THREAD, HOST_TURN)]},
                     'completion': {**clean, 'notifications': [completed(HOST_TURN, HOST_THREAD)]},
                     'empty objects': {**clean, 'thread_read': {}, 'turn_start': {}}}
            for label, events in cases.items():
                for require in (False, True):
                    with self.subTest(host=host, case=label, require=require):
                        self.assertRejects(INVALID, self.verify, selection, events, require)
        codex = selected()
        self.assertRejects(INVALID, self.verify, codex, unsupported_events(codex), False)

    def test_delivery_evidence_binding_counterparts(self):
        value: Any
        selection = selected()
        events = codex_events(selection)
        self.assertDelivery(selection, events, False)
        cases = {
            'events.host': {**events, 'host': 'claude-code'},
            'events.host case': {**events, 'host': 'Codex-CLI'},
            'events.cli_version': {**events, 'cli_version': 'codex-cli 0.160.0'},
            'events.cli_version thread creation': {**events, 'cli_version': THREAD_CREATED_VERSION},
            'events.selection_sha256': {**events, 'selection_sha256': sha('other selection')},
            'events.selection_sha256 case': {**events, 'selection_sha256': selection['selection_sha256'].upper()},
            'events.selection_sha256 unbound': {**events, 'selection_sha256': unbound(selection)['selection_sha256']},
            'events.run_id': {**events, 'run_id': OTHER_RUN},
            'events.session_id': {**events, 'session_id': OTHER_SESSION},
        }
        for field in EVENTS_FIELDS:
            cases['missing ' + field] = {k: v for k, v in events.items() if k != field}
        for field in ('host', 'cli_version', 'selection_sha256', 'run_id', 'session_id', 'thread_id', 'turn_id'):
            for value in ('', None, 5, 'x' * 600):
                cases['%s=%r' % (field, value if value != 'x' * 600 else 'overlong')] = {**events, field: value}
        for label, mutated in cases.items():
            for require in (False, True):
                with self.subTest(case=label, require=require):
                    self.assertRejects(EVIDENCE_MISMATCH, self.verify, selection, mutated, require)
        for value in (None, [], 'events'):
            with self.subTest(events=value):
                self.assertRejects(INVALID, self.verify, selection, value, False)
        # Re-sealed selection changes with refreshed evidence hash still disagree with the stale evidence fields.
        for change in ({'host': 'claude-code'}, {'cli_version': 'codex-cli 0.160.0'},
                       {'binding.run_id': OTHER_RUN}, {'binding.session_id': OTHER_SESSION}):
            with self.subTest(selection_change=change):
                moved = changed(selection, change)
                self.assertRejects(EVIDENCE_MISMATCH, self.verify, moved,
                                   {**events, 'selection_sha256': moved['selection_sha256']}, False)
        moved = changed(selection, {'resolved.native_id': ALT_ID})
        self.assertRejects('native-precedence-conflict', self.verify, moved,
                           {**events, 'selection_sha256': moved['selection_sha256']}, False)
        retargeted = codex_events(moved, thread=native_thread(model=OMIT))
        self.assertEqual(self.assertDelivery(moved, retargeted, False)['configured_id'], ALT_ID)

    def test_delivery_require_actual_id_must_be_a_real_boolean(self):
        value: Any
        selection = selected()
        events = codex_events(selection)
        record = expected_delivery(selection, events, False)
        self.assertDelivery(selection, events, False)
        for value in ('true', 'false', 'True', 1, 0, None, [], 'yes'):
            with self.subTest(require=value):
                self.assertRejects(INVALID, self.verify, selection, events, value)
                self.assertRejects(INVALID, self.consume, record, selection, events, value)
        self.assertRejects(INVALID, self.verify, None, events, False)

    def test_delivery_field_counterparts(self):
        """Mismatch-map rows delivery.*: validate_delivery_record recomputes; every field mutation is rejected."""
        chain = [rerouted(NATIVE_ID, ALT_ID), rerouted(ALT_ID, THIRD_ID)]
        scenarios = []
        for kind in KINDS:
            selection = selected(kind)
            for require in (False, True):
                scenarios.append((kind + '-reroutes', selection, codex_events(selection, notifications=chain),
                                  require, chain))
                scenarios.append((kind + '-plain', selection, codex_events(selection), require, []))
        for host in UNSUPPORTED_HOSTS:
            selection = selected('pinned', host)
            for require in (False, True):
                scenarios.append((host, selection, unsupported_events(selection), require, []))
        covered = set()
        for name, selection, events, require, reroutes in scenarios:
            genuine = expected_delivery(selection, events, require, reroutes)
            with self.subTest(scenario=name, require=require, mutation='none'):
                self.consume(copy.deepcopy(genuine), selection, events, require)
            for path, mutated in delivery_mutations(genuine, selection):
                covered.add(path)
                with self.subTest(scenario=name, require=require, mutation=path):
                    self.assertNotEqual(mutated, genuine)
                    self.assertRejects(CONSUMER_REJECT, self.consume, mutated, selection, events, require)
            with self.subTest(scenario=name, require=require, mutation='require flipped'):
                if expected_delivery(selection, events, not require, reroutes) != genuine:
                    self.assertRejects(CONSUMER_REJECT, self.consume, genuine, selection, events, not require)
        self.assertLessEqual(DELIVERY_FIELDS | {'reroutes[].' + f for f in REROUTE_FIELDS}, covered)

    def test_delivery_consumer_rejects_other_selection_or_evidence_counterparts(self):
        value: Any
        selection = selected()
        events = codex_events(selection)
        genuine = expected_delivery(selection, events, False)
        self.consume(genuine, selection, events, False)
        other = changed(selection, {'resolved.effort': 'low'})
        self.assertRejects(CONSUMER_REJECT, self.consume, genuine, other, codex_events(other), False)
        rerouted_events = codex_events(selection, notifications=[rerouted(NATIVE_ID, ALT_ID)])
        self.assertRejects(CONSUMER_REJECT, self.consume, genuine, selection, rerouted_events, False)
        self.assertRejects(INVALID, self.consume, genuine, pinned_selection(), events, False)
        for value in (None, [], 'delivery'):
            with self.subTest(record=value):
                self.assertRejects(INVALID, self.consume, value, selection, events, False)


def delivery_mutations(genuine, selection):
    """(field path, mutated record) pairs; each differs from the recomputed genuine record."""
    other_reason = {r: next(x for x in DELIVERY_REASONS if x != r) for r in DELIVERY_REASONS}
    native = selection['resolved']['native_id']
    rows: list[tuple[str, Any]] = [
        ('schema', {**genuine, 'schema': 'model-delivery/v2'}),
        ('schema', {**genuine, 'schema': 'Model-Delivery/v1'}),
        ('selection_sha256', {**genuine, 'selection_sha256': sha('other selection')}),
        ('selection_sha256', {**genuine, 'selection_sha256': genuine['selection_sha256'].upper()}),
        ('run_id', {**genuine, 'run_id': OTHER_RUN}),
        ('session_id', {**genuine, 'session_id': OTHER_SESSION}),
        ('turn_id', {**genuine, 'turn_id': OTHER_TURN}),
        ('configured_id', {**genuine, 'configured_id': ALT_ID}),
        ('configured_id', {**genuine, 'configured_id': ALIAS}),
        ('actual_id', {**genuine, 'actual_id': native}),
        ('actual_id', {**genuine, 'actual_id': CLAIMED_ID}),
        ('proof', {**genuine, 'proof': 'host-reported'}),
        ('proof', {**genuine, 'proof': 'host-reported', 'actual_id': native}),
        ('proof', {**genuine, 'proof': 'Unverified'}),
        ('source', {**genuine, 'source': 'unsupported' if genuine['source'] == 'codex-app-server'
                    else 'codex-app-server'}),
        ('source', {**genuine, 'source': 'model-self-attested'}),
        ('status', {**genuine, 'status': 'accepted' if genuine['status'] == 'blocked' else 'blocked'}),
        ('status', {**genuine, 'status': 'Accepted'}),
        ('reason', {**genuine, 'reason': other_reason[genuine['reason']]}),
        ('reason', {**genuine, 'reason': 'unchanged-model-verified'}),
        ('reroutes', {**genuine, 'reroutes': genuine['reroutes'] + [{'thread_id': OTHER_THREAD, 'turn_id': TURN,
                                                                     'from_model': native, 'to_model': ALT_ID,
                                                                     'reason': REROUTE_REASON}]}),
    ]
    for field in DELIVERY_FIELDS:
        rows.append((field, {k: v for k, v in genuine.items() if k != field}))
    rows.append(('schema', {**genuine, 'unexpected': True}))
    if genuine['reroutes']:
        rows.append(('reroutes', {**genuine, 'reroutes': []}))
        rows.append(('reroutes', {**genuine, 'reroutes': genuine['reroutes'][:1]}))
        rows.append(('reroutes', {**genuine, 'reroutes': genuine['reroutes'] + genuine['reroutes'][-1:]}))
        if len(genuine['reroutes']) > 1:
            rows.append(('reroutes', {**genuine, 'reroutes': list(reversed(genuine['reroutes']))}))
        swaps = {'thread_id': OTHER_THREAD, 'turn_id': OTHER_TURN, 'from_model': ALIAS, 'to_model': CLAIMED_ID,
                 'reason': 'fallback'}
        for field, value in swaps.items():
            changed_rows = copy.deepcopy(genuine['reroutes'])
            changed_rows[0][field] = value
            rows.append(('reroutes[].' + field, {**genuine, 'reroutes': changed_rows}))
            erased = copy.deepcopy(genuine['reroutes'])
            del erased[-1][field]
            rows.append(('reroutes[].' + field, {**genuine, 'reroutes': erased}))
        extra = copy.deepcopy(genuine['reroutes'])
        extra[0]['actual_id'] = ALT_ID
        rows.append(('reroutes', {**genuine, 'reroutes': extra}))
    else:
        rows.append(('reroutes', {**genuine, 'reroutes': [{'thread_id': THREAD, 'turn_id': genuine['turn_id'],
                                                           'from_model': native, 'to_model': native,
                                                           'reason': REROUTE_REASON}]}))
    return rows


# ---- CLI: bind / verify-delivery -----------------------------------------------------------------------------

class _Stderr:
    def __init__(self):
        self.buffer = io.BytesIO()

    def write(self, text):
        self.buffer.write(text.encode('utf-8'))
        return len(text)

    def flush(self):
        pass


class CliCase(IdentityCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name) / 'work'
        self.work.mkdir()
        self.outside = Path(self.temp.name) / 'outside'
        self.outside.mkdir()

    def write(self, name, value, raw=False):
        path = self.work / name
        path.write_bytes(value if raw else canonical(value))
        return name

    def run_cli(self, *args):
        return subprocess.run([sys.executable, '-B', str(SCRIPT), *args], cwd=self.work, capture_output=True,
                              timeout=120)

    def spawn(self, *args):
        return subprocess.Popen([sys.executable, '-B', str(SCRIPT), *args], cwd=self.work, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)

    def assertError(self, result, reasons):
        allowed = {reasons} if isinstance(reasons, str) else set(reasons)
        stderr = result.stderr.decode('utf-8', 'replace')
        self.assertEqual(result.returncode, 2, stderr)
        self.assertNotIn('Traceback', stderr)
        try:
            error = strict_load(result.stderr.strip())
        except ValueError as exc:
            self.fail(f'stderr is not one model-policy-error/v1 object ({exc}): {stderr[:300]}')
        self.assertEqual(set(error), {'schema', 'reason', 'message'})
        self.assertEqual(error['schema'], ERROR_SCHEMA)
        self.assertIn(error['reason'], allowed)
        self.assertIn(error['reason'], REASONS)
        self.assertTrue(isinstance(error['message'], str) and error['message'].strip()
                        and len(error['message']) <= MAX_TEXT)
        self.assertNoLeak(stderr)
        return error

    def assertOk(self, result):
        self.assertEqual(result.returncode, 0, result.stderr.decode('utf-8', 'replace'))
        self.assertNotIn(b'Traceback', result.stderr)

    def snapshot(self, *roots):
        state = {}
        for root in roots or (self.work, self.outside):
            for path in sorted(root.rglob('*')):
                info = path.lstat()
                state[str(path)] = (path.is_symlink() and os.readlink(path),
                                    path.is_file() and not path.is_symlink() and path.read_bytes(), info.st_mtime_ns)
        return state

    def bind_args(self, selection='selection.json', output='bound.json', run_id=RUN, session_id=SESSION, attempt='1'):
        return ['bind', '--selection', selection, '--run-id', run_id, '--session-id', session_id,
                '--attempt', attempt, '--output', output]

    def verify_args(self, selection='bound.json', events='events.json', require='false', output='delivery.json'):
        return ['verify-delivery', '--selection', selection, '--events', events, '--require-actual-id', require,
                '--output', output]

    def in_process(self, argv):
        stderr = _Stderr()
        previous = os.getcwd()
        os.chdir(self.work)
        try:
            with patch.object(sys, 'stderr', stderr):
                code = self.mp().main(argv)
        finally:
            os.chdir(previous)
        return code, stderr.buffer.getvalue()


class BindCliTests(CliCase):
    def test_TEST100_cli_bind_writes_canonical_bound_record(self):
        for kind, make in KINDS.items():
            for layout in ('canonical', 'pretty'):
                with self.subTest(kind=kind, layout=layout):
                    raw = canonical(make()) if layout == 'canonical' else json.dumps(make(), indent=2).encode() + b'\n'
                    name = self.write(kind + '-' + layout + '.json', raw, raw=True)
                    output = kind + '-' + layout + '-bound.json'
                    self.assertOk(self.run_cli(*self.bind_args(name, output, attempt='4')))
                    self.assertEqual((self.work / output).read_bytes(), canonical(bound(make(), attempt=4)))
                    self.assertEqual((self.work / name).read_bytes(), raw, 'input selection bytes changed')

    def test_TEST101_cli_identical_rebind_keeps_original_bytes_and_mtime(self):
        self.write('selection.json', pinned_selection())
        self.assertOk(self.run_cli(*self.bind_args()))
        target = self.work / 'bound.json'
        expected = canonical(bound(pinned_selection()))
        self.assertEqual(target.read_bytes(), expected)
        noncanonical = json.dumps(bound(pinned_selection()), indent=3, sort_keys=False).encode() + b'\n\n'
        for label, incumbent in (('canonical', expected), ('noncanonical whitespace', noncanonical)):
            with self.subTest(incumbent=label):
                target.write_bytes(incumbent)
                os.utime(target, ns=(1_700_000_000_000_000_000, 1_700_000_000_000_000_000))
                before = self.snapshot()
                self.assertOk(self.run_cli(*self.bind_args()))
                self.assertEqual(target.read_bytes(), incumbent)
                self.assertEqual(target.stat().st_mtime_ns, 1_700_000_000_000_000_000)
                self.assertEqual(self.snapshot(), before, 'idempotent resume must not write anything')
        with self.subTest(input='already bound identical selection'):
            self.write('already.json', bound(pinned_selection()))
            target.write_bytes(expected)
            before = self.snapshot()
            self.assertOk(self.run_cli(*self.bind_args('already.json')))
            self.assertEqual(self.snapshot(), before)

    def test_TEST101_cli_conflicting_or_malformed_incumbent_is_retained(self):
        self.write('selection.json', pinned_selection())
        self.assertOk(self.run_cli(*self.bind_args(output='fresh.json')))
        incumbents = {
            'different binding': canonical(bound(pinned_selection(), OTHER_RUN)),
            'different selection': canonical(bound(changed(pinned_selection(), {'resolved.native_id': ALT_ID}))),
            'unbound selection': canonical(pinned_selection()),
            'stale digest': canonical(put(bound(pinned_selection()), 'reason', 'edited after binding')),
            'truncated': canonical(bound(pinned_selection()))[:40],
            'empty': b'',
            'array': b'[]',
            'object': b'{}',
            'invalid utf-8': b'\xff\xfe{}',
            'duplicate keys': b'{"schema":"model-selection/v1","schema":"model-selection/v1"}',
            'two objects': canonical(bound(pinned_selection())) + b'\n' + canonical(bound(pinned_selection())),
        }
        for label, incumbent in incumbents.items():
            with self.subTest(incumbent=label):
                target = self.work / 'bound.json'
                target.write_bytes(incumbent)
                os.utime(target, ns=(1_600_000_000_000_000_000, 1_600_000_000_000_000_000))
                before = self.snapshot()
                self.assertError(self.run_cli(*self.bind_args()), 'resume-conflict')
                self.assertEqual(self.snapshot(), before, 'rejected resume must retain incumbent bytes and mtime')

    def test_TEST101_cli_symlink_and_directory_destinations_are_rejected(self):
        self.write('selection.json', pinned_selection())
        self.assertOk(self.run_cli(*self.bind_args(output='fresh.json')))
        real = self.outside / 'linked-target.json'
        real.write_bytes(canonical(bound(pinned_selection())))
        (self.work / 'directory').mkdir()
        cases = ['directory']
        try:
            os.symlink(real, self.work / 'link.json')
            os.symlink(self.outside / 'missing.json', self.work / 'dangling.json')
            os.symlink(self.work / 'fresh.json', self.work / 'inner-link.json')
            cases += ['link.json', 'dangling.json', 'inner-link.json']
        except OSError:
            self.assertEqual(os.name, 'nt', 'symlink creation is only tolerated to fail on Windows')
        for output in cases:
            with self.subTest(output=output):
                before = self.snapshot()
                self.assertError(self.run_cli(*self.bind_args(output=output)), 'input-invalid')
                self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.outside / 'missing.json').exists())

    def test_TEST101_concurrent_identical_binds_validate_one_complete_record(self):
        self.write('selection.json', pinned_selection())
        expected = canonical(bound(pinned_selection()))
        for round_number in range(6):
            with self.subTest(round=round_number):
                output = 'race-%d.json' % round_number
                racers = [self.spawn(*self.bind_args(output=output)) for _ in range(2)]
                results = [(p.communicate(timeout=120), p.returncode) for p in racers]
                for (_out, err), code in results:
                    self.assertEqual(code, 0, err.decode('utf-8', 'replace'))
                self.assertEqual((self.work / output).read_bytes(), expected)
        self.assertEqual(sorted(p.name for p in self.work.iterdir()),
                         sorted(['selection.json'] + ['race-%d.json' % n for n in range(6)]),
                         'temporary publication files leaked')

    def test_TEST101_concurrent_differing_binds_have_exactly_one_winner(self):
        self.write('selection.json', pinned_selection())
        runs = (RUN, OTHER_RUN)
        for round_number in range(6):
            with self.subTest(round=round_number):
                output = 'race-%d.json' % round_number
                racers = [self.spawn(*self.bind_args(output=output, run_id=run)) for run in runs]
                results = [(p.communicate(timeout=120), p.returncode) for p in racers]
                winners = [run for run, (_io, code) in zip(runs, results) if code == 0]
                self.assertEqual(len(winners), 1, [r[0][1].decode('utf-8', 'replace') for r in results])
                for ((_out, err), code) in results:
                    if code != 0:
                        self.assertError(subprocess.CompletedProcess([], code, b'', err), 'resume-conflict')
                self.assertEqual((self.work / output).read_bytes(), canonical(bound(pinned_selection(), winners[0])))
        self.assertEqual(sorted(p.name for p in self.work.iterdir()),
                         sorted(['selection.json'] + ['race-%d.json' % n for n in range(6)]))

    def test_TEST101_publish_failure_leaves_no_partial_target_or_temp(self):
        self.write('selection.json', pinned_selection())
        code, stderr = self.in_process(self.bind_args(output='control.json'))
        self.assertEqual(code, 0, stderr)
        self.assertEqual((self.work / 'control.json').read_bytes(), canonical(bound(pinned_selection())))
        failure = PermissionError(13, 'hard links unavailable in fixture')
        with patch.object(os, 'link', side_effect=failure):
            code, stderr = self.in_process(self.bind_args())
        self.assertEqual(code, 2)
        error = strict_load(stderr.strip())
        self.assertEqual(set(error), {'schema', 'reason', 'message'})
        self.assertIn(error['reason'], REASONS)
        self.assertNotIn(b'Traceback', stderr)
        self.assertFalse((self.work / 'bound.json').exists(), 'publish failure left a target')
        self.assertEqual(sorted(p.name for p in self.work.iterdir()), ['control.json', 'selection.json'])

    def test_TEST101_bound_records_never_use_replace_publication(self):
        self.write('selection.json', pinned_selection())
        forbidden = AssertionError('bound selection must use create-only publication, not replacement')
        with patch.object(os, 'replace', side_effect=forbidden), patch.object(os, 'rename', side_effect=forbidden):
            code, stderr = self.in_process(self.bind_args())
        self.assertEqual(code, 0, stderr)
        self.assertEqual((self.work / 'bound.json').read_bytes(), canonical(bound(pinned_selection())))
        self.assertEqual(sorted(p.name for p in self.work.iterdir()), ['bound.json', 'selection.json'])

    def test_TEST102_cli_changed_selection_requires_new_attempt_and_new_target(self):
        replacement = changed(pinned_selection(), {'resolved.native_id': ALT_ID})
        self.write('selection.json', pinned_selection())
        self.write('changed.json', replacement)
        self.assertOk(self.run_cli(*self.bind_args(output='attempt-1.json')))
        original = (self.work / 'attempt-1.json').read_bytes()
        for label, args in (('same attempt', self.bind_args('changed.json', 'attempt-1.json')),
                            ('new attempt old target', self.bind_args('changed.json', 'attempt-1.json', attempt='2')),
                            ('other session', self.bind_args(output='attempt-1.json', session_id=OTHER_SESSION)),
                            ('other attempt', self.bind_args(output='attempt-1.json', attempt='2'))):
            with self.subTest(case=label):
                before = self.snapshot()
                self.assertError(self.run_cli(*args), 'resume-conflict')
                self.assertEqual(self.snapshot(), before)
        self.assertOk(self.run_cli(*self.bind_args('changed.json', 'attempt-2.json', attempt='2')))
        self.assertEqual((self.work / 'attempt-2.json').read_bytes(), canonical(bound(replacement, attempt=2)))
        self.assertEqual((self.work / 'attempt-1.json').read_bytes(), original)
        self.write('bound-other.json', bound(pinned_selection(), OTHER_RUN))
        self.assertError(self.run_cli(*self.bind_args('bound-other.json', 'other-out.json')), 'resume-conflict')
        self.assertFalse((self.work / 'other-out.json').exists())

    def test_cli_bind_arguments_are_exact(self):
        self.write('selection.json', pinned_selection())
        self.assertOk(self.run_cli(*self.bind_args(output='control.json')))
        base = self.bind_args()
        cases = [[], ['Bind', *base[1:]], ['rebind', *base[1:]], ['bind'], base[:-1], base + ['extra'],
                 base + ['--attempt', '1'], base + ['--force'], base + ['--overwrite', 'true'],
                 ['bind', '--selection=selection.json', *base[3:]], base[:1] + base[3:]]
        for option in ('--selection', '--run-id', '--session-id', '--attempt', '--output'):
            index = base.index(option)
            cases.append(base[:index] + base[index + 2:])
            cases.append(base + [option, base[index + 1]])
        for attempt in ('0', '-1', '1.0', 'one', '', 'true', '0x1', '1e0', '١', ' 1'):
            cases.append(self.bind_args(attempt=attempt))
        for bad in BAD_IDS:
            cases.append(self.bind_args(run_id=bad))
            cases.append(self.bind_args(session_id=bad))
        for argv in cases:
            with self.subTest(argv=argv):
                before = self.snapshot()
                self.assertError(self.run_cli(*argv), 'input-invalid')
                self.assertEqual(self.snapshot(), before)

    def test_cli_unsafe_input_and_output_paths_are_rejected(self):
        self.write('selection.json', pinned_selection())
        self.assertOk(self.run_cli(*self.bind_args(output='control.json')))
        (self.outside / 'selection.json').write_bytes(canonical(pinned_selection()))
        (self.work / 'directory').mkdir()
        (self.work / 'sub').mkdir()
        inputs = ['../outside/selection.json', str(self.outside / 'selection.json'), 'directory', 'missing.json',
                  'sub\\..\\selection.json', 'sub/../selection.json', './selection.json', '',
                  'C:/selection.json', 'selection\n.json']
        outputs = ['../escape.json', str(self.outside / 'absolute.json'), 'directory', 'missing-dir/out.json',
                   'sub/../out.json', 'sub\\out.json', '', 'out\x07.json', 'C:out.json']
        try:
            os.symlink(self.outside / 'selection.json', self.work / 'link-in.json')
            os.symlink(self.outside / 'nothing.json', self.work / 'dangling-in.json')
            os.symlink(self.outside, self.work / 'link-dir', target_is_directory=True)
            inputs += ['link-in.json', 'dangling-in.json', 'link-dir/selection.json']
            outputs += ['link-dir/out.json']
        except OSError:
            self.assertEqual(os.name, 'nt', 'symlink creation is only tolerated to fail on Windows')
        for path in inputs:
            with self.subTest(selection=path):
                before = self.snapshot()
                self.assertError(self.run_cli(*self.bind_args(selection=path)), 'input-invalid')
                self.assertEqual(self.snapshot(), before)
        for path in outputs:
            with self.subTest(output=path):
                before = self.snapshot()
                self.assertError(self.run_cli(*self.bind_args(output=path)), 'input-invalid')
                self.assertEqual(self.snapshot(), before)
        self.assertFalse((Path(self.temp.name) / 'escape.json').exists())

    def test_cli_malformed_selection_bytes_are_rejected_without_output(self):
        good = canonical(pinned_selection())
        self.write('selection.json', good, raw=True)
        self.assertOk(self.run_cli(*self.bind_args(output='control.json')))
        oversized = good + b' ' * (MAX_INPUT_BYTES + 1 - len(good))
        cases = {'invalid utf-8': b'\xff' + good, 'second object': good + b'\n' + good, 'trailing junk': good + b'x',
                 'duplicate key': good[:-1] + b',"reason":"duplicate"}', 'overflow': good[:-1] + b',"x":1e999}',
                 'nan': good[:-1] + b',"x":NaN}', 'array': b'[' + good + b']', 'empty': b'', 'oversized': oversized,
                 'utf-16': json.dumps(pinned_selection()).encode('utf-16')}
        self.assertEqual(len(oversized), MAX_INPUT_BYTES + 1)
        for label, raw in cases.items():
            with self.subTest(case=label):
                self.write('bad.json', raw, raw=True)
                before = self.snapshot()
                self.assertError(self.run_cli(*self.bind_args('bad.json')), 'input-invalid')
                self.assertEqual(self.snapshot(), before)
            (self.work / 'bad.json').unlink()
        self.write('invalid.json', changed(pinned_selection(), {'resolved.effort': 'max'}))
        self.assertError(self.run_cli(*self.bind_args('invalid.json')), 'input-invalid')
        self.write('over.json', changed(pinned_selection(), {'estimate.amount': 9.0}))
        self.assertError(self.run_cli(*self.bind_args('over.json')), 'budget-unverifiable')
        self.assertFalse((self.work / 'bound.json').exists())


class VerifyDeliveryCliTests(CliCase):
    def stage(self, selection, events):
        self.write('bound.json', selection)
        self.write('events.json', events)

    def test_TEST133_cli_codex_branches_persist_delivery_and_block_with_exit_2(self):
        selection = selected()
        events = codex_events(selection)
        self.stage(selection, events)
        self.assertOk(self.run_cli(*self.verify_args(output='accepted.json')))
        self.assertEqual((self.work / 'accepted.json').read_bytes(),
                         canonical(expected_delivery(selection, events, False)))
        result = self.run_cli(*self.verify_args(require='true', output='blocked.json'))
        error = self.assertError(result, 'actual-id-unavailable')
        blocked = expected_delivery(selection, events, True)
        self.assertEqual((self.work / 'blocked.json').read_bytes(), canonical(blocked))
        self.assertEqual(error['reason'], blocked['reason'], 'stderr reason must match persisted blocked delivery')
        self.assertNoLeak((self.work / 'accepted.json').read_text(), (self.work / 'blocked.json').read_text())

    def test_TEST133_cli_unsupported_hosts_both_branches(self):
        for host in UNSUPPORTED_HOSTS:
            with self.subTest(host=host):
                selection = selected('latest', host)
                events = unsupported_events(selection)
                self.stage(selection, events)
                accepted, blocked = host + '-accepted.json', host + '-blocked.json'
                self.assertOk(self.run_cli(*self.verify_args(output=accepted)))
                self.assertEqual((self.work / accepted).read_bytes(),
                                 canonical(expected_delivery(selection, events, False)))
                self.assertError(self.run_cli(*self.verify_args(require='true', output=blocked)),
                                 'actual-id-unavailable')
                self.assertEqual((self.work / blocked).read_bytes(),
                                 canonical(expected_delivery(selection, events, True)))

    def test_TEST108_cli_pinned_reroute_persists_blocked_mismatch(self):
        selection = selected('pinned')
        change = rerouted(NATIVE_ID, ALT_ID)
        events = codex_events(selection, notifications=[change])
        self.stage(selection, events)
        for require in ('false', 'true'):
            with self.subTest(require=require):
                output = 'mismatch-' + require + '.json'
                self.assertError(self.run_cli(*self.verify_args(require=require, output=output)), 'actual-id-mismatch')
                self.assertEqual((self.work / output).read_bytes(),
                                 canonical(expected_delivery(selection, events, require == 'true', [change])))

    def test_TEST132_cli_latest_reroute_is_ordinary_but_still_blocks_required_proof(self):
        selection = selected('latest')
        change = rerouted(NATIVE_ID, ALT_ID)
        events = codex_events(selection, notifications=[change, rerouted(NATIVE_ID, THIRD_ID, OTHER_THREAD)])
        self.stage(selection, events)
        self.assertOk(self.run_cli(*self.verify_args(output='ordinary.json')))
        self.assertEqual((self.work / 'ordinary.json').read_bytes(),
                         canonical(expected_delivery(selection, events, False, [change])))
        self.assertError(self.run_cli(*self.verify_args(require='true', output='gate.json')), 'actual-id-unavailable')
        self.assertEqual((self.work / 'gate.json').read_bytes(),
                         canonical(expected_delivery(selection, events, True, [change])))

    def test_TEST108_cli_native_precedence_conflict_writes_no_delivery(self):
        selection = selected()
        self.stage(selection, codex_events(selection))
        self.assertOk(self.run_cli(*self.verify_args(output='control.json')))
        self.write('events.json', codex_events(selection, thread=native_thread(model=ALT_ID)))
        for require in ('false', 'true'):
            with self.subTest(require=require):
                before = self.snapshot()
                self.assertError(self.run_cli(*self.verify_args(require=require)), 'native-precedence-conflict')
                self.assertEqual(self.snapshot(), before)

    def test_cli_invalid_evidence_writes_nothing_and_preserves_existing_output(self):
        selection = selected()
        self.stage(selection, codex_events(selection))
        self.assertOk(self.run_cli(*self.verify_args(output='control.json')))
        self.write('unbound.json', pinned_selection())
        self.write('extra.json', {**codex_events(selection), 'actual_id': NATIVE_ID})
        self.write('dup.json', [rerouted(NATIVE_ID, ALT_ID)] * 2)
        self.write('dup-events.json', codex_events(selection, notifications=[rerouted(NATIVE_ID, ALT_ID)] * 2))
        self.write('wrong-hash.json', {**codex_events(selection), 'selection_sha256': sha('x')})
        (self.work / 'delivery.json').write_bytes(b'historical delivery bytes')
        for label, args in (('unbound selection', self.verify_args(selection='unbound.json')),
                            ('caller-authored actual_id', self.verify_args(events='extra.json')),
                            ('duplicate reroutes', self.verify_args(events='dup-events.json')),
                            ('events not object', self.verify_args(events='dup.json')),
                            ('wrong selection hash', self.verify_args(events='wrong-hash.json'))):
            with self.subTest(case=label):
                before = self.snapshot()
                self.assertError(self.run_cli(*args), EVIDENCE_MISMATCH)
                self.assertEqual(self.snapshot(), before)
        self.assertEqual((self.work / 'delivery.json').read_bytes(), b'historical delivery bytes')

    def test_cli_verify_arguments_are_exact(self):
        selection = selected()
        self.stage(selection, codex_events(selection))
        self.assertOk(self.run_cli(*self.verify_args(output='control.json')))
        base = self.verify_args()
        cases = [['Verify-Delivery', *base[1:]], ['verify', *base[1:]], ['verify-delivery'], base[:-1],
                 base + ['extra'], base + ['--require-actual-id', 'false'], base + ['--attestation', 'host'],
                 ['verify-delivery', '--require-actual-id=false', *base[1:5], *base[7:]]]
        for option in ('--selection', '--events', '--require-actual-id', '--output'):
            index = base.index(option)
            cases.append(base[:index] + base[index + 2:])
            cases.append(base + [option, base[index + 1]])
        for value in ('True', 'FALSE', 'False', 'TRUE', '1', '0', 'yes', 'no', '', ' false', 'false\n', 'null'):
            cases.append(self.verify_args(require=value))
        for argv in cases:
            with self.subTest(argv=argv):
                before = self.snapshot()
                self.assertError(self.run_cli(*argv), 'input-invalid')
                self.assertEqual(self.snapshot(), before)

    def test_cli_verify_unsafe_paths_and_malformed_evidence_bytes(self):
        selection = selected()
        events = codex_events(selection)
        self.stage(selection, events)
        self.assertOk(self.run_cli(*self.verify_args(output='control.json')))
        (self.outside / 'events.json').write_bytes(canonical(events))
        (self.work / 'directory').mkdir()
        paths = ['../outside/events.json', str(self.outside / 'events.json'), 'directory', 'missing.json',
                 'sub/../events.json', 'events\\json']
        try:
            os.symlink(self.outside / 'events.json', self.work / 'link-events.json')
            os.symlink(self.outside / 'nothing.json', self.work / 'dangling-events.json')
            paths += ['link-events.json', 'dangling-events.json']
        except OSError:
            self.assertEqual(os.name, 'nt', 'symlink creation is only tolerated to fail on Windows')
        for path in paths:
            with self.subTest(events=path):
                before = self.snapshot()
                self.assertError(self.run_cli(*self.verify_args(events=path)), 'input-invalid')
                self.assertEqual(self.snapshot(), before)
        for output in ('../escape.json', 'directory', 'missing-dir/out.json'):
            with self.subTest(output=output):
                before = self.snapshot()
                self.assertError(self.run_cli(*self.verify_args(output=output)), 'input-invalid')
                self.assertEqual(self.snapshot(), before)
        good = canonical(events)
        for label, raw in (('invalid utf-8', b'\xff' + good), ('second object', good + good),
                           ('duplicate key', good[:-1] + b',"host":"codex-cli"}'),
                           ('overflow', good[:-1] + b',"x":1e999}'),
                           ('oversized', good + b' ' * (MAX_INPUT_BYTES + 1 - len(good)))):
            with self.subTest(case=label):
                self.write('bad-events.json', raw, raw=True)
                before = self.snapshot()
                self.assertError(self.run_cli(*self.verify_args(events='bad-events.json')), 'input-invalid')
                self.assertEqual(self.snapshot(), before)

    def test_cli_outputs_and_errors_are_sanitized(self):
        selection = selected()
        events = codex_events(selection, thread=native_thread(model=NATIVE_ID, preview=SECRET + ' ' + SELF_CLAIM),
                              turn=native_turn(items=[agent_message(SECRET)]))
        self.stage(selection, events)
        self.assertOk(self.run_cli(*self.verify_args(output='ok.json')))
        blocked = self.run_cli(*self.verify_args(require='true', output='gate.json'))
        self.assertError(blocked, 'actual-id-unavailable')
        broken = {**events, 'thread_read': {'thread': native_thread(model=SECRET, preview=SECRET)}}
        self.write('broken.json', broken)
        failed = self.run_cli(*self.verify_args(events='broken.json', output='never.json'))
        self.assertError(failed, 'native-precedence-conflict')
        self.assertFalse((self.work / 'never.json').exists())
        for result in (blocked, failed):
            self.assertNoLeak(result.stderr.decode('utf-8', 'replace'), result.stdout.decode('utf-8', 'replace'))
        self.assertNoLeak((self.work / 'ok.json').read_text(), (self.work / 'gate.json').read_text())

    def test_error_contract_counterparts(self):
        selection = selected()
        self.stage(selection, codex_events(selection))
        error = self.assertError(self.run_cli(*self.verify_args(require='true')), 'actual-id-unavailable')
        self.assertEqual(error['reason'], strict_load((self.work / 'delivery.json').read_bytes())['reason'])
        validate = self.fn('validate_error_record')
        validate(error)
        for label, value in (('schema', {**error, 'schema': 'model-policy-error/v2'}),
                             ('reason unknown', {**error, 'reason': 'identity-unverified'}),
                             ('reason case', {**error, 'reason': 'Actual-Id-Unavailable'}),
                             ('message empty', {**error, 'message': ''}),
                             ('message overlong', {**error, 'message': 'x' * (MAX_TEXT + 1)}),
                             ('extra', {**error, 'delivery': 'x'})):
            with self.subTest(mutation=label):
                self.assertRejects(INVALID, validate, value)


# ---- Published wire contracts (independent structural checks) -------------------------------------------------

class SchemaContractTests(IdentityCase):
    """Direct contract declarations only; full validation uses the task-local jsonschema proof."""

    def load(self, name):
        path = CONTRACTS / name
        self.assertTrue(path.is_file(), 'missing published contract ' + name)
        return strict_load(path.read_bytes())

    def node(self, schema, node):
        seen: set[str] = set()
        while '$ref' in node:
            ref = node['$ref']
            self.assertTrue(ref.startswith('#/'), 'only local contract references are expected')
            self.assertNotIn(ref, seen, 'cyclic contract reference')
            seen.add(ref)
            node = schema
            for part in ref[2:].split('/'):
                node = node[part.replace('~1', '/').replace('~0', '~')]
        return node

    def assertClosed(self, schema, node, fields):
        node = self.node(schema, node)
        if node.get('type') != 'object' and 'object' not in (node.get('type') or []):
            branches = [self.node(schema, branch) for key in ('anyOf', 'oneOf')
                        for branch in node.get(key, [])]
            objects = [branch for branch in branches if branch.get('type') == 'object']
            self.assertEqual(len(objects), 1, 'expected one explicit nullable object branch')
            node = objects[0]
        self.assertIs(node.get('additionalProperties'), False)
        self.assertEqual(set(node.get('required', [])), fields)
        self.assertEqual(set(node.get('properties', {})), fields)
        return {key: self.node(schema, value) for key, value in node['properties'].items()}

    def test_selection_schema_closed_fields_and_enums(self):
        schema = self.load('model-selection.schema.json')
        props = self.assertClosed(schema, schema, SELECTION_FIELDS)
        self.assertEqual(props['schema'].get('const'), SELECTION_SCHEMA)
        self.assertEqual(set(props['risk']['enum']), set(RISKS))
        self.assertEqual(set(props['host']['enum']), set(HOSTS))
        nested = {name: self.assertClosed(schema, props[name], fields)
                  for name, fields in NESTED_OBJECTS.items()}
        self.assertEqual(set(nested['requested']['policy']['enum']), set(POLICIES))
        self.assertEqual(set(nested['requested']['policy_source']['enum']), set(PROVENANCE))
        self.assertEqual(set(nested['resolved']['effort']['enum']), set(EFFORTS))
        self.assertEqual(nested['binding']['attempt'].get('type'), 'integer')
        self.assertTrue(nested['binding']['attempt'].get('minimum') == 1 or
                        nested['binding']['attempt'].get('exclusiveMinimum') == 0)
        for name in ('budget', 'estimate'):
            self.assertEqual(nested[name]['amount'].get('type'), 'number')
            self.assertEqual(nested[name]['amount'].get('minimum'), 0)
            unit = nested[name]['unit']
            self.assertTrue(unit.get('const') == 'USD' or unit.get('enum') == ['USD'])
        self.assertEqual(props['update_candidates'].get('type'), 'array')
        self.assertIs(props['update_candidates'].get('uniqueItems'), True)

    def test_delivery_schema_closed_fields_and_enums(self):
        schema = self.load('model-delivery.schema.json')
        props = self.assertClosed(schema, schema, DELIVERY_FIELDS)
        self.assertEqual(props['schema'].get('const'), DELIVERY_SCHEMA)
        self.assertEqual(set(props['proof']['enum']), set(PROOFS))
        self.assertEqual(set(props['status']['enum']), set(DELIVERY_STATUSES))
        self.assertEqual(props['reroutes'].get('type'), 'array')
        self.assertClosed(schema, props['reroutes']['items'], REROUTE_FIELDS)

    def test_schema_digest_patterns_are_lowercase_exact_and_newline_safe(self):
        for name, fields in (
                ('model-selection.schema.json', ('policy_sha256', 'catalog_sha256',
                                                 'observation_sha256', 'selection_sha256')),
                ('model-delivery.schema.json', ('selection_sha256',))):
            schema = self.load(name)
            for field in fields:
                with self.subTest(schema=name, field=field):
                    node = self.node(schema, schema['properties'][field])
                    self.assertEqual(node.get('type'), 'string')
                    self.assertIn('pattern', node)
                    for value in ('0' * 64, 'a' * 64):
                        self.assertIsNotNone(re.search(node['pattern'], value))
                    for value in ('A' * 64, '0' * 63, '0' * 65, 'g' * 64, '0' * 64 + '\n'):
                        self.assertIsNone(re.search(node['pattern'], value), repr(value))








class SupplementalMonetaryMetadataTests(IdentityCase):
    def test_finite_large_integer_amounts_remain_exact_through_binding_and_resume(self):
        record = pinned_selection()
        record['budget']['amount'] = 10 ** 1000
        record['estimate']['amount'] = 10 ** 999
        record = seal(record)
        self.assertIsNone(self.validate(record))
        result = self.bind(record)
        self.assertEqual(result['budget']['amount'], 10 ** 1000)
        self.assertEqual(result['estimate']['amount'], 10 ** 999)
        self.assertIsNone(self.resume(result, record))
        self.assertEqual(result['selection_sha256'], digest(result))
        self.assertEqual(strict_load(canonical(result)), result)
        record['estimate']['amount'] = 10 ** 1001
        self.assertRejects(BUDGET, self.validate, seal(record))

    def test_https_source_metadata_accepts_ipv6_and_rejects_invalid_port_or_userinfo(self):
        contract = SchemaContractTests('test_delivery_schema_closed_fields_and_enums')
        schema = contract.load('model-selection.schema.json')
        estimate = contract.assertClosed(schema, schema['properties']['estimate'], ESTIMATE_FIELDS)
        pattern = estimate['source_url']['pattern']
        for url in ('https://pricing.example.invalid:443/pricing',
                    'https://[::1]/pricing', 'https://[2001:db8::1]:443/pricing'):
            with self.subTest(valid=url):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                self.assertIsNone(self.validate(seal(record)))
                self.assertIsNotNone(re.search(pattern, url), 'producer-accepted HTTPS must match schema')
        for url in ('https://example.invalid:abc/pricing', 'https://@example.invalid/pricing',
                    'https://example.invalid:65536/pricing'):
            with self.subTest(invalid=url):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                self.assertRejects(INVALID, self.validate, seal(record))




class SupplementalHttpsSchemeTests(IdentityCase):
    def test_https_ascii_scheme_case_variants_match_producer_and_schema(self):
        contract = SchemaContractTests('test_delivery_schema_closed_fields_and_enums')
        schema = contract.load('model-selection.schema.json')
        estimate = contract.assertClosed(schema, schema['properties']['estimate'], ESTIMATE_FIELDS)
        pattern = estimate['source_url']['pattern']
        for mask in range(32):
            scheme = ''.join(letter.upper() if mask & (1 << index) else letter
                             for index, letter in enumerate('https'))
            url = scheme + '://pricing.example.invalid/pricing'
            with self.subTest(scheme=scheme):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                self.assertIsNone(self.validate(seal(record)))
                self.assertIsNotNone(re.search(pattern, url), 'HTTPS scheme is ASCII case insensitive')




class UriAuthorityContractTests(IdentityCase):
    def test_empty_default_ports_bind_without_changing_valid_https_metadata(self):
        contract = SchemaContractTests('test_delivery_schema_closed_fields_and_enums')
        schema = contract.load('model-selection.schema.json')
        pattern = contract.assertClosed(schema, schema['properties']['estimate'], ESTIMATE_FIELDS)['source_url']['pattern']
        for url in ('https://pricing.example.invalid:/pricing', 'HTTPS://pricing.example.invalid:',
                    'https://[::1]:/pricing', 'https://[2001:db8::1]:'):
            with self.subTest(url=url):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                record = seal(record)
                self.assertIsNone(self.validate(record))
                result = self.bind(record)
                self.assertEqual(result['estimate']['source_url'], url)
                self.assertEqual(result['selection_sha256'], digest(result))
                self.assertIsNotNone(re.fullmatch(pattern, url), 'bound producer value must match the published schema')

    def test_original_bracketed_authority_suffix_cannot_be_discarded_by_urlsplit(self):
        for url in ('https://[::1]garbage/pricing', 'https://[::1]garbage:443/pricing',
                    'https://[2001:db8::1]unexpected/pricing'):
            with self.subTest(url=url):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                self.assertRejects(INVALID, self.validate, seal(record))


class UriAuthorityCliTests(CliCase):
    def test_cli_bound_record_conforms_to_original_uri_authority_and_preserves_rejections(self):
        contract = SchemaContractTests('test_delivery_schema_closed_fields_and_enums')
        schema = contract.load('model-selection.schema.json')
        pattern = contract.assertClosed(schema, schema['properties']['estimate'], ESTIMATE_FIELDS)['source_url']['pattern']
        for index, url in enumerate(('https://pricing.example.invalid:/pricing', 'https://[::1]:/pricing')):
            with self.subTest(valid=url):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                name = self.write('valid-%s.json' % index, seal(record))
                output = 'bound-%s.json' % index
                self.assertOk(self.run_cli(*self.bind_args(selection=name, output=output)))
                bound_record = strict_load((self.work / output).read_bytes())
                self.assertEqual(bound_record, bound(record))
                self.assertIsNotNone(re.fullmatch(pattern, bound_record['estimate']['source_url']))
        for index, url in enumerate(('https://[::1]garbage/pricing', 'https://[::1]garbage:443/pricing')):
            with self.subTest(invalid=url):
                record = pinned_selection()
                record['estimate']['source_url'] = url
                name = self.write('invalid-%s.json' % index, seal(record))
                output = 'rejected-%s.json' % index
                before = self.snapshot()
                self.assertError(self.run_cli(*self.bind_args(selection=name, output=output)), INVALID)
                self.assertFalse((self.work / output).exists())
                self.assertEqual(self.snapshot(), before)




class UriOriginalStringTests(IdentityCase):
    def test_leading_nonwhitespace_controls_cannot_be_normalized_into_https_metadata(self):
        for code in (0, 1, 27):
            with self.subTest(control=code):
                record = pinned_selection()
                record['estimate']['source_url'] = chr(code) + 'https://pricing.example.invalid/pricing'
                self.assertRejects(INVALID, self.validate, seal(record))


if __name__ == '__main__':
    unittest.main()
