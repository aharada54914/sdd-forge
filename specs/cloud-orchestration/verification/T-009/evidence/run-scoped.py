"""Capture exact local commands; no cloud actions and no full-repository suite."""
from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/cloud-T009-01a14ed8-ab42-7832-8945-e75ca77b0d2e')
PYTHON = '/tmp/cloud-quality-python/bin/python'
MYPYPATH = 'plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts'


def main() -> None:
    mode = sys.argv[1]
    commands = {
        'baseline': [
            ('cloud-verification', ['python3', '-B', 'tests/cloud-orchestration-verification.tests.py']),
            ('selected-plan', ['python3', '-B', 'tests/sdd-domain-multitarget-T-003.tests.py']),
            ('contracts', ['bash', 'tests/gates.tests.sh']),
            ('registry-schema', ['bash', 'tests/capability-registry-schema.tests.sh']),
            ('registry-parity', ['bash', 'tests/capability-registry-parity.tests.sh']),
            ('guard-projection', ['python3', '-B', 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py', '--check']),
            ('gate-projection', ['python3', '-B', 'plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py', '--check']),
            ('vendored-mirrors', ['python3', '-B', 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py', '--check']),
        ],
        'baseline-node-retry': [('registry-parity', ['bash', 'tests/capability-registry-parity.tests.sh'])],
        'static': [
            ('ruff', [PYTHON, '-m', 'ruff', 'check', '--config', 'tests/shared-launch-python/pyproject.toml', str(EVIDENCE / 'probe-boundaries.py'), str(EVIDENCE / 'run-scoped.py')]),
            ('mypy', [PYTHON, '-m', 'mypy', '--config-file', 'tests/shared-launch-python/pyproject.toml', str(EVIDENCE / 'probe-boundaries.py'), str(EVIDENCE / 'run-scoped.py')]),
        ],
        'final': [('cloud-verification', ['python3', '-B', 'tests/cloud-orchestration-verification.tests.py']), ('cloud-contracts', ['python3', '-B', 'tests/cloud-orchestration-contracts.tests.py']), ('selected-plan', ['python3', '-B', 'tests/sdd-domain-multitarget-T-003.tests.py']), ('contracts', ['bash', 'tests/gates.tests.sh']), ('constant-parity', ['bash', 'tests/constant-parity.tests.sh']), ('guard-invariants-sh', ['bash', 'tests/phase2-guard-invariants.tests.sh']), ('guard-invariants-ps1', ['/workspace/.tools/sdd-forge-dev/bin/pwsh', '-NoProfile', '-File', 'tests/phase2-guard-invariants.tests.ps1']), ('registry-schema', ['bash', 'tests/capability-registry-schema.tests.sh']), ('guard-projection', ['python3', '-B', 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py', '--check']), ('gate-projection', ['python3', '-B', 'plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py', '--check']), ('vendored-mirrors', ['python3', '-B', 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py', '--check']), ('ruff', ['/tmp/cloud-quality-python/bin/python', '-m', 'ruff', 'check', '--config', 'tests/shared-launch-python/pyproject.toml', 'plugins/sdd-quality-loop/scripts/check-contract.py', 'plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py', 'plugins/sdd-quality-loop/scripts/cloud_verification.py', 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py', 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py', 'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py', 'tests/cloud-orchestration-verification.tests.py', 'plugins/sdd-azure-cloud/scripts/azure_observation.py', 'plugins/sdd-aws-cloud/scripts/aws_observation.py']), ('mypy-shared', ['/tmp/cloud-quality-python/bin/python', '-m', 'mypy', '--config-file', 'tests/shared-launch-python/pyproject.toml', 'plugins/sdd-quality-loop/scripts/check-contract.py', 'plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py', 'plugins/sdd-quality-loop/scripts/cloud_verification.py', 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py', 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py', 'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py', 'tests/cloud-orchestration-verification.tests.py']), ('mypy-azure', ['/tmp/cloud-quality-python/bin/python', '-m', 'mypy', '--config-file', 'tests/shared-launch-python/pyproject.toml', 'plugins/sdd-azure-cloud/scripts/azure_observation.py']), ('mypy-aws', ['/tmp/cloud-quality-python/bin/python', '-m', 'mypy', '--config-file', 'tests/shared-launch-python/pyproject.toml', 'plugins/sdd-aws-cloud/scripts/aws_observation.py'])],
        'after': [
            ('cloud-verification', ['python3', '-B', 'tests/cloud-orchestration-verification.tests.py']),
            ('selected-plan', ['python3', '-B', 'tests/sdd-domain-multitarget-T-003.tests.py']),
        ],
    }["final" if mode == "final-2" else mode]
    env = dict(os.environ, TMPDIR=str(SCRATCH), MYPYPATH=MYPYPATH, PYTHONDONTWRITEBYTECODE='1')
    # Identities above are explicit caller input, never obtained from this environment.
    env['PATH'] = '/workspace/.tools/sdd-forge-dev/bin:/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin:' + os.defpath
    results = []
    for name, command in commands:
        started = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        proc = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
        path = EVIDENCE / f'{mode}-{name}.log'
        path.write_bytes(proc.stdout)
        results.append(dict(command=command, cwd=str(ROOT), environment_overrides={k: env[k] for k in ('TMPDIR','MYPYPATH','PYTHONDONTWRITEBYTECODE','PATH')}, started_at=started, finished_at=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), exit_code=proc.returncode, log=path.relative_to(ROOT).as_posix()))
        print(name, proc.returncode, flush=True)
    (EVIDENCE / f'{mode}-commands.json').write_text(json.dumps(results,indent=2)+'\n')
    if any(row['exit_code'] for row in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
