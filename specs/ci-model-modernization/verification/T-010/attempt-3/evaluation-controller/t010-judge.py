from pathlib import Path
import datetime,hashlib,importlib.util,json,os,random,re,subprocess,sys,time,uuid
ROOT=Path('/workspace/sdd-forge/specs/ci-model-modernization/verification/T-010');ATT=ROOT/'attempt-3';PRE=ROOT/'pre-output-preparation';PLAN=json.loads((PRE/'attempt-3-capability-fix/execution-plan.json').read_text());SNAP=Path(PLAN['snapshot_root']);FROZEN=SNAP/'inputs/specs/ci-model-modernization/verification/T-010/pre-output-preparation';PROTO=FROZEN/'semantic-judge-protocol-v1';OUT=ATT/'blinded-judges';PRIVATE=SNAP.parent/'judge-private';PRIVATE.mkdir(exist_ok=True);PRIVATE.chmod(0o700)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest(); now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat(); uid=lambda:uuid.uuid4().hex[:12]
def save(p,j):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
def document(path,content):return {'path':path,'content':content,'sha256':hashlib.sha256(content.encode()).hexdigest()}
def schema(v,s,base):
 if '$ref' in s:return schema(v,base['$defs'][s['$ref'].split('/')[-1]],base)
 types=s.get('type');types=[types] if isinstance(types,str) else types
 if types:assert any({'object':type(v)is dict,'array':type(v)is list,'string':type(v)is str,'integer':type(v)is int,'boolean':type(v)is bool,'null':v is None}.get(t,False) for t in types),'schema type'
 if 'const'in s:assert v==s['const'],'schema const'
 if 'enum'in s:assert v in s['enum'],'schema enum'
 if type(v)is dict:
  assert set(s.get('required',[]))<=v.keys(),'schema required'
  if s.get('additionalProperties')is False:assert v.keys()<=s.get('properties',{}).keys(),'schema extra'
  for k,x in v.items():
   if k in s.get('properties',{}):schema(x,s['properties'][k],base)
 if type(v)is list:
  assert len(v)>=s.get('minItems',0),'schema items'
  for x in v:schema(x,s.get('items',{}),base)
 if type(v)is str:
  assert len(v)>=s.get('minLength',0),'schema length'
  if 'pattern'in s:assert re.search(s['pattern'],v),'schema pattern'
 if type(v)is int and 'minimum'in s:assert v>=s['minimum'],'schema minimum'
 for branch in s.get('allOf',[]):
  conditional=branch.get('if',{});matches=all(v.get(k)==r.get('const') for k,r in conditional.get('properties',{}).items())
  if matches:schema(v,branch['then'],base)
def pins(label):
 m=json.loads((PRE/'attempt-3-capability-fix/task-input-manifest.json').read_text());bad=[r['path']for r in m['allowed_inputs']if h(SNAP/r['path'])!=r['sha256']];assert not bad,bad;save(ATT/'evidence'/('judge-source-'+label+'.json'),{'at':now(),'checked':len(m['allowed_inputs']),'changed':bad})
