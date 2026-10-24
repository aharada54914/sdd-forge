from pathlib import Path
import ast,hashlib,json,subprocess,tempfile
root=Path.cwd();e=root/'specs/a9-interrupted-review-recovery/verification/T-001'
bash=root/'plugins/sdd-review-loop/scripts/spec-review-precheck.sh';ps=root/'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1'
# Execute the actual production canonical function, without a substitute validator.
s=bash.read_text();line=next(line for line in s.splitlines() if line.startswith('def canonical(obj):'))
ns={'json':json};exec(compile(ast.parse(line),'actual-production-canonical-function','exec'),ns)
cases=[('unicode-ensure-ascii',{'value':'é😀'},'{"value":"\\u00e9\\ud83d\\ude00"}'),('retain-array-order',{'z':[2,1],'a':0},'{"a":0,"z":[2,1]}')]
rows=[]
with tempfile.TemporaryDirectory(prefix='canonical-',dir=e) as tmp:
 t=Path(tmp);driver=t/'probe.ps1';driver.write_text('''param([string]$Source,[string]$InputFile)
$ErrorActionPreference='Stop';$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($Source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'production parse failed'}
foreach($node in $ast.EndBlock.Statements){if($node -is [Management.Automation.Language.FunctionDefinitionAst]){. ([scriptblock]::Create($node.Extent.Text))}}
$value=Read-RecoveryJson $InputFile
[Console]::Write((ConvertTo-RecoveryCanonical $value))
''')
 for name,value,expected in cases:
  actual=ns['canonical'](value).decode();rows.append(dict(runtime='bash-production-python',case=name,actual=actual,expected=expected,passed=actual==expected))
  f=t/'input.json';f.write_text(json.dumps(value,ensure_ascii=False))
  result=subprocess.run(['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoLogo','-NoProfile','-File',str(driver),str(ps),str(f)],capture_output=True,text=True)
  rows.append(dict(runtime='powershell-native',case=name,actual=result.stdout,expected=expected,exit_code=result.returncode,stderr=result.stderr,passed=result.returncode==0 and result.stdout==expected))
report=dict(scope='actual canonical helpers only; supplemental unit probe, not whole-admission/origin proof',source_sha256={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (bash,ps)},cases=rows)
(e/'canonical-helper-probe.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(not all(r['passed'] for r in rows))
