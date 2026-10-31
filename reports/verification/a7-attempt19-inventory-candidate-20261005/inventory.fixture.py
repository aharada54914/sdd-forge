#!/usr/bin/env python3
"""Isolated, non-formal A18 inventory admission checks; never edits the owner root."""
import hashlib
import json
import pathlib
import runpy
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[3]
FEATURE = 'epic-195-a7-compatibility'
CONTRACT = 'reports/verification/a7-attempt19-formal-20261005/fresh-review-contract-attempt19.json'
PATCH = pathlib.Path(__file__).with_name('recovery.patch')
HELPER = 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'
PREDECESSOR = f'reports/spec-review/{FEATURE}/attempt-18/round-1'


def copy(root, rel):
    target = root / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / rel, target)


def fixture(root):
    contract = json.loads((ROOT / CONTRACT).read_text())
    for item in contract['evidence']:
        copy(root, item['path'])
    for rel in (CONTRACT, HELPER,
                'plugins/sdd-review-loop/scripts/failed-last-attempt.py',
                'plugins/sdd-review-loop/references/spec-review-calibration.md',
                'reports/review-context/identity-ledger.json',
                f'specs/{FEATURE}/requirements.md',
                f'specs/{FEATURE}/acceptance-tests.md',
                f'specs/{FEATURE}/investigation.md'):
        copy(root, rel)
    applied = subprocess.run(['git', 'apply', str(PATCH)], cwd=root,
                             text=True, capture_output=True, check=False)
    assert applied.returncode == 0, applied.stderr
    module = runpy.run_path(str(root / HELPER))
    return module['validate'], root / CONTRACT


def rejected(validate, root, contract, marker):
    try:
        validate(root, FEATURE, 19, contract)
    except (ValueError, OSError, KeyError, TypeError) as error:
        assert marker in str(error), (marker, str(error))
        return
    raise AssertionError('expected rejection: ' + marker)


with tempfile.TemporaryDirectory(prefix='a7-inventory-fixture-') as temp:
    root = pathlib.Path(temp).resolve()
    validate, contract = fixture(root)
    print('CANDIDATE_SHA256:', hashlib.sha256((root / HELPER).read_bytes()).hexdigest())
    result = validate(root, FEATURE, 19, contract)
    assert result['terminal_attempt'] == 7
    assert result['terminal_round'] == 2
    print('PASS: candidate admits exact 7-file A18 inventory and historical chain')

    unknown = root / PREDECESSOR / 'reviewer-a-unknown.txt'
    unknown.write_text('negative fixture only\n')
    rejected(validate, root, contract, 'interrupted evidence inventory mismatch')
    unknown.unlink()
    print('PASS: unknown eighth file rejected')

    target = root / PREDECESSOR / 'reviewer-a-first-turn.txt'
    target.write_bytes(target.read_bytes() + b'changed fixture\n')
    changed = hashlib.sha256(target.read_bytes()).hexdigest()
    data = json.loads(contract.read_text())
    rel = target.relative_to(root).as_posix()
    for item in data['evidence']:
        if item['path'] == rel:
            item['sha256'] = changed
    for item in data['interrupted_evidence_inventory']['files']:
        if item['path'] == rel:
            item['sha256'] = changed
    contract.write_text(json.dumps(data, indent=2) + '\n')
    rejected(validate, root, contract, 'interrupted evidence inventory mismatch')
    print('PASS: changed historical bytes rejected even after contract repinning')

    target.write_bytes((ROOT / rel).read_bytes())
    shutil.copy2(ROOT / CONTRACT, contract)
    data = json.loads(contract.read_text())
    data['interrupted_evidence_inventory']['files'].pop()
    contract.write_text(json.dumps(data, indent=2) + '\n')
    rejected(validate, root, contract, 'invalid interrupted evidence inventory')
    print('PASS: incomplete inventory rejected')

print('PASS: owner history remains untouched')
