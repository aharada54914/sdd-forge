from pathlib import Path
import subprocess,sys,json,hashlib,datetime,re
root=Path('/workspace/sdd-forge');revision,run_id,basearg=sys.argv[1:];base=Path(basearg);tag='v1.19.0'
out=root/'specs/cloud-orchestration/verification/T-008/root-release-final';out.mkdir(exist_ok=True)
def call(args):
 return subprocess.check_output(args,cwd=root,text=True)
def tags():
 return dict(line.split()[::-1] for line in call(['git','ls-remote','--tags','origin']).splitlines())
assert len(revision)==40 and all(x in '0123456789abcdef' for x in revision)
local=call(['python3','/tmp/cloud-validate-release-local.py',str(base),revision]);json.loads(local)
ci=json.loads(call(['gh','run','view',run_id,'--json','status,conclusion,jobs,headSha,url,workflowName']))
assert ci['headSha']==revision and ci['status']=='completed' and ci['conclusion']=='success',ci
old=json.loads((root/'specs/cloud-orchestration/verification/T-008/root-release-attempt-1/ci-final.json').read_text())
assert {j['name'] for j in ci['jobs']}=={j['name'] for j in old['jobs']}
for job in ci['jobs']:
 assert job['status']=='completed'
 assert job['conclusion']==('skipped' if job['name']=='capability-mode Gate' else 'success'),job
assert {'test (windows-latest)','test (macos-latest)','test (ubuntu-latest)','required-checks'}<={j['name'] for j in ci['jobs']}
# The actual Windows test output must be captured and checked before invoking this publisher.
win=json.loads((out/'native-windows-junction.json').read_text())
assert win['revision']==revision and str(win['run_id'])==run_id and win['status']=='PASS' and win['native_windows_executed'] is True
log=root/win['evidence'];assert hashlib.sha256(log.read_bytes()).hexdigest()==win['sha256']
assert re.search(r'test_windows_output_parent_junction_is_rejected \([^\n]+\) \.\.\. ok(?:\r?\n|$)', log.read_text())
assert not call(['git','tag','--list',tag]).strip(),'local tag already exists; no replacement allowed'
before=tags();assert 'refs/tags/'+tag not in before and 'refs/tags/'+tag+'^{}' not in before
initial=dict(line.split()[::-1] for line in (root/'specs/cloud-orchestration/verification/T-008/attempt-1/remote-tags-before.txt').read_text().splitlines())
assert all(before.get(k)==v for k,v in initial.items()),'historical remote tags changed'
(out/'ci-final.json').write_text(json.dumps(ci,indent=2)+'\n')
(out/'local-full-validation.json').write_text(local)
(out/'tags-before.json').write_text(json.dumps(before,indent=2)+'\n')
message=out/'tag-message.txt';message.write_text(f'sdd-forge {tag}\n\nAzure/AWS orchestration and multi-target integration fixes.\nExact commit: {revision}\nFull CI: {ci["url"]}\nFull local POSIX and PowerShell profiles passed on this commit.\nLive cloud sandbox acceptance remains blocked; no release assets published.\n')
call(['git','tag','-a',tag,revision,'-F',str(message)])
push=subprocess.run(['git','push','origin','refs/tags/'+tag],cwd=root,text=True,capture_output=True)
(out/'tag-push.log').write_text(push.stdout+push.stderr);assert push.returncode==0,'tag push failed; preserve local tag and inspect remote, never force'
after=tags();assert after['refs/tags/'+tag+'^{}']==revision and all(after.get(k)==v for k,v in before.items())
assert call(['git','cat-file','-t','refs/tags/'+tag]).strip()=='tag'
(out/'tags-after.json').write_text(json.dumps(after,indent=2)+'\n')
record={'tag':tag,'revision':revision,'annotated_tag_object':after['refs/tags/'+tag],'run_id':int(run_id),'ci_url':ci['url'],'published_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'historical_tags_unchanged':True,'release_assets':'not published','live_cloud_acceptance':'BLOCKED: sandbox unavailable'}
(out/'tag-publication.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
