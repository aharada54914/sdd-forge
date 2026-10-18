"""Reproduce only T-002 and its direct schema regression; never the full suite."""
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
V=Path(__file__).resolve().parent
commands=[
    (['python3','-B','tests/cloud-orchestration-contracts.tests.py'],'green.log'),
    (['bash','tests/project-context-schema.tests.sh'],'regression.log'),
    (['bash','plugins/sdd-implementation/scripts/validate-task-input-manifest.sh','--manifest',
      'specs/cloud-orchestration/verification/T-002/task-input-manifest.json','--snapshot-root',
      '/tmp/cloud-T-002-01a14d58/inputs','--expected-task','T-002'],'manifest-validation-final.log'),
]
results=[]
for command,log in commands:
    p=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    (V/log).write_text(p.stdout+p.stderr)
    results.append({'command':command,'exit_code':p.returncode,'log':str((V/log).relative_to(ROOT))})
    if p.returncode: raise SystemExit(p.returncode)
compiled=[]
for rel in ['plugins/sdd-quality-loop/scripts/cloud_contracts.py','tests/cloud-orchestration-contracts.tests.py']:
    compile((ROOT/rel).read_bytes(),rel,'exec')
    compiled.append(rel)
manifest=json.loads((V/'task-input-manifest.json').read_bytes())
unchanged=[]
for item in manifest['allowed_inputs']:
    # External policy and T-001's mutable worker report are preserved in the snapshot;
    # frozen feature inputs and reused concrete code/schema dependencies must still match.
    if item['path'].startswith(('specs/cloud-orchestration/', 'contracts/', 'plugins/', 'tests/')):
        assert hashlib.sha256((ROOT/item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']
        unchanged.append(item['path'])
(V/'execution.json').write_text(json.dumps({'classification':'local synthetic tests; no cloud calls',
    'python':sys.version,'platform':platform.platform(),'commands':results,
    'compile_checked':compiled,'unchanged_initial_inputs':unchanged,
    'limits':['stdlib trace reports line, not branch, coverage','no dedicated Python lint/type tool installed',
              'no cloud/CI/OIDC/native Windows test','no full repository test run']},indent=2)+'\n')
print('T-002 local reproduction complete; no task or gate status changed')
