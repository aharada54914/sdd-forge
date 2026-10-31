import os,copy,hashlib,importlib.util,json,shlex,subprocess,sys
from pathlib import Path
ROOT=Path('/workspace/sdd-forge');OUT=Path(__file__).resolve().parent
S=ROOT/'plugins/sdd-quality-loop/scripts'
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m);return m
F=load('collector_fixtures',ROOT/'tests/project-evidence-collector.tests.py')
T=load('selected_fixtures',ROOT/'tests/sdd-domain-multitarget-T-003.tests.py')
results={}
case=F.CollectorTests();case.setUp()
try:
 root=case.root;fixture=case.fixture
 fixture.manifest['checks']=['cli-library'];fixture.write_manifest();fixture.task();fixture.observation.unlink()
 registry,manifest,contract=T.passing_fixture('cli-library');contract.update(task_id='T-001',feature='example')
 # Retain every existing owner-required check, but collect this selected gate for real.
 for row in contract['checks']:
  if row['id']=='cli-library': row.update(passes=False,evidence='',command='',exit_code=1)
 case.contract.write_text(json.dumps(contract));(root/'evidence.log').write_text('Preexisting synthetic owner fixture evidence, not a new execution claim.\n');(root/'verifier.py').write_text('pass\n')
 for name,data in [('registry.json',registry),('manifest.json',manifest)]: (root/name).write_text(json.dumps(data))
 output=root/'specs/example/verification/T-001/selected-plan.json';output.parent.mkdir(parents=True)
 def evaluate(contract_path):
  cmd=[sys.executable,str(S/'evaluate-selected-plan.py'),'--repo-root',str(root),'--registry',str(root/'registry.json'),'--facet-manifest',str(root/'manifest.json'),'--contract',str(contract_path),'--output',str(output)]
  r=subprocess.run(cmd,capture_output=True,text=True,timeout=30)
  return dict(exit_code=r.returncode,stdout=r.stdout,stderr=r.stderr,plan=json.loads(output.read_text()) if output.exists() else None)
 before=evaluate(case.contract)
 collected=F.C.collect(root,case.contract,fixture.task_path,'example','cli-library')
 generated=root/collected['contract'];after=evaluate(generated)
 required=lambda c:{r['id']:r['required'] for r in c['checks']}
 new=json.loads(generated.read_text());assert required(contract)==required(new)
 assert json.loads(case.contract.read_text())==contract
 assert before['exit_code']==1 and after['exit_code']==0,(before,after,collected)
 observation=next((root/'reports/project-skill-observations/T-001/run1').glob('cli-library.json'))
 actual=json.loads(observation.read_text());assert actual['schema']=='project-verification-observation/v2'
 missing=copy.deepcopy(new);missing['checks']=[r for r in missing['checks'] if r['id']!='unit-tests'];(root/'missing.json').write_text(json.dumps(missing));blocked=evaluate(root/'missing.json');assert blocked['exit_code']==1
 original=copy.deepcopy(actual);mutations=[]
 for label in ['unknown-schema','unknown-toolchain','stale-toolchain','stale-environment','legacy-v1']:
  bad=copy.deepcopy(original)
  if label=='unknown-schema':bad['schema']='project-verification-observation/v999'
  elif label=='unknown-toolchain':bad['environment']['toolchain']={}
  elif label=='stale-toolchain':bad['environment']['toolchain'][0]['sha256']='0'*64
  elif label=='stale-environment':bad['environment']['variables_sha256']='0'*64
  else:
   bad['schema']='project-verification-observation/v1';bad['environment'].pop('toolchain');bad['environment'].pop('variables_sha256')
  observation.write_text(json.dumps(bad))
  try:
   validated=F.C.V.validate(root,'example',observation,fixture.task_path)
   projection=F.C.V.project_execution({'id':'cli-library','required':True},validated)
   assert 'passes' not in projection,(label,projection)
   mutations.append(dict(case=label,status=validated[2],projects_pass=False))
  except ValueError as e:mutations.append(dict(case=label,rejected=str(e)))
 observation.write_text(json.dumps(original))
 results['selected_plan']=dict(before=before,after=after,missing_required=blocked,collector=collected,required_set_unchanged=True,original_contract_unchanged=True,observation=original,negative_observations=mutations,scope='Existing synthetic Registry/Facet Manifest selected-plan fixture with real execution of cli-library only. Other baseline observations retain synthetic preexisting test evidence; not complete Full approval.')
except Exception:
 print('fixture retained until cleanup:',case.root,file=sys.stderr);raise
finally:case.doCleanups()
# Lite owner executes its declared script; it does not import arbitrary observations.
results['lite']=[]
for label,baseline_exit,preexisting,runtime in [('without-observation',0,False,'posix'),('unrelated-observation',0,True,'posix'),('baseline-failure',7,False,'posix'),('powershell-owner',0,False,'powershell')]:
 case=F.CollectorTests();case.setUp()
 try:
  root=case.root;(root/'scripts').mkdir()
  summary=dict(schema='sdd-capability-summary/v1',feature='fixture',track='lite',capabilities=['fixture'],required_lite_checks=['emit-proof'],full_upgrade_required=False)
  (root/'summary.json').write_text(json.dumps(summary))
  (root/'scripts/test.sh').write_text('#!/bin/sh\nprintf baseline-executed\\n\nexit '+str(baseline_exit)+'\n')
  argv=[sys.executable,str(ROOT/'plugins/sdd-bootstrap/scripts/project-skill.py'),'run','--root',str(root),'--name','example','--check','smoke','--task-input-manifest',str(case.fixture.task_path)]
  (root/'scripts/emit-proof.sh').write_text('#!/bin/sh\nexec '+shlex.join(argv)+'\n')
  (root/'scripts/test.ps1').write_text("Write-Output 'baseline-executed'\nexit "+str(baseline_exit)+'\n')
  (root/'scripts/emit-proof.ps1').write_text('& '+ ' '.join("'"+a.replace("'","''")+"'" for a in argv)+'\nexit $LASTEXITCODE\n')
  if preexisting:(root/'untrusted-observation.json').write_text('{"schema":"project-verification-observation/v999","outcome":"passed"}')
  r=subprocess.run([sys.executable,str(ROOT/'plugins/sdd-lite/lib/run-lite-gate.py'),'--summary',str(root/'summary.json'),'--enforcement','required','--repo-root',str(root),'--runtime',runtime,'--check','test'],capture_output=True,text=True,timeout=40,env=dict(os.environ,PATH='/workspace/.tools/sdd-forge-dev/bin:'+os.environ['PATH']))
  payload=json.loads(r.stdout);assert r.returncode==(1 if baseline_exit else 0),(label,r.stderr,payload)
  assert [c['id'] for c in payload['checks']]==['test','emit-proof'],payload
  observation=json.loads(next((root/'reports/project-skill-observations/T-001/run1').glob('smoke.json')).read_text())
  assert observation['schema']=='project-verification-observation/v2' and observation['outcome']=='passed'
  results['lite'].append(dict(case=label,exit_code=r.returncode,result=payload,observation_schema=observation['schema'],scope='Explicit fixture script adapter through the unchanged Lite owner; required baseline test also executes. Not automatic discovery of observations.'))
 finally:case.doCleanups()
results['product_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [S/'validate-project-skill.py',S/'collect-project-evidence.py',S/'evaluate-selected-plan.py',ROOT/'plugins/sdd-lite/lib/run-lite-gate.py']}
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n');print('selected-plan and Lite owner integration controls passed')
