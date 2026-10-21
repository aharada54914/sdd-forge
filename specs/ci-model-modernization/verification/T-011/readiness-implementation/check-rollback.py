"""Exercise a T011-only rollback in a disposable local Git checkout."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
OWNED=Path('/workspace/.task-scratch/ci-model-modernization/t011-readiness-implementation')
CHECKOUT=OWNED/'rollback-checkout'
CHECKOUT.mkdir(exist_ok=False)
TARGETS=['tests/verification-impact.py','tests/verification-catalog.json','contracts/verification-ci-plan.schema.json','tests/verification-ci-plan.tests.py']
BASE=OWNED/'before'
paths=set(TARGETS+['tests/verification.py','tests/verification-workflow.py','tests/verification-ci.py','tests/verification-ci.tests.py','tests/verification-timings.json','tests/verification-impact.tests.py','.github/workflows/test.yml'])
paths.update(s['path'] for s in json.loads((ROOT/'tests/verification-catalog.json').read_text())['suites'])
for p in paths:
    source=BASE/p if p in TARGETS else ROOT/p
    target=CHECKOUT/p
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
for name in ['js-yaml','argparse']:
    p='mcp/sdd-forge-mcp/node_modules/'+name
    shutil.copytree(ROOT/p,CHECKOUT/p)
env=dict(os.environ,TMPDIR='/workspace/.task-scratch/ci-model-modernization',PYTHONDONTWRITEBYTECODE='1')
env['PATH']='/workspace/.tools/sdd-forge-dev/bin:'+env['PATH']
def git(*args):
    return subprocess.check_output(['git','-C',str(CHECKOUT),*args],text=True).strip()
git('init','-q'); git('config','user.name','T011 rollback fixture'); git('config','user.email','fixture@example.invalid')
(CHECKOUT/'.gitignore').write_text('mcp/sdd-forge-mcp/node_modules/\n__pycache__/\n')
git('add','.'); git('commit','-qm','local T011 subset baseline')
baseline_revision=git('rev-parse','HEAD')
records=[]
def pins(base):
    return {p:hashlib.sha256((base/p).read_bytes()).hexdigest() for p in TARGETS}
def run(label,extra=()):
    command=[sys.executable,'-B','tests/verification-ci-plan.tests.py',*extra,'-v']
    started=time.monotonic(); result=subprocess.run(command,cwd=CHECKOUT,env=env,capture_output=True,text=True)
    (HERE/(label+'.log')).write_text(result.stdout+result.stderr)
    row={'phase':label,'command':command,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-started,'pins':pins(CHECKOUT)}
    records.append(row); (HERE/'rollback-progress.json').write_text(json.dumps(records,indent=2)+'\n')
    print(json.dumps({'phase':label,'exit_code':result.returncode,'tail':result.stderr[-200:]}),flush=True)
    assert result.returncode==0,label
run('rollback-baseline50')
for p in TARGETS: shutil.copy2(ROOT/p,CHECKOUT/p)
assert pins(CHECKOUT)==pins(ROOT)
run('rollback-candidate54')
git('checkout',baseline_revision,'--',*TARGETS)
assert pins(CHECKOUT)==pins(BASE)
run('rollback-reverted50')
for p in TARGETS: shutil.copy2(ROOT/p,CHECKOUT/p)
assert pins(CHECKOUT)==pins(ROOT)
run('rollback-restored-focused4',('OmissionReadinessTests',))
record={'scope':'Disposable local source subset; only T011 three products and four new test methods toggled; preexisting work preserved. No source repository checkout/reset. Catalog suite files are read-only validation closure and not executed as a full profile.','timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checkout':str(CHECKOUT),'fixture_baseline_revision':baseline_revision,'copied_source_files':len(paths),'baseline_pins':pins(BASE),'restored_candidate_pins':pins(CHECKOUT),'source_repository_candidate_pins':pins(ROOT),'exact_restoration':pins(CHECKOUT)==pins(ROOT),'checks':records}
(HERE/'rollback-results.json').write_text(json.dumps(record,indent=2)+'\n')
