"""Disposable rollback to PRE-REPAIR candidate bytes, never origin/main."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/cloud-T-002-repair-01a14d8e')
CHECKOUT = SCRATCH / 'rollback-checkout'
before = json.loads((EVIDENCE / 'before.json').read_text())
paths = [p for p in before['files'] if not p.startswith('reports/')]
commands=[]

def run(name, command, cwd):
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (EVIDENCE / (name + '.log')).write_bytes(result.stdout)
    commands.append(dict(command=command,cwd=str(cwd),exit_code=result.returncode,evidence=name+'.log'))
    assert result.returncode == 0, (name, result.returncode)

def hashes():
    return {p:hashlib.sha256((CHECKOUT/p).read_bytes()).hexdigest() if (CHECKOUT/p).is_file() else None for p in paths}

run('rollback-create',['git','worktree','add','--detach',str(CHECKOUT),before['base_revision']],ROOT)
try:
    # Overlay complete initial input snapshot, including previously UNTRACKED candidate implementation.
    for source in (SCRATCH/'pre-repair').rglob('*'):
        if not source.is_file():continue
        relative=source.relative_to(SCRATCH/'pre-repair')
        if relative.parts[0]=='external':continue
        target=CHECKOUT/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
    baseline=hashes()
    assert all(baseline[p]==before['files'][p] for p in paths)
    for phase in ('before','candidate','restored'):
        if phase=='candidate':
            for p in paths:
                target=CHECKOUT/p
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(ROOT/p,target)
        if phase=='restored':
            for p in paths:
                if before['files'][p] is None:
                    (CHECKOUT/p).unlink(missing_ok=True)
                else:
                    shutil.copyfile(SCRATCH/'pre-repair'/p,CHECKOUT/p)
            assert hashes()==baseline
        for suite in ('contracts','execution'):
            run(f'rollback-{phase}-{suite}',['python3','-B',f'tests/cloud-orchestration-{suite}.tests.py'],CHECKOUT)
        run(f'rollback-{phase}-schema',['bash','tests/project-context-schema.tests.sh'],CHECKOUT)
    restored=hashes()
finally:
    run('rollback-remove',['git','worktree','remove','--force',str(CHECKOUT)],ROOT)
(EVIDENCE/'rollback.json').write_text(json.dumps(dict(base_revision=before['base_revision'],baseline=baseline,restored=restored,commands=commands,meaning='Local code rollback only; no cloud cleanup, no active checkout edits.'),indent=2)+'\n')
