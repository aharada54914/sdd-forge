#!/usr/bin/env python3
"""Read-only admission for an explicitly authorized, invalidated review restart.

This is NOT a verdict validator. The caller must validate the returned terminal
contract and both persisted reservations, before and after acquiring its lock.
Only the opt-in fresh-review route depends on Python.
"""
import hashlib
import json
import pathlib
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    def unique(pairs):
        data = {}
        for key, value in pairs:
            require(key not in data, 'duplicate JSON key')
            data[key] = value
        return data
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)


def regular(root, relative):
    require(isinstance(relative, str) and relative and '\\' not in relative,
            'invalid evidence path')
    path = pathlib.PurePosixPath(relative)
    require(not path.is_absolute() and all(p not in ('..', '.') for p in relative.split('/')),
            'evidence must use a canonical repository-relative path')
    target = root / relative
    require(target.is_file() and target.resolve() == target and not target.is_symlink(),
            'missing, symlinked or escaping evidence: ' + relative)
    return target


def validate(root, feature, attempt, contract_path):
    root = root.resolve()
    contract_path = contract_path.absolute()
    require(contract_path.is_file() and contract_path.resolve() == contract_path,
            'contract must be a regular, non-symlink file')
    data = read_json(contract_path)
    require(set(data) == {'schema', 'feature', 'next_attempt', 'reason', 'input_hashes',
                          'evidence', 'transcript'}, 'unexpected fresh-review contract keys')
    require(data['schema'] == 'spec-fresh-review-recovery/v1' and data['feature'] == feature
            and type(data['next_attempt']) is int and data['next_attempt'] == attempt
            and attempt >= 4, 'fresh-review identity mismatch')
    require(data['reason'] == 'failed-first-turn-resumed', 'unsupported invalidation reason')
    base = f'reports/spec-review/{feature}'
    attempts = root / base
    require(max([int(p.name[8:]) for p in attempts.iterdir()
                 if re.fullmatch(r'attempt-[1-9][0-9]*', p.name)] or [0]) == attempt - 1,
            'only the next attempt may be opened')
    hashes = {}
    for name, field in [('requirements.md', 'requirements_sha256'),
                        ('acceptance-tests.md', 'acceptance_sha256'),
                        ('investigation.md', 'investigation_sha256')]:
        rel = f'specs/{feature}/{name}'
        hashes[field] = digest(regular(root, rel)) if (root / rel).exists() else None
    requirements = regular(root, f'specs/{feature}/requirements.md').read_text()
    require(re.findall(r'^Spec-Review-Status:\s*(\S+)\s*$', requirements, re.M) == ['Pending'],
            'fresh-review recovery requires current Pending inputs')
    require(hashes['acceptance_sha256'], 'acceptance tests are required')
    hashes['calibration_sha256'] = digest(regular(root,
        'plugins/sdd-review-loop/references/spec-review-calibration.md'))
    values = [hashes['requirements_sha256'], hashes['acceptance_sha256']]
    if hashes['investigation_sha256']:
        values.append(hashes['investigation_sha256'])
    hashes['input_sha256'] = hashlib.sha256(':'.join(values).encode()).hexdigest()
    require(data['input_hashes'] == hashes, 'current input hashes do not match authorization')
    pinned = {}
    require(isinstance(data['evidence'], list), 'evidence must be an array')
    for entry in data['evidence']:
        require(set(entry) == {'path', 'sha256'} and entry['path'] not in pinned,
                'duplicate or malformed evidence entry')
        require(isinstance(entry['sha256'], str) and
                re.fullmatch('[0-9a-f]{64}', entry['sha256']), 'invalid evidence hash')
        target = regular(root, entry['path'])
        require(digest(target) == entry['sha256'], 'evidence hash mismatch: ' + entry['path'])
        pinned[entry['path']] = target
    expected = set()
    terminal_attempt = attempt - 3
    terminal_root = root / base / f'attempt-{terminal_attempt}'
    terminal_round = max([int(p.name[6:]) for p in terminal_root.iterdir()
                          if re.fullmatch('round-[1-3]', p.name)] or [0])
    require(terminal_round > 0, 'terminal predecessor missing')
    terminal = f'{base}/attempt-{terminal_attempt}/round-{terminal_round}'
    expected.update(f'{terminal}/{name}' for name in ('spec-review-contract.json',
        'precheck-result.json', 'reviewer-a.json', 'reviewer-b.json',
        'integrated-summary.json', 'integrated-verdict.json'))
    invocations = []
    sessions = []
    for old_attempt, failed in [(attempt - 2, False), (attempt - 1, True)]:
        rel = f'{base}/attempt-{old_attempt}/round-1'
        directory = root / rel
        require(sorted(p.name for p in directory.parent.iterdir()) == ['round-1'],
                'interrupted attempts must contain only round 1')
        names = {'precheck-result.json', 'reviewer-a-host-allocation.json',
                 'reviewer-a.json' if failed else 'launch-blocker-note.md'}
        require(set(p.name for p in directory.iterdir()) == names,
                'interrupted evidence inventory mismatch')
        expected.update(f'{rel}/{name}' for name in names)
        pre = read_json(regular(root, rel + '/precheck-result.json'))
        require(pre.get('schema') == 'spec-review-precheck/v1' and pre.get('stage') == 'spec'
                and pre.get('feature') == feature and type(pre.get('attempt')) is int
                and pre['attempt'] == old_attempt and type(pre.get('round')) is int
                and pre['round'] == 1 and pre.get('reset') is True
                and pre.get('spec_review_status_field') == 'Pending', 'invalid predecessor precheck')
        for key in hashes:
            require(pre.get(key) is None and key == 'investigation_sha256' or
                    isinstance(pre.get(key), str) and re.fullmatch('[0-9a-f]{64}', pre[key]),
                    'invalid predecessor input hash')
        inv = f'reports/review-context/{feature}-spec-a{old_attempt}r1-a-invocation.json'
        require(not (root / inv.replace('-a-invocation', '-b-invocation')).exists(),
                'reviewer B has already been launched')
        expected.add(inv)
        invocation = read_json(regular(root, inv))
        receipt = read_json(regular(root, rel + '/reviewer-a-host-allocation.json'))
        require(invocation.get('schema') == 'review-context-invocation/v2'
                and invocation.get('stage') == 'spec' and invocation.get('feature') == feature
                and invocation.get('role') == 'spec-reviewer-a' and invocation.get('read_only') is True,
                'invalid predecessor invocation')
        require(sum(e == {'path': rel + '/precheck-result.json',
                          'sha256': digest(root / rel / 'precheck-result.json')}
                    for e in invocation.get('allowed_input_manifest', [])) == 1,
                'invocation does not bind predecessor precheck')
        require(receipt.get('feature') == feature and receipt.get('attempt') == old_attempt
                and receipt.get('round') == 1 and receipt.get('role') == 'spec-reviewer-a'
                and receipt.get('host_id') == invocation.get('run_id')
                and receipt.get('host_session_id') == invocation.get('host_session_id'),
                'allocation does not match reservation')
        invocations.append(inv)
        sessions.append(invocation['host_session_id'])
    require(sessions[0] != sessions[1], 'interrupted contexts are not independent')
    transcript = data['transcript']
    require(set(transcript) == {'path', 'failed_end_turn_uuid', 'resume_uuid', 'resumed_end_turn_uuid'},
            'invalid transcript declaration')
    expected.add(transcript['path'])
    require(set(pinned) == expected, 'contract must pin exactly the full recovery evidence set')
    events = [json.loads(line) for line in pinned[transcript['path']].read_text().splitlines() if line.strip()]
    indexes = []
    for key in ('failed_end_turn_uuid', 'resume_uuid', 'resumed_end_turn_uuid'):
        hits = [i for i, event in enumerate(events) if event.get('uuid') == transcript[key]]
        require(len(hits) == 1, 'transcript event missing or duplicated')
        indexes.append(hits[0])
    first, resume, last = indexes
    require(first < resume < last, 'invalid failed/resumed turn order')
    for i in indexes:
        require(events[i].get('sessionId') == sessions[1], 'transcript session mismatch')
    ends = [i for i, event in enumerate(events) if event.get('type') == 'assistant'
            and event.get('message', {}).get('stop_reason') == 'end_turn']
    require(ends == [first, last], 'transcript must show exactly the failed first and resumed turns')
    text = lambda event: '\n'.join(c.get('text', '') for c in event['message']['content']
                                   if isinstance(c, dict) and c.get('type') == 'text')
    require('BLOCKED' in text(events[first]) and events[resume].get('type') == 'user'
            and isinstance(events[resume].get('message', {}).get('content'), str),
            'transcript does not establish failed-first-turn resume')
    output = read_json(pinned[f'{base}/attempt-{attempt - 1}/round-1/reviewer-a.json'])
    payload = re.search(r'```json\s*(.*?)\s*```', text(events[last]), re.S)
    returned = json.loads(payload.group(1) if payload else text(events[last]))
    require(returned == output and output.get('host_session_id') == sessions[1],
            'preserved output does not match resumed host transcript')
    return {'terminal_attempt': terminal_attempt, 'terminal_round': terminal_round,
            'terminal_dir': terminal, 'invocations': invocations,
            'contract_sha256': digest(contract_path)}


if __name__ == '__main__':
    try:
        require(len(sys.argv) == 5, 'expected root, feature, next attempt and contract')
        print(json.dumps(validate(pathlib.Path(sys.argv[1]), sys.argv[2], int(sys.argv[3]),
                                  pathlib.Path(sys.argv[4])), sort_keys=True))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print('ERROR: fresh-review recovery: ' + str(error), file=sys.stderr)
        sys.exit(1)
