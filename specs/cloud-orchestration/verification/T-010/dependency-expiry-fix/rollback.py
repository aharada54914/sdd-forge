"""Exact two-file code rollback/reapply over preserved dirty entry bytes; offline."""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path.cwd().resolve()
EVIDENCE = ROOT / 'specs/cloud-orchestration/verification/T-010/dependency-expiry-fix'
SCRATCH = Path('/tmp/cloud-T010-01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c')
CHECKOUT = SCRATCH / 'rollback'
FILES = ['plugins/sdd-quality-loop/scripts/cloud_authorization.py',
         'tests/cloud-orchestration-verification.tests.py']


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hashes(root: Path) -> dict[str, str]:
    return {p: digest(root / p) for p in FILES}


def copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def main() -> None:
    entry = json.loads((EVIDENCE / 'entry.json').read_bytes())
    with (EVIDENCE / 'rollback-create.log').open('w') as log:
        subprocess.run(['git', 'worktree', 'add', '--detach', str(CHECKOUT), entry['base_revision']],
                       check=True, stdout=log, stderr=subprocess.STDOUT)
    # Only declared implementation inputs, not raw peer reports or transport logs.
    for row in entry['inputs']:
        copy(SCRATCH / 'inputs' / row['snapshot_path'], CHECKOUT / row['path'])
    supplement = json.loads((EVIDENCE / 'supplemental-input-map.json').read_bytes())
    supplement += json.loads((EVIDENCE / 'regression-dependencies.json').read_bytes())
    for row in supplement:
        if not row['path'].startswith('/'):
            copy(SCRATCH / 'supplemental-inputs' / row['snapshot_path'], CHECKOUT / row['path'])
    candidate = SCRATCH / 'candidate'
    for path in FILES:
        copy(ROOT / path, candidate / path)
    initial, expected = hashes(CHECKOUT), hashes(candidate)
    assert initial == {r['path']: r['sha256'] for r in entry['inputs'] if r['path'] in FILES}
    commands: list[dict] = []
    result = dict(task_id='T-010', task_attempt_count=3, base_revision=entry['base_revision'],
                  checkout=str(CHECKOUT), initial=initial, candidate=expected, commands=commands,
                  reconstruction='Detached entry commit plus exact initial dirty-input snapshots and declared unchanged dependencies.',
                  network_guard='Exercised parent/direct Python/shell/PowerShell-child sentinels on every test command.',
                  resource_rollback=False, completed=False)
    env = dict(os.environ)
    env['CLOUD_AZURE_UPSTREAM_ROOT'] = str(CHECKOUT / 'specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream')

    def save() -> None:
        (EVIDENCE / 'rollback.json').write_text(json.dumps(result, indent=2) + '\n')

    def run(label: str, suite: str, *cases: str, expected_exit: int = 0) -> None:
        command = [sys.executable, '-B', str(EVIDENCE / 'run-scoped.py'),
                   f'tests/cloud-orchestration-{suite}.tests.py', *cases]
        started = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        with (EVIDENCE / (label + '.log')).open('w') as log:
            proc = subprocess.run(command, cwd=CHECKOUT, env=env, stdout=log,
                                  stderr=subprocess.STDOUT, timeout=600)
        commands.append(dict(label=label, argv=command, started_at=started,
                             exit_code=proc.returncode, expected_exit=expected_exit))
        save()
        print(label, proc.returncode, flush=True)
        assert proc.returncode == expected_exit, label

    def apply() -> None:
        for path in FILES:
            copy(candidate / path, CHECKOUT / path)
        assert hashes(CHECKOUT) == expected

    save()
    for suite in ('verification', 'execution', 'contracts'):
        run('rollback-entry-' + suite, suite)
    apply()
    run('rollback-candidate-focused', 'verification', 'DependencyCallbackExpiryCases')
    for path in FILES:
        copy(SCRATCH / 'inputs' / 'before' / path, CHECKOUT / path)
    result['restored'] = hashes(CHECKOUT)
    assert result['restored'] == initial
    save()
    for suite in ('verification', 'execution', 'contracts'):
        run('rollback-restored-' + suite, suite)
    # Sensitivity: retain new tests against the original production bytes.
    copy(candidate / FILES[1], CHECKOUT / FILES[1])
    run('rollback-defect-reproduced', 'verification', 'DependencyCallbackExpiryCases', expected_exit=1)
    apply()
    for suite in ('verification', 'execution', 'contracts'):
        cases = ('DependencyCallbackExpiryCases',) if suite == 'verification' else ()
        run('rollback-reapplied-' + suite, suite, *cases)
    result['reapplied'] = hashes(CHECKOUT)
    assert result['reapplied'] == expected == hashes(ROOT)
    result['completed'] = True
    save()


if __name__ == '__main__':
    main()
