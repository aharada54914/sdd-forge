import datetime, hashlib, json, os, pathlib, platform, shlex, shutil, subprocess, sys, time
O=pathlib.Path(__file__).resolve().parents[1]; W=O/'work'; T=O/'tmp'
E=W/'specs/shared-review-launch-repair/verification/T-002/native-revalidation-attempt-4'; E.mkdir(parents=True,exist_ok=True)
B=T/'bin'; B.mkdir(exist_ok=True)
commands='rtk python3 bash sh pwsh jq shasum awk sed grep find sort uniq tr cut head tail wc cat cp mv rm mkdir mktemp dirname basename realpath readlink test date perl env iconv stat cmp uname xargs dd od printf sleep touch expr chmod'.split()
resolved={}
for n in commands:
    target=shutil.which(n)
    if target:
        resolved[n]=target
        if not (B/n).exists(): (B/n).symlink_to(target)
env=os.environ.copy(); env.update(PATH=str(B), TMPDIR=str(T)+'/', TMP=str(T), TEMP=str(T), TMPPREFIX=str(T/'zsh'), PYTHONDONTWRITEBYTECODE='1', XDG_CACHE_HOME=str(T/'cache'), DOTNET_CLI_HOME=str(T/'dotnet'), POWERSHELL_TELEMETRY_OPTOUT='1')
assert shutil.which('git',path=env['PATH']) is None
for n in ['rtk','python3','bash','pwsh','jq','iconv','shasum']:
    assert n in resolved, 'missing runtime '+n
records=[]
def run(label,argv):
    command=['rtk','proxy']+argv
    started=datetime.datetime.now(datetime.timezone.utc).isoformat(); start=time.monotonic()
    result=subprocess.run(command,cwd=W,env=env,capture_output=True)
    stdout=E/(label+'.stdout.log'); stderr=E/(label+'.stderr.log'); stdout.write_bytes(result.stdout); stderr.write_bytes(result.stderr)
    row=dict(label=label,argv=command,command=shlex.join(command),cwd=str(W),native_cwd=str(O),shell_login=False,started_at=started,elapsed_seconds=time.monotonic()-start,exit_code=result.returncode,stdout_path=stdout.relative_to(W).as_posix(),stderr_path=stderr.relative_to(W).as_posix())
    records.append(row); (E/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
    print(label+': exit '+str(result.returncode),flush=True)
    print(result.stdout.decode(errors='replace'),end='',flush=True); print(result.stderr.decode(errors='replace'),end='',flush=True)
    return result.returncode
(E/'environment.json').write_text(json.dumps(dict(platform=platform.platform(),python=sys.version,executables=resolved,environment={k:env[k] for k in ['PATH','TMPDIR','TMP','TEMP','TMPPREFIX','PYTHONDONTWRITEBYTECODE','XDG_CACHE_HOME','DOTNET_CLI_HOME','POWERSHELL_TELEMETRY_OPTOUT']},git_available=False,native_cwd=str(O)),indent=2)+'\n')
run('runtime-versions',['pwsh','-NoProfile','-Command','$PSVersionTable | ConvertTo-Json -Depth 3'])
checks=[('hash-parity',['pwsh','-NoProfile','-File','tests/review-hash-normalization.tests.ps1']),('traceability-freeze',['python3','-B','tests/traceability-freeze-contract.tests.py']),('downstream-parity',['bash','tests/downstream-review-precheck-parity.tests.sh']),('unreadable-equivalence',['pwsh','-NoProfile','-File','specs/shared-review-launch-repair/verification/T-002/unreadable-equivalence.ps1','-Root',str(W),'-FixtureDirectory',str(T/'unreadable')])]
for label,argv in checks:
    if run(label,argv): raise SystemExit(1)
