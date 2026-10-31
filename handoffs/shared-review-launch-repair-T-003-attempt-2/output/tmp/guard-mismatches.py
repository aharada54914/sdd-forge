import hashlib, json, os, pathlib, re, shutil, subprocess, sys
out=pathlib.Path.cwd(); work=out/'work'; root=out/'tmp/guard-preflight'; root.mkdir()
q='plugins/sdd-quality-loop/scripts/'
paths=[
 'plugins/sdd-review-loop/scripts/launch-impl-review.py',
 'plugins/sdd-review-loop/scripts/preflight-host-review.py',
 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py',
 'plugins/sdd-review-loop/scripts/probe-nontty-review.py',
 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs',
 q+'preflight-evaluator-delivery.py']
projections=[q+'generated/'+s for s in ('guard_invariants.py','guard-invariants.generated.js','guard-invariants.generated.ps1','guard-invariants.generated.sh')]
files=paths+projections+[q+'sdd-hook-guard.'+s for s in ('py','js','ps1','sh')]
for name in files:
 p=root/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes((work/name).read_bytes())
commands={'Python':[sys.executable,'-B',str(root/(q+'sdd-hook-guard.py')),'--emit','exit'], 'Node':['node',str(root/(q+'sdd-hook-guard.js')),'--emit','exit'], 'PowerShell':['pwsh','-NoProfile','-File',str(root/(q+'sdd-hook-guard.ps1')),'-Emit','exit'], 'Bash':['bash',str(root/(q+'sdd-hook-guard.sh')),'--emit','exit']}
records=[]; env=dict(os.environ,CLAUDE_PROJECT_DIR=str(root),PYTHONDONTWRITEBYTECODE='1'); env.pop('PAYLOAD',None)
def run(label,runtime,name,tool,expected):
 payload=json.dumps({'tool_name':tool,'tool_input':{'file_path':str(root/name),'content':'fixture'}})
 cmd=['rtk','proxy',*commands[runtime]]; r=subprocess.run(cmd,cwd=root,env=env,input=payload,capture_output=True,text=True)
 records.append(dict(label=label,runtime=runtime,argv=cmd,cwd=str(root),stdin=payload,exit=r.returncode,stdout=r.stdout,stderr=r.stderr))
 assert r.returncode==expected,records[-1]
 if expected==2: assert 'agents must not modify gate scripts' in r.stderr,records[-1]
for name in paths:
 originals={p:(root/p).read_bytes() for p in projections}
 for runtime in commands:
  run('intact baseline',runtime,name,'Write',2); run('intact read allowance',runtime,name,'Read',0); run('unrelated setup control',runtime,'ordinary.txt','Write',0)
 hashes=[]
 for p,before in originals.items():
  mutated=before.replace((repr(name)+', ').encode(),b'').replace((json.dumps(name)+',').encode(),b'').replace(('    "'+name+'",\n').encode(),b'').replace(("    '"+name+"',\n").encode(),b'')
  if p.endswith('.sh'): continue
  assert mutated!=before,p
  (root/p).write_bytes(mutated)
  hashes.append(dict(path=p,before=hashlib.sha256(before).hexdigest(),mutated=hashlib.sha256(mutated).hexdigest()))
 for runtime in commands:
  run('isolated removed-membership mismatch: expected protection lost',runtime,name,'Write',0); run('mutation read control',runtime,name,'Read',0)
 for p,before in originals.items(): (root/p).write_bytes(before)
 for h in hashes: h['restored']=hashlib.sha256((root/h['path']).read_bytes()).hexdigest(); assert h['before']==h['restored']
 records.append(dict(label='rollback',entrypoint=name,hashes=hashes))
 for runtime in commands: run('restored-byte GREEN',runtime,name,'Write',2)
canon=json.loads((work/'plugins/sdd-quality-loop/references/guard-invariants.json').read_bytes())
unrelated=dict(canon); unrelated['protected_gate_suffixes']=[p for p in canon['protected_gate_suffixes'] if p not in paths]
encoded=lambda d:json.dumps(d,sort_keys=True,separators=(',',':')).encode()
pin=hashlib.sha256(encoded(unrelated)).hexdigest()
changed=json.loads(encoded(unrelated)); changed['protected_gate_suffixes'].pop(0)
assert hashlib.sha256(encoded(changed)).hexdigest()!=pin
records.append(dict(label='unrelated membership mismatch',before=pin,mutated=hashlib.sha256(encoded(changed)).hexdigest(),restored=hashlib.sha256(encoded(unrelated)).hexdigest()))
workflow=(work/'.github/workflows/test.yml').read_bytes()
pattern=rb'(?m)^        run: python3 -B tests/quality-nontty-transport[.]tests[.]py[ \t]*$'
assert len(re.findall(pattern,workflow))==1
mutated=re.sub(pattern,b'',workflow)
assert not re.search(pattern,mutated)
records.append(dict(label='workflow registration mismatch',before=hashlib.sha256(workflow).hexdigest(),mutated=hashlib.sha256(mutated).hexdigest(),restored=hashlib.sha256(workflow).hexdigest()))
ev=work/'specs/shared-review-launch-repair/verification/T-003'
(ev/'guard-preflight-mismatches.json').write_text(json.dumps(records,indent=2)+'\n')
print('Six entrypoints x four available runtimes: intact denial/read, removed-membership mismatch, byte restoration verified. Unrelated membership pin:',pin)
