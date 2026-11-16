#!/usr/bin/env python3
"""Recompute readiness using the existing CI verifier and current GitHub PR identity.

This is an evidence summary, never a merge command or a replacement for rulesets.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hub_ci', ROOT / 'tests/verification-ci.py')
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


def readiness(root, repository, pr_number, run_id, plan_path, evidence_dir):
    if not ci.repository_identity(repository) or not ci.run_identity(run_id) or pr_number <= 0:
        raise ValueError('invalid GitHub identity')
    endpoint = f'/repos/{repository}/pulls/{pr_number}'
    before, _ = ci.api_get(endpoint)
    head = before['head']['sha']
    if not re.fullmatch('[a-f0-9]{40}', head):
        raise ValueError('invalid PR revision')
    reasons = []
    if before.get('state') != 'open' or before.get('draft') is not False:
        reasons.append('PR is closed or draft')
    if before.get('mergeable') is not True:
        reasons.append('GitHub mergeability is blocked or unknown')
    if before.get('mergeable_state') != 'clean':
        reasons.append('GitHub required checks/reviews are blocked or unknown')
    manifest = ci.read_json(Path(evidence_dir) / 'collection.json')
    if manifest['repository'] != repository or manifest.get('event_context', {}).get('pr_number') != pr_number:
        raise ValueError('observations do not identify the requested PR')
    context = manifest.get('event_context', {})
    if context.get('head_sha') != head or context.get('base_sha') != before['base']['sha']:
        reasons.append('CI evidence belongs to an older PR head or base')
    result = ci.aggregate(Path(root), ci.read_json(plan_path), Path(evidence_dir), run_id, head)
    ci.validate_result(result)
    if result['status'] != 'PASS':
        reasons.append('Required revision-bound verification did not pass')
    after, _ = ci.api_get(endpoint)
    if (after.get('state') != 'open' or after.get('draft') is not False or
            after.get('mergeable') is not True or after.get('mergeable_state') != 'clean'):
        reasons.append('GitHub mergeability changed or is unknown')
    if after['head']['sha'] != head or after['base']['sha'] != before['base']['sha']:
        reasons.append('PR revision changed during verification')
    evidence = {'result': result, 'pr_head':head, 'pr_base':before['base']['sha'],
                'repository':repository, 'pr_number':pr_number}
    return {'schema':'sdd-merge-readiness/v1', 'head':head,
            'status':'blocked' if reasons else 'ready', 'reasons':reasons,
            'evidenceSha256':hashlib.sha256(ci.P.canonical(evidence)).hexdigest(),
            'checkedAt':int(time.time() * 1000)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--pr', type=int, required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True, help='Existing trusted CI collection directory; never synthesized by the hub')
    args = parser.parse_args()
    try:
        value = readiness(args.root.resolve(), args.repository, args.pr, args.run_id, args.plan, args.evidence_dir)
        print(json.dumps(value, ensure_ascii=False))
        return 0 if value['status'] == 'ready' else 1
    except (ValueError, KeyError, OSError, TypeError):
        print(json.dumps({'error':'verification-unavailable; no readiness claim'}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
