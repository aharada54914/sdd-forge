import hashlib, importlib.util, json, os, platform, statistics, subprocess, sys, time
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path('/workspace/sdd-forge'); OUT=Path(__file__).parent
records=[]
def sha(raw): return hashlib.sha256(raw).hexdigest()
def call(argv,cwd=None):
 p=subprocess.run(argv,cwd=cwd,capture_output=True); records.append(dict(argv=list(map(str,argv)),cwd=str(cwd),exit=p.returncode,stdout=p.stdout.decode(errors='replace'),stderr=p.stderr.decode(errors='replace')))
 if p.returncode: raise RuntimeError(records[-1])
 return p.stdout
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
paths=['plugins/sdd-review-loop/scripts/fixed-review-inputs.py','plugins/sdd-review-loop/scripts/launch-impl-review.py','plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py','plugins/sdd-quality-loop/scripts/review-conditional-inputs.py']
source_pins={p:sha((ROOT/p).read_bytes()) for p in paths}
head=call(['git','rev-parse','HEAD'],ROOT).decode().strip()
F=load('fixed',ROOT/paths[0]); L=load('launcher',ROOT/paths[1]); C=load('conditional',ROOT/paths[3])
feature='workflow-state-integrity'; pre='reports/impl-review/'+feature+'/attempt-1/round-1/precheck-result.json'
conditional=C.resolve(ROOT,feature,'impl',revision=head)
data={'feature':feature,'stage':'impl','role':'impl-reviewer-a','allowed_input_manifest':conditional['inputs']}
selected=sorted(L.required_input_paths(ROOT,data,ROOT/pre,1,1,{'inventory':{'commit':head}}))
repo=OUT/'fixture'; repo.mkdir(); call(['git','init','-q'],repo)
for p in selected:
 target=repo/p; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(call(['git','show',head+':'+p],ROOT))
call(['git','add','.'],repo); call(['git','-c','user.name=Measurement Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixed original review inputs'],repo)
commit=call(['git','rev-parse','HEAD'],repo).decode().strip(); snapshot=OUT/'snapshot'; inventory=F.materialize(repo,commit,selected,snapshot)
record=OUT/'inventory.json'; record.write_text(json.dumps(inventory,indent=2)+'\n')
expected={x['path']:x['sha256'] for x in inventory['inputs']}
def consume(sources):
 if set(sources)!=set(expected): raise ValueError('required-set-mismatch')
 result=[]
 for p in sorted(sources):
  raw=Path(sources[p]).read_bytes()
  if sha(raw)!=expected[p]: raise ValueError('read-bytes-mismatch')
  result.append({'path':p,'sha256':sha(raw),'bytes':len(raw)})
 return result
samples=[]
for pair in range(5):
 for route in (['baseline','index'] if pair%2==0 else ['index','baseline']):
  started=time.perf_counter_ns()
  argv=[sys.executable,'-B',str(ROOT/paths[0]),'source-map' if route=='baseline' else 'reviewer-index','--repo',str(repo),'--snapshot',str(snapshot),'--record',str(record)]
  raw=call(argv); output=json.loads(raw)
  if route=='baseline':
   sources=output['sources']; state=F.state_reference(repo,inventory)
  else:
   sources={x['path']:x['source'] for x in output['sources']}; state=output['state_reference']; assert output['verdict'] is None and output['unresolved_findings'] is None
  consumed=consume(sources); elapsed=time.perf_counter_ns()-started
  output_path=OUT/f'{pair}-{route}.json'; output_path.write_bytes(raw)
  samples.append(dict(pair=pair,route=route,elapsed_ns=elapsed,inputs=consumed,state=state,output_sha256=sha(raw),argv=argv,human_active_ns=None))
for pair in range(5):
 a,b=[s for s in samples if s['pair']==pair]; assert a['inputs']==b['inputs'] and a['state']==b['state']
negative=[]
def probe(label):
 result={}
 for route in ['baseline','index']:
  argv=[sys.executable,'-B',str(ROOT/paths[0]),'source-map' if route=='baseline' else 'reviewer-index','--repo',str(repo),'--snapshot',str(snapshot),'--record',str(record)]
  p=subprocess.run(argv,capture_output=True); result[route]={'argv':argv,'exit':p.returncode,'stdout':p.stdout.decode(),'stderr':p.stderr.decode()}
 negative.append({'case':label,'results':result}); return result
victim=selected[0]; target=snapshot/victim; old=target.read_bytes(); target.chmod(0o644); target.write_bytes(old+b'\ntamper\n'); target.chmod(0o444)
assert all(v['exit'] for v in probe('snapshot-byte-tamper')['baseline':'index']) if False else True
r=probe('snapshot-byte-tamper'); assert all(v['exit']==1 for v in r.values())
target.chmod(0o644); target.write_bytes(old); target.chmod(0o444)
working=repo/victim; old_working=working.read_bytes(); working.write_bytes(old_working+b'\ndirty\n'); r=probe('dirty-current-selected-source'); assert r['baseline']['exit']==0 and r['index']['exit']==1; working.write_bytes(old_working)
snapshot.chmod(0o755); target.parent.chmod(0o755); target.unlink(); r=probe('missing-required-original'); assert all(v['exit']==1 for v in r.values()); target.write_bytes(old); target.chmod(0o444)
for label,mutation in [('omit-required-original',lambda m:m.pop(victim)),('replace-required-original',lambda m:m.update({victim:str(OUT/'inventory.json')}))]:
 sources={p:str(snapshot/p) for p in selected}; mutation(sources)
 try: consume(sources); raise AssertionError('accepted bad handoff')
 except ValueError as error: negative.append({'case':label,'consumer_rejected':str(error)})
# Real conditional owner rejects missing bindings before review admission.
if conditional['inputs']:
 bad=dict(data,allowed_input_manifest=[])
 try: L.required_dependencies(ROOT,bad,{'inventory':{'commit':head}}); raise AssertionError('missing conditional accepted')
 except ValueError as error: negative.append({'case':'missing-conditional-admission','rejected':str(error)})
after={p:sha((ROOT/p).read_bytes()) for p in paths}; assert after==source_pins
summary={'source_head':head,'source_pins_before':source_pins,'source_pins_after':after,'os':platform.platform(),'python':sys.version,'fixture_commit':commit,'feature':feature,'role':'impl-reviewer-a','conditional':conditional,'required_inputs':selected,'input_count':len(selected),'bytes_read_per_route':sum(x['bytes'] for x in samples[0]['inputs']),'pairs':5,'samples':samples,'negative_controls':negative,'timing':{route:{'median_ns':statistics.median([s['elapsed_ns'] for s in samples if s['route']==route]),'min_ns':min(s['elapsed_ns'] for s in samples if s['route']==route),'max_ns':max(s['elapsed_ns'] for s in samples if s['route']==route)} for route in ['baseline','index']},'human_time':'unobserved','review_quality':'not evaluated; byte/set preservation and rejection controls only','heavy_build_test_reuse':'not implemented'}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n'); (OUT/'commands.json').write_text(json.dumps(records,indent=2)+'\n'); print(json.dumps({k:summary[k] for k in ['source_head','input_count','bytes_read_per_route','timing','negative_controls']},indent=2))
