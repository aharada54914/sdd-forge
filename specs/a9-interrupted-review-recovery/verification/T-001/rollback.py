from pathlib import Path
import subprocess,sys,tempfile,shutil,re,json,hashlib,os
root=Path.cwd();evidence=root/'specs/a9-interrupted-review-recovery/verification/T-001';base='f8746874413e96775f4b64671a3696be2cc90e7d'
source=(root/'tests/spec-review-interrupted-recovery.tests.sh').read_text();python=source[source.index('import copy,'):source.rindex('\nPY')]
oldargv=sys.argv;sys.argv=['fixture',str(root),'bash'];namespace={'__name__':'rollback_fixture'};exec(compile(python,'fixture-test-source','exec'),namespace);sys.argv=oldargv
fixture_builder=namespace['fixture'];snapshot=namespace['snapshot'];feature=namespace['FEATURE'];source_dir=namespace['SOURCE']
fixture_source=subprocess.check_output(['git','show',base+':tests/spec-review-loop.tests.sh'],text=True)
writer=re.search(r'^write_contract\(\) \{\n.*?^\}',fixture_source,re.M|re.S).group(0)
results=[]
with tempfile.TemporaryDirectory(prefix='rollback-',dir=evidence) as temporary:
 scratch=Path(temporary)
 for runtime in ('bash','powershell'):
  for scenario in ('interrupted-source','terminal-reset','partial-target'):
   repository=scratch/(runtime+'-'+scenario);fixture_builder(repository)
   for plugin in ('sdd-review-loop','sdd-quality-loop'):
    shutil.copytree(root/'plugins'/plugin,repository/'plugins'/plugin,dirs_exist_ok=True)
   shutil.copytree(root/'contracts',repository/'contracts')
   # Revert precisely the two production files inside this disposable checkout.
   for ext in ('sh','ps1'):
    path=f'plugins/sdd-review-loop/scripts/spec-review-precheck.{ext}'
    (repository/path).write_bytes(subprocess.check_output(['git','show',base+':'+path]))
   if scenario!='interrupted-source':
    script=scratch/'write-terminal.sh';script.write_text('set -euo pipefail\n'+writer+'\nROOT=$1;FEATURE=$2;SPEC_DIR="$ROOT/specs/$FEATURE"\nwrite_contract "$ROOT/$3" BLOCKED Major\n')
    subprocess.run(['bash',str(script),str(repository),feature,source_dir],check=True)
   target=repository/f'reports/spec-review/{feature}/attempt-4/round-1'
   if scenario=='partial-target':target.mkdir(parents=True);(target/'precheck-result.json').write_text('{synthetic-partial')
   before=snapshot(repository)
   command=['bash',str(repository/'plugins/sdd-review-loop/scripts/spec-review-precheck.sh'),feature,'4','1','--reset'] if runtime=='bash' else ['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoLogo','-NoProfile','-File',str(repository/'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1'),'-Feature',feature,'-Attempt','4','-Round','1','-Reset']
   result=subprocess.run(command,text=True,capture_output=True)
   after=dict(snapshot(repository));unchanged=all(after.get(path)==digest for path,digest in before)
   correct=(result.returncode==0 if scenario=='terminal-reset' else result.returncode!=0)
   quarantined=scenario!='partial-target' or (target/'precheck-result.json').read_text()=='{synthetic-partial'
   no_unexpected_target=scenario!='interrupted-source' or not target.exists()
   passed=correct and unchanged and quarantined and no_unexpected_target
   row=dict(runtime=runtime,scenario=scenario,exit_code=result.returncode,historical_bytes_unchanged=unchanged,partial_target_quarantined=quarantined,no_unexpected_target=no_unexpected_target,passed=passed,stdout=result.stdout,stderr=result.stderr)
   results.append(row);print(json.dumps(row),flush=True)
(evidence/'rollback.json').write_text(json.dumps({'base':base,'scope':'only precheck twins reverted inside synthetic temporary repositories','results':results},indent=2)+'\n')
raise SystemExit(0 if all(row['passed'] for row in results) else 1)
