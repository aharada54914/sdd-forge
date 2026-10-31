#!/usr/bin/env python3
"""Build non-formal attempt-17 input candidates from pinned existing evidence."""
import copy
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
HERE = pathlib.Path(__file__).resolve().parent
SOURCE = ROOT / 'reports/verification/a7-spec-fresh-review-contract-attempt16-20261005.json'
SOURCE_SHA = 'b561635431116926ac3195893f276a2e67ad6fde980de6ce867a0a834816eb03'
OLD_APPROVAL = 'reports/verification/a7-spec-fresh-review-approval-attempt16-20261005.json'
APPROVAL_REL = 'reports/verification/a7-attempt17-recovery-candidate-20261005/approval-audit-attempt17.candidate.json'
CONTRACT_REL = 'reports/verification/a7-attempt17-recovery-candidate-20261005/fresh-review-contract-attempt17.candidate.json'
FEATURE = 'epic-195-a7-compatibility'
ADDED = (
    f'reports/spec-review/{FEATURE}/attempt-16/round-1/precheck-result.json',
    f'reports/spec-review/{FEATURE}/attempt-16/round-1/reviewer-a-host-allocation.json',
    f'reports/spec-review/{FEATURE}/attempt-16/round-1/launch-blocker-note.md',
    f'reports/review-context/{FEATURE}-spec-a16r1-a-invocation.json',
)
EXPECTED_ADDED = (
    'bc35f564ec1a0bd03eb1805a40fdec200d19c5f4b9e6835f06c7d5c264477acd',
    '09d1c7951c26ef046e01f4fe34c9c24c8df81117f173a46179fd8e9b71089db1',
    '04d73ceb0e6f560a31db9470cce2264f2b3e3518f34007cb07dfb2b58d6072ce',
    '04f7b6e81a782a85e28fdf58d6ed05f9daaa47221c8f1ab5e7df7987bbcda21a',
)


def sha(path):
    if not path.is_file() or path.is_symlink():
        raise ValueError('missing or unsafe evidence: ' + str(path))
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def main():
    if HERE.parents[2] != ROOT or sha(SOURCE) != SOURCE_SHA:
        raise ValueError('wrong checkout or changed attempt-16 source contract')
    if (ROOT / f'reports/spec-review/{FEATURE}/attempt-17').exists():
        raise ValueError('attempt 17 already exists; no candidate rewrite')
    old = json.loads(SOURCE.read_bytes())
    if old['next_attempt'] != 16 or old['terminal_attempt'] != 7 or \
            old['partial_attempts'] != list(range(8, 16)) or \
            old['failed_final_round'] != 3 or old['authority']['path'] != OLD_APPROVAL:
        raise ValueError('unexpected attempt-16 source shape')
    if any(sha(ROOT / item['path']) != item['sha256'] for item in old['evidence']):
        raise ValueError('attempt-16 pinned evidence changed')
    spec = ROOT / 'specs' / FEATURE
    current = {
        'requirements_sha256': sha(spec / 'requirements.md'),
        'acceptance_sha256': sha(spec / 'acceptance-tests.md'),
        'investigation_sha256': sha(spec / 'investigation.md'),
        'calibration_sha256': sha(ROOT / 'plugins/sdd-review-loop/references/spec-review-calibration.md'),
    }
    current['input_sha256'] = hashlib.sha256(':'.join(current[key] for key in
        ('requirements_sha256', 'acceptance_sha256', 'investigation_sha256')).encode()).hexdigest()
    if current != old['input_hashes'] or re.findall(
            r'^Spec-Review-Status:\s*(\S+)\s*$',
            (spec / 'requirements.md').read_text(), re.M) != ['Pending']:
        raise ValueError('current Pending input hashes changed')
    if [sha(ROOT / rel) for rel in ADDED] != list(EXPECTED_ADDED):
        raise ValueError('attempt-16 round-1 evidence changed')
    approval_source = json.loads((ROOT / OLD_APPROVAL).read_bytes())
    if approval_source['user_statement'] != '全部承認する\n追加で何回でもレビュー、限定修正して良い' or \
            approval_source['recorded_by_role'] != 'orchestrator' or \
            approval_source['input_hashes'] != old['input_hashes']:
        raise ValueError('existing authorization transcription differs')
    approval = copy.deepcopy(approval_source)
    approval['next_attempt'] = 17
    contract = copy.deepcopy(old)
    contract['next_attempt'] = 17
    contract['partial_attempts'].append(16)
    contract['historical_failed_rounds'] = [{
        'attempt': 15,
        'failed_final_round': contract.pop('failed_final_round'),
        'failed_turn': contract.pop('failed_turn'),
    }]
    contract['authority'] = {'path': APPROVAL_REL}
    evidence = [item for item in contract['evidence'] if item['path'] != OLD_APPROVAL]
    if len(evidence) + 1 != len(contract['evidence']):
        raise ValueError('old approval pin was not unique')
    evidence.extend({'path': rel, 'sha256': expected}
                    for rel, expected in zip(ADDED, EXPECTED_ADDED))
    evidence.append({'path': APPROVAL_REL,
                     'sha256': hashlib.sha256(encode(approval)).hexdigest()})
    if len({item['path'] for item in evidence}) != len(evidence):
        raise ValueError('duplicate evidence path')
    contract['evidence'] = sorted(evidence, key=lambda item: item['path'])
    approval_path = ROOT / APPROVAL_REL
    contract_path = ROOT / CONTRACT_REL
    if approval_path.exists() or contract_path.exists():
        raise ValueError('candidate output exists; preserve it and inspect before changing')
    approval_path.write_bytes(encode(approval))
    contract_path.write_bytes(encode(contract))
    if sha(approval_path) != next(item['sha256'] for item in contract['evidence']
                                  if item['path'] == APPROVAL_REL):
        raise ValueError('approval candidate readback mismatch')
    print('CANDIDATE_ONLY approval_sha256=' + sha(approval_path))
    print('CANDIDATE_ONLY contract_sha256=' + sha(contract_path))


if __name__ == '__main__':
    main()
