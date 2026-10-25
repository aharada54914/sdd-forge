#!/usr/bin/env python3
"""Offline golden artifact grading and bounded comparison; never launches a model.

Candidate collection belongs to an isolated host executor. Its observed receipts
are inputs, not cryptographic proof or product gate authority. No adoption occurs.
"""
import argparse
import hashlib
import json
import math
import statistics
from pathlib import Path

CASES = Path(__file__).resolve().parent / 'golden'


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON member')
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique_object,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError('non-finite JSON')))


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode() if not isinstance(value, str) else value.encode()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def safe_file(root, name):
    relative = Path(name)
    if relative.is_absolute() or not relative.parts or any(p in ('.', '..') for p in name.split('/')) or '\\' in name or ':' in name:
        raise ValueError('noncanonical artifact path')
    path = root
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('linked artifact')
    if not path.is_file():
        raise ValueError('missing artifact')
    return path


def case(name):
    if not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in name):
        raise ValueError('invalid case')
    data = read_json(CASES / name / 'case.json')
    # Fixture origins are local recorded incidents, not candidate-provided assertions.
    safe_file(CASES.parents[1], data['origin'])
    return data


def grade(name, output):
    data = case(name)
    if output.is_symlink() or not output.is_dir():
        raise ValueError('output must be a real directory')
    failures = []
    expected = data['expected']
    absent = data.get('absent', [])
    permitted = set(data['files']) | set(expected) | {'input.md'}
    for path in output.rglob('*'):
        rel = path.relative_to(output).as_posix()
        if path.is_symlink() or (path.is_file() and rel not in permitted):
            failures.append('unapproved output: ' + rel)
    for name_, content in data['files'].items():
        if name_ in absent:
            if (output / name_).exists() or (output / name_).is_symlink():
                failures.append('owned scratch not removed: ' + name_)
        else:
            try:
                if safe_file(output, name_).read_bytes() != encoded(content):
                    failures.append('source changed: ' + name_)
            except (OSError, ValueError):
                failures.append('source missing or unsafe: ' + name_)
    for name_, value in expected.items():
        try:
            actual = read_json(safe_file(output, name_))
            if type(actual) is not type(value) or encoded(actual) != encoded(value):
                failures.append('incorrect artifact: ' + name_)
        except (OSError, ValueError):
            failures.append('invalid artifact: ' + name_)
    return {'case': name, 'pass': not failures, 'failures': failures}


def snapshot(root):
    entries = {}
    if root.is_symlink() or not root.is_dir():
        raise ValueError('unsafe output root')
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('linked output')
        if path.is_file():
            entries[path.relative_to(root).as_posix()] = digest(path.read_bytes())
    return digest(encoded(entries))


def prepare(name, destination):
    data = case(name)
    if destination.exists() or destination.is_symlink():
        raise ValueError('workspace already exists')
    destination.mkdir(parents=True)
    for rel, value in data['files'].items():
        path = destination / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encoded(value))
    (destination / 'input.md').write_bytes((CASES / name / 'input.md').read_bytes())
    return {'initial_tree_sha256': snapshot(destination), 'case_sha256': digest((CASES / name / 'case.json').read_bytes())}


def number(value, name, positive=False):
    if type(value) not in (int, float) or not math.isfinite(value) or value < 0 or (positive and value == 0):
        raise ValueError('invalid ' + name)
    return value


