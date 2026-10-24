from pathlib import Path
import hashlib,json,os,subprocess,sys,datetime
root=Path.cwd();evidence=root/'specs/a9-interrupted-review-recovery/verification/T-001'
paths=['plugins/sdd-review-loop/scripts/spec-review-precheck.sh','plugins/sdd-review-loop/scripts/spec-review-precheck.ps1','tests/spec-review-interrupted-recovery.tests.sh','tests/spec-review-interrupted-recovery.tests.ps1','tests/spec-review-loop.tests.sh','tests/verification-catalog.json']
def pins():return {path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in paths}
runtime=sys.argv[1];label=sys.argv[2] if len(sys.argv)>2 else 'final';commands={'bash':['bash','tests/spec-review-interrupted-recovery.tests.sh'],'powershell':['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoLogo','-NoProfile','-File','tests/spec-review-interrupted-recovery.tests.ps1']}
command=commands[runtime];before=pins();started=datetime.datetime.now(datetime.timezone.utc).isoformat();env=dict(os.environ);env.pop('SDD_RECOVERY_TEST_FILTER',None)
with open(evidence/f'{label}-{runtime}.log','w') as output:result=subprocess.run(command,stdout=output,stderr=subprocess.STDOUT,env=env)
after=pins();receipt=dict(runtime=runtime,command=command,started_utc=started,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),exit_code=result.returncode,source_before=before,source_after=after,source_unchanged=before==after,filter=None,output=f'specs/a9-interrupted-review-recovery/verification/T-001/{label}-{runtime}.log')
(evidence/f'{label}-{runtime}.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt));raise SystemExit(result.returncode or int(before!=after))
