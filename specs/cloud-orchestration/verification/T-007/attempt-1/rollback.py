"""Restore only T-007 code/config in an isolated committed worktree."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import time

ROOT = Path.cwd()
EVIDENCE = ROOT / 'specs/cloud-orchestration/verification/T-007/attempt-1'
SCRATCH = Path('/tmp/cloud-t007-01a14f96')
SNAPSHOT = SCRATCH / 'snapshot/initial'
TREE = SCRATCH / 'rollback'
entry = json.loads((EVIDENCE / 'entry.json').read_text())
manifest = json.loads((EVIDENCE / 'task-input-manifest.json').read_text())
outputs = [p for p in manifest['allowed_outputs'] if not p.startswith(('reports/', 'specs/')) and (ROOT / p).is_file()]
outputs += ['tests/uninstall.tests.sh', 'tests/uninstall.tests.ps1']
records = []
PREFIX = sys.argv[1] if len(sys.argv) > 1 else ""


def command(label, args, cwd=ROOT):
    label = PREFIX + label
    tick = time.monotonic()
    with (EVIDENCE / (label + '.log')).open('wb') as stream:
        result = subprocess.run(args, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    records.append(dict(label=label, command=args, cwd=str(cwd), exit_code=result.returncode, elapsed_seconds=round(time.monotonic()-tick, 3)))
    (EVIDENCE / (PREFIX + 'rollback-commands.json')).write_text(json.dumps(records, indent=2) + '\n')
    return result.returncode


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def hashes():
    return {p: digest(TREE / p) for p in outputs}


assert command('rollback-create', ['git', 'worktree', 'add', '--detach', str(TREE), entry['base_revision']]) == 0
# Reconstruct exact initial dirty candidate, not merely the older Git HEAD.
paths = []
for item in entry['before']:
    relative = item['path']
    source = SNAPSHOT / relative
    assert digest(source) == item['sha256'], relative
    target = TREE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    paths.append(relative)
assert command('rollback-stage-baseline', ['git', 'add', '--', *paths], TREE) == 0
assert command('rollback-commit-baseline', ['git', '-c', 'user.name=Rollback Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Preserve initial candidate inputs for T007 rollback'], TREE) == 0
baseline = hashes()
assert command('rollback-before', ['bash', 'tests/install.tests.sh'], TREE) == 0
for relative in outputs:
    target = TREE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / relative, target)
assert command('rollback-stage-candidate', ['git', 'add', '--', *outputs], TREE) == 0
assert command('rollback-commit-candidate', ['git', '-c', 'user.name=Rollback Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Isolated T007 packaging candidate'], TREE) == 0
candidate = hashes()
assert command('rollback-candidate', ['python3', '-B', 'tests/install-cloud.tests.py'], TREE) == 0
# Only task-owned output code/config is restored; approvals, ledgers and frozen
# evidence are not rewritten. New task files are removed, not broadly cleaned.
for relative in outputs:
    source = SNAPSHOT / relative
    target = TREE / relative
    if source.is_file():
        shutil.copy2(source, target)
    else:
        target.unlink(missing_ok=True)
assert command('rollback-stage-restored', ['git', 'add', '--', *outputs], TREE) == 0
assert command('rollback-commit-restored', ['git', '-c', 'user.name=Rollback Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'Restore only T007 task-owned code/config'], TREE) == 0
restored = hashes()
assert restored == baseline
assert command('rollback-restored', ['bash', 'tests/install.tests.sh'], TREE) == 0
result = dict(base_revision=entry['base_revision'], initial_candidate_snapshot=str(SNAPSHOT), before=baseline, candidate=candidate, restored=restored, exact_task_owned_restoration=True, baseline_command='bash tests/install.tests.sh', baseline_and_restored_exit_codes=[0, 0], cloud_resources_touched=False)
(EVIDENCE / (PREFIX + 'rollback-result.json')).write_text(json.dumps(result, indent=2) + '\n')
assert command('rollback-remove', ['git', 'worktree', 'remove', '--force', str(TREE)]) == 0
print('Isolated committed checkout rollback and restored baseline: OK')
