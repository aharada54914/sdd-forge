import base64, importlib.util, json, subprocess, sys
from pathlib import Path
ROOT=Path('/workspace/sdd-forge'); OUT=Path(__file__).resolve().parent
SCRIPTS=ROOT/'plugins/sdd-quality-loop/scripts'
spec=importlib.util.spec_from_file_location('session',SCRIPTS/'workflow-state-session.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
requests=OUT/'requests.json';requests.write_text(json.dumps(dict(schema='workflow-state-batch/v1',requests=['first','second'])))
results=[]
for case in ['valid','stale','forged','invalid','boundary']:
 registry=OUT/case/'specs/workflow-state-registry.json'
 rows={}
 for runtime,command in [('bash',['bash',str(m.GATE)]),('powershell',['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoProfile','-File',str(SCRIPTS/'check-workflow-state.ps1')])]:
  r=subprocess.run(command+['--registry',str(registry)],capture_output=True,text=True,timeout=150)
  rows[runtime]=dict(exit_code=r.returncode,stdout=r.stdout,stderr=r.stderr)
 assert rows['bash']['exit_code']==rows['powershell']['exit_code'],(case,rows)
 if case=='valid':
  raw=m.execute_snapshot(m.capture(registry),registry,m.runner(),120)
  rows['sealed_raw']=dict(exit_code=raw[0],stdout=raw[1].decode(),stderr=raw[2].decode(),reason=raw[3],cleanup=raw[4])
  assert raw[0]==75 and raw[4],rows['sealed_raw']
 r=subprocess.run(['bash',str(m.GATE),'--registry',str(registry),'--batch',str(requests)],capture_output=True,text=True,timeout=180)
 rows['batch_cli_exit']=r.returncode
 batch=json.loads(r.stdout);rows['batch']=batch
 if batch.get('status')=='cold-required':
  assert r.returncode==2 and batch['complete'] is False and batch['results']==[],(case,batch)
  rows['comparison']='explicit cold fallback, no published PASS'
 else:
  assert all(row['exit_code']==rows['bash']['exit_code'] for row in batch['results']),(case,rows)
  assert batch['complete']==(rows['bash']['exit_code']==0)
  for row in batch['results']:
   assert base64.b64decode(row['stderr']).decode()==rows['bash']['stderr'],(case,'stderr mismatch')
  rows['comparison']='same normal exit and stderr'
 if case=='valid':
  assert rows['bash']['exit_code']==0,rows
  assert batch['status']=='cold-required' and batch['reason']=='external-or-historical-dependency',rows
 else:assert rows['bash']['exit_code']!=0,(case,rows)
 results.append(dict(case=case,**rows));print(case,rows['bash']['exit_code'],r.returncode,rows['comparison'],flush=True)
(OUT/'result.json').write_text(json.dumps(dict(scope='Linux Bash and Linux PowerShell; sealed batch Linux bubblewrap only',passed=True,results=results),indent=2)+'\n')