def build():
 assert not OUT.exists(),'fresh judge bundles required';pins('before-bundles');mapping=[];redactions=[];domains={'implementation':[],'review':[],'investigation':[],'skill-command-plan':[]};fixtures={};rubrics={}
 original=(FROZEN/'original-model-rubric.md').read_text()
 for domain in domains:
  rubrics[domain]=[document('criteria/model-rubric.md',original)]
  if domain=='skill-command-plan':
   for n,rel in enumerate(['skill-rubric-v1.md','executor-preparation-v3/skill-binding-rubric-v3.md','skill-comparison-v5/skill-rubric-v5.md']):
    raw=(FROZEN/rel).read_text();lines=[]
    for i,line in enumerate(raw.splitlines(keepends=True),1):
     # Only blind identity mappings; preserve the complete remaining substantive criterion text.
     clean=re.sub(r'`skill-bindings.json` binds opaque project inputs cedar and maple to whole preserved/current', '`skill-bindings.json` binds the two opaque project inputs to whole procedure',line)
     clean=re.sub(r'Cedar uses the same whole preserved baseline skill, SHA-256 `[^`]+`\. Maple now uses the whole Root current `[^`]+`, SHA-256 `[^`]+`\. The prior Maple SHA `[^`]+` was an intermediate T-008 snapshot before the 17:09 managed-allocation-boundary addition\.', '[Identity-only source-version/hash mapping withheld.] The prior procedure was an intermediate T-008 snapshot before the 17:09 managed-allocation-boundary addition.',clean)
     if clean!=line:redactions.append({'raw_path':rel,'line':i,'raw':line.rstrip('\n'),'blinded':clean.rstrip('\n'),'raw_sha256':h(FROZEN/rel)})
     lines.append(clean)
    rubrics[domain].append(document('criteria/skill-'+str(n+1)+'.md',''.join(lines)))
 for batch in PLAN['batches']:
  for arm in batch['arms']:
   case=arm['case'];domain='implementation'if case=='harbor'else 'review'if case in('orchard','meadow')else 'investigation'if case=='willow'else 'skill-command-plan';output=Path(arm['argv'][arm['argv'].index('--output')+1]);sid=uid()
   if case not in fixtures:
    fid=uid();fixture=FROZEN/('skill-comparison-v5/inputs'if case in('cedar','maple')else 'inputs')/case;fixtures[case]={'fixture_id':fid,'files':[document('fixtures/'+fid+'/'+str(p.relative_to(fixture)),p.read_text())for p in sorted(fixture.rglob('*'))if p.is_file()]}
   fid=fixtures[case]['fixture_id'];summary=json.loads((output/'summary.json').read_text());sc=output/'deterministic-score.stdout.json';score=json.loads(sc.read_text());answer=(output/'answer.txt').read_text();artifacts=[document(str(p.relative_to(output/'project')),p.read_text())for p in sorted((output/'project').rglob('*'))if p.is_file()];obs=summary.get('observation',{});files={str(p.relative_to(output)):h(p)for p in output.rglob('*')if p.is_file()}
   domains[domain].append({'submission_id':sid,'fixture_id':fid,'artifacts':artifacts,'answer':answer,'deterministic_score':{'scorer_sha256':h(FROZEN/'score.py'),'receipt_sha256':h(sc),'hard_pass':score['status']=='deterministic-pass','receipt':sc.read_text()},'controller_observations':{'wall_budget_satisfied':summary.get('elapsed_seconds',301)<=300,'tool_budget_satisfied':obs.get('observed_tool_calls',25)<=24,'scope_satisfied':not summary['failures'],'actual_backend_id_attested':False,'reroute_mismatch':bool(obs.get('reroutes')),'native_skill_binding_accepted':summary.get('native_turns_started')==1 and not summary['failures'] if case in('cedar','maple') else None}})
   mapping.append({'submission_id':sid,'fixture_id':fid,'domain':domain,'case':case,'model':arm['model'],'effort':arm['effort'],'repetition':arm['repetition'],'output':str(output),'raw_hashes':files,'redactions':[]})
 input_schema=json.loads((PROTO/'input.schema.json').read_text());manifest={'at':now(),'protocol_manifest_sha256':h(PROTO/'protocol-manifest.json'),'source_manifest_sha256':h(PRE/'attempt-3-capability-fix/task-input-manifest.json'),'domains':{},'privacy':'private mapping and raw native events excluded; stable shuffled opaque IDs; source identity bindings line-preserving redacted only'}
 for domain,subs in domains.items():
  random.SystemRandom().shuffle(subs);fs=[v for v in fixtures.values()if v['fixture_id']in {s['fixture_id']for s in subs}];request_case={'implementation':'harbor','review':'orchard','investigation':'willow','skill-command-plan':'skill'}[domain];request=(FROZEN/'requests'/(request_case+'.txt')).read_text()
  if domain=='review':request+='\nPaired clean-control request:\n'+(FROZEN/'requests/meadow.txt').read_text()
  bundle={'protocol_version':'semantic-judge-protocol-v1','domain':domain,'natural_request':request,'rubric_documents':rubrics[domain],'fixtures':fs,'submissions':subs};schema(bundle,input_schema,input_schema)
  encoded=json.dumps(bundle,ensure_ascii=False);assert '/workspace/'not in encoded and 'native-model-trials'not in encoded and 'native-skill-trials'not in encoded,'private path leak'
  # Identity labels are forbidden in artifact/answer/fixture filenames and content; criterion prose may name experiment arms.
  payload=json.dumps({'fixtures':fs,'submissions':subs},ensure_ascii=False)
  for label in ['gpt-6-astra','gpt-6.1-sol','gpt-6-luna','cedar','maple']:assert label not in payload.lower(),'identity leak '+label
  target=OUT/domain;save(target/'input.json',bundle)
  for name in ['brief.txt','input.schema.json','response.schema.json']:(target/name).write_bytes((PROTO/name).read_bytes())
  manifest['domains'][domain]={'submissions':len(subs),'files':{p.name:h(p)for p in target.iterdir()if p.is_file()},'schema_pass':True,'privacy_pass':True}
 save(PRIVATE/'root-map.json',mapping);save(PRIVATE/'identity-redactions.json',redactions);save(OUT/'bundle-manifest.json',manifest);pins('after-bundles');print(json.dumps({'bundle_manifest_sha256':h(OUT/'bundle-manifest.json'),'domains':manifest['domains'],'private_map':str(PRIVATE/'root-map.json')},indent=2))

