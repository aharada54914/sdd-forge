"""Disposable checkout rollback of ONLY T-012 files, preserving candidate dependencies."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/cloud-T012-01a14de5')
CHECKOUT = SCRATCH / 'rollback'
BASE = json.loads((EVIDENCE/'before.json').read_bytes())['base_revision']
OWNED = ['plugins/sdd-azure-cloud/scripts/cloud.py', 'tests/cloud-orchestration-execution.tests.py',
         *['plugins/sdd-azure-cloud/scripts/'+name for name in
           ('azure_arm.py','azure_execution.py','azure_governed.py','governed-setup.md')]]
paths = set()
for directory in ('plugins/sdd-azure-cloud','plugins/sdd-aws-cloud','templates/cloud',
                  'specs/cloud-orchestration/verification/T-012/inputs/native-workspace',
                  'specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream'):
    paths.update(str(p.relative_to(ROOT)) for p in (ROOT/directory).rglob('*')
                 if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
paths.update(str(p.relative_to(ROOT)) for p in (ROOT/'contracts').glob('cloud-*.json'))
paths.update(['plugins/sdd-quality-loop/scripts/'+name for name in
              ('cloud_contracts.py','cloud_authorization.py','validate-approval-sidecar.py')])
paths.update('tests/cloud-orchestration-'+name+'.tests.py' for name in ('contracts','execution','routing'))
paths = sorted(paths)
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
entries=[dict(path=p,sha256=sha(ROOT/p)) for p in paths]
(EVIDENCE/'regression-dependencies.json').write_text(json.dumps(dict(
    classification='current transitive regression dependency snapshot; not initial pre-implementation inputs',
    files=entries),indent=2)+'\n')
for p in paths:
    target=SCRATCH/'regression-inputs'/p
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/p,target)
results=[]
def run(label,args,cwd):
    proc=subprocess.run(args,cwd=cwd,capture_output=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
    (EVIDENCE/(label+'.log')).write_bytes(proc.stdout+proc.stderr)
    results.append(dict(label=label,command=args,cwd=str(cwd),exit_code=proc.returncode))
    if proc.returncode:
        raise RuntimeError(label+' failed')
run('rollback-create',['git','worktree','add','--detach',str(CHECKOUT),BASE],ROOT)
try:
    for p in paths:
        target=CHECKOUT/p
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(SCRATCH/'regression-inputs'/p,target)
    before={p:sha(CHECKOUT/p) for p in paths if p not in OWNED}
    run('rollback-candidate',['python3','-B','tests/cloud-orchestration-execution.tests.py'],CHECKOUT)
    for p in OWNED:
        original=ROOT/'specs/cloud-orchestration/verification/T-012/inputs/before'/p
        if original.is_file():
            shutil.copyfile(original,CHECKOUT/p)
        else:
            (CHECKOUT/p).unlink(missing_ok=True)
    restored={p:sha(CHECKOUT/p) if (CHECKOUT/p).exists() else None for p in OWNED}
    run('rollback-restored-execution',['python3','-B','tests/cloud-orchestration-execution.tests.py'],CHECKOUT)
    run('rollback-restored-routing',['python3','-B','tests/cloud-orchestration-routing.tests.py'],CHECKOUT)
    after={p:sha(CHECKOUT/p) for p in before}
    assert before==after, 'Non-task candidate dependencies changed'
    for p in OWNED:
        shutil.copyfile(SCRATCH/'regression-inputs'/p,CHECKOUT/p)
    run('rollback-reapplied',['python3','-B','tests/cloud-orchestration-execution.tests.py'],CHECKOUT)
    (EVIDENCE/'rollback.json').write_text(json.dumps(dict(base_revision=BASE,restored=restored,
        unrelated_candidate_bytes_unchanged=True,commands=results,cloud_resources='No cloud actions; code rollback never deletes resources'),indent=2)+'\n')
finally:
    run('rollback-remove',['git','worktree','remove','--force',str(CHECKOUT)],ROOT)
