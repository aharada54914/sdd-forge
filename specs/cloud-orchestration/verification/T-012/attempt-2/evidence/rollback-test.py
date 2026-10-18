"""Restore only continuation-owned bytes in disposable checkout; entry is known Red."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[6]
E = Path(__file__).resolve().parent
S = Path('/tmp/cloud-T012-01a14e03')
CHECKOUT = S/'rollback'
base = json.loads((E/'before.json').read_bytes())['base_revision']
owned = ['plugins/sdd-azure-cloud/scripts/'+n for n in ('cloud.py','azure_execution.py','governed-setup.md')]
owned.append('tests/cloud-orchestration-execution.tests.py')
old = json.loads((ROOT/'specs/cloud-orchestration/verification/T-012/evidence/regression-dependencies.json').read_bytes())
paths = {v['path'] for v in old['files']} | set(owned)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
candidate = {p: sha(ROOT/p) for p in paths}
for p in paths:
    dest=S/'candidate'/p; dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(ROOT/p,dest)
initial = {v['original']:v for v in json.loads((E.parent/'inputs/path-map.json').read_bytes())}
commands=[]
def run(label, args, cwd=CHECKOUT, expected=0):
    result=subprocess.run(args,cwd=cwd,capture_output=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
    output=result.stdout+result.stderr
    (E/(label+'.log')).write_bytes(output)
    commands.append(dict(label=label,command=args,cwd=str(cwd),exit_code=result.returncode,expected_exit_code=expected))
    assert result.returncode==expected,(label,result.returncode)
    return output.decode()
run('rollback-create',['git','worktree','add','--detach',str(CHECKOUT),base],ROOT)
try:
    for p in paths:
        dest=CHECKOUT/p; dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(S/'candidate'/p,dest)
    run('rollback-candidate',['python3','-B','tests/cloud-orchestration-execution.tests.py'])
    run('rollback-candidate-contracts',['python3','-B','tests/cloud-orchestration-contracts.tests.py'])
    run('rollback-candidate-routing',['python3','-B','tests/cloud-orchestration-routing.tests.py'])
    for p in owned:
        shutil.copyfile(S/'inputs'/initial[p]['path'],CHECKOUT/p)
        assert sha(CHECKOUT/p)==initial[p]['sha256']
    result=run('rollback-entry-known-red',['python3','-B','tests/cloud-orchestration-execution.tests.py'],expected=1)
    assert 'Ran 54 tests' in result and 'FAILED (failures=2)' in result
    for name in ('test_cross_job_original_prepare_archive_cannot_repeat_unknown_put',
                 'test_unavailable_incomplete_or_excessive_intent_history_blocks_without_put'):
        assert 'FAIL: '+name in result
    run('rollback-entry-contracts',['python3','-B','tests/cloud-orchestration-contracts.tests.py'])
    run('rollback-entry-routing',['python3','-B','tests/cloud-orchestration-routing.tests.py'])
    assert all(sha(CHECKOUT/p)==candidate[p] for p in paths if p not in owned)
    restored={p:sha(CHECKOUT/p) for p in owned}
    for p in owned:shutil.copyfile(S/'candidate'/p,CHECKOUT/p)
    run('rollback-reapplied',['python3','-B','tests/cloud-orchestration-execution.tests.py'])
    assert all(sha(CHECKOUT/p)==candidate[p] for p in paths)
finally:
    run('rollback-remove',['git','worktree','remove','--force',str(CHECKOUT)],ROOT)
(E/'rollback.json').write_text(json.dumps(dict(base_revision=base,commands=commands,
    classification='continuation rollback preserves original candidate; known two Red restored, never passing baseline',
    restored=restored,candidate=[dict(path=p,sha256=candidate[p]) for p in sorted(paths)],
    unrelated_candidate_bytes_unchanged=True,cloud_actions=False),indent=2)+'\n')
