"""Scoped reproducibility checks; never invokes the full suite or cloud transports."""
from pathlib import Path
import ast
import hashlib
import json
import subprocess

ROOT=Path(__file__).resolve().parents[5]
E=Path(__file__).resolve().parent
P=E.relative_to(ROOT).as_posix()
python='/tmp/cloud-quality-python/bin/python'
sources=['plugins/sdd-quality-loop/scripts/cloud_contracts.py','plugins/sdd-quality-loop/scripts/cloud_authorization.py','tests/cloud-orchestration-contracts.tests.py','tests/cloud-orchestration-execution.tests.py','templates/cloud/iam/trusted-policy.example.py']
commands=[
 ('green-contracts',['python3','-B',sources[2]]),
 ('green-admission',['python3','-B',sources[3]]),
 ('regression',['bash','tests/project-context-schema.tests.sh']),
 ('ruff',[python,'-m','ruff','check','--config','tests/shared-launch-python/pyproject.toml',*sources]),
 ('mypy',[python,'-m','mypy','--config-file','tests/shared-launch-python/pyproject.toml',*sources]),
 ('manifest-validation-final',['bash','plugins/sdd-implementation/scripts/validate-task-input-manifest.sh','--manifest',P+'/task-input-manifest.json','--snapshot-root','/tmp/cloud-T-002-repair-01a14d8e/inputs','--expected-task','T-002']),
 ('diff-check',['git','diff','--check','--',*sources,'templates/cloud/iam/README.md',*sorted(str(p.relative_to(ROOT)) for p in (ROOT/'contracts').glob('cloud-*.schema.json'))]),
]
results=[]
for name,command in commands:
    result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    path=E/(name+'.log');path.write_bytes(result.stdout)
    results.append(dict(command=command,exit_code=result.returncode,evidence=str(path.relative_to(ROOT))))
    print(name,result.returncode)
static={}
for name in sources:
    data=(ROOT/name).read_bytes();compile(data,name,'exec');tree=ast.parse(data)
    static[name]=dict(sha256=hashlib.sha256(data).hexdigest(),compile='OK',imports=[ast.unparse(n) for n in ast.walk(tree) if isinstance(n,(ast.Import,ast.ImportFrom))],dynamic_execution_calls=[ast.unparse(n.func) for n in ast.walk(tree) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id in ('eval','exec')])
(E/'static-check.json').write_text(json.dumps(static,indent=2)+'\n')
(E/'execution.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['exit_code']==0 for r in results) else 1)
