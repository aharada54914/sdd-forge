from pathlib import Path
import os, json, hashlib, subprocess, shlex, shutil, platform, datetime
out=Path(__file__).resolve().parents[1]
work=out/'work'
ev=work/'specs/shared-review-launch-repair/verification/T-002/native-revalidation-attempt-3-20261010'
ev.mkdir(parents=True,exist_ok=True)
bin_dir=out/'tmp/runtime-bin'; bin_dir.mkdir(exist_ok=True)
# Expose actual installed test runtimes only; exclude Git to prevent owner-history discovery.
tools={}
for name in 'rtk bash sh pwsh python3 jq shasum sha256sum awk sed find cp mv rm mkdir mktemp dirname sort cat head tail tr wc grep cut cmp printf uname readlink xargs stat diff tee touch base64 chmod date perl basename realpath env which uniq sleep'.split():
    path=shutil.which(name)
    if path:
        tools[name]=path
        link=bin_dir/name
        if not link.exists(): link.symlink_to(path)
assert all(n in tools for n in ['rtk','bash','pwsh','python3','jq','shasum'])
env=os.environ.copy()
env.update(PATH=str(bin_dir),TMPDIR=str(out/'tmp'),TMP=str(out/'tmp'),TEMP=str(out/'tmp'),TMPPREFIX=str(out/'tmp/zsh'),PYTHONDONTWRITEBYTECODE='1',XDG_CACHE_HOME=str(out/'tmp/cache'),XDG_CONFIG_HOME=str(out/'tmp/config'),XDG_DATA_HOME=str(out/'tmp/data'),GIT_CEILING_DIRECTORIES=str(out))
assert shutil.which('git',path=env['PATH']) is None
records=[]
def run(label,args):
    argv=['rtk','proxy']+args
    start=datetime.datetime.now(datetime.timezone.utc).isoformat()
    with (ev/(label+'.stdout.log')).open('wb') as stdout, (ev/(label+'.stderr.log')).open('wb') as stderr:
        result=subprocess.run(argv,cwd=work,env=env,stdout=stdout,stderr=stderr)
    row={'label':label,'argv':argv,'command':shlex.join(argv),'cwd':str(work),'native_cwd':str(out),'shell_login':False,'started_at':start,'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exit_code':result.returncode,'stdout':str((ev/(label+'.stdout.log')).relative_to(work)),'stderr':str((ev/(label+'.stderr.log')).relative_to(work))}
    records.append(row)
    (ev/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
    print(label+' exit='+str(result.returncode),flush=True)
    return result.returncode
(ev/'environment.json').write_text(json.dumps({'platform':platform.platform(),'machine':platform.machine(),'python':platform.python_version(),'native_cwd':str(out),'test_cwd':str(work),'shell_login':False,'environment_overrides':{k:env[k] for k in ['PATH','TMPDIR','TMP','TEMP','TMPPREFIX','PYTHONDONTWRITEBYTECODE','XDG_CACHE_HOME','XDG_CONFIG_HOME','XDG_DATA_HOME','GIT_CEILING_DIRECTORIES']},'runtime_paths':tools,'git_available_to_tests':False,'note':'Installed runtime executables linked into scratch PATH; no source replacement, no Git commands, no owner history. Existing no-Git fixture handling applies.'},indent=2)+'\n')
run('runtime-versions',['pwsh','-NoProfile','-Command','$PSVersionTable | ConvertTo-Json -Depth 4'])
for label,args in [
 ('hash-parity',['pwsh','-NoProfile','-File','tests/review-hash-normalization.tests.ps1']),
 ('traceability-freeze',['python3','-B','tests/traceability-freeze-contract.tests.py']),
 ('downstream-parity',['bash','tests/downstream-review-precheck-parity.tests.sh']),
 ('unreadable-equivalence',['pwsh','-NoProfile','-File','specs/shared-review-launch-repair/verification/T-002/unreadable-equivalence.ps1','-Root',str(work),'-FixtureDirectory',str(out/'tmp/unreadable-equivalence')])]:
    code=run(label,args)
    if code:
        print('STOP_ON_REQUIRED_TEST_FAILURE '+label,flush=True)
        break
