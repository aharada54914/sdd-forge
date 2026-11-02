#!/usr/bin/env python3
"""Observe candidate impact selection; never execute, skip, or approve a check."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
# README is also a public contract. This is a hypothesis to measure, not safe selection.
README_SUITES = {
    'tests/workflow-documentation.tests.sh',
    'tests/design-system-contract.tests.sh',
    'tests/repository-release-validation.tests.sh',
    'tests/bump-version-gate.tests.sh',
    'tests/spec-review-loop.tests.sh',
}


def changed_paths(root, base, head):
    """No rename detection: both removed and added paths affect the decision."""
    if not base:
        return None, 'base-unavailable'
    try:
        revisions = []
        for ref in (base, head):
            revisions.append(subprocess.run(
                ['git', 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}'],
                cwd=root, check=True, capture_output=True, text=True,
                timeout=30,
            ).stdout.strip())
        result = subprocess.run(
            ['git', 'diff', '--no-renames', '--name-only', '-z', *revisions, '--'],
            cwd=root, check=True, capture_output=True,
            timeout=30,
        )
        return set(result.stdout.decode('utf-8').split('\0')) - {''}, 'diff-available'
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired, UnicodeDecodeError):
        return None, 'diff-unavailable'


def propose(paths, full):
    if paths is None:
        return full.copy(), 'diff-unavailable'
    if not paths:
        return full.copy(), 'no-change-full-baseline'
    if paths != {'README.md'}:
        return full.copy(), 'unknown-or-shared-impact'
    if not README_SUITES.issubset(full):
        return full.copy(), 'candidate-suites-unavailable'
    return [suite for suite in full if suite in README_SUITES], 'readme-only-hypothesis'


def compare(receipts, full, selected, head, catalog_sha256, suite_hashes, workspace_state):
    """Only matching complete observations can finish comparison; skips are unknown."""
    statuses = {}
    rejected = 0
    for receipt in receipts:
        if (workspace_state != (head, True)
                or not isinstance(receipt, dict)
                or receipt.get('schema') != 'verification-receipt/v1'
                or not head or receipt.get('revision') != head
                or receipt.get('revision_after') != head
                or receipt.get('clean_before') is not True
                or receipt.get('clean_after') is not True
                or receipt.get('catalog_sha256') != catalog_sha256
                or not isinstance(receipt.get('results'), list)):
            rejected += 1
            continue
        for result in receipt['results']:
            if not isinstance(result, dict):
                continue
            suite, status = result.get('suite'), result.get('status')
            if (suite not in full or not suite_hashes.get(suite)
                    or result.get('source_sha256') != suite_hashes[suite]):
                continue
            valid = ((status == 'passed' and type(result.get('exit_code')) is int
                      and result['exit_code'] == 0)
                     or (status == 'failed' and type(result.get('exit_code')) is int
                         and result['exit_code'] != 0))
            if valid:
                # A later successful rerun must not erase an observed miss.
                if statuses.get(suite) != 'failed':
                    statuses[suite] = status
    missing = [suite for suite in full if suite not in statuses]
    missed = [suite for suite in full
              if statuses.get(suite) == 'failed' and suite not in selected]
    return {'status': 'incomplete' if missing or workspace_state != (head, True) else 'complete',
            'missed_failures': missed, 'unobserved': missing,
            'rejected_receipts': rejected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base')
    parser.add_argument('--head', default='HEAD')
    parser.add_argument('--profile', default='local-posix')
    parser.add_argument('--receipt', action='append', default=[])
    args = parser.parse_args()
    catalog_path = ROOT / 'tests/verification-catalog.json'
    from verification import load_catalog, repository_state
    try:
        catalog = load_catalog(catalog_path, ROOT)
    except (OSError, ValueError):
        parser.error('verification catalog unavailable or invalid')
    if args.profile not in catalog['profiles']:
        parser.error('unknown catalog profile')
    full = catalog['profiles'][args.profile]
    paths, diff_status = changed_paths(ROOT, args.base, args.head)
    selected, reason = propose(paths, full)
    try:
        head = subprocess.run(
            ['git', 'rev-parse', '--verify', '--end-of-options', args.head + '^{commit}'],
            cwd=ROOT, check=True, capture_output=True, text=True,
            timeout=30,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        head = None
    receipts = []
    for name in args.receipt:
        try:
            receipts.append(json.loads(Path(name).read_text(encoding='utf-8')))
        except (OSError, ValueError):
            receipts.append(None)
    digest = hashlib.sha256(catalog_path.read_bytes()).hexdigest()
    print(json.dumps({
        'schema': 'verification-impact/v1', 'mode': 'shadow',
        'required_checks': 'unchanged', 'profile': args.profile,
        'revision': head, 'diff_status': diff_status, 'reason': reason,
        'changed_path_count': len(paths) if paths is not None else None,
        'selected': selected, 'full_count': len(full),
        'comparison': compare(receipts, full, selected, head, digest, {
            suite: hashlib.sha256((ROOT / suite).read_bytes()).hexdigest()
            for suite in full
        }, repository_state(ROOT)),
    }, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