def compare(manifest_path):
    data = read_json(manifest_path)
    if not isinstance(data, dict) or data.get('schema') != 'golden-comparison/v1':
        raise ValueError('unsupported experiment')
    repeats = data['repetitions']
    if type(repeats) is not int or not 1 <= repeats <= 10:
        raise ValueError('repetitions must be 1..10')
    timeout = number(data['timeout_seconds'], 'timeout', True)
    budget = number(data['total_seconds_limit'], 'budget', True)
    selected = data['cases']
    if not isinstance(selected, list) or not selected or len(set(selected)) != len(selected):
        raise ValueError('invalid case selection')
    if not isinstance(data.get('runs'), list) or any(not isinstance(r, dict) for r in data['runs']):
        raise ValueError('runs must be observation objects')
    if any(type(r.get('repetition')) is not int for r in data['runs']):
        raise ValueError('trial repetition must be an integer')
    if not isinstance(data.get('case_sha256'), dict) or not isinstance(data.get('input_sha256'), dict):
        raise ValueError('missing input pins')
    conditions = data['conditions']
    if not isinstance(conditions, dict) or any(not conditions.get(k) for k in ('model', 'effort', 'host', 'tool_permissions')):
        raise ValueError('missing fixed conditions')
    variants = data['variants']
    if not isinstance(variants, dict) or set(variants) != {'A', 'B'} or any(
            not isinstance(v, dict) or any(not isinstance(v.get(k), str) or not v[k]
            for k in ('framework_revision', 'config_sha256', 'adapter_version')) for v in variants.values()):
        raise ValueError('missing pinned variant composition')
    frozen = data['case_sha256']
    for name in selected:
        case(name)
        if frozen.get(name) != digest((CASES / name / 'case.json').read_bytes()):
            raise ValueError('stale case or rubric')
    expected_order = [(name, variant, n) for name in selected for n in range(1, repeats + 1)
                      for variant in (('A', 'B') if n % 2 else ('B', 'A'))]
    expected = set(expected_order)
    if [(r['case'], r['variant'], r['repetition']) for r in data['runs']] != expected_order:
        raise ValueError('trials must preserve the frozen alternating A/B order')
    for name in selected:
        entries = {rel: digest(encoded(value)) for rel, value in case(name)['files'].items()}
        entries['input.md'] = digest((CASES / name / 'input.md').read_bytes())
        if data['input_sha256'].get(name) != digest(encoded(entries)):
            raise ValueError('initial input does not match frozen fixture')
    seen = set()
    outcomes = []
    total = 0
    for row in data['runs']:
        key = (row['case'], row['variant'], row['repetition'])
        if key not in expected or key in seen:
            raise ValueError('duplicate or unexpected trial')
        seen.add(key)
        duration = number(row['seconds'], 'seconds')
        total += duration
        status = row['status']
        if status not in ('completed', 'failed', 'timeout', 'interrupted', 'not-run'):
            raise ValueError('invalid run status')
        if row.get('conditions') != conditions:
            raise ValueError('unmatched execution conditions')
        if row.get('input_sha256') != data['input_sha256'][row['case']]:
            raise ValueError('unmatched initial input')
        if type(row.get('safety_violation')) is not bool or type(row.get('required_regression')) is not bool:
            raise ValueError('missing safety/regression observation')
        for metric in ('tokens', 'cost'):
            if row.get(metric) is None:
                if not row.get(metric + '_unavailable_reason'):
                    raise ValueError('missing unknown metric reason')
            else:
                number(row[metric], metric)
        result = {'pass': False, 'failures': [status]}
        if status != 'not-run':
            trace_path = safe_file(manifest_path.parent, row['trace'])
            trace_bytes = trace_path.read_bytes()
            if not trace_bytes or digest(trace_bytes) != row['trace_sha256']:
                raise ValueError('missing or changed externally observed tool trace')
        if status == 'completed':
            output_rel = row['output']
            output = manifest_path.parent / output_rel
            # Every completed output is pinned; mtime and candidate PASS text are irrelevant.
            if (Path(output_rel).is_absolute() or any(p in ('', '.', '..') for p in output_rel.split('/'))
                    or '\\' in output_rel or ':' in output_rel
                    or not output.resolve().is_relative_to(manifest_path.parent.resolve())
                    or any(p.is_symlink() for p in [output, *output.parents] if p != manifest_path.parent)):
                raise ValueError('unsafe output location')
            if snapshot(output) != row['output_sha256']:
                raise ValueError('changed output')
            result = grade(row['case'], output)
        passed = result['pass'] and duration <= timeout and not row['safety_violation'] and not row['required_regression']
        outcomes.append(dict(row, passed=passed, grading=result))
    if seen != expected:
        raise ValueError('missing trials; record not-run rather than dropping them')
    groups = {}
    for variant in ('A', 'B'):
        rows = [r for r in outcomes if r['variant'] == variant]
        times = [r['seconds'] for r in rows if r['status'] != 'not-run']
        groups[variant] = {'n': len(rows), 'k': sum(r['passed'] for r in rows), 'all_success': all(r['passed'] for r in rows),
                           'median_seconds': statistics.median(times) if times else None,
                           'range_seconds': [min(times), max(times)] if times else None,
                           'p95': None, 'p95_unavailable_reason': 'small fixed sample; no stable tail claim'}
    refused = total > budget or any(r['safety_violation'] or r['required_regression'] for r in outcomes)
    return {'schema': 'behavioral-comparison/v1', 'manifest_sha256': digest(manifest_path.read_bytes()),
            'groups': groups, 'variants': variants, 'conditions': conditions, 'runs': outcomes, 'budget_exceeded': total > budget,
            'mechanical_criteria_satisfied': not refused and all(r['passed'] for r in outcomes),
            'adoption_eligible': False,
            'adoption_ineligible_reason': 'external collection/trace authenticity and independent safety observations require review',
            'adoption_decision': 'pending-human', 'real_app_evaluation': 'not-performed',
            'collection_provenance': 'externally supplied observations; not independently authenticated',
            'split': {name: case(name)['split'] for name in selected}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ('prepare', 'grade'):
        p = sub.add_parser(command)
        p.add_argument('--case', required=True)
        p.add_argument('--output', type=Path, required=True)
    p = sub.add_parser('compare')
    p.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'prepare':
            result = prepare(args.case, args.output)
        elif args.command == 'grade':
            result = grade(args.case, args.output)
        else:
            result = compare(args.manifest)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return int(args.command == 'grade' and not result['pass'])
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        print(json.dumps({'error': str(exc)}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
