from pathlib import Path
import subprocess,tempfile,tarfile,io,json,hashlib,datetime,shutil
r=Path('/workspace/sdd-forge');d=r/'specs/cloud-orchestration/verification/T-003/preview-expiry-fix';prod='plugins/sdd-quality-loop/scripts/cloud_authorization.py';test='tests/cloud-orchestration-execution.tests.py';shared='plugins/sdd-quality-loop/scripts/cloud_contracts.py';fixtures='tests/cloud-orchestration-contracts.tests.py';rows=[]
with tempfile.TemporaryDirectory(prefix='cloud-preview-expiry-rollback-') as tmp:
 root=Path(tmp)
 archive=subprocess.check_output(['git','archive','HEAD'],cwd=r)
 with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(root,filter='data')
 for p in [prod,test,shared,fixtures]+[str(p.relative_to(r)) for p in (r/'contracts').glob('cloud-*.schema.json')]+[str(p.relative_to(r)) for p in (r/'templates/cloud').rglob('*') if p.is_file()]:
  target=root/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(r/p,target)
 for phase in ('candidate','restored'):
  if phase=='restored':
   (root/prod).write_bytes((d/'authorization-before.py.txt').read_bytes());(root/test).write_bytes((d/'tests-before.py.txt').read_bytes())
  x=subprocess.run(['python3','-B',test],cwd=root,capture_output=True,text=True);(d/('rollback-'+phase+'.log')).write_text(x.stdout+x.stderr);rows.append({'phase':phase,'exit_code':x.returncode,'command':['python3','-B',test],'source_sha256':hashlib.sha256((root/prod).read_bytes()).hexdigest(),'test_sha256':hashlib.sha256((root/test).read_bytes()).hexdigest()});print(phase,x.returncode,(x.stdout+x.stderr)[-120:]);assert x.returncode==0
(d/'rollback.json').write_text(json.dumps({'scope':'code-only exact before-byte restore in disposable git archive; no provider writes or historical rollback','checks':rows,'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
