"""Restore task entry bytes in a private disposable checkout, never live files."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import TypedDict


class FileRecord(TypedDict):
    path: str
    candidate_sha256: str
    entry_sha256: str | None


repo = Path(sys.argv[1]).resolve()
scratch = Path(sys.argv[2]).resolve()
checkout = scratch / 'rollback-release-prep'
checkout.mkdir()
archive = scratch / 'entry.tar'
base = (scratch / 'base-revision.txt').read_text().strip()
subprocess.run(['git', 'archive', '--format=tar', '--output', str(archive), base], cwd=repo, check=True)
subprocess.run(['tar', '-xf', str(archive), '-C', str(checkout)], check=True)
manifest = json.loads((repo / 'specs/cloud-orchestration/verification/T-008/attempt-1/task-input-manifest.json').read_text())
outputs = manifest['allowed_outputs']
changed = subprocess.check_output(['git', 'diff', '--name-only'], cwd=repo, text=True).splitlines()
changed += ['plugins/sdd-azure-cloud/examples/local-route-example.py',
            'plugins/sdd-azure-cloud/references/dependencies.md', 'plugins/sdd-aws-cloud/references/dependencies.md',
            'reports/verification/cloud-orchestration-release.md']
changed += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=repo, text=True).splitlines()
changed = sorted(set(p for p in changed if not p.startswith('specs/cloud-orchestration/verification/T-008/') and p != 'reports/implementation/cloud-orchestration/T-008.md'))
owned = [p for p in changed if any(p == x or (x.endswith('/') and p.startswith(x)) for x in outputs)]
records: list[FileRecord] = []
for p in owned:
    f = repo / p
    dest = checkout / p
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(f, dest)
    before = scratch / 'initial' / p
    records.append(FileRecord(path=p, candidate_sha256=hashlib.sha256(f.read_bytes()).hexdigest(),
                        entry_sha256=hashlib.sha256(before.read_bytes()).hexdigest() if before.exists() else None))
env = dict(os.environ, PATH='/workspace/.tools/sdd-forge-dev/bin:' + os.environ['PATH'])
evidence = repo / 'specs/cloud-orchestration/verification/T-008/attempt-1'
commands = [([sys.executable, '-B', str(evidence / 'docs-check.py'), str(checkout)], 'docs'),
            (['/workspace/.tools/sdd-forge-dev/bin/pwsh', '-NoProfile', '-File', 'tests/validate-repository.ps1'], 'validator')]

def check(stage: str, expected_docs: int) -> None:
    for args, name in commands:
        result = subprocess.run(args, cwd=checkout, env=env, capture_output=True, timeout=180)
        (evidence / f'rollback-{stage}-{name}.log').write_bytes(result.stdout + result.stderr)
        expected = expected_docs if name == 'docs' else 0
        assert result.returncode == expected, (stage, name, result.returncode)
        print(stage, name, 'exit', result.returncode, 'expected', expected)

check('candidate', 0)
for record in records:
    p = record['path']
    initial = scratch / 'initial' / p
    dest = checkout / p
    if initial.exists():
        shutil.copyfile(initial, dest)
        assert hashlib.sha256(dest.read_bytes()).hexdigest() == record['entry_sha256']
    else:
        dest.unlink()
check('restored-entry', 1)
for record in records:
    dest = checkout / record['path']
    shutil.copyfile(repo / record['path'], dest)
    assert hashlib.sha256(dest.read_bytes()).hexdigest() == record['candidate_sha256']
check('reapplied', 0)
(evidence / 'rollback-hashes.json').write_text(json.dumps(dict(base_revision=base, files=records), indent=2) + '\n')
print('PASS: exact task-owned entry restoration and reapply; no cloud rollback or live workspace edits')
