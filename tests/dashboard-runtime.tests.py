"""Actual per-project daemon lifecycle; fixtures never change canonical tasks."""
import importlib.util,json,os,signal,subprocess,tempfile,time,unittest,urllib.request,threading,types
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'plugins/sdd-ship/scripts/dashboard-runtime.py'
spec=importlib.util.spec_from_file_location('runtime',SCRIPT);runtime=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime)
class RuntimeTests(unittest.TestCase):
 def test_isolation_recovery_persistence_and_auth(self):
  with tempfile.TemporaryDirectory(prefix='sdd-runtime-test-') as tmp:
   base=Path(tmp);env={**os.environ,'XDG_STATE_HOME':str(base/'state')}
   roots=[base/'one',base/'two']
   for root in roots:
    (root/'specs/demo').mkdir(parents=True)
    (root/'AGENTS.md').write_text('# AGENTS\n\n## Active Spec Directories\n\n- `specs/demo/`\n')
    (root/'specs/demo/requirements.md').write_text('# Requirements\nSpec-Review-Status: Pending\n')
    (root/'specs/demo/tasks.md').write_text('# Tasks\nTask-Review-Status: Pending\n\n## T-001 Test\nApproval: Approved\nStatus: Blocked\nRisk: low\n')
   def command(root,cmd='start'):
    p=subprocess.run(['python3',str(SCRIPT),cmd,'--root',str(root)],env=env,capture_output=True,text=True,timeout=55)
    self.assertEqual(p.returncode,0,p.stderr);return json.loads(p.stdout)
   def read(status,path):
    with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(status['url']+path,timeout=5) as r:return json.load(r)
   def until(fn):
    end=time.monotonic()+25
    while time.monotonic()<end:
     result=fn()
     if result:return result
     time.sleep(.3)
    self.fail('condition timed out')
   try:
    a=command(roots[0]);b=command(roots[1]);self.assertNotEqual(a['identity'],b['identity']);self.assertNotEqual(a['workerPid'],b['workerPid'])
    self.assertEqual(command(roots[0])['pid'],a['pid'])
    original=read(a,'api/dashboard');history=read(a,'api/observations');self.assertEqual(history['events'][0]['notify'],True)
    directory=base/'state/sdd-forge/dashboard'/a['identity'];record=json.loads((directory/'runtime.json').read_text())
    with self.assertRaises(urllib.error.HTTPError) as caught:urllib.request.urlopen('http://127.0.0.1:'+str(record['port'])+'/status')
    self.assertEqual(caught.exception.code,403)
    os.kill(a['workerPid'],signal.SIGKILL)
    def recovered():
     s=command(roots[0],'status');return s if s['state']=='running' and s['workerPid']!=a['workerPid'] else None
    restored=until(recovered);self.assertGreaterEqual(restored['restarts'],1)
    self.assertEqual(read(restored,'api/observations')['events'],history['events'])
    self.assertEqual(read(restored,'api/dashboard')['changedAt'],original['changedAt'])
    # Stop the entire environment-owned supervisor, then resume with invalid source.
    last=read(restored,'api/dashboard')
    command(roots[0],'stop');until(lambda:not (directory/'runtime.json').exists())
    (roots[0]/'specs/demo/tasks.md').write_text('broken')
    resumed=command(roots[0]);failed=read(resumed,'api/dashboard');self.assertIsNotNone(failed['error']);self.assertEqual(failed['data'],original['data']);self.assertEqual(failed['checkedAt'],last['checkedAt'])
    self.assertEqual(read(resumed,'api/observations')['events'][-1]['kind'],'source-failed')
    self.assertIsNone(read(b,'api/dashboard')['error'])
   finally:
    for root in roots:subprocess.run(['python3',str(SCRIPT),'stop','--root',str(root)],env=env,capture_output=True,timeout=10)
    time.sleep(2)
 def test_publisher_restarts_and_stops_on_configuration_failure(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=Path(tmp);script=base/'publish-dashboard.py'
   script.write_text('import sys,json,time\nc=json.loads(sys.stdin.readline())\nif c["publisherToken"]=="reject":sys.exit(78)\ntime.sleep(60)\n')
   original=runtime.__file__;runtime.__file__=str(base/'dashboard-runtime.py')
   stop=threading.Event();config={'url':'https://example.test','credentials':{'serviceToken':'fixture','publisherToken':'fixture'}}
   publication=[config];state={'publisherRestarts':0}
   thread=threading.Thread(target=runtime.publish_loop,args=(types.SimpleNamespace(root=tmp,entry='fixture'),publication,state,stop));thread.start()
   def until(fn):
    deadline=time.monotonic()+15
    while time.monotonic()<deadline:
     if fn():return
     time.sleep(.1)
    self.fail('publisher condition timed out')
   try:
    until(lambda:state.get('publisherPid'));first=state['publisherPid'];os.kill(first,signal.SIGKILL)
    until(lambda:state.get('publisherPid') and state['publisherPid']!=first);self.assertEqual(state['publisherRestarts'],1)
    publication[0]={'url':config['url'],'credentials':{'serviceToken':'fixture','publisherToken':'reject'}}
    until(lambda:state.get('publisherState')=='configuration-required');self.assertIsNone(publication[0])
    for value in ['http://example.test','https://user:pass@example.test','https://example.test/?token=x']:
     with self.assertRaises(ValueError):runtime.validate_publication({'url':value,'credentials':config['credentials']})
   finally:stop.set();thread.join(10);runtime.__file__=original
 def test_private_state_required(self):
  with tempfile.TemporaryDirectory() as tmp:
   old=os.environ.get('XDG_STATE_HOME');os.environ['XDG_STATE_HOME']=tmp
   try:
    directory=runtime.state_directory('/test');directory.chmod(0o755)
    with self.assertRaises(ValueError):runtime.state_directory('/test')
   finally:
    if old is None:os.environ.pop('XDG_STATE_HOME',None)
    else:os.environ['XDG_STATE_HOME']=old
if __name__=='__main__':unittest.main()
