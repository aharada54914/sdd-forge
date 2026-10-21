"""Owned public app-server JSONRPC executor. Trial mode is explicit; default is zero-turn."""
import argparse, datetime, hashlib, json, os, pathlib, queue, signal, subprocess, sys, tempfile, threading, time
ROOT=pathlib.Path(__file__).resolve().parent
BASE=ROOT.parent
sys.path.insert(0,str(BASE/'native-preparation-v2'))
from fixture_tools import FixtureTools,EventController,specs
CLI='/opt/codex/bin/codex'
DISABLE=['shell_tool','unified_exec','apps','plugins','multi_agent','browser_use','browser_use_external','browser_use_full_cdp_access','computer_use','image_generation','view_image','sleep_tool','tool_suggest','skill_search','code_mode_host','hooks']
LIMIT_LINE=4*1024*1024

def stop(process):
    # Kill the owned process group even if its parent exited, so public-test descendants cannot linger.
    try:os.killpg(process.pid,signal.SIGTERM)
    except ProcessLookupError:pass
    try:process.wait(timeout=2)
    except subprocess.TimeoutExpired:pass
    try:os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    process.wait(timeout=2)

class Client:
    """Same bounded stdio JSON-lines protocol as CodexClient; handles server requests instead of dropping them."""
    def __init__(self,cwd):
        self.argv=[CLI,'app-server']+sum((['--disable',f] for f in DISABLE),[])
        self.process=subprocess.Popen(self.argv,cwd=cwd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,start_new_session=True)
        self.lines=queue.Queue(maxsize=64);self.sequence=0;self.deadline=time.monotonic()+60;self.methods=[];self.pending=[];self.total_bytes=0
        def reader():
            while True:
                line=self.process.stdout.readline(LIMIT_LINE+1)
                self.lines.put(line)
                if not line or len(line)>LIMIT_LINE:return
        threading.Thread(target=reader,daemon=True).start()
    def send(self,message):
        if 'method' in message:self.methods.append(message['method'])
        data=json.dumps(message,allow_nan=False).encode()+b'\n';done=queue.Queue(maxsize=1)
        def write():
            try:self.process.stdin.write(data);self.process.stdin.flush();done.put(None)
            except OSError as exc:done.put(exc)
        threading.Thread(target=write,daemon=True).start()
        try:failure=done.get(timeout=max(.01,min(15,self.deadline-time.monotonic())))
        except queue.Empty:raise TimeoutError('protocol write timeout') from None
        if failure:raise failure
    def receive(self):
        left=self.deadline-time.monotonic()
        if left<=0:raise TimeoutError('wall timeout')
        try:line=self.lines.get(timeout=left)
        except queue.Empty:raise TimeoutError('wall timeout') from None
        self.total_bytes+=len(line)
        if not line or len(line)>LIMIT_LINE or self.total_bytes>32*1024*1024:raise RuntimeError('closed or oversized protocol stream')
        value=json.loads(line)
        if not isinstance(value,dict):raise RuntimeError('non-object protocol record')
        return value
    def request(self,method,params):
        self.sequence+=1;ident=self.sequence;self.send({'id':ident,'method':method,'params':params})
        while True:
            msg=self.receive()
            if 'method' in msg:
                self.pending.append(msg);continue
            if msg.get('id')!=ident:raise RuntimeError('uncorrelated response')
            if 'error' in msg:raise RuntimeError('native RPC rejected '+method+': '+json.dumps(msg['error'])[:1000])
            return msg['result']
    def close(self):stop(self.process)

