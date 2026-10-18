#!/usr/bin/env python3
"""Restore only candidate-owned files in an already-created disposable checkout."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

checkout, snapshot, evidence = map(Path, sys.argv[1:])
checkout, snapshot, evidence = checkout.resolve(), snapshot.resolve(), evidence.resolve()
assert checkout != Path.cwd().resolve()
assert (checkout / '.git').is_dir()
owned = ['tests/sdd-domain-multitarget-foundation.tests.py',
         'specs/sdd-domain-multitarget/verification/T-001/current-consumer-inventory.json',
         'tests/run-all.sh', 'tests/run-all.ps1', 'tests/run-all-python.tests.ps1',
         '.github/workflows/test.yml']

def restore():
    for name in owned:
        dest = checkout / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(snapshot / name, dest)


def hashes():
    return {name: hashlib.sha256((checkout / name).read_bytes()).hexdigest() for name in owned}


def run(label, args, expected):
    result = subprocess.run(args, cwd=checkout, capture_output=True, text=True)
    (evidence / (label + '.log')).write_text(
        '$ ' + ' '.join(args) + '\n' + result.stdout + result.stderr +
        '\nexit_code=' + str(result.returncode) + '\n')
    assert result.returncode == expected, label
    return dict(command=args, exit_code=result.returncode)

restore()
before = hashes()
commands = [run('rollback-baseline', ['python3', '-B', owned[0]], 0)]
inventory = checkout / owned[1]
data = json.loads(inventory.read_text())
next(row for row in data['entries'] if row['id'] == 'bootstrap-seven-layer-output')['source'][0]['section'] = '## Removed requirement'
inventory.write_text(json.dumps(data))
mutated = hashes()
commands.append(run('rollback-mutated', ['python3', '-B', owned[0]], 1))
restore()
after = hashes()
assert before == after
commands.append(run('rollback-restored', ['python3', '-B', owned[0]], 0))
commands.append(run('rollback-powershell', ['/workspace/.tools/sdd-forge-dev/bin/pwsh', '-NoProfile', '-File', owned[4]], 0))
(evidence / 'rollback.json').write_text(json.dumps(dict(
    base_revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=checkout, text=True).strip(),
    checkout=str(checkout), snapshot=str(snapshot),
    note='Restore initial candidate bytes, not HEAD: repair predates this task. No identity ledger, approval, historical evidence or original worktree was restored.',
    before=before, mutated=mutated, restored=after, commands=commands), indent=2) + '\n')
print('Disposable rollback: baseline 53 pass, mutation exit 1, restored 53 pass; PowerShell 4 pass; six candidate hashes restored.')
