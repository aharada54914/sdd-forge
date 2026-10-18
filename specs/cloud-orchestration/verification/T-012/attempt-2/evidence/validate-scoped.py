"""Task-only repeatable validation; all provider/auth transports are deterministic."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[6]
E = Path(__file__).resolve().parent
S = Path('/tmp/cloud-T012-01a14e03')
files = ['plugins/sdd-azure-cloud/scripts/' + n + '.py'
         for n in ('cloud', 'azure_arm', 'azure_execution', 'azure_governed')]
files.append('tests/cloud-orchestration-execution.tests.py')
commands = [
    ('execution', ['python3', '-B', 'tests/cloud-orchestration-execution.tests.py']),
    ('contracts', ['python3', '-B', 'tests/cloud-orchestration-contracts.tests.py']),
    ('routing', ['python3', '-B', 'tests/cloud-orchestration-routing.tests.py']),
    ('ruff', ['/tmp/cloud-quality-python/bin/ruff', 'check', '--no-cache', *files]),
    ('mypy', ['/tmp/cloud-quality-python/bin/mypy', '--cache-dir', str(S/'mypy'),
              '--follow-imports', 'silent', '--ignore-missing-imports', *files]),
    ('schema-parity', ['python3', '-B', str(E/'capture-fixture.py')]),
    ('coverage', ['python3', '-B', str(E/'verify-local.py')]),
    ('manifest-validation-final', ['bash', 'plugins/sdd-implementation/scripts/validate-task-input-manifest.sh',
      '--manifest', str(E.parent/'task-input-manifest.json'), '--snapshot-root', str(S/'inputs'), '--expected-task', 'T-012']),
    ('diff-check', ['git', 'diff', '--check', '--', *files, 'reports/implementation/cloud-orchestration/T-012.md']),
]
results = []
for label, command in commands:
    now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    run = subprocess.run(command, cwd=ROOT, capture_output=True,
                         env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
    (E/(label+'.log')).write_bytes(run.stdout+run.stderr)
    results.append(dict(command=command, started_at=now, exit_code=run.returncode,
                        log=(E/(label+'.log')).relative_to(ROOT).as_posix()))
    print(label, run.returncode, flush=True)
(E/'execution.json').write_text(json.dumps(dict(
    classification='task-scoped deterministic transport tests; native local compiler regression; no cloud',
    run_id='01a14e03-aadd-7da3-9d54-8d3db30fd7bc', task_attempt_count=2,
    files=[dict(path=p,sha256=hashlib.sha256((ROOT/p).read_bytes()).hexdigest()) for p in files],
    commands=results, live={'TEST-003':'BLOCKED','TEST-005':'BLOCKED','TEST-009':'BLOCKED'}), indent=2)+'\n')
raise SystemExit(int(any(r['exit_code'] for r in results)))
