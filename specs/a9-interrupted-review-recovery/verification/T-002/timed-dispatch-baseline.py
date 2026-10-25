"""Exactly twelve retrospective native dispatch checks; no live evidence/provider."""
from pathlib import Path
from datetime import datetime,timezone
import sys,subprocess,tempfile,json,hashlib,os,time
repo=Path('/workspace/sdd-a9-recovery');output=repo/'specs/a9-interrupted-review-recovery/verification/T-002/retrospective-dispatch-timing.json'
assert not output.exists(),'preserve prior timed receipt'
sha=lambda b:hashlib.sha256(b).hexdigest()
script=repo/'tests/spec-review-interrupted-recovery.tests.sh';source=script.read_text();code=source[source.index('import copy,'):source.rindex('\nPY')]
revisions={phase:subprocess.check_output(['git','rev-parse',ref],cwd=repo,text=True).strip() for phase,ref in [('checkpoint','aa54d2fc'),('current','f7e6bc53')]}
rows=[]
for runtime in ['bash','powershell']:
 sys.argv=['-',str(repo),runtime];n={'__name__':'retrospective_dispatch'};exec(compile(code,str(script),'exec'),n)
 for phase,revision in revisions.items():
  with tempfile.TemporaryDirectory(prefix='a9-t002-timed-') as tmp:
   base=Path(tmp)/'fixture';n['transition_fixture'](base)
   for ext in ['sh','ps1']:
    rel='plugins/sdd-review-loop/scripts/spec-review-precheck.'+ext
    (base/rel).write_bytes(subprocess.check_output(['git','show',revision+':'+rel],cwd=repo))
   source_rel='plugins/sdd-review-loop/scripts/spec-review-precheck.'+('sh' if runtime=='bash' else 'ps1')
   source_hash=sha((base/source_rel).read_bytes())
   for case,options in [('TEST-002',[]),('TEST-003',['reset']),('TEST-005',['--unknown'])]:
    before=n['snapshot'](base);cmd,env=n['transition_command'](base,options)
    start=datetime.now(timezone.utc).isoformat();clock=time.monotonic()
    result=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=90)
    elapsed=time.monotonic()-clock;end=datetime.now(timezone.utc).isoformat()
    same=n['snapshot'](base)==before;absent=not os.path.lexists(base/f'reports/spec-review/{n["FEATURE"]}/attempt-4')
    text=result.stdout+result.stderr
    reason=('a new attempt requires --reset' in text if case=='TEST-002' else 'reset requires a terminal PASS or BLOCKED contract' in text if case=='TEST-003' else ('Usage:' in text or 'unknown' in text or 'parameter cannot be found' in text))
    ok=result.returncode!=0 and same and absent and reason
    rows.append(dict(runtime=runtime,phase=phase,case=case,label='retrospective timed check; not the original preimplementation timestamp',source_revision=revision,source_path=source_rel,source_sha256=source_hash,fixture_generator_path=str(script.relative_to(repo)),fixture_generator_sha256=sha(script.read_bytes()),started_at_utc=start,finished_at_utc=end,elapsed_seconds=elapsed,command=cmd,exit_code=result.returncode,stdout=result.stdout,stderr=result.stderr,all_fixture_bytes_unchanged=same,target_attempt_absent=absent,expected_rejection_reason=reason,result='PASS' if ok else 'FAIL'))
receipt={'schema':'a9-t002-retrospective-dispatch/v1','scope':'exactly three reused dispatch behaviors, two source revisions, two native runtimes; original untimed logs retained','timestamp_source':'UTC datetime sampled immediately before/after each actual subprocess; never file mtime or commit timestamp','actual_native_calls':len(rows),'provider_calls':0,'results':rows}
output.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({'receipt':str(output),'calls':len(rows),'pass':sum(r['result']=='PASS' for r in rows)}));raise SystemExit(any(r['result']!='PASS' for r in rows))
