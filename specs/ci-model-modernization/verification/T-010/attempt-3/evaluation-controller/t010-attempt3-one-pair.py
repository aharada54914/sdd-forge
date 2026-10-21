from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import datetime,hashlib,json,os,signal,subprocess,sys,time
ROOT=Path('/workspace/sdd-forge');BASE=ROOT/'specs/ci-model-modernization/verification/T-010';AD=BASE/'pre-output-preparation/attempt-3-capability-fix';PLAN=json.loads((AD/'execution-plan.json').read_text());MANIFEST=json.loads((AD/'task-input-manifest.json').read_text());SNAP=Path(PLAN['snapshot_root']);ATT=BASE/'attempt-3/evidence';ATT.mkdir(parents=True,exist_ok=True);PRIVATE=SNAP.parent/'actual-private-logs';PRIVATE.mkdir(exist_ok=True)
env=dict(os.environ);env['PATH']='/opt/codex/bin:'+env.get('PATH','');env['TMPDIR']='/workspace/.task-scratch/ci-model-modernization';env['PYTHONDONTWRITEBYTECODE']='1'
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat();h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
batch=PLAN['batches'][int(sys.argv[1])];name=batch['name']
def pins(label):
 changed=[r['path'] for r in MANIFEST['allowed_inputs'] if h(SNAP/r['path'])!=r['sha256']]
 with (ATT/'immutable-source-checks.jsonl').open('a') as f:f.write(json.dumps({'at':now(),'label':label,'checked':len(MANIFEST['allowed_inputs']),'changed':changed})+'\n')
 if changed:raise RuntimeError('immutable source drift '+str(changed))
def run(arm):
 argv=arm['argv'];output=Path(argv[argv.index('--output')+1]);identity=output.name;start=now();begin=time.monotonic();cmd=[sys.executable,'-B','/workspace/.tools/run-with-subreaper.py']+argv
 if output.exists():raise RuntimeError('no overwrite/retry permitted: '+str(output))
 with (PRIVATE/(identity+'.stdout.log')).open('xb') as stdout,(PRIVATE/(identity+'.stderr.log')).open('xb') as stderr:
  p=subprocess.Popen(cmd,cwd=SNAP/'inputs',env=env,stdout=stdout,stderr=stderr,start_new_session=True)
  try:code=p.wait(timeout=360)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);code=p.wait(timeout=5)
 summary=json.loads((output/'summary.json').read_text()) if (output/'summary.json').exists() else {'failures':['missing summary']};events=[json.loads(x) for x in (output/'events.jsonl').read_text().splitlines()] if (output/'events.jsonl').exists() else [];errors=[x.get('params',{}).get('error') for x in events if x.get('method')=='error'];record={'arm':identity,'case':arm['case'],'model':arm['model'],'effort':arm['effort'],'repetition':arm['repetition'],'started_at':start,'finished_at':now(),'elapsed_seconds':time.monotonic()-begin,'argv':cmd,'exit_code':code,'output':str(output),'summary':summary,'native_errors':errors,'actual_answer':(output/'answer.txt').exists(),'private_stdout':str(PRIVATE/(identity+'.stdout.log')),'private_stderr':str(PRIVATE/(identity+'.stderr.log'))}
 if arm['case']!='harbor' and (output/'answer.txt').exists() and (output/'project').exists():
  sp=subprocess.run([sys.executable,'-B','/workspace/.tools/run-with-subreaper.py']+arm['scoring_argv'],cwd=SNAP/'inputs',env=env,capture_output=True,text=True,timeout=330);(output/'deterministic-score.stdout.json').write_text(sp.stdout);(output/'deterministic-score.stderr.log').write_text(sp.stderr);record['score']={'argv':arm['scoring_argv'],'exit_code':sp.returncode,'stdout_sha256':h(output/'deterministic-score.stdout.json'),'stderr_sha256':h(output/'deterministic-score.stderr.log')}
 else:record['score']='STOP_ROOT_HARBOR_SAFETY_REVIEW' if arm['case']=='harbor' else 'unavailable_no_answer'
 record['output_hashes']={str(p.relative_to(output)):h(p) for p in output.rglob('*') if p.is_file()} if output.exists() else {}
 (ATT/(identity+'-receipt.json')).write_text(json.dumps(record,indent=2)+'\n')
 return {'arm':identity,'output':str(output),'exit_code':code,'native_turns_started':summary.get('native_turns_started',0),'turn_status':summary.get('turn_status'),'failures':summary.get('failures',[]),'tools':summary.get('observation',{}).get('observed_tool_calls'),'actual_answer':record['actual_answer'],'native_errors':errors,'score_exit':record['score'].get('exit_code') if isinstance(record['score'],dict) else None}
pins(name+' before');dp=subprocess.run(batch['discovery_argv'],cwd=batch['discovery_cwd'],env=env,capture_output=True,text=True,timeout=90);obsfile=Path(batch['discovery_cwd'])/(name+'.json');(PRIVATE/(name+'-discovery.stderr.log')).write_text(dp.stderr);obs=json.loads(obsfile.read_text()) if obsfile.exists() else {};models={x['native_id']:x for x in obs.get('models',[])};stamp=datetime.datetime.fromisoformat(obs['observed_at'].replace('Z','+00:00')) if obs.get('observed_at') else None;fresh=stamp is not None and (datetime.datetime.now(datetime.timezone.utc)-stamp).total_seconds()<=300;available=[arm for arm in batch['arms'] if dp.returncode==0 and obs.get('status')=='complete' and fresh and models.get(arm['model'],{}).get('available') and arm['effort'] in models[arm['model']]['efforts']];withheld=[arm['model'] for arm in batch['arms'] if arm not in available]
(ATT/(name+'-discovery-receipt.json')).write_text(json.dumps({'at':now(),'argv':batch['discovery_argv'],'exit_code':dp.returncode,'status':obs.get('status'),'fresh':fresh,'observation_sha256':h(obsfile) if obsfile.exists() else None,'available':[a['model'] for a in available],'withheld':withheld,'proof_scope':'listing only, not inference/quota/backend execution'},indent=2)+'\n');print(json.dumps({'event':'batch-start','batch':name,'available':[a['model'] for a in available],'withheld':withheld}),flush=True)
with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,available))
pins(name+' after');result={'event':'batch-complete','batch':name,'results':results,'withheld':withheld};(ATT/(name+'-batch-result.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
