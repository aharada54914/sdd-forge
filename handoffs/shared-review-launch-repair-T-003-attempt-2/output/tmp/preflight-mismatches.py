import copy, hashlib, json, os, pathlib, subprocess, sys
out=pathlib.Path.cwd(); work=out/'work'; root=out/'tmp/preflight'; root.mkdir()
m=json.loads((out.parent/'manifest.json').read_text())
files=[e['path'] for e in m['allowed_inputs'] if e['path'].startswith('plugins/sdd-quality-loop/scripts/generated/') or e['path'] in ('plugins/sdd-quality-loop/scripts/generate-guard-invariants.py','plugins/sdd-quality-loop/references/guard-invariants.json','.github/workflows/test.yml')]
for name in files:
 p=root/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes((work/name).read_bytes())
gen='plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'; canon='plugins/sdd-quality-loop/references/guard-invariants.json'
records=[]
def run(label, expected, diagnostic=''):
 cmd=['rtk','proxy',sys.executable,'-B',str(root/gen),'--check']; r=subprocess.run(cmd,cwd=out,capture_output=True,text=True)
 records.append(dict(label=label,argv=cmd,cwd=str(out),exit=r.returncode,stdout=r.stdout,stderr=r.stderr))
 assert r.returncode==expected and diagnostic in r.stderr,records[-1]
run('intact baseline',0)
for name in (canon,gen):
 p=root/name; before=p.read_bytes()
 if name==canon:
  data=json.loads(before); data['protected_gate_suffixes'].append('plugins/sdd-review-loop/scripts/t003-extra.py'); mutated=(json.dumps(data,indent=2)+'\n').encode()
 else:
  mutated=before.replace(b'BASELINE_SUFFIXES = (',b'BASELINE_SUFFIXES = (\n    "plugins/sdd-review-loop/scripts/t003-extra.py",',1)
 p.write_bytes(mutated); run('isolated mutation RED '+name,1,'exact baseline/inventory union'); p.write_bytes(before); run('restored-byte GREEN '+name,0)
 records[-1]['hashes']={k:hashlib.sha256(v).hexdigest() for k,v in [('before',before),('mutated',mutated),('restored',p.read_bytes())]}
for name in files:
 if '/generated/' not in name: continue
 p=root/name; before=p.read_bytes(); mutated=before+b'\n'; p.write_bytes(mutated); run('isolated stale projection RED '+name,1,str(p)); p.write_bytes(before); run('restored-byte GREEN '+name,0)
 records[-1]['hashes']={k:hashlib.sha256(v).hexdigest() for k,v in [('before',before),('mutated',mutated),('restored',p.read_bytes())]}
ev=work/'specs/shared-review-launch-repair/verification/T-003'
(ev/'preflight-mismatches.json').write_text(json.dumps(records,indent=2)+'\n')
print('Executed canonical-only, generator-only and four independent stale-projection mismatches; all expected exit 1 diagnostics and restored exit 0 verified.')
