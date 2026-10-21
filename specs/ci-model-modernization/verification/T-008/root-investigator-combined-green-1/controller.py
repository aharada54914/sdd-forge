from pathlib import Path
import hashlib,json,os,subprocess,sys,time
r=Path('/workspace/sdd-forge'); manifest=Path(sys.argv[1]); expected=sys.argv[2]; name=sys.argv[3]
assert name.startswith('root-investigator-') and '/' not in name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(manifest)==expected
m=json.loads(manifest.read_bytes()); allocation=json.loads((manifest.parent/'allocation.json').read_bytes()); snapshot=Path(allocation['snapshot_root'])
for ref in m['allowed_inputs']:assert sha(snapshot/ref['path'])==ref['sha256'],ref['path']
sources={}
for ref in m['allowed_inputs']:
 relative=ref['path'].removeprefix('inputs/')
 if relative.startswith(('external/','legacy-runtime/')):continue
 assert sha(r/relative)==ref['sha256'],relative
 sources[relative]=ref['sha256']
o=r/'specs/ci-model-modernization/verification/T-008'/name;o.mkdir(exist_ok=False)
(o/'controller.py').write_bytes(Path(__file__).read_bytes())
harness=o/'focused.py'
harness.write_text('''from pathlib import Path
import importlib.util,json,sys,unittest
root=Path('/workspace/sdd-forge'); output=Path(__file__).parent
spec=importlib.util.spec_from_file_location('t008_spec_root_actual',root/'tests/model-policy-installed.tests.py');assert spec and spec.loader
module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
class Result(unittest.TextTestResult):
 def __init__(self,*args,**kwargs):super().__init__(*args,**kwargs);self.subtests_run=0;self.subtests_passed=0
 def addSubTest(self,test,subtest,error):
  self.subtests_run+=1
  if error is None:self.subtests_passed+=1
  super().addSubTest(test,subtest,error)
suite=unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(module.InstalledDefaultNativeCallerCandidateTests),unittest.defaultTestLoader.loadTestsFromTestCase(module.InstalledClaudeBatchTests)]);assert suite.countTestCases()==6
result=unittest.TextTestRunner(verbosity=2,resultclass=Result).run(suite)
(output/'focused-result.json').write_text(json.dumps({'tests_run':result.testsRun,'subtests_run':result.subtests_run,'subtests_passed':result.subtests_passed,'failures':len(result.failures),'errors':len(result.errors),'skips':len(result.skipped),'successful':result.wasSuccessful()},indent=2)+'\\n')
raise SystemExit(0 if result.wasSuccessful() else 1)
''')
files=['plugins/sdd-implementation/scripts/managed-model-entry.py','tests/model-policy-installed.tests.py','tests/fixtures/model-policy-installed/recording-claude.py','tests/fixtures/model-policy-installed/recording-investigator.py','tests/fixtures/model-policy-installed/recording-diagnosis.py','tests/fixtures/model-policy-installed/recording-implementation.py','tests/fixtures/model-policy-installed/recording-wfi.py','tests/fixtures/model-policy-installed/recording-domain.py','tests/fixtures/model-policy-installed/recording-self-improvement.py','tests/fixtures/model-policy-installed/recording-batch-agent.py','tests/fixtures/model-policy-installed/recording-protected.py','tests/fixtures/model-policy-installed/protected-review-data.py','plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py','plugins/sdd-review-loop/scripts/launch-impl-review.py','plugins/sdd-review-loop/scripts/preflight-host-review.py']
py='/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3'
commands=[['/tmp/ci-model-resume-python/bin/ruff','check',*files],['/tmp/ci-model-resume-python/bin/python','-m','mypy','--config-file','tests/shared-launch-python/pyproject.toml',*files],['bash', '-n', 'tests/install.tests.sh'], ['/workspace/.tools/sdd-forge-dev/bin/pwsh', '-NoProfile', '-NonInteractive', '-Command', '$parsedTokens=$null; $parseErrors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) "tests/install.tests.ps1"), [ref]$parsedTokens, [ref]$parseErrors) | Out-Null; if ($parseErrors.Count) { $parseErrors | ForEach-Object { Write-Error $_ }; exit 1 }'], [py,'-B',str(harness)]]
env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',SDD_TEST_PWSH='/workspace/.tools/sdd-forge-dev/bin/pwsh',TMPDIR='/workspace/.task-scratch/ci-model-modernization')
env['PATH']='/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin:/workspace/.tools/sdd-forge-dev/bin:/workspace/.tools/rtk/0.51.0:'+env.get('PATH','')
rows=[]
try:
 for index,command in enumerate(commands,1):
  start=time.monotonic()
  with (o/f'{index}.stdout.log').open('xb') as stdout,(o/f'{index}.stderr.log').open('xb') as stderr: result=subprocess.run(command,cwd=r,env=env,stdout=stdout,stderr=stderr,timeout=1200)
  rows.append({'command':command,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-start,'logs':[{'path':str((o/f'{index}.{kind}.log').relative_to(r)),'sha256':sha(o/f'{index}.{kind}.log')} for kind in ('stdout','stderr')]})
  print(json.dumps({'command':index,'exit_code':result.returncode}),flush=True)
  if result.returncode and index<len(commands):break
finally:
 after={path:sha(r/path) for path in sources}
 (o/'results.json').write_text(json.dumps({'manifest_sha256':expected,'commands':rows,'source_before':sources,'source_after':after,'source_unchanged':sources==after,'scope':'Actual installed16Skill22role4host2installer unsupported boundary fixtures only; not native modelwork or adoption/full T008 acceptance'},indent=2)+'\n')
 assert sources==after
