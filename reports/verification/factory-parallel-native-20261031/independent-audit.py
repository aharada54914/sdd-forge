import json,hashlib,pathlib,zipfile,statistics,importlib.util,subprocess
R=pathlib.Path('/workspace/scratch/factory-parallel-host-20261031');repo=pathlib.Path('/workspace/sdd-forge')
def read(p):return json.loads(p.read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
run=read(R/'run.json');jobs=read(R/'jobs.json')['jobs'];artifacts=read(R/'artifacts.json')['artifacts']
assert run['id']==41158269796 and run['run_attempt']==1 and run['conclusion']=='success' and run['status']=='completed'
assert len(jobs)==len(artifacts)==3
source='006e5a553f0667bfc6070dce25e6e9cffe9ea730'
measurement=repo/'plugins/sdd-quality-loop/scripts/run_measurement.py'
measurement=pathlib.Path('/workspace/scratch/factory-parallel-original-measurement.py')
measurement.write_bytes(subprocess.check_output(['git','show',source+':plugins/sdd-quality-loop/scripts/run_measurement.py'],cwd=repo))
spec=importlib.util.spec_from_file_location('independent_measurement',measurement);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
variants=[];digests={};sqlite={};programs=set();count=0
for p in (2,4,8):
 base=R/f'parallel-{p}';inner=base/f'parallel-{p}';d=read(inner/'result.json')
 artifact,=[a for a in artifacts if a['name']==f'parallel-{p}-{run["id"]}-1'];job,=[j for j in jobs if j['name']==f'observation ({p})']
 assert sha((R/f'parallel-{p}.zip').read_bytes())==artifact['digest'].split(':')[1]
 assert artifact['workflow_run']['id']==run['id'] and artifact['workflow_run']['head_sha']==run['head_sha']
 with zipfile.ZipFile(R/f'parallel-{p}.zip') as archive:
  for item in archive.infolist():
   if not item.is_dir():assert (base/item.filename).read_bytes()==archive.read(item)
 assert job['run_id']==run['id'] and job['run_attempt']==1 and job['head_sha']==run['head_sha'] and job['conclusion']=='success'
 assert d['native']==dict(GITHUB_REPOSITORY=run['repository']['full_name'],GITHUB_RUN_ID=str(run['id']),GITHUB_RUN_ATTEMPT='1',GITHUB_JOB='observation',GITHUB_SHA=run['head_sha'])
 assert d['source']==source and d['dirty'] is False and d['parallel']==p
 assert read(base/f'supervisor-{p}.json')==dict(cleanup=True,reason=None,exit_code=0)
 assert len(d['trials'])==3
 peaks=[];times=[]
 for t,trial in enumerate(d['trials']):
  assert trial['status']=='success' and len(trial['rows'])==8
  assert {row['id'] for row in trial['rows']}=={f'item-{i}' for i in range(8)}
  summary=read(inner/str(t)/'summary.json');reduced=m.summarize(inner/str(t)/'measurement',as_of=None)
  assert summary['complete'] and reduced['complete'] and not reduced['diagnostics']
  assert len(reduced['spans'])==9 and all(s['outcome']=='success' for s in reduced['spans'])
  assert reduced['measurement']['environment']['head']==source
  events=[]
  for row in trial['rows']:
   count+=1;dest=inner/str(t)/row['id'];assert read(dest/'record.json')==row
   assert row['outcome']=='passed' and row['exit_code']==0 and row['cleanup'] and row['directory_cleanup']
   for name in ('stdout','stderr'):assert sha((dest/pathlib.Path(row[name]['path']).name).read_bytes())==row[name]['sha256']
   assert sha((dest/'check.json').read_bytes())==row['observation_sha256']
   actual=read(dest/pathlib.Path(row['stdout']['path']).name);assert actual==row['fixture_output']
   seed=row['id'].removeprefix('item-');assert (actual['seed'],actual['count'],actual['total'])==(seed,10000,49995000)
   value=seed.encode()*65536
   for _ in range(128):value=hashlib.sha256(value).digest()+value[32:]
   assert actual['digest']==sha(value)
   digests.setdefault(seed,set()).add(actual['digest']);sqlite.setdefault(seed,set()).add(row['observed_outputs']['trial.sqlite']);programs.add(row['inputs']['sdd/skills/probe/run.py'])
   events.extend([(row['started_seconds'],1),(row['finished_seconds'],-1)])
  active=peak=0
  for _,delta in sorted(events):active+=delta;peak=max(peak,active)
  assert active==0 and peak<=p and peak==trial['peak_wrapper_concurrency'];peaks.append(peak);times.append(trial['seconds'])
 variants.append(dict(parallel=p,job_id=job['id'],runner_id=job['runner_id'],cpu_count=d['machine']['cpu_count'],image=d['machine']['image'],seconds=times,median_seconds=statistics.median(times),peak_wrapper_concurrency=peaks,zip_sha256=artifact['digest']))
assert count==72 and len(programs)==1 and all(len(x)==1 for x in digests.values()) and all(len(x)==1 for x in sqlite.values())
report=dict(status='PASS',run_id=run['id'],attempt=1,workflow_source=run['head_sha'],product_source=source,children_checked=count,measurements_reduced=9,variants=variants,limits=['Fixture temporary directories are not an OS security sandbox.','Separate hosted jobs and fixed order; no causal speedup inference.','No external WorkOrder ownership/lease, human-load or provider monetary-cost proof.','Observation receipt files referenced by runner rows were not included in these archives; this is a fixture audit, not evidence-bundle gate acceptance.'])
path=pathlib.Path('/workspace/scratch/factory-parallel-independent-summary.json');path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
