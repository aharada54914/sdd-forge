"""Disposable local rollback; never changes the active checkout or evidence history."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/cloud-T-002-01a14d58')
CHECKOUT = SCRATCH/'rollback-checkout'
before = json.loads((EVIDENCE/'before.json').read_text())
owned = [*sorted(str(p.relative_to(ROOT)) for p in (ROOT/'contracts').glob('cloud-*.schema.json')),
         'plugins/sdd-quality-loop/scripts/cloud_contracts.py', 'tests/cloud-orchestration-contracts.tests.py']
assert not CHECKOUT.exists()
commands = []
def run(args, cwd, log, expected=0):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    (EVIDENCE/log).write_text(result.stdout+result.stderr)
    commands.append(dict(command=args,cwd=str(cwd),exit_code=result.returncode,expected_exit_code=expected,log=log))
    if result.returncode != expected:
        raise RuntimeError('Rollback check failed; inspect retained log')

def hashes():
    return {p: hashlib.sha256((CHECKOUT/p).read_bytes()).hexdigest() if (CHECKOUT/p).is_file() else None for p in owned}

run(['git','worktree','add','--detach',str(CHECKOUT),before['base_revision']],ROOT,'rollback-checkout.log')
try:
    initial=hashes()
    assert all(value is None for value in initial.values())
    run(['bash','tests/project-context-schema.tests.sh'],CHECKOUT,'rollback-baseline-before.log')
    for rel in owned:
        (CHECKOUT/rel).parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/rel,CHECKOUT/rel)
    installed=hashes()
    run(['python3','-B','tests/cloud-orchestration-contracts.tests.py'],CHECKOUT,'rollback-candidate-green.log')
    # Before-byte state for every task-owned file is absent; only those are removed.
    for rel in owned:
        assert before['task_owned_before_sha256'][rel] is None
        (CHECKOUT/rel).unlink()
    restored=hashes()
    assert restored == initial
    run(['bash','tests/project-context-schema.tests.sh'],CHECKOUT,'rollback-baseline-after.log')
    (EVIDENCE/'rollback.json').write_text(json.dumps(dict(classification='local disposable checkout; no cloud resources',
        base_revision=before['base_revision'],before=initial,candidate=installed,restored=restored,commands=commands),indent=2)+'\n')
finally:
    run(['git','worktree','remove','--force',str(CHECKOUT)],ROOT,'rollback-cleanup.log')
