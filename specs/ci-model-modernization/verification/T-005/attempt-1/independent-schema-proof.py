#!/usr/bin/env python3
"""Independent T-005 schema/consumer proof. Run only after Root admits candidate inputs.

Requires already-installed jsonschema. Never invokes a native host or modifies source.
Writes new task-local receipts; a schema pass is never a native provenance claim.
"""
from __future__ import annotations

import argparse
import copy
from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
from typing import Any, Callable

Json = dict[str, Any]
STAMP = '2026-10-19T19:00:00Z'
HASH = 'a' * 64
SELECTION_FIELDS = {
    'schema', 'role', 'risk', 'host', 'cli_version', 'scope_id', 'requested', 'resolved',
    'policy_sha256', 'catalog_sha256', 'observation_sha256', 'observed_at', 'source_date',
    'reason', 'update_candidates', 'binding', 'selection_sha256', 'budget', 'estimate',
}
DELIVERY_FIELDS = {
    'schema', 'selection_sha256', 'run_id', 'session_id', 'turn_id', 'configured_id',
    'actual_id', 'proof', 'source', 'reroutes', 'status', 'reason',
}
NESTED_SELECTION = {
    'requested': {'policy', 'model_id', 'policy_source', 'model_source'},
    'resolved': {'catalog_id', 'native_id', 'effort', 'effort_control'},
    'binding': {'run_id', 'session_id', 'attempt'},
    'budget': {'amount', 'unit'},
    'estimate': {'catalog_id', 'amount', 'unit', 'source_url', 'source_date'},
}
REROUTE_FIELDS = {'thread_id', 'turn_id', 'from_model', 'to_model', 'reason'}


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def seal(record: Json) -> Json:
    value = copy.deepcopy(record)
    value['selection_sha256'] = digest(canonical({k: v for k, v in value.items()
                                                 if k != 'selection_sha256'}))
    return value


def selection() -> Json:
    return seal({
        'schema': 'model-selection/v1', 'role': 'implementer', 'risk': 'high',
        'host': 'codex-cli', 'cli_version': 'codex-cli 0.159.2', 'scope_id': 'client-fixture',
        'requested': {'policy': 'pinned', 'model_id': 'model-alias',
                      'policy_source': 'cli', 'model_source': 'cli'},
        'resolved': {'catalog_id': 'openai/model-a', 'native_id': 'model-a',
                     'effort': 'high', 'effort_control': 'flag'},
        'policy_sha256': HASH, 'catalog_sha256': 'b' * 64, 'observation_sha256': 'c' * 64,
        'observed_at': STAMP, 'source_date': STAMP, 'reason': 'Explicit pinned fixture.',
        'update_candidates': ['model-c'],
        'binding': {'run_id': 'run-fixture', 'session_id': 'session-fixture', 'attempt': 1},
        'budget': {'amount': 2, 'unit': 'USD'},
        'estimate': {'catalog_id': 'openai/model-a', 'amount': 1, 'unit': 'USD',
                     'source_url': 'https://example.invalid/pricing', 'source_date': STAMP},
    })


def host_events(record: Json) -> Json:
    return {
        'host': record['host'], 'cli_version': record['cli_version'],
        'selection_sha256': record['selection_sha256'], 'run_id': 'run-fixture',
        'session_id': 'session-fixture', 'thread_id': 'thread-fixture', 'turn_id': 'turn-fixture',
        'thread_read': {'thread': {
            'id': 'thread-fixture', 'sessionId': 'session-fixture', 'model': 'model-a',
            'cliVersion': '0.158.0', 'createdAt': 1, 'updatedAt': 2, 'cwd': '/fixture',
            'ephemeral': True, 'modelProvider': 'openai', 'preview': '', 'projectId': None,
            'source': 'appServer', 'status': {'type': 'idle'}, 'turns': [],
            'reasoningEffort': 'high',
        }},
        'turn_start': {'turn': {'id': 'turn-fixture', 'items': [], 'status': 'inProgress'}},
        'notifications': [],
    }


