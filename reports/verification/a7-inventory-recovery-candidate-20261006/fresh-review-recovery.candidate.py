#!/usr/bin/env python3
"""Read-only admission for an explicitly authorized, invalidated review restart.

This is NOT a verdict validator. The caller must validate the returned terminal
contract before and after acquiring its lock. Historical reservations are
checked here against the ledger, without comparing their input hashes to the
current (necessarily amended) specification files.
Only the opt-in fresh-review route depends on Python. A v2 contract without
history keys retains the original two-partial shape; paired history keys name
the complete contiguous partial-attempt chain after its terminal anchor.
"""
import hashlib
import runpy
import json
import pathlib
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path, content=None):
    def unique(pairs):
        data = {}
        for key, value in pairs:
            require(key not in data, 'duplicate JSON key')
            data[key] = value
        return data
    return json.loads(path.read_bytes() if content is None else content, object_pairs_hook=unique)


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


def validate_historical_reservations(root, invocations):
    ledger_rel = 'reports/review-context/identity-ledger.json'
    ledger = read_json(regular(root, ledger_rel))
    require(isinstance(ledger, dict) and set(ledger) == {'schema', 'records'} and
            ledger['schema'] == 'review-identity-ledger/v1' and
            isinstance(ledger['records'], list) and bool(ledger['records']),
            'invalid canonical identity ledger')
    records = {}
    runs, sessions = set(), set()
    previous = ''
    identifier = r'[A-Za-z0-9][A-Za-z0-9._:-]*'
    sha = r'[0-9a-f]{64}'
    for sequence, record in enumerate(ledger['records'], 1):
        required = {'sequence', 'stage', 'role', 'run_id', 'host_session_id',
                    'previous_record_sha256', 'record_sha256'}
        optional = set(record) - required if isinstance(record, dict) else set()
        require(isinstance(record, dict) and required <= set(record) and
                optional <= {'allowed_inputs_sha256', 'scratch_declaration_sha256'} and
                type(record['sequence']) is int and record['sequence'] == sequence and
                all(isinstance(record[key], str) and re.fullmatch(identifier, record[key])
                    for key in ('stage', 'role', 'run_id', 'host_session_id')) and
                record['previous_record_sha256'] == previous and
                isinstance(record['record_sha256'], str) and
                re.fullmatch(sha, record['record_sha256']),
                'invalid canonical identity ledger chain')
        require(record['run_id'] not in runs and record['host_session_id'] not in sessions,
                'canonical identity ledger identity is not unique')
        runs.add(record['run_id'])
        sessions.add(record['host_session_id'])
        binding = ''
        if 'allowed_inputs_sha256' in record:
            require(record['stage'] in ('spec', 'impl') and
                    re.fullmatch(sha, record['allowed_inputs_sha256']),
                    'invalid canonical allowed-input binding')
            binding = '|allowed-inputs-v1|' + record['allowed_inputs_sha256']
        if 'scratch_declaration_sha256' in record:
            require(record['stage'] == 'quality' and record['role'] == 'sdd-evaluator' and
                    'allowed_inputs_sha256' not in record and
                    re.fullmatch(sha, record['scratch_declaration_sha256']),
                    'invalid canonical scratch binding')
            binding = '|scratch-declaration-v1|' + record['scratch_declaration_sha256']
        text = '|'.join(str(record[key]) for key in ('sequence', 'stage', 'role',
            'run_id', 'host_session_id', 'previous_record_sha256')) + binding
        require(hashlib.sha256(text.encode()).hexdigest() == record['record_sha256'],
                'canonical identity ledger record hash is invalid')
        previous = record['record_sha256']
        records[(record['run_id'], record['host_session_id'])] = record

    for invocation in invocations:
        envelope = {'allowed_input_manifest', 'fallback_mode', 'feature',
                    'host_session_id', 'identity_ledger_path',
                    'identity_ledger_sha256', 'input_mode',
                    'previous_record_sha256', 'read_only', 'role', 'run_id',
                    'schema', 'sequence', 'stage'}
        require(isinstance(invocation, dict) and set(invocation) == envelope and
                invocation['input_mode'] == 'file-manifest' and
                invocation['fallback_mode'] == 'none' and
                invocation['read_only'] is True and
                invocation['identity_ledger_path'] == ledger_rel and
                isinstance(invocation['identity_ledger_sha256'], str) and
                re.fullmatch(sha, invocation['identity_ledger_sha256']) and
                type(invocation['sequence']) is int and invocation['sequence'] >= 2 and
                isinstance(invocation['previous_record_sha256'], str) and
                re.fullmatch(sha, invocation['previous_record_sha256']),
                'invalid historical invocation envelope')
        inputs = invocation.get('allowed_input_manifest')
        require(isinstance(inputs, list) and bool(inputs) and
                all(isinstance(item, dict) and set(item) == {'path', 'sha256'} and
                    isinstance(item['path'], str) and isinstance(item['sha256'], str) and
                    re.fullmatch(sha, item['sha256']) for item in inputs) and
                len({item['path'] for item in inputs}) == len(inputs),
                'invalid historical allowed-input manifest')
        bound_text = '\n'.join(item['path'] + '\t' + item['sha256'] for item in inputs)
        bound_sha = hashlib.sha256(bound_text.encode()).hexdigest()
        record = records.get((invocation['run_id'], invocation['host_session_id']))
        require(record is not None and record['sequence'] == invocation['sequence'] and
                record['stage'] == invocation['stage'] and
                record['role'] == invocation['role'] and
                record['previous_record_sha256'] == invocation['previous_record_sha256'] and
                record.get('allowed_inputs_sha256') == bound_sha,
                'historical reservation does not match canonical ledger')


