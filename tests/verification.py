#!/usr/bin/env python3
"""Plan and execute registered suites without interpreting workflow source text."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
RUNTIMES = {'bash', 'powershell', 'python'}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def load_catalog(path, root):
    raw = path.read_bytes()
    data = json.loads(raw, object_pairs_hook=unique_object)
    if data.get('schema') != 'verification-catalog/v1':
        raise ValueError('invalid verification catalog schema')
    suites = {}
    for row in data['suites']:
        name = row['path']
        if (not isinstance(name, str) or not re.fullmatch(r'tests/[A-Za-z0-9_./-]+', name)
                or '..' in PurePosixPath(name).parts or str(PurePosixPath(name)) != name):
            raise ValueError('invalid suite path')
        if name in suites or row['runtime'] not in RUNTIMES:
            raise ValueError('duplicate suite or unsupported runtime')
        if not (root / name).is_file() or not (root / name).resolve().is_relative_to(root.resolve()):
            raise ValueError('missing suite or suite outside repository: ' + name)
        for key in ('args', 'host_args'):
            if not isinstance(row.get(key, []), list) or any(not isinstance(arg, str) or '\0' in arg for arg in row.get(key, [])):
                raise ValueError('invalid suite arguments')
        if any(runtime not in RUNTIMES for runtime in row.get('requires', [])):
            raise ValueError('unknown runtime prerequisite')
        suites[name] = row
    assigned = set()
    for profile, paths in data['profiles'].items():
        if not isinstance(paths, list) or not re.fullmatch(r'[a-z0-9-]+', profile) or len(paths) != len(set(paths)):
            raise ValueError('invalid profile or duplicate suite in profile')
        if set(paths) - suites.keys():
            raise ValueError('profile contains unregistered suite')
        assigned.update(paths)
    for name, row in suites.items():
        if set(row.get('optional_in', [])) - data['profiles'].keys():
            raise ValueError('unknown optional profile')
        if row.get('ci_jobs'):
            assigned.add(name)
    for name, row in suites.items():
        seen = set()
        current = name
        while current not in assigned:
            if current in seen or current not in suites:
                raise ValueError('missing or cyclic delegated suite')
            seen.add(current)
            current_row = suites[current]
            if current_row.get('excluded'):
                if not isinstance(current_row['excluded'], str) or not current_row['excluded'].strip():
                    raise ValueError('missing exclusion reason')
                if current != name:
                    raise ValueError('delegated suite parent is excluded')
                break
            current = current_row.get('delegated_to')
            if current is None:
                raise ValueError('suite has no execution profile or explicit exclusion: ' + name)
    candidates = {p.relative_to(root).as_posix() for p in (root / 'tests').rglob('*')
                  if p.is_file() and re.search(r'\.tests\.(sh|ps1|py)$', p.name, re.I)}
    if candidates - suites.keys():
        raise ValueError('unregistered test suites: ' + ', '.join(sorted(candidates - suites.keys())))
    data['_suites'] = suites
    data['_sha256'] = hashlib.sha256(raw).hexdigest()
    return data


def load_weights(path):
    if path is None:
        return {}
    data = json.loads(path.read_bytes(), object_pairs_hook=unique_object)
    if data.get('schema') != 'ci-suite-timings/v1':
        raise ValueError('invalid suite timing schema')
    weights = {name: row['weight_seconds'] for name, row in data['suites'].items()}
    if any(isinstance(w, bool) or not isinstance(w, (int, float)) or not math.isfinite(w) or w <= 0
           for w in weights.values()):
        raise ValueError('suite weights must be finite positive numbers')
    return weights


def shard_suites(paths, count, weights):
    if count < 1:
        raise ValueError('shard count must be positive')
    buckets = [[] for _ in range(count)]
    loads = [0.0] * count
    # Unknown durations use one unit, never an invented observation.
    for path in sorted(paths, key=lambda p: (-weights.get(p, 1), p)):
        index = min(range(count), key=lambda i: (loads[i], i))
        buckets[index].append(path)
        loads[index] += weights.get(path, 1)
    # Keep original execution order inside each independently balanced shard.
    membership = [set(bucket) for bucket in buckets]
    return [[p for p in paths if p in bucket] for bucket in membership]


def runtime_command(runtime, powershell=None, host_args=None):
    host_args = host_args or []
    if runtime == 'python':
        return [sys.executable, '-B'] + host_args
    if runtime == 'powershell':
        executable = shutil.which(powershell or 'pwsh')
        return [executable, '-NoProfile'] + host_args + ['-File'] if executable else None
    executable = shutil.which('bash')
    return [executable] + host_args if executable else None


def repository_state(root):
    try:
        revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root, text=True, capture_output=True, check=False)
        status = subprocess.run(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=root,
                                text=True, capture_output=True, check=False)
    except OSError:
        return None, None
    return (revision.stdout.strip() if revision.returncode == 0 else None,
            not status.stdout if status.returncode == 0 else None)


def execute(catalog, selected, root, profile=None, powershell=None):
    revision, clean_before = repository_state(root)
    receipt = {'schema': 'verification-receipt/v1', 'profile': profile,
               'revision': revision, 'clean_before': clean_before, 'reusable': False,
               'catalog_sha256': catalog['_sha256'], 'selected': selected, 'results': []}
    failed = False
    for name in selected:
        row = catalog['_suites'][name]
        result = {'suite': name, 'source_sha256': hashlib.sha256((root / name).read_bytes()).hexdigest()}
        command = runtime_command(row['runtime'], powershell, row.get('host_args'))
        missing = command is None or any(runtime_command(r, powershell) is None for r in row.get('requires', []))
        start = time.monotonic()
        print('==> ' + name, flush=True)
        if missing:
            optional = profile in row.get('optional_in', [])
            result.update(status='skipped' if optional else 'failed', exit_code=None, reason='missing-runtime')
        else:
            try:
                completed = subprocess.run(command + [name] + row.get('args', []), cwd=root, check=False)
                result.update(status='passed' if completed.returncode == 0 else 'failed', exit_code=completed.returncode)
            except OSError:
                result.update(status='failed', exit_code=None, reason='process-start-failed')
        result['seconds'] = round(time.monotonic() - start, 6)
        receipt['results'].append(result)
        failed |= result['status'] == 'failed'
        print(result['status'].upper() + ': ' + name, flush=True)
    receipt['revision_after'], receipt['clean_after'] = repository_state(root)
    return receipt, int(failed)


def write_receipt(path, receipt):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         prefix=path.name + '.', delete=False) as output:
            temporary = Path(output.name)
            json.dump(receipt, output, indent=2)
            output.write('\n')
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--profile')
    selection.add_argument('--suite')
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--list', action='store_true')
    action.add_argument('--run', action='store_true')
    action.add_argument('--plan', action='store_true')
    parser.add_argument('--catalog', type=Path, default=ROOT / 'tests/verification-catalog.json')
    parser.add_argument('--timings', type=Path, default=ROOT / 'tests/verification-timings.json')
    parser.add_argument('--shard-index', type=int, default=0)
    parser.add_argument('--shard-count', type=int, default=1)
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--powershell')
    args = parser.parse_args()
    try:
        catalog = load_catalog(args.catalog, ROOT)
        if args.suite:
            if args.suite not in catalog['_suites']:
                raise ValueError('unregistered suite')
            paths = [args.suite]
        else:
            if args.profile not in catalog['profiles']:
                raise ValueError('unknown verification profile')
            paths = catalog['profiles'][args.profile]
        if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
            raise ValueError('invalid shard selection')
        weights = load_weights(args.timings)
        selected = shard_suites(paths, args.shard_count, weights)[args.shard_index]
        if args.list:
            if selected:
                print('\n'.join(selected))
            return 0
        if not args.run:
            print(json.dumps({'schema': 'verification-plan/v1', 'profile': args.profile,
                              'selected': selected, 'shard_index': args.shard_index,
                              'shard_count': args.shard_count}, indent=2))
            return 0
        receipt, code = execute(catalog, selected, ROOT, args.profile, args.powershell)
        if args.receipt:
            write_receipt(args.receipt, receipt)
        else:
            print(json.dumps(receipt, separators=(',', ':')))
        return code
    except (ValueError, KeyError, TypeError, OSError):
        # Configuration can point outside the checkout; do not echo local paths.
        print('verification: invalid catalog, selection, timing input, or receipt destination', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
