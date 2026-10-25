from pathlib import Path
import sys,subprocess,json,tempfile,hashlib
repo=Path('/workspace/sdd-a9-recovery');runtime=sys.argv[1]
s=(repo/'tests/spec-review-interrupted-recovery.tests.sh').read_text();code=s[s.index('import copy,'):s.rindex('\nPY')];sys.argv=['-',str(repo),runtime]
n={'__name__':'rollback_control'};exec(compile(code,'retained-test-harness','exec'),n)
with tempfile.TemporaryDirectory(prefix='a9-t002-rollback-') as tmp:
 root=Path(tmp)/'fixture';n['transition_fixture'](root);target=root/f'reports/spec-review/{n["FEATURE"]}/attempt-4/round-1'
 cmd,env=n['transition_command'](root,gate=Path(tmp)/'fault',stop=True);r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=90)
 assert r.returncode!=0 and target.is_dir() and not (target/'precheck-result.json').exists()
 for ext in ('sh','ps1'):
  path=f'plugins/sdd-review-loop/scripts/spec-review-precheck.{ext}'
  (root/path).write_bytes(subprocess.check_output(['git','show','aa54d2fc:'+path],cwd=repo))
 before=n['snapshot'](root);cases=[]
 for name,opts in [('recovery-remains-disabled',['recovery']),('ordinary-reset-retains-terminal-contract-rule',['reset'])]:
  cmd,env=n['transition_command'](root,opts);r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=90)
  assert r.returncode!=0 and n['snapshot'](root)==before and target.is_dir()
  cases.append({'case':name,'exit':r.returncode,'history_unchanged':True,'partial_quarantined':True})
 print(json.dumps({'runtime':runtime,'reverted_source':'aa54d2fc','status':'PASS','cases':cases,'live_recovery':False}))
