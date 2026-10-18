"""Scoped code rollback/reapply in a disposable detached checkout; never resources."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path.cwd().resolve()
SCRATCH = Path('/tmp/cloud-T010-01a14f3e-b525-78c0-9d78-d79635e2a5de')
CHECKOUT = SCRATCH / 'rollback'
EVIDENCE = ROOT / 'specs/cloud-orchestration/verification/T-010/attempt-2/evidence'
FILES = [
    'plugins/sdd-quality-loop/scripts/cloud_dependencies.py',
    'plugins/sdd-quality-loop/scripts/cloud_authorization.py',
    'plugins/sdd-azure-cloud/scripts/azure_governed.py',
    'plugins/sdd-aws-cloud/scripts/aws_governed.py',
    'tests/cloud-orchestration-verification.tests.py',
]


def sha(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def hashes(root: Path) -> dict[str, str | None]:
    return {name: sha(root / name) for name in FILES}


def main() -> None:
    label = sys.argv[1] if len(sys.argv) > 1 else 'run1'
    assert label.isalnum()
    evidence = EVIDENCE / ('rollback-' + label)
    evidence.mkdir(exist_ok=False)
    candidate = SCRATCH / ('rollback-candidate-' + label)
    candidate.mkdir(exist_ok=False)
    initial = hashes(CHECKOUT)
    mapping = json.loads((EVIDENCE / 'initial-input-map.json').read_bytes())
    entry = {row['source']: row for row in mapping['inputs']}
    for name in FILES:
        assert initial[name] == (entry[name]['sha256'] if name in entry else None), name
        dest = candidate / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
    candidate_hashes = hashes(candidate)
    runner = SCRATCH / 'rollback-offline-runner.py'
    shutil.copyfile(EVIDENCE / 'run-scoped.py', runner)
    env = dict(os.environ)
    env.update(
        PATH='/workspace/.tools/sdd-forge-dev/bin:' + env['PATH'],
        CLOUD_BICEP_BIN='/workspace/.tools/cloud/bicep/0.48.1/bicep',
        CLOUD_CDK_ROOT='/workspace/.tools/cloud/cdk/2.1145.0',
        CLOUD_NODE_BIN='/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin/node',
        CLOUD_AZURE_UPSTREAM_ROOT=str(CHECKOUT / 'specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream'),
    )
    commands: list[dict] = []
    result = dict(
        schema='task-rollback-experiment/v1', task_id='T-010', attempt=2,
        checkout=str(CHECKOUT), entry_revision=mapping['base_revision'],
        reconstruction='detached task-entry commit plus exact preserved initial dirty-input snapshot; explicitly declared unchanged test dependencies overlaid',
        initial=initial, candidate=candidate_hashes, commands=commands,
        network_guard='exercised parent/direct Python/shell/PowerShell-child urllib sentinel on every run',
        resource_rollback=False,
    )

    def save() -> None:
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')

    def run(label: str, suite: str, *cases: str, expected: int = 0) -> None:
        command = [sys.executable, '-B', str(runner), f'tests/cloud-orchestration-{suite}.tests.py', *cases]
        with (evidence / (label + '.log')).open('w') as log:
            started = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            proc = subprocess.run(command, cwd=CHECKOUT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        commands.append(dict(label=label, argv=command, started_at=started, exit_code=proc.returncode, expected_exit=expected))
        save()
        assert proc.returncode == expected, label
        print(label, proc.returncode, flush=True)

    def apply() -> None:
        for name in FILES:
            shutil.copyfile(candidate / name, CHECKOUT / name)
        assert hashes(CHECKOUT) == candidate_hashes

    save()
    run('entry-verification', 'verification')
    run('entry-admission', 'execution', 'Admission')
    apply()
    dependency_cases = ('DependencyReceiptCases', 'DependencyFieldMatrix', 'DependencyGraphCases', 'DependencyBoundaryCases', 'DependencyFinalBoundaryCases')
    run('candidate-dependencies', 'verification', *dependency_cases)
    for name in FILES:
        if name in entry:
            shutil.copyfile(SCRATCH / 'snapshot' / entry[name]['snapshot'], CHECKOUT / name)
        else:
            (CHECKOUT / name).unlink()
    result['restored'] = hashes(CHECKOUT)
    assert result['restored'] == initial
    save()
    run('restored-verification', 'verification')
    run('restored-admission', 'execution', 'Admission')
    # Feature-loss control: new matched dependency cases against the original
    # blanket-denial boundary. This is rollback sensitivity, not historical Red.
    test = FILES[-1]
    shutil.copyfile(candidate / test, CHECKOUT / test)
    run('restored-feature-loss', 'verification', 'DependencyReceiptCases.test_dependency_matched_control_at_both_shared_stages', expected=1)
    shutil.copyfile(SCRATCH / 'snapshot' / entry[test]['snapshot'], CHECKOUT / test)
    assert hashes(CHECKOUT) == initial
    apply()
    run('reapplied-dependencies', 'verification', *dependency_cases)
    result['reapplied'] = hashes(CHECKOUT)
    assert result['reapplied'] == candidate_hashes
    assert hashes(ROOT) == candidate_hashes, 'main checkout changed during experiment'
    result['completed'] = True
    save()


if __name__ == '__main__':
    main()
