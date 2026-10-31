import hashlib, json, os, pathlib, re, subprocess, sys
out=pathlib.Path.cwd(); work=out/'work'; root=out/'tmp/regression-mutations'; root.mkdir()
m=json.loads((out.parent/'manifest.json').read_bytes())
for entry in m['allowed_inputs']:
 name=entry['path']; p=root/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes((work/name).read_bytes())
suite='tests/host-review-preflight.tests.py'; q='plugins/sdd-quality-loop/scripts/'
paths=[
 'plugins/sdd-review-loop/scripts/launch-impl-review.py',
 'plugins/sdd-review-loop/scripts/preflight-host-review.py',
 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py',
 'plugins/sdd-review-loop/scripts/probe-nontty-review.py',
 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs',q+'preflight-evaluator-delivery.py']
tests=['test_011a_launch_impl_review','test_011b_preflight_host_review','test_011c_validate_nontty_spec_launch','test_011d_probe_nontty_review','test_011e_nontty_impl_pretool_guard','test_011f_preflight_evaluator_delivery']
projections=[q+'generated/'+s for s in ('guard_invariants.py','guard-invariants.generated.js','guard-invariants.generated.ps1')]
records=[]
def run(label,test,expected,diagnostic=''):
 cmd=['rtk','proxy',sys.executable,'-B',str(root/suite),'ProtectedEntrypointTests.'+test,'-v']
 r=subprocess.run(cmd,cwd=out,env=os.environ,capture_output=True,text=True)
 record=dict(label=label,argv=cmd,cwd=str(out),exit=r.returncode,stdout=r.stdout,stderr=r.stderr); records.append(record)
 assert r.returncode==expected and diagnostic in r.stderr,record
 if expected==1 and test.startswith('test_011'): assert 'broken fixture' not in r.stderr,record
 return record
for name,test in zip(paths,tests):
 run('intact candidate GREEN',test,0)
 originals={p:(root/p).read_bytes() for p in projections}; hashes=[]
 try:
  for p,before in originals.items():
   mutated=before.replace((repr(name)+', ').encode(),b'').replace((json.dumps(name)+',').encode(),b'')
   assert before!=mutated,p
   (root/p).write_bytes(mutated)
   hashes.append(dict(path=p,before=hashlib.sha256(before).hexdigest(),mutated=hashlib.sha256(mutated).hexdigest()))
  run('isolated registration mutation RED (not original production RED)',test,1,'AssertionError: 0 != 2')
 finally:
  for p,before in originals.items(): (root/p).write_bytes(before)
 for h in hashes: h['restored']=hashlib.sha256((root/h['path']).read_bytes()).hexdigest(); assert h['before']==h['restored']
 run('restored-byte GREEN',test,0)['rollback_hashes']=hashes
workflow=root/'.github/workflows/test.yml'; before=workflow.read_bytes(); test='test_013_ci_transport_registration'
run('intact actual workflow GREEN',test,0)
mutated,count=re.subn(rb'(?m)^        run: python3 -B tests/quality-nontty-transport[.]tests[.]py[ \t]*$',b'',before); assert count==1
try:
 workflow.write_bytes(mutated)
 cmd=['rtk','proxy',sys.executable,'-B',str(root/(q+'generate-guard-invariants.py')),'--check']
 r=subprocess.run(cmd,cwd=out,capture_output=True,text=True); records.append(dict(label='CI omission is invisible to generator --check',argv=cmd,cwd=str(out),exit=r.returncode,stdout=r.stdout,stderr=r.stderr)); assert r.returncode==0
 run('isolated actual workflow removal RED',test,1,'CI transport registration missing')
finally: workflow.write_bytes(before)
run('restored actual workflow GREEN',test,0)['rollback_hashes']=[dict(path='.github/workflows/test.yml',before=hashlib.sha256(before).hexdigest(),mutated=hashlib.sha256(mutated).hexdigest(),restored=hashlib.sha256(workflow.read_bytes()).hexdigest())]
canon=root/'plugins/sdd-quality-loop/references/guard-invariants.json'; before=canon.read_bytes(); data=json.loads(before); data['protected_gate_suffixes'].pop(0); mutated=(json.dumps(data)+'\n').encode()
try:
 canon.write_bytes(mutated); run('isolated unrelated membership RED','test_012d_unrelated_membership_unchanged',1,'unrelated invariant keys or membership changed')
finally: canon.write_bytes(before)
run('restored unrelated membership GREEN','test_012d_unrelated_membership_unchanged',0)['rollback_hashes']=[dict(path=str(canon.relative_to(root)),before=hashlib.sha256(before).hexdigest(),mutated=hashlib.sha256(mutated).hexdigest(),restored=hashlib.sha256(canon.read_bytes()).hexdigest())]
(work/'specs/shared-review-launch-repair/verification/T-003/regression-mutations.json').write_text(json.dumps(records,indent=2)+'\n')
print('Six per-entrypoint unittest REDs, actual CI omission RED, unrelated-membership RED and exact-byte rollback GREEN completed.')
