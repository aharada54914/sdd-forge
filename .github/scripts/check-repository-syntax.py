#!/usr/bin/env python3
"""Deterministic JSON / YAML syntax check of tracked repository files (issue #620).

Usage: check-repository-syntax.py [--root DIR] [--path REL ...]

Inventory is `git ls-files -z --cached` (tracked and staged paths) ending in
.json/.yaml/.yml, read from current working-tree bytes, plus untracked files
named with --path (a portable relative path: '/'-separated, no backslash,
colon, empty, '.' or '..' segment). Other untracked candidates are never read
or named; they are only counted, and while any remain coverage is incomplete
and the result is fail.

JSON is strict UTF-8 JSON (no BOM, no NaN/Infinity) and is never retried as
YAML. YAML is strict UTF-8 parsed by PyYAML safe_load_all; a leading BOM is
legal YAML. Only the exact path+SHA256 records below are exceptional, and
every one must be present. Exit 0 pass, 1 syntax failure or incomplete
coverage, 2 usage/git/dependency error. Output is one JSON object on stdout
with paths and fixed categories only, never content.
This is syntax validation only, not schema or consumer compatibility.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys

SCHEMA = 'repository-syntax-check/v1'
SUFFIXES = {'.json': 'json', '.yaml': 'yaml', '.yml': 'yaml'}
NEGATIVE = 'tests/fixtures/capability-resolver/resolve-project-context-block/contract-discovery-failed-governing-schema-'
# Intentional invalid inputs owned by tests/resolve-project-context-block-check.py: must fail exactly so.
EXPECTED_NEGATIVE = {
    NEGATIVE + 'malformed/resolver-evidence.schema.json':
        ('54dcf34a93a6f8f1c7b9132fd8dfa9cf9f9789fe2e63d83075202d5955e92c4f', 'invalid_json'),
    NEGATIVE + 'invalid-utf8/resolver-evidence.schema.json':
        ('919024a80c6fa2b10274aa97b72c380f4c001c01504aca6851d5ee3ed3e1262a', 'invalid_utf8'),
}
# Frozen historical evidence with one leading UTF-8 BOM; stripped in memory only.
LEGACY_BOM = {
    'reports/runs/RUN-20260711T012801Z-epic-136-phase1-rce.json':
        'e3c6fe0c8cee2ca073206b8ca1620d6ea31c69daf95be8e956580457f0ca446e',
    'reports/task-review/epic-136-phase2-gates/attempt-2/round-3/reviewer-a.json':
        '4a44ec7f94b763de9e8d88c02b3bb72567c52bb656a8e19e9f2178322474e647',
    'reports/task-review/epic-136-phase2-gates/attempt-2/round-3/reviewer-b.json':
        '832876531f8b739c43583eaf8eaf86e3c240e4624edb6b7d69ec983fdd12c4fe',
    'reports/task-review/epic-136-phase2-gates/attempt-2/round-3/task-review-contract.json':
        'a6ae90890b0ebb0531ef719526121844c33b4c96ee2fd64963cabb5e7e82f698',
    'specs/epic-136-phase2-gates/verification/T-005.cross-model.json':
        'e74e3713fb36415856686f1f1124d6e21f6d24c905eaa00e90b8783ef438ca1d',
    'specs/epic-136-phase2-gates/verification/T-006.cross-model.json':
        'd203f801e050f544d20368a9ed82004887af30964cc4615bf65cac8216d46de7',
}
BOM = b'\xef\xbb\xbf'


def stop(category):
    print(json.dumps({'schema': SCHEMA, 'result': 'error', 'category': category}))
    raise SystemExit(2)


def git_paths(root, *args):
    try:
        out = subprocess.run(['git', '-C', str(root), 'ls-files', '-z', *args],
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        stop('git')
    return {os.fsdecode(p) for p in out.split(b'\0') if p and PurePosixPath(os.fsdecode(p)).suffix in SUFFIXES}


def reject_constant(name):
    raise ValueError(name)


def parse(kind, data, yaml):
    """Return None when valid, else a fixed failure category."""
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return 'invalid_utf8'
    if kind == 'json' and text.startswith('﻿'):
        return 'bom'
    try:
        if kind == 'json':
            json.loads(text, parse_constant=reject_constant)
        else:
            for _ in yaml.safe_load_all(text):
                pass
    except Exception:  # Any parser exception (incl. recursion) is a syntax failure; details are not printed.
        return 'invalid_' + kind
    return None


def read(root, rel):
    """Return (bytes, None) or (None, category) without following symlinks."""
    path = root / rel
    try:
        if path.resolve() != root / rel:
            return None, 'symlink'
        if not stat.S_ISREG(os.lstat(path).st_mode):
            return None, 'not_regular'
        return path.read_bytes(), None
    except FileNotFoundError:
        return None, 'missing'
    except (OSError, RuntimeError):
        return None, 'unreadable'


def portable(rel):
    """Lexical check, independent of the host OS, done before any filesystem access."""
    parts = rel.split('/')
    return ('\\' not in rel and ':' not in rel
            and all(part not in ('', '.', '..') for part in parts)
            and PurePosixPath(rel).suffix in SUFFIXES)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument('--path', action='append', default=[])
    options = parser.parse_args()
    try:
        import yaml
    except ImportError:
        stop('dependency_missing')
    root = Path(options.root).resolve()
    try:
        top = subprocess.run(['git', '-C', str(root), 'rev-parse', '--show-toplevel'],
                             capture_output=True, text=True, check=False).stdout.strip()
    except OSError:
        stop('git')
    if not top or Path(top).resolve() != root:
        stop('usage')
    tracked = git_paths(root, '--cached')
    untracked = git_paths(root, '--others', '--exclude-standard')
    explicit = set()
    for rel in options.path:
        if not portable(rel) or not (root / rel).exists():
            stop('usage')
        if rel not in tracked:
            explicit.add(rel)
    candidates = sorted(tracked | explicit)

    counts = {'json': 0, 'yaml': 0, 'explicit': len(explicit), 'untracked_unchecked': len(untracked - explicit)}
    failures, legacy, negative = [], [], []
    for rel in candidates:
        kind = SUFFIXES[PurePosixPath(rel).suffix]
        counts[kind] += 1
        data, category = read(root, rel)
        if data is not None:
            digest = hashlib.sha256(data).hexdigest()
            if rel in EXPECTED_NEGATIVE:
                expected_digest, expected = EXPECTED_NEGATIVE[rel]
                if digest == expected_digest and parse(kind, data, yaml) == expected:
                    negative.append(rel)
                    continue
                category = 'stale_exception'
            elif rel in LEGACY_BOM:
                if digest == LEGACY_BOM[rel] and data.startswith(BOM):
                    category = parse(kind, data[len(BOM):], yaml)
                    if category is None:
                        legacy.append(rel)
                else:
                    category = 'stale_exception'
            else:
                category = parse(kind, data, yaml)
        if category:
            failures.append({'path': rel, 'category': category})
    # An exception record absent from the inventory must fail, never pass silently.
    failures += [{'path': rel, 'category': 'missing_exception'}
                 for rel in EXPECTED_NEGATIVE.keys() | LEGACY_BOM.keys() if rel not in candidates]
    failures.sort(key=lambda f: f['path'])

    # An unvalidated untracked candidate fails the run; it is reported by count only.
    complete = counts['untracked_unchecked'] == 0
    passed = complete and not failures
    print(json.dumps({
        'schema': SCHEMA, 'result': 'pass' if passed else 'fail', 'counts': counts,
        'complete_candidate_coverage': complete,
        'legacy_bom': legacy, 'expected_negative': negative, 'failures': failures,
    }, ensure_ascii=True))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
