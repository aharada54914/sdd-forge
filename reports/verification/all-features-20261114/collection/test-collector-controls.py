from pathlib import Path
import contextlib,io,importlib.util,json,os,tempfile,threading,urllib.error
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
p=Path('/workspace/sites/sdd-forge-status-audit/.sites-checkout/scripts/collect-progress.py');spec=importlib.util.spec_from_file_location('collector',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checks=[]
with tempfile.TemporaryDirectory(prefix='collector-controls-') as tmp:
 root=Path(tmp);task=root/'specs/a/tasks.md';task.parent.mkdir(parents=True);task.write_text('## T-001 Test\nStatus: Done\nApproval: Approved\n');config={'project':'test','sources':[{'id':'test','root':str(root)}]}
 class Fake:
  def __init__(self,fail=False):self.fail=fail;self.writes=[]
  def call(self,path,value=None):
   if value is None:return {'data':None,'revision':'','checkedAt':None,'lastSuccessAt':None,'changedAt':None}
   self.writes.append(path)
   if path=='/api/health' and self.fail:raise urllib.error.HTTPError('http://127.0.0.1',500,'failed',{},None)
   return {'ok':True}
 with contextlib.redirect_stdout(io.StringIO()):assert m.run(config,Fake(True),1,.1)==1
 checks.append('health publication failure cannot return success')
 assert m.collect(config)[0]['features'][0]['phase']=='unknown';checks.append('task Done does not fabricate workflow phase')
 class Conflict(Fake):
  def __init__(self,mismatch=False):super().__init__();self.reads=0;self.puts=0;self.mismatch=mismatch
  def call(self,path,value=None):
   if value is None:
    self.reads+=1
    return {'data':{'project':'different' if self.mismatch and self.reads>1 else 'test'},'revision':'old','checkedAt':None,'lastSuccessAt':None,'changedAt':None}
   if path=='/api/snapshot':
    self.puts+=1
    if self.puts==1:raise urllib.error.HTTPError('http://127.0.0.1',409,'conflict',{},None)
   return {'ok':True}
 conflict=Conflict()
 with contextlib.redirect_stdout(io.StringIO()):assert m.run(config,conflict,2,.1)==0
 assert conflict.reads==2 and conflict.puts==2;checks.append('conflict rereads state before successful subsequent cycle')
 mismatch=Conflict(True)
 try:
  with contextlib.redirect_stdout(io.StringIO()):m.run(config,mismatch,2,.1)
  raise AssertionError('changed project accepted')
 except ValueError:assert mismatch.puts==1
 checks.append('conflict changing project identity stops before another write')
 for name,body in [('invalid-state','## T-001 Test\nStatus: Verified\n'),('duplicate-status','## T-001 Test\nStatus: Done\nStatus: Planned\n'),('duplicate-id','## T-001 Test\nStatus: Done\n## T-001 Again\nStatus: Done\n')]:
  task.write_text(body)
  try:m.collect(config);raise AssertionError(name+' accepted')
  except ValueError:checks.append(name+' rejected')
 task.unlink();outside=root/'outside.md';outside.write_text('## T-001 Test\nStatus: Done\n');external=root.parent/(root.name+'-external.md');external.write_text(outside.read_text());task.symlink_to(external)
 try:
  try:m.collect(config);raise AssertionError('outside symlink accepted')
  except ValueError:checks.append('outside source symlink rejected')
 finally:external.unlink()
 original=os.environ.get('SDD_PUBLISHER_TOKEN');os.environ['SDD_PUBLISHER_TOKEN']='controlled-synthetic-secret'
 try:
  for url in ['http://example.com','https://user:pass@example.com','https://example.com?x=1','https://example.com/path']:
   try:m.Client(url);raise AssertionError('bad endpoint accepted')
   except ValueError:pass
  checks.append('unsafe or credential-bearing endpoints rejected')
  counts={'redirect':0,'target':0}
  class Handler(BaseHTTPRequestHandler):
   def do_GET(self):
    if self.path=='/api/dashboard':counts['redirect']+=1;self.send_response(302);self.send_header('Location','http://127.0.0.1:'+str(self.server.server_port)+'/target');self.end_headers()
    else:counts['target']+=1;self.send_response(200);self.end_headers();self.wfile.write(b'{}')
   def log_message(self,*args):pass
  server=ThreadingHTTPServer(('127.0.0.1',0),Handler);thread=threading.Thread(target=server.serve_forever);thread.start()
  try:
   try:m.Client('http://127.0.0.1:'+str(server.server_port)).call('/api/dashboard');raise AssertionError('redirect followed')
   except urllib.error.HTTPError as e:assert e.code==302
   assert counts=={'redirect':1,'target':0};checks.append('real HTTP redirect refused before forwarding credentials')
  finally:server.shutdown();thread.join();server.server_close()
 finally:
  if original is None:os.environ.pop('SDD_PUBLISHER_TOKEN',None)
  else:os.environ['SDD_PUBLISHER_TOKEN']=original
print(json.dumps({'passed':len(checks),'checks':checks}))
Path('/workspace/sites/sdd-forge-status-audit/qa/collector-controls.json').write_text(json.dumps({'passed':len(checks),'checks':checks},indent=2)+'\n')
