import ast, hashlib, json, re, tempfile
from pathlib import Path
source=Path(__file__).with_name('update-verification.py')
node=next(n for n in ast.parse(source.read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='task_gate')
namespace=globals();exec(compile(ast.Module(body=[node],type_ignores=[]),str(source),'exec'),namespace)
results=[]
with tempfile.TemporaryDirectory() as folder:
 root=Path(folder);reports=root/'reports/quality-gate';reports.mkdir(parents=True)
 verification=root/'specs/example/verification';verification.mkdir(parents=True)
 report=reports/'20261107-T-001-pass.md';report.write_text('Task ID: T-001\nVERDICT: PASS\n')
 relative=report.relative_to(root).as_posix()
 bundle={'task_id':'T-001','feature':'example','quality_report':relative,'review_verdict':{'verdict':'PASS'},'artifacts':[{'path':relative,'sha256':hashlib.sha256(report.read_bytes()).hexdigest()}]}
 target=verification/'T-001.evidence.json'
 def check(name,expected):
  actual=task_gate(root,'example','T-001',False)
  assert actual==expected,(name,actual,expected)
  results.append({'case':name,'passed':True})
 check('missing bundle does not imply completion',None)
 target.write_text(json.dumps(bundle));check('dated canonical report resolved by bundle',relative)
 report.write_text('Task ID: T-001\nVERDICT: PASS\nchanged\n');check('stale report hash rejected',None)
 report.write_text('Task ID: T-001\nVERDICT: PASS\n')
 bundle['task_id']='T-002';target.write_text(json.dumps(bundle));check('different task rejected',None)
 bundle['task_id']='T-001';bundle['feature']='other';target.write_text(json.dumps(bundle));check('different feature rejected',None)
 bundle['feature']='example';bundle['quality_report']='../../outside.md';target.write_text(json.dumps(bundle));check('outside report path rejected',None)
 (reports/'T-001.md').write_text('Task ID: T-001\nVERDICT: PASS\n')
 assert task_gate(root,'example','T-001',True)=='reports/quality-gate/T-001.md'
 results.append({'case':'lite direct report supported','passed':True})
print(json.dumps({'checks':results,'passed':len(results)},indent=2))