def validate(root, feature, attempt, contract_path):
    root = root.resolve()
    contract_path = contract_path.absolute()
    require(contract_path.is_file() and contract_path.resolve() == contract_path,
            'contract must be a regular, non-symlink file')
    contract_rel = contract_path.relative_to(root).as_posix()
    require(contract_rel.startswith('reports/verification/'),
            'contract must be retained under reports/verification')
    regular(root, contract_rel)
    contract_bytes = contract_path.read_bytes()
    contract_sha = hashlib.sha256(contract_bytes).hexdigest()
    data = read_json(contract_path, contract_bytes)
    base_keys = {'schema', 'feature', 'next_attempt', 'reason', 'input_hashes',
                 'evidence', 'transcript', 'authority', 'historical_disposition'}
    history_keys = {'terminal_attempt', 'partial_attempts'}
    later_round_keys = history_keys | {'failed_final_round', 'failed_turn'}
    earlier_round_keys = history_keys | {'historical_failed_rounds'}
    require(set(data) in (base_keys, base_keys | history_keys, base_keys | later_round_keys,
                          base_keys | earlier_round_keys,
                          base_keys | later_round_keys | {'historical_failed_rounds'},
                          base_keys | earlier_round_keys | {'interrupted_evidence_inventory'},
                          base_keys | earlier_round_keys | {'interrupted_transport_inventories'}),
            'unexpected fresh-review contract keys')
    later_round = 'failed_final_round' in data
    require(data['schema'] == 'spec-fresh-review-recovery/v2' and data['feature'] == feature
            and type(data['next_attempt']) is int and data['next_attempt'] == attempt
            and attempt >= 4, 'fresh-review identity mismatch')
    require(data['reason'] == 'authorized-history-quarantine', 'unsupported recovery reason')
    require(data['historical_disposition'] == {
        'outputs': 'diagnostic-only', 'transition_legality': 'not-established'},
        'historical outputs must remain quarantined; no retroactive legality claim')
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
    if set(data) == base_keys:
        # Retain the original v2 two-partial contract without reinterpreting it.
        terminal_attempt = attempt - 3
        partial_attempts = [attempt - 2, attempt - 1]
    else:
        terminal_attempt = data['terminal_attempt']
        partial_attempts = data['partial_attempts']
        require(type(terminal_attempt) is int and terminal_attempt >= 1 and
                terminal_attempt <= attempt - 3 and
                isinstance(partial_attempts, list) and
                all(type(item) is int for item in partial_attempts) and
                partial_attempts == list(range(terminal_attempt + 1, attempt)),
                'partial attempts must be a complete ordered chain after the terminal anchor')
    historical_failed = data.get('historical_failed_rounds', [])
    require(isinstance(historical_failed, list) and bool(historical_failed) ==
            ('historical_failed_rounds' in data), 'invalid historical failed-round list')
    require(all(isinstance(item, dict) and set(item) ==
                {'attempt', 'failed_final_round', 'failed_turn'} and
                type(item['attempt']) is int and item['attempt'] in partial_attempts[:-1] and
                type(item['failed_final_round']) is int and
                item['failed_final_round'] in (2, 3)
                for item in historical_failed) and
            [item['attempt'] for item in historical_failed] ==
            sorted(set(item['attempt'] for item in historical_failed)),
            'historical failed rounds must be unique ordered earlier partial attempts')
    historical_by_attempt = {item['attempt']: item for item in historical_failed}
    terminal_root = root / base / f'attempt-{terminal_attempt}'
    terminal_round = max([int(p.name[6:]) for p in terminal_root.iterdir()
                          if re.fullmatch('round-[1-3]', p.name)] or [0])
    require(terminal_round > 0, 'terminal predecessor missing')
    terminal = f'{base}/attempt-{terminal_attempt}/round-{terminal_round}'
    expected.update(f'{terminal}/{name}' for name in ('spec-review-contract.json',
        'precheck-result.json', 'reviewer-a.json', 'reviewer-b.json',
        'integrated-summary.json', 'integrated-verdict.json'))
    invocations = []
    historical_invocations = []
    sessions = []
    completed_rounds = []
    inventory = data.get('interrupted_evidence_inventory')
    if inventory is not None:
        require(feature == 'epic-195-a7-compatibility' and attempt == 19 and
                isinstance(inventory, dict) and set(inventory) == {'attempt', 'files'} and
                type(inventory['attempt']) is int and inventory['attempt'] == 18 and
                isinstance(inventory['files'], list) and len(inventory['files']) == 7 and
                all(isinstance(item, dict) and set(item) == {'path', 'sha256'} and
                    isinstance(item['path'], str) and isinstance(item['sha256'], str) and
                    re.fullmatch('[0-9a-f]{64}', item['sha256']) for item in inventory['files']),
                'invalid interrupted evidence inventory')
    transport = data.get('interrupted_transport_inventories')
    transport_by_attempt = {}
    if 'interrupted_transport_inventories' in data:
        require(isinstance(transport, list) and bool(transport),
                'invalid transport inventories')
        for entry in transport:
            require(isinstance(entry, dict) and set(entry) == {'attempt', 'files'} and
                    type(entry['attempt']) is int and entry['attempt'] in partial_attempts and
                    entry['attempt'] not in historical_by_attempt and
                    isinstance(entry['files'], list) and bool(entry['files']),
                    'invalid transport inventory entry')
            require(entry['attempt'] not in transport_by_attempt,
                    'duplicate transport inventory attempt')
            transport_by_attempt[entry['attempt']] = entry['files']
        require(list(transport_by_attempt) == sorted(transport_by_attempt),
                'transport inventories must be ordered')
    transport_required = {
        'launch-blocker-note.md', 'precheck-result.json',
        'reviewer-a-host-allocation.json', 'reviewer-a-first-turn.txt',
        'reviewer-a-nontty-preflight.json', 'reviewer-a-reservation-receipt.txt',
        'reviewer-a-role-config.json',
    }
    transport_optional = {
        'reviewer-a-cli-stderr.txt', 'reviewer-a-cli-wrapper.json',
        'reviewer-a-delivery-proof.json', 'reviewer-a-reservation-stderr.txt',
    }
    a18_inventory = {
        'launch-blocker-note.md': 'bf8567992c455ee37bf890530c70683edd1ca0bf171bff933278764df9d8c621',
        'precheck-result.json': '3ee3a996576106de56423931eecfcf6cedb027ad8f64d850c671b1102b173740',
        'reviewer-a-first-turn.txt': '845f0c4d06153767fbebfa6ec6b4c158539ba43a9797bf028f9ece98bdff9f85',
        'reviewer-a-host-allocation.json': '18785b66c6b9fd1ccb8e76cd5ebc6cacc9215788ff8ad051a5fcce6e395b94d3',
        'reviewer-a-nontty-preflight.json': '217bd5693476afe70128b4a184294c94785dadbdd7746f93cdbe243fb9d8e078',
        'reviewer-a-reservation-receipt.txt': 'e1b96325621fd95a93f851568fa6eabfe33f257d7749e40452fdd63f1e80cdf4',
        'reviewer-a-role-config.json': '9e041233ee4fea5dd253541de62296517ff014f16227abf3f6d104b6cea111f4',
    }
    for old_attempt in (partial_attempts[:-1] if later_round else partial_attempts):
        if old_attempt in historical_by_attempt:
            item = historical_by_attempt[old_attempt]
            module = runpy.run_path(str(regular(root,
                'plugins/sdd-review-loop/scripts/failed-last-attempt.py')))
            failed = module['inspect'](root, feature, attempt, item['failed_final_round'],
                                       hashes, item['failed_turn'], old_attempt=old_attempt)
            expected.update(failed['evidence_paths'])
            completed_rounds.extend(failed['completed_rounds'])
            invocations.extend(failed['invocation_paths'])
            historical_invocations.extend(failed['invocations'])
            sessions.extend(entry['host_session_id'] for entry in failed['invocations'])
            continue
        rel = f'{base}/attempt-{old_attempt}/round-1'
        directory = root / rel
        require(sorted(p.name for p in directory.parent.iterdir()) == ['round-1'],
                'interrupted attempts must contain only round 1')
        actual_names = set(p.name for p in directory.iterdir())
        actual_paths = {f'{rel}/{name}' for name in actual_names}
        common_names = {'precheck-result.json', 'reviewer-a-host-allocation.json'}
        no_output_names = common_names | {'launch-blocker-note.md'}
        reviewer_output_names = common_names | {'reviewer-a.json'}
        if set(data) == base_keys:
            expected_names = reviewer_output_names if old_attempt == attempt - 1 else no_output_names
            require(actual_names == expected_names, 'interrupted evidence inventory mismatch')
        elif old_attempt in transport_by_attempt:
            files = transport_by_attempt[old_attempt]
            require(all(isinstance(item, dict) and set(item) == {'path', 'sha256'} and
                        isinstance(item['path'], str) and isinstance(item['sha256'], str) and
                        re.fullmatch('[0-9a-f]{64}', item['sha256']) for item in files),
                    'invalid transport inventory file')
            by_path = {item['path']: item['sha256'] for item in files}
            require(len(by_path) == len(files) and set(by_path) == actual_paths and
                    transport_required <= actual_names and
                    actual_names <= transport_required | transport_optional,
                    'transport inventory names mismatch')
            evidence_hashes = {item['path']: item['sha256'] for item in data['evidence']}
            for evidence_rel, expected_sha in by_path.items():
                require(digest(regular(root, evidence_rel)) == expected_sha and
                        evidence_hashes.get(evidence_rel) == expected_sha,
                        'transport inventory bytes mismatch')
        elif inventory is not None and old_attempt == inventory['attempt']:
            expected_files = {f'{rel}/{name}': sha for name, sha in a18_inventory.items()}
            inventory_files = {item['path']: item['sha256'] for item in inventory['files']}
            require(actual_names == set(a18_inventory) and
                    len(inventory_files) == len(inventory['files']) and
                    inventory_files == expected_files,
                    'interrupted evidence inventory mismatch')
            for item in inventory['files']:
                require(digest(regular(root, item['path'])) == item['sha256'] and
                        next((entry['sha256'] for entry in data['evidence']
                              if entry['path'] == item['path']), None) == item['sha256'],
                        'interrupted evidence inventory hash mismatch: ' + item['path'])
        else:
            require(actual_names in (no_output_names, reviewer_output_names),
                    'interrupted evidence inventory mismatch')
        expected.update(f'{rel}/{name}' for name in actual_names)
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
        require(isinstance(invocation, dict) and
                invocation.get('schema') == 'review-context-invocation/v2'
                and invocation.get('stage') == 'spec' and invocation.get('feature') == feature
                and invocation.get('role') == 'spec-reviewer-a' and invocation.get('read_only') is True,
                'invalid predecessor invocation')
        require(sum(e == {'path': rel + '/precheck-result.json',
                          'sha256': digest(root / rel / 'precheck-result.json')}
                    for e in invocation.get('allowed_input_manifest', [])) == 1,
                'invocation does not bind predecessor precheck')
        expected_inputs = {
            f'specs/{feature}/requirements.md': pre['requirements_sha256'],
            f'specs/{feature}/acceptance-tests.md': pre['acceptance_sha256'],
            'plugins/sdd-review-loop/references/spec-review-calibration.md':
                pre['calibration_sha256'],
            rel + '/precheck-result.json': digest(root / rel / 'precheck-result.json'),
        }
        if pre.get('investigation_sha256') is not None:
            expected_inputs[f'specs/{feature}/investigation.md'] = pre['investigation_sha256']
        require(isinstance(invocation.get('allowed_input_manifest'), list) and
                len(invocation['allowed_input_manifest']) == len(expected_inputs) and
                all(isinstance(item, dict) and set(item) == {'path', 'sha256'} and
                    expected_inputs.get(item['path']) == item['sha256']
                    for item in invocation['allowed_input_manifest']) and
                len({item['path'] for item in invocation['allowed_input_manifest']}) ==
                len(expected_inputs), 'historical manifest differs from its precheck')
        require(receipt.get('feature') == feature and receipt.get('attempt') == old_attempt
                and receipt.get('round') == 1 and receipt.get('role') == 'spec-reviewer-a'
                and receipt.get('host_id') == invocation.get('run_id')
                and receipt.get('host_session_id') == invocation.get('host_session_id'),
                'allocation does not match reservation')
        if actual_names == reviewer_output_names:
            output = read_json(regular(root, rel + '/reviewer-a.json'))
            require(output.get('schema') == 'spec-reviewer-a/v1' and
                    output.get('stage') == 'spec' and
                    output.get('role') == 'spec-reviewer-a' and
                    output.get('run_id') == invocation.get('run_id') and
                    output.get('host_session_id') == invocation.get('host_session_id'),
                    'reviewer-A diagnostic output identity does not match reservation')
        invocations.append(inv)
        historical_invocations.append(invocation)
        sessions.append(invocation['host_session_id'])
    if later_round:
        require(partial_attempts[-1] == attempt - 1,
                'failed later round must be in immediately preceding attempt')
        transcript_rel = data['transcript']['path']
        require(isinstance(data['failed_turn'], dict) and
                data['failed_turn'].get('transcript_path') == transcript_rel,
                'failed turn must bind the contract transcript')
        module = runpy.run_path(str(regular(root,
            'plugins/sdd-review-loop/scripts/failed-last-attempt.py')))
        last = module['inspect'](root, feature, attempt, data['failed_final_round'],
                                 hashes, data['failed_turn'])
        expected.update(last['evidence_paths'])
        completed_rounds.extend(last['completed_rounds'])
        invocations.extend(last['invocation_paths'])
        historical_invocations.extend(last['invocations'])
        sessions.extend(item['host_session_id'] for item in last['invocations'])
    require(len(set(sessions)) == len(sessions), 'interrupted contexts are not independent')
    validate_historical_reservations(root, historical_invocations)
    transcript = data['transcript']
    require(isinstance(transcript, dict) and set(transcript) == {'path'},
            'transcript is pinned diagnostic evidence, not proof of turn validity')
    if historical_failed and not later_round:
        require(transcript['path'] == historical_failed[-1]['failed_turn'].get('transcript_path'),
                'contract transcript must bind the last failed multi-round attempt')
    expected.add(transcript['path'])
    authority = data['authority']
    require(isinstance(authority, dict) and set(authority) == {'path'},
            'authority must name a retained approval audit record')
    require(authority['path'].startswith('reports/verification/'),
            'approval audit record must be retained under reports/verification')
    expected.add(authority['path'])
    require(set(pinned) == expected, 'contract must pin exactly the full recovery evidence set')
    approval = read_json(pinned[authority['path']])
    approval_keys = {'schema', 'feature', 'next_attempt', 'origin',
                     'recorded_by_role', 'user_statement', 'scope', 'input_hashes'}
    if transport is not None:
        approval_keys.add('transport_inventories_sha256')
        inventory_sha = hashlib.sha256(json.dumps(transport, sort_keys=True,
            separators=(',', ':'), ensure_ascii=False).encode('utf-8')).hexdigest()
        require(approval.get('transport_inventories_sha256') == inventory_sha,
                'transport inventory approval binding mismatch')
    require(set(approval) == approval_keys,
            'unexpected approval audit record keys')
    require(approval['schema'] == 'spec-fresh-review-approval-audit/v1'
            and approval['feature'] == feature
            and type(approval['next_attempt']) is int and approval['next_attempt'] == attempt
            and approval['origin'] == 'current-user-conversation'
            and approval['recorded_by_role'] == 'orchestrator'
            and isinstance(approval['user_statement'], str)
            and bool(approval['user_statement'].strip())
            and approval['scope'] == 'quarantine-history-and-start-fresh-review-only'
            and approval['input_hashes'] == hashes, 'approval audit binding mismatch')
    # This pins the orchestrator's transcription of actual human authorization.
    # It is not a signature, registered approver credential, or sudo-mode grant.
    # Historical transcript bytes and outputs are retained, never adopted as PASS.
    require(digest(contract_path) == contract_sha, 'contract changed during validation')
    return {'terminal_attempt': terminal_attempt, 'terminal_round': terminal_round,
            'terminal_dir': terminal, 'invocations': invocations,
            'completed_rounds': completed_rounds,
            'contract_path': contract_rel, 'contract_sha256': contract_sha, 'input_hashes': hashes}


if __name__ == '__main__':
    try:
        require(len(sys.argv) == 5, 'expected root, feature, next attempt and contract')
        print(json.dumps(validate(pathlib.Path(sys.argv[1]), sys.argv[2], int(sys.argv[3]),
                                  pathlib.Path(sys.argv[4])), sort_keys=True))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print('ERROR: fresh-review recovery: ' + str(error), file=sys.stderr)
        sys.exit(1)
