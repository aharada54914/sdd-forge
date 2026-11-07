from pathlib import Path
import hashlib,json,shutil,subprocess,sys
r=Path(sys.argv[1]).resolve();r.mkdir()
files={
'specs/sum/requirements.md':'# Requirements\nREQ-001: Sum all supplied integers; the empty list totals zero.\n',
'specs/sum/design.md':'# Design\nUse Python built-in sum in sum_values. No storage, network, dependencies, or UI.\n',
'specs/sum/acceptance-tests.md':'# Acceptance\nAC-001: [2, 3, -1] yields 4. AC-002: [] yields 0.\n',
'specs/sum/tasks.md':'# Tasks\n### T-001: Sum values\nApproval: Approved\nStatus: Implementation Complete\n',
'specs/sum/traceability.md':'# Traceability\nREQ-001 -> AC-001, AC-002 -> T-001 -> sum_values.py, tests/test_sum.py\n',
'sum_values.py':'def sum_values(values):\n    return sum(values)\n',
'tests/test_sum.py':"import importlib.util\nfrom pathlib import Path\nspec=importlib.util.spec_from_file_location('sum_values',Path(__file__).resolve().parents[1]/'sum_values.py')\nm=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)\nassert m.sum_values([2,3,-1]) == 4\nassert m.sum_values([]) == 0\nprint('2 acceptance checks passed')\n"}
for name,text in files.items():p=r/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
result=subprocess.run(['/usr/bin/python3','-I','-B','tests/test_sum.py'],cwd=r,capture_output=True,text=True,check=True)
p=r/'reports/test-result.txt';p.parent.mkdir(parents=True);p.write_text(result.stdout)
outputs=['sum_values.py','tests/test_sum.py','reports/test-result.txt']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report='reports/implementation/sum/T-001.md';p=r/report;p.parent.mkdir(parents=True);p.write_text('# Implementation Report: T-001\n\n- Task ID: T-001\n\nReport Schema: implementation-report/v2\n\n## Summary\nDisposable transport integration fixture only; not a full workflow claim. Implemented integer summation.\n\n## Outputs\n\n| Path | SHA-256 |\n|---|---|\n'+''.join('| `'+n+'` | `'+sha(r/n)+'` |\n' for n in outputs)+'\n## Test Evidence\nCommand: /usr/bin/python3 -I -B tests/test_sum.py\nActual output: reports/test-result.txt\n')
cal='plugins/sdd-quality-loop/references/quality-gate-calibration.md';p=r/cal;p.parent.mkdir(parents=True);shutil.copyfile(Path('/workspace/sdd-forge')/cal,p)
ledger='reports/review-context/identity-ledger.json';p=r/ledger;p.parent.mkdir(parents=True);shutil.copyfile('/workspace/.tools/sdd-forge-dev/verification-workspace/native-launcher-integration/'+ledger,p)
paths=sorted(list(files)+['reports/test-result.txt',report,cal])
d=dict(schema='review-context-invocation/v2',stage='quality',role='sdd-evaluator',feature='sum',task_id='T-001',input_mode='file-manifest',fallback_mode='none',read_only=True,allowed_input_manifest=[dict(path=n,sha256=sha(r/n)) for n in paths],run_id='placeholder',host_session_id='placeholder',identity_ledger_path=ledger,identity_ledger_sha256='0'*64,sequence=2,previous_record_sha256='0'*64)


m=r/'reports/task-inputs/sum/T-001.json';m.parent.mkdir(parents=True)
m.write_text(json.dumps({'schema':'task-input-manifest/v1','task_id':'T-001','run_id':'fixture-implementation-run','session_id':'fixture-implementation-session','allowed_inputs':[{'path':'specs/sum/requirements.md','sha256':sha(r/'specs/sum/requirements.md')}]}))
p=r/report
p.write_text(p.read_text()+'\n## Isolation Evidence\n\n- **Scratch Root**: '+str(r)+'\nRun ID: fixture-implementation-run\n- **Run ID**: fixture-implementation-run\n- **Session ID**: fixture-implementation-session\nInput manifest: `'+m.relative_to(r).as_posix()+'`, SHA-256 `'+sha(m)+'`\n\nImplementation IDs above are synthetic transport test fixture labels, not a claimed native implementation run.\n')
d['implementation_manifest']={'path':m.relative_to(r).as_posix(),'sha256':sha(m)}
d['allowed_input_manifest'].append(d['implementation_manifest'].copy())
for entry in d['allowed_input_manifest']:entry['sha256']=sha(r/entry['path'])
p=r/'template.json';p.write_text(json.dumps(d,indent=2)+'\n');print(sha(p))
