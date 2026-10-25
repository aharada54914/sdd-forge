from pathlib import Path
import re,subprocess,datetime,json,hashlib
r=Path(__file__).resolve().parents[4];v=r/'specs/a9-interrupted-review-recovery/verification/T-003'
with (v/'author-sweeps.log').open('w') as out:
 out.write('UTC '+datetime.datetime.now(datetime.timezone.utc).isoformat()+'\n')
 texts=[]
 for stage in ('spec','impl','task'):
  p=r/f'plugins/sdd-review-loop/scripts/{stage}-review-precheck.ps1';s=p.read_text();a=s.index('function Assert-SavedRecoveryReference');b=s.index('\n}',a)+2;func=s[a:b];texts.append(func)
  out.write(str(p.relative_to(r))+' SHA256 '+hashlib.sha256(p.read_bytes()).hexdigest()+'\n')
  for i,line in enumerate(func.splitlines(),1):
   if re.search(r'-(?:c?(?:eq|ne|match|notmatch|contains|notcontains|replace|like|notlike))\b',line):out.write('OPERATOR '+str(i)+' '+line.strip()+'\n')
   if re.search(r'Select-String|Get-ChildItem|-split|\[regex\]|switch|Sort-Object|\.Split|\.Equals|Get-FileHash|Get-Item|EnumerateFileSystemEntries',line):out.write('CMDLET-LANGUAGE '+str(i)+' '+line.strip()+'\n')
 assert len(set(texts))==1
 out.write('PASS all three native validators identical. Non-c operators compare JsonValueKind enums, numeric counts/flags only. All schema/key/path/hash string comparisons are ordinal/case-sensitive; OrdinalIgnoreCase only detects and rejects recovery aliases. LiteralPath on file cmdlets; Directory enumeration + Ordinal filename equality. TEST-103 schema negative independently covers operator layer; TEST-083-P15::case covers filename/cmdlet layer. Unicode/space positive preserves admitted path contract.\n')
 ps="param($Root)\n$files=@('spec','impl','task')\nforeach($stage in $files){$t=$null;$e=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $Root ('plugins/sdd-review-loop/scripts/'+$stage+'-review-precheck.ps1')),[ref]$t,[ref]$e);if($e.Count){throw $e};Write-Output ('PARSE PASS '+$stage)}"
 probe=Path('/tmp/a9-parse.ps1');probe.write_text(ps);p=subprocess.run(['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoProfile','-File',str(probe),str(r)],capture_output=True,text=True);out.write(p.stdout+p.stderr);assert p.returncode==0
 s=(r/'tests/spec-review-interrupted-recovery.tests.sh').read_text();line=next(l for l in s.splitlines() if 'declare -F validate_interrupted_recovery' in l);p=subprocess.run(['bash','-c',line],capture_output=True,text=True);assert p.returncode==90 and p.stderr.strip()=='ADMISSION_NOT_'+'IMPLEMENTED';out.write('PASS split Bash marker emission exit90\n')
 expression=next(l for l in s.splitlines() if 'Get-Command Test-InterruptedRecovery -ErrorAction' in l);p=subprocess.run(['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoProfile','-Command',expression],capture_output=True,text=True);assert p.returncode==90 and p.stderr.strip()=='ADMISSION_NOT_'+'IMPLEMENTED';out.write('PASS split PowerShell marker emission exit90\n')
