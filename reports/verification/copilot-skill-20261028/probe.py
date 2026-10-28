import hashlib,json,os,subprocess,tempfile
from pathlib import Path
base=Path('/workspace/.tools/sdd-forge-dev/verification-workspace')
product=Path('/workspace/scratch/issue-resolution-20261027/project-observation-fix/plugins/sdd-bootstrap/scripts/project-skill.py')
cli=Path('/tmp/sdd-forge-host-cli-check/node_modules/.bin/copilot')
with tempfile.TemporaryDirectory(prefix='copilot-discovery-',dir=base) as temporary:
 root=Path(temporary); skill=root/'sdd/skills/inspect-copilot-fixture'; skill.mkdir(parents=True)
 (skill/'SKILL.md').write_text('---\nname: inspect-copilot-fixture\ndescription: Inspect the synthetic project note.\n---\nRead note.txt and return its exact sentence.\n')
 (skill/'run.py').write_text('print("synthetic")\n'); note=root/'note.txt'; note.write_text('Synthetic Copilot project note.\n')
 env=os.environ.copy(); env['COPILOT_HOME']=str(root/'copilot-state')
 def run(args,timeout=30):
  return subprocess.run(args,cwd=root,env=env,capture_output=True,text=True,timeout=timeout)
 seal=run(['python3',str(product),'seal','--root',str(root),'--name','inspect-copilot-fixture','--runtime','python3','--entry','run.py','--check','probe']); assert seal.returncode==0,seal.stderr
 projected=run(['python3',str(product),'project','--root',str(root),'--name','inspect-copilot-fixture','--host','copilot']); assert projected.returncode==0,projected.stderr
 relative=json.loads(projected.stdout)['path']; generated=root/relative; expected={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (generated,note)}
 discovery=run([str(cli),'skill','list','--json']); assert discovery.returncode==0,discovery.stderr
 found=[x for x in json.loads(discovery.stdout) if x.get('name')=='inspect-copilot-fixture']; assert len(found)==1 and Path(found[0]['path']).resolve()==generated.parent.resolve()
 try:
  model=run([str(cli),'-p','Invoke $inspect-copilot-fixture, read note.txt, and return its exact sentence.','--trust-folder','--disable-builtin-mcps','--allow-tool','read','--deny-tool','shell','--deny-tool','write','--deny-tool','agent','--silent'],timeout=100)
  clean=(model.stdout+'\n'+model.stderr).lower(); error='authentication-or-entitlement' if any(x in clean for x in ('authenticat','not logged','sign in','401','403','not authorized','not authorised','permission')) else ('other-failure' if model.returncode else None)
  outcome={'exit_code':model.returncode,'quoted_actual_note':'Synthetic Copilot project note.' in model.stdout,'error_category':error,'indicators':{term:(term in clean) for term in ('401','403','not authenticated','authentication','not logged','sign in','unauthorized','forbidden','permission','entitlement','subscription','quota','token','rate limit')}}
 except subprocess.TimeoutExpired:
  outcome={'exit_code':None,'quoted_actual_note':False,'error_category':'timeout'}
 after={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (generated,note)}
 print(json.dumps({'cli_version':'1.0.104','source_sha256':hashlib.sha256(product.read_bytes()).hexdigest(),'seal_status':json.loads(seal.stdout)['status'],'generated_path':relative,'wrapper_sha256':expected[relative],'discovered':len(found)==1,'source':found[0].get('source'),'enabled':found[0].get('enabled'),'path_is_wrapper_directory':True,'model':outcome,'fixture_bytes_unchanged':expected==after,'cleanup':'temporary directory removed on exit'}))
