from pathlib import Path
import os,sys,json,hashlib,subprocess,time
r=Path('/workspace/sdd-forge');t=r/'specs/ci-model-modernization/verification/T-008';ad=Path(sys.argv[1]);expected=sys.argv[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(ad)==expected;m=json.loads(ad.read_text());a=json.loads((ad.parent/'allocation.json').read_text());snapshot=Path(a['snapshot_root'])
for x in m['allowed_inputs']:assert sha(snapshot/x['path'])==x['sha256']
o=t/'root-current-shared-54';o.mkdir(exist_ok=False);(o/'controller.py').write_bytes(Path(__file__).read_bytes());sources={}
for x in m['allowed_inputs']:
 n=x['path'].removeprefix('inputs/')
 if n.startswith(('external/','legacy-runtime/')):continue
 assert (r/n).is_file() and sha(r/n)==x['sha256'],n
 sources[n]=sha(r/n)
(o/'source-before.json').write_text(json.dumps(sources,indent=2)+'\n')
def harness(name,path,count):
 p=o/(name+'.py');p.write_text('''from pathlib import Path
import importlib.util,json,sys,unittest
r=Path('/workspace/sdd-forge');o=Path(__file__).parent;p=r/PATH;s=importlib.util.spec_from_file_location(NAME,p);assert s and s.loader;m=importlib.util.module_from_spec(s);sys.modules[s.name]=m;s.loader.exec_module(m)
class Result(unittest.TextTestResult):
 def __init__(self,*a,**kw):super().__init__(*a,**kw);self.subtests_run=0;self.subtests_passed=0
 def addSubTest(self,test,subtest,err):
  self.subtests_run+=1
  if err is None:self.subtests_passed+=1
  super().addSubTest(test,subtest,err)
suite=unittest.defaultTestLoader.loadTestsFromModule(m);assert suite.countTestCases()==COUNT,suite.countTestCases();v=unittest.TextTestRunner(verbosity=2,resultclass=Result).run(suite);(o/RESULT).write_text(json.dumps({'tests_run':v.testsRun,'subtests_run':v.subtests_run,'subtests_passed':v.subtests_passed,'failures':len(v.failures),'errors':len(v.errors),'skips':len(v.skipped),'successful':v.wasSuccessful(),'discovery_count':suite.countTestCases()},indent=2)+'\\n');raise SystemExit(0 if v.wasSuccessful() else 1)
'''.replace('PATH',repr(path)).replace('NAME',repr('t008_root_'+name)).replace('COUNT',str(count)).replace('RESULT',repr(name+'-result.json')));return p
installed=harness('shared','tests/model-policy-launch.tests.py',54);py='/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3';driver='plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py';test='tests/model-policy-installed.tests.py';ps='/workspace/.tools/sdd-forge-dev/bin/pwsh'
psparse="$tokens = $null; $parseErrors = $null; [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'plugins/sdd-quality-loop/scripts/emit-run-record.ps1'), [ref]$tokens, [ref]$parseErrors) | Out-Null; if ($parseErrors.Count) { $parseErrors | ForEach-Object { Write-Error $_ }; exit 1 }"
commands=[[py,'-B',str(installed)]];rows=[];env=dict(os.environ,TMPDIR='/workspace/.task-scratch/ci-model-modernization',PYTHONDONTWRITEBYTECODE='1',SDD_TEST_PWSH=ps);env['PATH']='/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin:/workspace/.tools/sdd-forge-dev/bin:/workspace/.tools/rtk/0.51.0:'+env.get('PATH','')
try:
 for i,cmd in enumerate(commands,1):
  start=time.monotonic()
  with (o/f'{i}.stdout.log').open('xb') as stdout,(o/f'{i}.stderr.log').open('xb') as stderr:v=subprocess.run(cmd,cwd=r,env=env,stdout=stdout,stderr=stderr,timeout=1800)
  rows.append({'command':cmd,'exit_code':v.returncode,'elapsed_seconds':time.monotonic()-start,'logs':[{'path':str((o/f'{i}.{k}.log').relative_to(r)),'sha256':sha(o/f'{i}.{k}.log')} for k in ('stdout','stderr')]});print(json.dumps({'command':i,'exit_code':v.returncode}),flush=True)
  if v.returncode and i <= 4:break
finally:
 after={n:sha(r/n) for n in sources};(o/'results.json').write_text(json.dumps({'manifest_sha256':expected,'commands':rows,'source_before':sources,'source_after':after,'source_unchanged':sources==after,'scope':'Actual current T007 sharedlaunch54 regression after all T008 additions including impl/task paired actual source role/guard/canonical path and domain paired canonical path and WFI readonly carrier, original investigator/indirect/diagnosis/single-task implementer/delegation, not real model availability/backend identity/cloud or whole-task acceptance'},indent=2)+'\n');assert sources==after