def expected_delivery(record: Json, *, required: bool = False,
                      reroutes: list[Json] | None = None) -> Json:
    changed = bool(reroutes) and record['requested']['policy'] == 'pinned'
    return {
        'schema': 'model-delivery/v1', 'selection_sha256': record['selection_sha256'],
        'run_id': record['binding']['run_id'], 'session_id': record['binding']['session_id'],
        'turn_id': 'turn-fixture', 'configured_id': record['resolved']['native_id'],
        'actual_id': None, 'proof': 'unverified',
        'source': 'codex-app-server' if record['host'] == 'codex-cli' else 'unsupported',
        'reroutes': reroutes or [], 'status': 'blocked' if changed or required else 'accepted',
        'reason': ('actual-id-mismatch' if changed else 'actual-id-unavailable' if required else
                   'reroute-observed' if reroutes else 'identity-unverified'),
    }


def set_path(record: Json, path: str, value: Any) -> Json:
    result = copy.deepcopy(record)
    cursor: Any = result
    parts = path.split('.')
    for part in parts[:-1]:
        cursor = cursor[int(part)] if isinstance(cursor, list) else cursor[part]
    last = parts[-1]
    if isinstance(cursor, list):
        cursor[int(last)] = value
    else:
        cursor[last] = value
    return result


