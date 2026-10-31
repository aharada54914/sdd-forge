from pathlib import Path
import hashlib,json,re,stat
out=Path.cwd(); work=out/'work'; ev=work/'specs/shared-review-launch-repair/verification/T-003'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest_path=out.parent/'manifest.json'; manifest_sha=sha(manifest_path)
assert manifest_sha=='2cfa85dd398feb18497c28c4753b8dcff37b8ee209c344de4c36f8ef4cdf6409'
m=json.loads(manifest_path.read_bytes()); report_path='reports/implementation/shared-review-launch-repair/T-003.md'; report=(work/report_path).read_text()
identity='01a1258a-7238-78c3-a0b0-a630c254f506'; run_id='T-003-'+identity
for key in ('session_id','agent_instance_id'): assert m[key]==identity
assert m['run_id']==run_id
required=[f'Run ID: {run_id}', 'Task Attempt Count: 2',f'- **Scratch Root**: {out}',f'- **Run ID**: {run_id}',f'- **Session ID**: {identity}',f'- **Agent Instance ID**: {identity}','- Model: gpt-6-astra','- Effort: high','- **Task Attempt Count**: 2','- **Isolation Mode**: fresh-agent']
for line in required: assert report.splitlines().count(line)==1,line
provenance=json.loads((ev/'provenance.json').read_bytes()); assert f"`spec_revision`: `{provenance['spec_revision']}`" in report
spec=next(e for e in m['allowed_inputs'] if e['path']=='specs/shared-review-launch-repair/requirements.md'); assert spec['sha256']==provenance['spec_revision']
rows=re.findall(r'^\| `([^`]+)` \| `([0-9a-f]{64})` \|$',report.split('## Outputs\n',1)[1].split('\n## ',1)[0],re.M)
assert len(rows)==24 and len({p for p,h in rows})==len(rows)
assert report_path not in {p for p,h in rows}
expected={'tests/host-review-preflight.tests.py'}|{str(p.relative_to(work)) for p in ev.iterdir() if p.is_file()}
assert {p for p,h in rows}==expected
for path,digest in rows:
 assert sha(work/path)==digest,path
 try: assert sha(work/path)==('0'*64)
 except AssertionError: pass
 else: raise AssertionError('tampered output hash unexpectedly accepted')
integrity=json.loads((ev/'source-integrity.json').read_bytes()); source_rows=integrity['entries']
for e in m['allowed_inputs']:
 assert sha(out.parent/'snapshot'/e['path'])==e['sha256'],e['path']
for e in source_rows:
 assert sha(work/e['path'])==e['after_sha256'],e['path']
 if e['authorized_source_mode'] is not None: assert stat.S_IMODE((work/e['path']).stat().st_mode)==e['authorized_source_mode']
assert [e['path'] for e in source_rows if e['changed']]==['tests/host-review-preflight.tests.py']
base=(out.parent/'snapshot/tests/host-review-preflight.tests.py').read_text(); test=(work/'tests/host-review-preflight.tests.py').read_text()
assert base[base.index('class HostReviewPreflightTests'):base.index("if __name__")] in test
validation=json.loads((ev/'report-validation.json').read_bytes()); assert validation['exit']==0 and validation['stdout']=='IMPLEMENTATION_REPORT_OK\n' and validation['stderr']==''
for name in ('focused-host.json','final-generator.json','final-parity.json','isolated-regression-execution.json'):
 assert json.loads((ev/name).read_bytes())['exit']==0
mutations=json.loads((ev/'regression-mutations.json').read_bytes()); assert len([r for r in mutations if r['exit']==1])==8
rollbacks=[h for r in mutations for h in r.get('rollback_hashes',[])]; assert len(rollbacks)==20
assert all(h['before']==h['restored'] and h['before']!=h['mutated'] for h in rollbacks)
report_sha=sha(work/report_path)
delivered=[{'path':'work/'+p,'repository_path':p,'sha256':h,'mode':stat.S_IMODE((work/p).stat().st_mode),'kind':'source' if p.startswith('tests/') else 'evidence'} for p,h in rows]
delivered.append({'path':'work/'+report_path,'repository_path':report_path,'sha256':report_sha,'mode':stat.S_IMODE((work/report_path).stat().st_mode),'kind':'implementation-report'})
result='DELIVERY_INTEGRITY_OK: 25 delivered files; 24 Outputs hashes; 57 immutable input hashes; one changed source; 20 exact rollback triples.\n'
index={'schema':'t003-delivery-index/v1','task_id':'T-003','feature':'shared-review-launch-repair','run_id':run_id,'session_id':identity,'agent_instance_id':identity,'task_attempt_count':2,'model':'gpt-6-astra','effort':'high','output_root':str(out),'scratch_root':str(out),'manifest':{'path':str(manifest_path),'sha256':manifest_sha},'spec_revision':provenance['spec_revision'],'delivery_status':'implementation artifacts complete; parent-owned lifecycle unchanged','task_state_transition_performed':False,'delivered_files':delivered,'before_after_source_hashes':source_rows,'report_validation':{'evidence_path':'work/specs/shared-review-launch-repair/verification/T-003/report-validation.json','evidence_sha256':sha(ev/'report-validation.json'),'validated_final_report_sha256':report_sha,'exit':0,'stdout':'IMPLEMENTATION_REPORT_OK\n','stderr':''},'final_integrity_check':{'argv':['rtk','proxy','python3','tmp/finalize-index.py'],'cwd':str(out),'login':False,'exit':0,'stdout':result,'stderr':'','script_sha256':sha(out/'tmp/finalize-index.py'),'script_source':(out/'tmp/finalize-index.py').read_text(),'mismatch_check':'Every declared output digest checked against bytes; deliberately wrong digest rejected for each.'},'limitations':{k:'NOT RUN' for k in ('Windows','installed-host activation','independent review','quality gate','CI','merge')},'packaging_note':'Only delivered_files are intended delivery. Unchanged work inputs and output/tmp are not source changes. Report self-hash is excluded from Outputs and bound here. This index does not contain a self-hash.'}
p=out/'delivery-index.json'; p.write_text(json.dumps(index,indent=2)+'\n')
readback=json.loads(p.read_bytes()); assert readback==index
for e in readback['delivered_files']: assert sha(out/e['path'])==e['sha256'],e['path']
print(result,end='')
