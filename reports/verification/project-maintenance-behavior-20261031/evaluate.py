"""Prepared independent #597 evaluation; execute only after product sources stabilize."""
import hashlib,importlib.util,json,os,sys,tempfile
from pathlib import Path
ROOT=Path('/workspace/sdd-forge');OUT=Path(__file__).resolve().parent
PRODUCT=ROOT/'plugins/sdd-bootstrap/scripts/project-skill.py'
APP='''from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
ROUTE = "/items"
AUTH = False
BROKEN = False
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self):
  if self.path == ROUTE:
   self.send_response(200); self.end_headers(); self.wfile.write(b"BROKEN" if BROKEN else b"items-ready")
  elif self.path == "/account":
   if AUTH and self.headers.get("Authorization") != "Bearer fixture-evaluation-token":
    self.send_response(401); self.end_headers(); self.wfile.write(b"authentication-required"); return
   self.send_response(200); self.end_headers(); self.wfile.write(b"account-ready")
  else:
   self.send_response(404); self.end_headers(); self.wfile.write(b"route-not-found")
def serve(): return ThreadingHTTPServer(("127.0.0.1",0),Handler)
'''
HELPER='''import json,subprocess,sys,threading,urllib.request,urllib.error
from pathlib import Path
sys.path.insert(0,str(Path.cwd()))
import app
ROUTE = "/items"
AUTH_HEADER = None
server=app.serve();thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
base="http://127.0.0.1:"+str(server.server_port)
results=[]
def http(feature,path,expected,headers=None):
 try:
  with urllib.request.urlopen(urllib.request.Request(base+path,headers=headers or {}),timeout=2) as response:
   body=response.read().decode();status=response.status
  passed=status==200 and body==expected
  result=dict(feature=feature,path=path,status=status,body=body,passed=passed)
 except urllib.error.HTTPError as error:
  result=dict(feature=feature,path=path,status=error.code,body=error.read().decode(),passed=False)
 results.append(result);print(json.dumps(result),flush=True)
try:
 http("browse-items",ROUTE,"items-ready")
 http("view-account","/account","account-ready",{"Authorization":AUTH_HEADER} if AUTH_HEADER else {})
 cli=subprocess.run(["fixture-cli","show"],capture_output=True,text=True,timeout=2)
 result=dict(feature="cli-status",exit_code=cli.returncode,stdout=cli.stdout.strip(),passed=cli.returncode==0 and cli.stdout.strip()=="cli-ready")
 results.append(result);print(json.dumps(result),flush=True)
finally:server.shutdown();server.server_close();thread.join(timeout=2)
raise SystemExit(0 if all(r["passed"] for r in results) else 1)
'''
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def run():
 spec=importlib.util.spec_from_file_location('maintenance_owner',PRODUCT);A=importlib.util.module_from_spec(spec);spec.loader.exec_module(A)
 results=[]
 for scenario in ['route-change','auth-added','cli-disappeared','product-regression']:
  with tempfile.TemporaryDirectory(prefix='issue597-') as temp:
   base=Path(temp);root=base/'project';skill=root/'sdd/skills/verify-fixture';skill.mkdir(parents=True)
   tools=base/'tools';tools.mkdir();cli=tools/'fixture-cli';cli.write_text('#!/bin/sh\nprintf "cli-ready\\n"\n');cli.chmod(0o755)
   oldpath=os.environ['PATH'];os.environ['PATH']=str(tools)+os.pathsep+oldpath
   try:
    (root/'app.py').write_text(APP);(skill/'run.py').write_text(HELPER)
    (skill/'SKILL.md').write_text('---\nname: verify-fixture\ndescription: Verify three user paths.\n---\nRun all features in features/README.md; preserve handwritten extensions.\n')
    extension=skill/'handwritten.md';extension.write_text('# Human-authored extension fixture\nKeep this explanation unchanged.\n');extension_sha=digest(extension)
    features=skill/'features';features.mkdir();(features/'README.md').write_text('\n'.join('['+name+']('+name+'.md)' for name in ['browse-items','view-account','cli-status'])+'\n')
    for name in ['browse-items','view-account','cli-status']:(features/(name+'.md')).write_text('# '+name+'\nCheck ID: aggregate\n')
    A.seal(root,'verify-fixture','python3','run.py',['aggregate'],['fixture-cli'])
    baseline=A.run(root,'verify-fixture','aggregate',timeout=10,inputs=['app.py']);assert baseline['outcome']=='passed',baseline
    baseline_path=root/baseline['receipt']
    def trace(result):
     logs=(root/result['stdout']['path']).read_text();return [json.loads(line) for line in logs.splitlines() if line]
    assert {r['feature'] for r in trace(baseline)}=={'browse-items','view-account','cli-status'}
    if scenario=='route-change':(root/'app.py').write_text(APP.replace('ROUTE = "/items"','ROUTE = "/v2/items"'))
    elif scenario=='auth-added':(root/'app.py').write_text(APP.replace('AUTH = False','AUTH = True'))
    elif scenario=='cli-disappeared':cli.unlink()
    else:(root/'app.py').write_text(APP.replace('BROKEN = False','BROKEN = True'))
    application_sha=digest(root/'app.py');before=A.maintain(root,'verify-fixture',baseline_path,10)
    observed=trace(before['results'][0]);entry=dict(case=scenario,baseline=baseline,baseline_features=trace(baseline),maintenance=before,observed_features=observed,unexecuted_features=[f for f in ['browse-items','view-account','cli-status'] if f not in {r['feature'] for r in observed}])
    assert before['status']=='blocked',before
    if scenario=='cli-disappeared':assert before['classification']=='environment-unavailable' and observed==[]
    else:
     assert before['classification']=='product-regression-or-harness-gap'
     assert len(observed)==3
    if scenario in ['route-change','auth-added']:
     corrected=HELPER.replace('ROUTE = "/items"','ROUTE = "/v2/items"') if scenario=='route-change' else HELPER.replace('AUTH_HEADER = None','AUTH_HEADER = "Bearer fixture-evaluation-token"')
     (skill/'run.py').write_text(corrected)
     try:A.seal(root,'verify-fixture','python3','run.py',['aggregate'],['fixture-cli'])
     except ValueError as error:entry['reseal_without_explicit_removal']=str(error)
     else:raise AssertionError('silent reseal')
     (skill/'skill-manifest.json').unlink();A.seal(root,'verify-fixture','python3','run.py',['aggregate'],['fixture-cli'])
     after=A.maintain(root,'verify-fixture',baseline_path,10);assert after['status']=='changed',after
     after_features=trace(after['results'][0]);assert len(after_features)==3 and all(r['passed'] for r in after_features)
     entry.update(repair='Only run.py route/auth constant changed; old manifest explicitly removed and resealed.',after=after,after_features=after_features)
    elif scenario=='product-regression':
     assert (skill/'run.py').read_text()==HELPER
     repeated=A.maintain(root,'verify-fixture',baseline_path,10);assert repeated['status']=='blocked'
     entry['no_expectation_relaxation']=True;entry['repeat']=repeated
    assert digest(extension)==extension_sha and digest(root/'app.py')==application_sha
    entry.update(handwritten_extension_unchanged=True,product_source_unchanged_by_maintenance=True)
    results.append(entry)
   finally:os.environ['PATH']=oldpath
 out=dict(schema='independent-maintenance-behavior/v1',product_sha256=digest(PRODUCT),results=results,classification_limit='The helper reports product-regression-or-harness-gap for failed assertions; exact cause below is inferred from captured actual HTTP/CLI behavior, not claimed as helper diagnosis.',passed=True)
 (OUT/'result.json').write_text(json.dumps(out,indent=2)+'\n');print('all four maintenance scenarios passed')
if __name__=='__main__':run()
