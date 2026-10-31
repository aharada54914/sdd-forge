from pathlib import Path
import json,os,subprocess,sys
out=Path.cwd(); work=out/'work'; ev=work/'specs/shared-review-launch-repair/verification/T-003'
cmd=['rtk','proxy','bash',str(work/'plugins/sdd-implementation/scripts/validate-implementation-report.sh'),str(work/'reports/implementation/shared-review-launch-repair/T-003.md')]
env=dict(os.environ,TMPDIR=str(out/'tmp'),TMP=str(out/'tmp'),TEMP=str(out/'tmp'),PYTHONDONTWRITEBYTECODE='1')
r=subprocess.run(cmd,cwd=out,env=env,capture_output=True,text=True)
record={'argv':cmd,'cwd':str(out),'login':False,'environment_overrides':{k:env[k] for k in ('TMPDIR','TMP','TEMP','PYTHONDONTWRITEBYTECODE')},'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
p=ev/'report-validation.json'
if '--confirm' in sys.argv:
 assert json.loads(p.read_bytes())==record,'validator result changed after report Outputs binding'
else: p.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2)); sys.exit(r.returncode)