def public_checks(files,remaining):
    """Only original public test, with supplied fixture files. This is not an OS read sandbox."""
    expected={'README.md','selector.py','test_selector.py'}
    if set(files)!=expected or files['test_selector.py']!=(BASE/'inputs/harbor/test_selector.py').read_text():
        return {'success':False,'output':'Public test inputs differ from supplied fixture.'}
    with tempfile.TemporaryDirectory(prefix='harbor-',dir='/workspace/.task-scratch') as temp:
        project=pathlib.Path(temp)
        for name,text in files.items():(project/name).write_text(text)
        # -I excludes script cwd; insert the fixed owned project, then run only its original public test.
        argv=[sys.executable,'-I','-B','-c','import runpy,sys; sys.path.insert(0,"."); runpy.run_path("test_selector.py",run_name="__main__")']
        environment={'PATH':'/usr/bin:/bin','PYTHONDONTWRITEBYTECODE':'1','TMPDIR':temp,'LANG':'C.UTF-8'}
        process=subprocess.Popen(argv,cwd=temp,env=environment,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
        chunks=[];overflow=threading.Event()
        def read_output():
            data=process.stdout.read(16385);chunks.append(data[:16384])
            if len(data)>16384:
                overflow.set()
                try:os.killpg(process.pid,signal.SIGKILL)
                except ProcessLookupError:pass
        reader=threading.Thread(target=read_output,daemon=True);reader.start()
        try:code=process.wait(timeout=max(.01,min(300,remaining)))
        except subprocess.TimeoutExpired:
            stop(process);return {'success':False,'output':'Public test timeout.'}
        finally:
            stop(process);reader.join(timeout=1)
        if overflow.is_set():return {'success':False,'output':'Public test output limit exceeded.'}
        text=b''.join(chunks).decode(errors='replace').replace(temp,'<project>')
        return {'success':code==0,'output':text or ('Public test passed.' if code==0 else 'Public test failed.')}

def load_input(case):
    project=BASE/'inputs'/case
    files={str(p.relative_to(project)):p.read_text() for p in project.rglob('*') if p.is_file() and not p.is_symlink()}
    if not files:raise ValueError('empty fixture')
    request=(BASE/'requests'/('skill.txt' if case in ('cedar','maple') else case+'.txt')).read_text()
    return files,request

def run(config,output,trial=False):
    files,request=load_input(config['case']);writable=config['case']=='harbor'
    if output.exists():raise ValueError('fresh output required')
    output.mkdir(parents=True)
    project=pathlib.Path(tempfile.mkdtemp(prefix='harbor-' if writable else 'meadow-',dir='/workspace/.task-scratch'))
    for name,text in files.items():
        p=project/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
    initial={name:hashlib.sha256(text.encode()).hexdigest() for name,text in files.items()}
    summary={'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'mode':'native-trial' if trial else 'native-zero-turn','configured_id':config['model'],'effort':config['effort'],'actual_id':None,'proof':'unverified','native_turns_started':0,'failures':[],'os_isolation':'not proven; native read-only policy and fixture API only','project':str(project)}
    client=None;events=[];controller=None;configured={}
    try:
        client=Client(str(project));client.request('initialize',{'clientInfo':{'name':'fixture_client','version':'0.1.0'},'capabilities':{'experimentalApi':True}});client.send({'method':'initialized','params':{}})
        started=client.request('thread/start',{'model':config['model'],'cwd':str(project),'ephemeral':True,'approvalPolicy':'never','sandbox':'read-only','allowProviderModelFallback':False,'dynamicTools':specs(writable),'config':{'model_reasoning_effort':config['effort']}})
        configured={k:started.get(k) for k in ('model','reasoningEffort','cwd','instructionSources','sandbox','activePermissionProfile')}
        summary['thread_id']=started['thread']['id']
        if started.get('model')!=config['model']:summary['failures'].append('configured-model-mismatch')
        # No native trial may inherit a source repository, report directory, or unrelated session instructions.
        sources=started.get('instructionSources',[])
        if sources:
            summary['instruction_sources_require_review']=sources;summary['failures'].append('instruction-sources-not-empty')
        if started.get('reasoningEffort')!=config['effort']:summary['failures'].append('configured-effort-mismatch')
        if not trial or summary['failures']:return summary
        tools=FixtureTools(files,writable=writable,public_checks=public_checks)
        client.deadline=tools.started+300
        turn_input=[{'type':'text','text':request}]
        if config.get('skill_binding')=='native-skill':turn_input.append({'type':'skill','name':'spec-review-loop','path':str(project/'procedure.md')})
        response=client.request('turn/start',{'threadId':summary['thread_id'],'model':config['model'],'effort':config['effort'],'cwd':str(project),'input':turn_input})
        summary['native_turns_started']=1;summary['turn_id']=response['turn']['id']
        controller=EventController(tools,summary['thread_id'],summary['turn_id'])
        pending=client.pending;client.pending=[]
        while True:
            msg=pending.pop(0) if pending else client.receive();events.append(msg)
            if 'method' not in msg:continue
            params=msg.get('params',{})
            reply=controller.handle(msg)
            if controller.reroutes:controller.failures.append('model-rerouted')
            if reply is not None:client.send(reply)
            elif 'id' in msg:
                controller.failures.append('unexpected-server-request:'+msg['method']);client.send({'id':msg['id'],'error':{'code':-32601,'message':'Unsupported fixture interface request.'}})
            if controller.summary()['failures']:
                client.send({'id':99999,'method':'turn/interrupt','params':{'threadId':summary['thread_id'],'turnId':summary['turn_id']}});break
            if msg['method']=='turn/completed' and params.get('threadId')==summary['thread_id'] and params.get('turn',{}).get('id')==summary['turn_id']:
                summary['turn_status']=params['turn'].get('status');break
    except Exception as exc:
        summary['failures'].append(type(exc).__name__+': '+str(exc)[:1500])
        if client and summary.get('turn_id'):
            try:client.send({'id':99999,'method':'turn/interrupt','params':{'threadId':summary['thread_id'],'turnId':summary['turn_id']}})
            except (OSError,ValueError):pass
    finally:
        if client:summary['sent_methods']=client.methods;summary['argv']=client.argv;client.close()
        if configured:(output/'thread-config.json').write_text(json.dumps(configured,indent=2)+'\n')
        if controller:
            observed=controller.summary();summary['observation']=observed;summary['failures']+=observed['failures'];summary['elapsed_seconds']=time.monotonic()-controller.tools.started
            if summary['elapsed_seconds']>300:summary['failures'].append('timeout')
            files=controller.tools.artifacts()
            if controller.final is not None:(output/'answer.txt').write_text(controller.final)
            if summary.get('turn_status')!='completed':summary['failures'].append('turn-not-completed')
        if trial:
            # Native builtin file writes remain visible even though dynamic Edit is in-memory.
            after={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in project.rglob('*') if p.is_file()}
            if after!=initial:summary['failures'].append('native-project-files-changed-outside-interface')
            for name,text in files.items():
                dest=output/'project'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
            (output/'events.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in events))
        summary['finished_at']=datetime.datetime.now(datetime.timezone.utc).isoformat()
        (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    return summary

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);p.add_argument('--trial',action='store_true',help='Starts actual model turn. Root must authorize after T-008 readiness. Omit for zero-turn probe.');a=p.parse_args()
    result=run(json.loads(a.config.read_text()),a.output,a.trial)
    sys.exit(1 if result['failures'] else 0)
