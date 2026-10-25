from pathlib import Path
import subprocess,tempfile,json,hashlib,datetime,os,re
r=Path(__file__).resolve().parents[4];o=r/'specs/a9-interrupted-review-recovery/verification/T-003/prerequisites.log'
with tempfile.TemporaryDirectory(prefix='a9-prereq-') as tmp,o.open('w') as out:
 d=Path(tmp);(d/'record').write_text('saved');(d/'pre.json').write_text(json.dumps({'schema':'spec-review-precheck/v1','recovery':{'record_path':'record','record_sha256':hashlib.sha256(b'saved').hexdigest()}}))
 sh=(r/'plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh').read_text().split('\n# RT-20260908-004:',1)[0]
 (d/'probe.sh').write_text(sh+'\nvalidate_saved_recovery_reference "$1" "$1/pre.json"\n')
 p=subprocess.run(['/bin/bash',str(d/'probe.sh'),str(d)],env={'PATH':str(d)},capture_output=True,text=True)
 out.write('UTC '+datetime.datetime.now(datetime.timezone.utc).isoformat()+'\nTEST-105::bash-missing-python exit='+str(p.returncode)+'\n'+p.stdout+p.stderr);assert p.returncode!=0
 ps=(r/'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1').read_text();a=ps.index('function Assert-SavedRecoveryReference');b=ps.index('\nfunction ',a+10);func=ps[a:b]
 (d/'probe.ps1').write_text("param($Root)\n$ErrorActionPreference='Stop'\n"+func+"\nfunction Get-FileHash { throw 'Synthetic unavailable hashing primitive' }\nAssert-SavedRecoveryReference $Root (Join-Path $Root 'pre.json')\n")
 p=subprocess.run(['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoProfile','-File',str(d/'probe.ps1'),str(d)],capture_output=True,text=True)
 out.write('TEST-105::powershell-missing-hash exit='+str(p.returncode)+'\n'+p.stdout+p.stderr);assert p.returncode!=0
 p=subprocess.run(['/bin/bash','-c','exec "$1" -NoProfile -File "$2"','missing-runtime',str(d/'absent-pwsh'),str(d/'probe.ps1')],capture_output=True,text=True)
 out.write('TEST-105::missing-runtime exit='+str(p.returncode)+'\n'+p.stdout+p.stderr);assert p.returncode==127
 (d/'pre.json').write_text('{')
 p=subprocess.run(['/bin/bash',str(d/'probe.sh'),str(d)],capture_output=True,text=True)
 out.write('TEST-105::bash-malformed-parser-input exit='+str(p.returncode)+'\n'+p.stdout+p.stderr);assert p.returncode!=0
 (d/'probe.ps1').write_text("param($Root)\n$ErrorActionPreference='Stop'\n"+func+"\nAssert-SavedRecoveryReference $Root (Join-Path $Root 'pre.json')\n")
 p=subprocess.run(['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoProfile','-File',str(d/'probe.ps1'),str(d)],capture_output=True,text=True)
 out.write('TEST-105::powershell-malformed-parser-input exit='+str(p.returncode)+'\n'+p.stdout+p.stderr);assert p.returncode!=0
 out.write('PASS prerequisite rejection; native runtime availability independently recorded in integration-powershell.log.\n')