def validate(domain,response,bundle):
 sch=json.loads((PROTO/'response.schema.json').read_text());schema(response,sch,sch);assert response['domain']==domain;subs={s['submission_id']:s for s in bundle['submissions']};assert {x['submission_id']for x in response['submissions']}==set(subs);assert len(response['submissions'])==len(subs)
 rubric='\n'.join(x['content']for x in bundle['rubric_documents']);globaldocs={x['path']:x['content']for x in bundle['rubric_documents']};globaldocs.update({x['path']:x['content']for f in bundle['fixtures']for x in f['files']})
 def evidence(e):
  sid=e['submission_id'];docs=dict(globaldocs)
  if sid is not None:
   assert sid in subs,'unknown evidence submission';s=subs[sid];docs.update({d['path']:d['content']for d in s['artifacts']});docs['answer.txt']=s['answer'];docs['deterministic-score.json']=s['deterministic_score']['receipt']
  assert e['path']in docs,'unknown citation path '+e['path'];lines=docs[e['path']].splitlines();assert 1<=e['line']<=len(lines),'citation line out of range';assert e['quote']==lines[e['line']-1] or e['quote']==lines[e['line']-1].strip(),'inexact citation quote'
 for s in response['submissions']:
  if not subs[s['submission_id']]['deterministic_score']['hard_pass']:assert s['deterministic_failure_preserved'],'hard failure waived'
  for c in s['criteria']:
   assert c['criterion_quote']in rubric,'criterion not quoted from frozen rubric'
   for e in c['evidence']:evidence(e)
 for r in response['material_regressions']:
  assert r['reference_id']in subs and r['affected_id']in subs and r['reference_id']!=r['affected_id'];assert r['criterion_quote']in rubric
  for e in r['evidence']:evidence(e)
 return {'schema_pass':True,'ids_pass':True,'exact_criterion_quotes_pass':True,'exact_path_line_quotes_pass':True,'hard_failures_preserved':True}

