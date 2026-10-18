from pathlib import Path
import json,subprocess,hashlib
r=Path('/workspace/sdd-forge');base=Path('/workspace/cloud-release-v119-4b');dest=r/'specs/cloud-orchestration/verification/T-008/root-release-final/local';rev='2aaac49c528d0dfe28437082d54fb86a32f04a15'
validation=json.loads(subprocess.check_output(['python3','/tmp/cloud-validate-release-local.py',str(base),rev],cwd=r,text=True));assert validation['status']=='PASS';dest.mkdir(exist_ok=False);inventory=[]
for profile in ('local-posix','local-powershell'):
 for idx in range(4):
  for suffix in ('result.json','receipt.json','log'):
   name=f'{profile}-{idx}.{suffix}';source=base/name;target=dest/name;raw=source.read_bytes();target.write_bytes(raw);digest=hashlib.sha256(raw).hexdigest();assert hashlib.sha256(target.read_bytes()).hexdigest()==digest;inventory.append({'path':str(target.relative_to(r)),'sha256':digest,'bytes':len(raw),'source':str(source)})
(dest.parent/'local-artifact-inventory.json').write_text(json.dumps({'revision':rev,'artifacts':inventory},indent=2)+'\n');subprocess.run(['python3',str(dest.parent/'validate-local.py'),str(dest),rev],cwd=r,check=True)
