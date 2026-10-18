"""Caller-only real verify-profile trial. Config and rubric are not candidate inputs."""
import hashlib,json,os,selectors,subprocess,sys,time
from pathlib import Path
cfg=json.loads(Path(sys.argv[1]).read_text())
public=Path(cfg['public_directory']);public.mkdir(parents=True,exist_ok=False)
private=Path(cfg['private_directory']);private.mkdir(parents=True,exist_ok=False)
proc=subprocess.Popen(['/workspace/.tools/sdd-forge-dev/verify-codex','app-server','--stdio','--strict-config'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=(private/'stderr.log').open('x'),bufsize=0)
selector=selectors.DefaultSelector();selector.register(proc.stdout,selectors.EVENT_READ);buffer=b''
events=(private/'events.jsonl').open('x')
def save(name,value):
 with (public/name).open('x') as f:json.dump(value,f,indent=2);f.write('\n')
def send(value):proc.stdin.write((json.dumps(value)+'\n').encode());proc.stdin.flush()
def read(deadline):
 global buffer
 while time.monotonic()<deadline:
  if b'\n' in buffer:
   line,buffer=buffer.split(b'\n',1);value=json.loads(line);events.write(json.dumps(value)+'\n');events.flush();return value
  if selector.select(1):
   block=os.read(proc.stdout.fileno(),65536)
   if not block:raise RuntimeError('native host closed')
   buffer+=block
 raise TimeoutError('native host trial deadline')
def request(number,method,params):
 send({'id':number,'method':method,'params':params})
 while True:
  value=read(time.monotonic()+180)
  if value.get('id')==number:
   if 'error' in value:raise RuntimeError(str(value['error']))
   return value['result']
try:
 init=request(1,'initialize',{'clientInfo':{'name':'cloud-host-trial','version':'1.0.0'},'capabilities':{'experimentalApi':True}})
 assert init['codexHome']=='/workspace/.tools/sdd-forge-dev/codex-verify'
 send({'method':'initialized'})
 discovered=request(2,'skills/list',{'cwds':[c['workspace'] for c in cfg['cases']]})
 save('skill-discovery.json',discovered)
 assert len(discovered['data'])==len(cfg['cases'])
 for entry in discovered['data']:
  assert not entry.get('errors'),entry.get('errors')
  for name,digest in cfg['expected_skill_hashes'].items():
   matches=[s for s in entry['skills'] if s['name']==name and s.get('enabled')]
   assert len(matches)==1,(name,'not uniquely enabled')
   assert hashlib.sha256(Path(matches[0]['path']).read_bytes()).hexdigest()==digest,(name,'stale installed skill')
 summaries=[]
 for index,case in enumerate(cfg['cases']):
  number=10+index*10
  allocated=request(number,'thread/start',{'cwd':case['workspace'],'model':cfg['model'],'sandbox':'workspace-write','approvalPolicy':'never','config':{'model_reasoning_effort':cfg['effort'],'features.multi_agent':False,'features.apps':False,'web_search':'disabled'}})
  thread=allocated['thread'];assert thread['status']['type']=='idle' and not thread['turns'] and thread['parentThreadId'] is None
  prompt=Path(case['prompt_file']).read_text()
  identity={'case':case['name'],'thread_id':thread['id'],'session_id':thread['sessionId'],'model':allocated['model'],'effort':cfg['effort'],'workspace':case['workspace'],'prompt_sha256':hashlib.sha256(prompt.encode()).hexdigest(),'profile':init['codexHome']}
  save(case['name']+'-identity.json',identity)
  request(number+1,'turn/start',{'threadId':thread['id'],'input':[{'type':'text','text':prompt}]})
  commands=[];answer='';deadline=time.monotonic()+1200
  while True:
   value=read(deadline);method=value.get('method','');params=value.get('params',{})
   if 'id' in value and method:
    send({'id':value['id'],'error':{'code':-32000,'message':'Only already authorized isolated local checks; no additional approval, credentials, or cloud activity'}})
   if method=='item/completed':
    item=params.get('item',{})
    if item.get('type')=='agentMessage':answer=item.get('text','')
    if item.get('type')=='commandExecution':commands.append(item)
   if method=='turn/completed':
    delivery=params['turn'];break
  (private/(case['name']+'-commands.json')).write_text(json.dumps(commands,indent=2)+'\n')
  (private/(case['name']+'-final.txt')).write_text(answer)
  result={**identity,'turn_status':delivery['status'],'turn_id':delivery['id'],'command_count':len(commands),'error':delivery.get('error'),'acceptance':'Caller must verify actual commands and artifacts; completed turn is not PASS.'}
  save(case['name']+'-delivery.json',result);summaries.append(result);print(json.dumps(result),flush=True)
  if delivery['status']!='completed':raise RuntimeError('native trial did not complete')
 save('deliveries.json',summaries)
finally:
 proc.terminate()
 try:proc.wait(timeout=5)
 except subprocess.TimeoutExpired:proc.kill();proc.wait()
 selector.close();events.close()