def judge(domain):
 target=OUT/domain;assert not(target/'judge-summary.json').exists(),'no overwrite/retry';manifest=json.loads((OUT/'bundle-manifest.json').read_text());assert all(h(target/n)==v for n,v in manifest['domains'][domain]['files'].items());bundle=json.loads((target/'input.json').read_text());schema(bundle,json.loads((target/'input.schema.json').read_text()),json.loads((target/'input.schema.json').read_text()));pins(domain+'-before')
 discovery=ATT/'discovery'/('judge-'+domain+'.json');cmd=['python3','-B',str(SNAP/'inputs/plugins/sdd-implementation/scripts/model-policy.py'),'discover','--host','codex-cli','--scope-id','t010-attempt3-judge-'+domain,'--output',discovery.name];d=subprocess.run(cmd,cwd=discovery.parent,capture_output=True,text=True,timeout=90);(PRIVATE/(domain+'-discovery-v2.stderr.log')).write_text(d.stderr);obs=json.loads(discovery.read_text());available=next((x for x in obs.get('models',[])if x['native_id']=='gpt-6-astra'),{});assert d.returncode==0 and obs.get('status')=='complete'and available.get('available')and 'high'in available.get('efforts',[])and (datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(obs['observed_at'].replace('Z','+00:00'))).total_seconds()<=300,'judge arm unavailable'

 spec=importlib.util.spec_from_file_location('transport',FROZEN/'executor-preparation-v3/runner.py');v3=importlib.util.module_from_spec(spec);spec.loader.exec_module(v3);v3.DISABLE=[x for x in v3.DISABLE if x!='code_mode_host']
 project=Path(__import__('tempfile').mkdtemp(prefix='review-',dir='/workspace/.task-scratch'))
 for name in ['input.json','brief.txt','response.schema.json']:(project/name).write_bytes((target/name).read_bytes())
 initial={p.name:h(p)for p in project.iterdir()};client=None;events=[];summary={'started_at':now(),'configured_id':'gpt-6-astra','effort':'high','actual_id':None,'proof':'unverified','native_turns_started':0,'domain':domain,'failures':[],'observed_tool_calls':0};started=time.monotonic();final=None
 try:
  client=v3.Client(str(project));client.request('initialize',{'clientInfo':{'name':'semantic_judge','version':'1'},'capabilities':{'experimentalApi':True}});client.send({'method':'initialized','params':{}});t=client.request('thread/start',{'model':'gpt-6-astra','cwd':str(project),'ephemeral':True,'approvalPolicy':'never','sandbox':'read-only','allowProviderModelFallback':False,'dynamicTools':[],'config':{'model_reasoning_effort':'high'}});assert t['model']=='gpt-6-astra'and t['reasoningEffort']=='high'and not t.get('instructionSources');thread=t['thread']['id'];started=time.monotonic();client.deadline=started+300;summary['thread_id']=thread;turn=client.request('turn/start',{'threadId':thread,'model':'gpt-6-astra','effort':'high','cwd':str(project),'input':[{'type':'text','text':(target/'brief.txt').read_text()+'\n\n'+(target/'input.json').read_text()}],'outputSchema':json.loads((target/'response.schema.json').read_text())})['turn']['id'];summary['native_turns_started']=1;summary['turn_id']=turn;pending=client.pending;client.pending=[]
  while True:
   msg=pending.pop(0)if pending else client.receive();events.append(msg);method=msg.get('method','');params=msg.get('params',{})
   if method=='thread/tokenUsage/updated':summary['provider_token_usage']=params.get('tokenUsage',{}).get('total')
   if method=='error':summary['failures'].append('native-error:'+json.dumps(params.get('error'))[:600])
   if method in('model/rerouted','thread/model/rerouted'):summary['failures'].append('model-rerouted')
   item=params.get('item',{});kind=item.get('type','')
   if method=='item/tool/call'or ('id'in msg and method)or method=='item/started'and kind not in('agentMessage','reasoning','userMessage','plan'):
    summary['observed_tool_calls']+=1;summary['failures'].append('unauthorized-judge-tool:'+method+':'+kind)
    if 'id'in msg:client.send({'id':msg['id'],'error':{'code':-32601,'message':'No tools authorized for semantic judgment.'}})
    client.send({'id':99999,'method':'turn/interrupt','params':{'threadId':thread,'turnId':turn}});break
   if method=='item/completed'and kind=='agentMessage':final=item.get('text')
   if method=='turn/completed'and params.get('threadId')==thread and params.get('turn',{}).get('id')==turn:
    summary['turn_status']=params['turn'].get('status');break
 except Exception as exc:summary['failures'].append(type(exc).__name__+': '+str(exc)[:1600])
 finally:
  if client:summary['argv']=client.argv;client.close()
  summary['elapsed_seconds']=time.monotonic()-started;summary['finished_at']=now()
  if summary['elapsed_seconds']>300:summary['failures'].append('timeout')
  if {p.name:h(p)for p in project.iterdir()}!=initial:summary['failures'].append('judge-project-write')
  if final is not None:
   (target/'judge-answer.txt').write_text(final)
   try:
    response=json.loads(final);save(target/'judge-response.json',response);summary['validation']=validate(domain,response,bundle)
   except Exception as exc:summary['failures'].append('validation:'+type(exc).__name__+': '+str(exc)[:2000])
  else:summary['failures'].append('no-judge-answer')
  if summary.get('turn_status')!='completed':summary['failures'].append('judge-turn-not-completed')
  (PRIVATE/(domain+'-events.jsonl')).write_text(''.join(json.dumps(x)+'\n'for x in events));summary['private_events_sha256']=h(PRIVATE/(domain+'-events.jsonl'));save(target/'judge-summary.json',summary);pins(domain+'-after');print(json.dumps(summary,indent=2))
if __name__=='__main__':
 if sys.argv[1]=='build':build()
 else:judge(sys.argv[1])