def get_path(record: Json, path: str) -> Any:
    cursor: Any = record
    for part in path.split('.'):
        cursor = cursor[int(part)] if isinstance(cursor, list) else cursor[part]
    return cursor


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--native-schema-dir', type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    results: list[Json] = []
    source_receipts: list[Json] = []

    def source(path: Path) -> bytes:
        raw = path.read_bytes()
        source_receipts.append({'path': str(path.resolve()), 'sha256': digest(raw)})
        return raw

    def check(name: str, layer: str, action: Callable[[], None]) -> None:
        try:
            action()
        except Exception as error:
            results.append({'case': name, 'layer': layer, 'status': 'FAIL',
                            'error': type(error).__name__ + ': ' + str(error)[:512]})
        else:
            results.append({'case': name, 'layer': layer, 'status': 'PASS'})

    def require(ok: bool, message: str) -> None:
        if not ok:
            raise AssertionError(message)

    # No silent skip if jsonschema or its optional RFC3339 extra is absent.
    import jsonschema
    checker = jsonschema.FormatChecker()
    calendar_calls: list[str] = []

    @checker.checks('date-time')
    def calendar(value: Any) -> bool:
        if not isinstance(value, str):
            return True  # JSON Schema's type assertion is separate.
        calendar_calls.append(value)
        match = re.fullmatch(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?Z', value)
        if match is None:
            return False
        try:
            datetime.strptime(match[1], '%Y-%m-%dT%H:%M:%S')
        except ValueError:
            return False
        return True

    schemas: dict[str, Any] = {}
    validators: dict[str, Any] = {}
    for kind in ('selection', 'delivery'):
        schema = json.loads(source(root / f'contracts/model-{kind}.schema.json'))
        jsonschema.Draft202012Validator.check_schema(schema)
        schemas[kind] = schema
        validators[kind] = jsonschema.Draft202012Validator(schema, format_checker=checker)
    helper_path = root / 'plugins/sdd-implementation/scripts/model-policy.py'
    source(helper_path)
    module_spec = importlib.util.spec_from_file_location('t005_independent_candidate', helper_path)
    if module_spec is None or module_spec.loader is None:
        raise RuntimeError('Cannot import admitted helper')
    helper = importlib.util.module_from_spec(module_spec)
    sys.modules[module_spec.name] = helper
    module_spec.loader.exec_module(helper)

    def schema_accepts(kind: str, value: Json, accepted: bool) -> None:
        actual = validators[kind].is_valid(value)
        require(actual == accepted, f'{kind} schema accepted={actual}, expected={accepted}')

    def runtime_accepts(kind: str, value: Json, accepted: bool,
                        events: Json | None = None, original: Json | None = None,
                        required: bool = False) -> None:
        try:
            if kind == 'selection':
                helper.validate_selection_record(value)
            else:
                helper.validate_delivery_record(value, selection=original, events=events,
                                                require_actual_id=required)
        except helper.PolicyError:
            actual = False
        else:
            actual = True
        require(actual == accepted, f'{kind} runtime accepted={actual}, expected={accepted}')

    def pair(kind: str, value: Json, *, schema_ok: bool, runtime_ok: bool,
             events: Json | None = None, original: Json | None = None,
             required: bool = False) -> None:
        schema_accepts(kind, value, schema_ok)
        runtime_accepts(kind, value, runtime_ok, events, original, required)

    base = selection()
    events = host_events(base)
    delivered = expected_delivery(base)
    check('selection.base', 'schema+runtime', lambda: pair('selection', base, schema_ok=True, runtime_ok=True))
    check('delivery.base', 'schema+runtime', lambda: pair('delivery', delivered, schema_ok=True,
          runtime_ok=True, original=base, events=events))
    check('selection.fields', 'wire-inventory', lambda: require(
        set(schemas['selection']['required']) == SELECTION_FIELDS and
        set(schemas['selection']['properties']) == SELECTION_FIELDS, 'Selection wire fields drifted'))
    check('delivery.fields', 'wire-inventory', lambda: require(
        set(schemas['delivery']['required']) == DELIVERY_FIELDS and
        set(schemas['delivery']['properties']) == DELIVERY_FIELDS, 'Delivery wire fields drifted'))

    native_schemas = {}
    for filename in ('ThreadReadResponse.json', 'TurnStartResponse.json', 'ModelReroutedNotification.json'):
        native_schemas[filename] = json.loads(source(args.native_schema_dir / filename))
    for filename, value in [('ThreadReadResponse.json', events['thread_read']),
                            ('TurnStartResponse.json', events['turn_start'])]:
        check('native-fixture.' + filename, 'native-structure-only',
              lambda filename=filename, value=value: jsonschema.Draft7Validator(
                  native_schemas[filename]).validate(value))

    # Every owned required field is deleted separately; every object rejects an extra property.
    for kind, record, groups in [('selection', base, {'': SELECTION_FIELDS, **NESTED_SELECTION}),
                                 ('delivery', delivered, {'': DELIVERY_FIELDS})]:
        for object_path, fields in groups.items():
            for field in sorted(fields):
                changed = copy.deepcopy(record)
                target = get_path(changed, object_path) if object_path else changed
                target.pop(field)
                check(f'{kind}.missing.{object_path}.{field}', 'schema+runtime',
                      lambda changed=changed, kind=kind: pair(kind, changed, schema_ok=False,
                          runtime_ok=False, original=base, events=events))
            changed = copy.deepcopy(record)
            target = get_path(changed, object_path) if object_path else changed
            target['undeclared'] = True
            check(f'{kind}.unknown.{object_path}', 'schema+runtime',
                  lambda changed=changed, kind=kind: pair(kind, changed, schema_ok=False,
                      runtime_ok=False, original=base, events=events))

    bad_values = {
        'schema': ['model-selection/v2', 'Model-selection/v1', None],
        'role': ['', 'role\n', 'a' * 129, 1], 'risk': ['HIGH', 'unknown', None],
        'host': ['Codex-cli', 'unknown', None], 'cli_version': ['', 'x\n', 'x' * 129, 1],
        'scope_id': ['--flag', 'a b', 'a;b', 'a/b\n', 'é', 'a' * 129, None],
        'requested.policy': ['Pinned', 'unknown', 1],
        'requested.model_id': ['--flag', 'a b', 'a;b', 'id\n', 'é', 'x' * 129],
        'requested.policy_source': ['CLI', 'unknown', None],
        'requested.model_source': ['CLI', 'unknown', 1],
        'resolved.catalog_id': ['', '--flag', 'id\n', None],
        'resolved.native_id': ['', 'a b', 'id\n', 'é', 'x' * 129, None],
        'resolved.effort': ['max', 'ultra', 'HIGH', None],
        'resolved.effort_control': ['', ' ', 'x' * 513, None],
        'policy_sha256': ['A' * 64, 'a' * 63, HASH + '\n', None],
        'catalog_sha256': ['A' * 64, HASH + '\n', None],
        'observation_sha256': ['A' * 64, HASH + '\n', None],
        'observed_at': ['2026-02-30T00:00:00Z', '2026-10-19T19:00:00+00:00', STAMP + '\n', None],
        'source_date': ['2026-02-30T00:00:00Z', '2026-10-19T19:00:00z', None],
        'reason': ['', ' ', 'x' * 513, None],
        'update_candidates': [['x', 'x'], ['--flag'], ['x\n'], [1], None],
        'binding.run_id': ['', '--flag', 'run\n', None],
        'binding.session_id': ['', 'id\n', None], 'binding.attempt': [0, -1, True, 1.5, '1', None],
        'budget.amount': [-1, True, '1', None], 'budget.unit': ['usd', 'credits', None],
        'estimate.catalog_id': ['', 'x\n', None], 'estimate.amount': [-1, True, '1', None],
        'estimate.unit': ['usd', 'credits', None],
        'estimate.source_url': ['http://example.invalid', 'not-a-url', None],
        'estimate.source_date': ['2026-02-30T00:00:00Z', STAMP + '\n', None],
        'selection_sha256': ['A' * 64, HASH + '\n', None],
    }
    for path, values in bad_values.items():
        for index, value in enumerate(values):
            changed = set_path(base, path, value)
            if path != 'selection_sha256':
                changed = seal(changed)
            check(f'selection.invalid.{path}.{index}', 'schema+runtime',
                  lambda changed=changed: pair('selection', changed, schema_ok=False, runtime_ok=False))

    # Positive syntax cases are independent of live access or T-006 eligibility.
    for name, changed in [
        ('unbound', set_path(base, 'binding', None)),
        ('unknown-price', {**base, 'budget': None, 'estimate': None}),
        ('zero-budget', {**base, 'budget': {'amount': 0, 'unit': 'USD'},
                         'estimate': {**base['estimate'], 'amount': 0}}),
        ('long-fraction', set_path(base, 'observed_at', '2026-10-19T19:00:00.12345678901234567890Z')),
        ('record-only-control', set_path(base, 'resolved.effort_control', 'none')),
        ('latest-compatible', {**base, 'requested': {'policy': 'latest-compatible', 'model_id': None,
                                'policy_source': 'shipped', 'model_source': None}}),
    ]:
        changed = seal(changed)
        check('selection.positive.' + name, 'schema+runtime',
              lambda changed=changed: pair('selection', changed, schema_ok=True, runtime_ok=True))
    check('calendar-checker-executed', 'test-harness', lambda: require(
        STAMP in calendar_calls and '2026-02-30T00:00:00Z' in calendar_calls,
        'Explicit stdlib date-time checker was not exercised by the actual schema'))

    # Valid shapes with cross-field inconsistency: JSON Schema is not a two-record comparator.
    for name, changed in [
        ('estimate-catalog', set_path(base, 'estimate.catalog_id', 'openai/other')),
        ('estimate-over-budget', set_path(base, 'estimate.amount', 3)),
        ('budget-missing-estimate', set_path(base, 'estimate', None)),
        ('pinned-no-id', set_path(base, 'requested.model_id', None)),
    ]:
        changed = seal(changed)
        check('selection.semantic.' + name, 'consumer-consistency',
              lambda changed=changed: runtime_accepts('selection', changed, False))
    bad_digest = {**base, 'selection_sha256': 'd' * 64}
    check('selection.semantic.digest', 'consumer-consistency', lambda: pair(
        'selection', bad_digest, schema_ok=True, runtime_ok=False))

    # Re-seal each valid changed claim; rejection must compare immutable counterparts, not stale hash.
    valid_changes = {
        'role': 'investigator', 'risk': 'critical', 'host': 'claude-code',
        'cli_version': 'codex-cli 0.159.3', 'scope_id': 'client-other',
        'requested.model_id': 'other-alias', 'requested.policy_source': 'environment',
        'requested.model_source': 'environment', 'resolved.native_id': 'model-b',
        'resolved.effort': 'medium', 'resolved.effort_control': 'none',
        'policy_sha256': 'd' * 64, 'catalog_sha256': 'd' * 64, 'observation_sha256': 'd' * 64,
        'observed_at': '2026-10-19T19:01:00Z', 'source_date': '2026-10-18T19:00:00Z',
        'reason': 'Other valid reason.', 'update_candidates': ['model-d'],
        'binding.run_id': 'run-other', 'binding.session_id': 'session-other', 'binding.attempt': 2,
        'budget.amount': 3, 'estimate.amount': 0.5,
        'estimate.source_url': 'https://example.invalid/other',
        'estimate.source_date': '2026-10-18T19:00:00Z',
    }

    def resume_rejects(candidate: Json) -> None:
        pair('selection', candidate, schema_ok=True, runtime_ok=True)
        try:
            helper.validate_resume_selection(base, candidate)
        except helper.PolicyError as error:
            require(error.reason == 'resume-conflict', 'Expected resume-conflict')
        else:
            raise AssertionError('Changed valid immutable claim was accepted')

    for path, value in valid_changes.items():
        candidate = seal(set_path(base, path, value))
        check('resume.resealed.' + path, 'immutable-consumer',
              lambda candidate=candidate: resume_rejects(candidate))
    changed_catalog = copy.deepcopy(base)
    changed_catalog['resolved']['catalog_id'] = 'openai/model-b'
    changed_catalog['estimate']['catalog_id'] = 'openai/model-b'
    check('resume.resealed.catalog-and-estimate', 'immutable-consumer',
          lambda: resume_rejects(seal(changed_catalog)))

    def delivery_matches(record: Json, captured: Json, required: bool, expected: Json) -> None:
        actual = helper.verify_delivery(record, captured, require_actual_id=required)
        require(actual == expected, 'Delivery differs from independent expected record')
        pair('delivery', actual, schema_ok=True, runtime_ok=True, original=record,
             events=captured, required=required)

    for required in (False, True):
        check('delivery.require.' + str(required), 'consumer-proof-scope',
              lambda required=required: delivery_matches(base, events, required,
                                                          expected_delivery(base, required=required)))
    for host in ('claude-code', 'copilot-cli', 'gemini-cli'):
        record = seal(set_path(base, 'host', host))
        captured = {**host_events(record), 'thread_read': None, 'turn_start': None, 'notifications': []}
        for required in (False, True):
            check('delivery.unsupported.' + host + '.' + str(required), 'consumer-proof-scope',
                  lambda record=record, captured=captured, required=required: delivery_matches(
                      record, captured, required, expected_delivery(record, required=required)))
    native_reroute = {'threadId': 'thread-fixture', 'turnId': 'turn-fixture', 'fromModel': 'model-a',
                      'toModel': 'model-b', 'reason': 'highRiskCyberActivity'}
    normalized = {'thread_id': 'thread-fixture', 'turn_id': 'turn-fixture', 'from_model': 'model-a',
                  'to_model': 'model-b', 'reason': 'highRiskCyberActivity'}
    check('native-fixture.reroute', 'native-structure-only', lambda: jsonschema.Draft7Validator(
          native_schemas['ModelReroutedNotification.json']).validate(native_reroute))
    captured_reroute = {**events, 'notifications': [{'method': 'model/rerouted', 'params': native_reroute}]}
    blocked = expected_delivery(base, reroutes=[normalized])
    check('delivery.reroute.pinned', 'consumer-proof-scope', lambda: delivery_matches(
          base, captured_reroute, False, blocked))
    for part in ('threadId', 'turnId'):
        unrelated = {**events, 'notifications': [
            {'method': 'model/rerouted', 'params': {**native_reroute, part: 'unrelated'}}]}
        check('delivery.reroute.unrelated.' + part, 'consumer-proof-scope',
              lambda unrelated=unrelated: delivery_matches(base, unrelated, False, delivered))
    for value in (None, 'model-a'):
        captured = copy.deepcopy(events)
        captured['thread_read']['thread']['model'] = value
        check('delivery.configured.' + str(value), 'consumer-proof-scope',
              lambda captured=captured: delivery_matches(base, captured, False, delivered))
    captured = copy.deepcopy(events)
    captured['thread_read']['thread'].pop('model')
    check('delivery.configured.omitted', 'consumer-proof-scope',
          lambda: delivery_matches(base, captured, False, delivered))

    # All persisted delivery fields get explicit counterpart mutation, including every reroute leaf.
    changes = {
        'schema': 'model-delivery/v2', 'selection_sha256': 'd' * 64, 'run_id': 'run-other',
        'session_id': 'session-other', 'turn_id': 'turn-other', 'configured_id': 'model-b',
        'actual_id': 'model-a', 'proof': 'host-reported', 'source': 'self-asserted',
        'reroutes': [], 'status': 'accepted', 'reason': 'identity-unverified',
        'reroutes.0.thread_id': 'thread-other', 'reroutes.0.turn_id': 'turn-other',
        'reroutes.0.from_model': 'model-c', 'reroutes.0.to_model': 'model-c',
        'reroutes.0.reason': 'other',
    }
    for path, value in changes.items():
        changed = set_path(blocked, path, value)
        check('delivery.counterpart.' + path, 'consumer-consistency',
              lambda changed=changed: runtime_accepts('delivery', changed, False,
                                                       captured_reroute, base))
    for field in sorted(REROUTE_FIELDS):
        changed = copy.deepcopy(blocked)
        changed['reroutes'][0].pop(field)
        check('delivery.missing.reroute.' + field, 'schema+runtime',
              lambda changed=changed: pair('delivery', changed, schema_ok=False, runtime_ok=False,
                                           original=base, events=captured_reroute))
    changed = copy.deepcopy(blocked)
    changed['reroutes'][0]['undeclared'] = True
    check('delivery.unknown.reroute', 'schema+runtime', lambda: pair(
          'delivery', changed, schema_ok=False, runtime_ok=False, original=base, events=captured_reroute))
    forged = {**delivered, 'actual_id': 'model-a', 'proof': 'host-reported'}
    check('delivery.forged-positive', 'consumer-consistency', lambda: runtime_accepts(
          'delivery', forged, False, events, base))

    source_receipts.append({'path': str(Path(__file__).resolve()),
                            'sha256': digest(Path(__file__).read_bytes())})
    failures = sum(row['status'] == 'FAIL' for row in results)
    summary = {'schema': 'task-local-schema-proof/v1', 'task_id': 'T-005',
               'cases': len(results), 'failures': failures, 'calendar_checker_calls': len(calendar_calls),
               'native_execution': False, 'sources': source_receipts, 'results': results}
    raw = canonical(summary)
    with (output / 'results.json').open('xb') as stream:
        stream.write(raw + b'\n')
    print(json.dumps({'cases': len(results), 'failures': failures,
                      'results_sha256': digest(raw + b'\n'), 'native_execution': False}))
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
