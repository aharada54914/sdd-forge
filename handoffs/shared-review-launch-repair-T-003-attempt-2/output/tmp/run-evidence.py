import json, os, pathlib, subprocess, sys, time
out=pathlib.Path(__file__).resolve().parents[1]
work=out/'work'
ev=work/'specs/shared-review-launch-repair/verification/T-003'
name=sys.argv[1]
cmd=['rtk','proxy',*sys.argv[2:]]
env={**os.environ,'TMPDIR':str(out/'tmp'),'TMP':str(out/'tmp'),'TEMP':str(out/'tmp'),'PYTHONDONTWRITEBYTECODE':'1','XDG_CACHE_HOME':str(out/'tmp/cache'),'DOTNET_CLI_HOME':str(out/'tmp/dotnet')}
start=time.time()
r=subprocess.run(cmd,cwd=out,env=env,capture_output=True,text=True)
record={'argv':cmd,'cwd':str(out),'environment_overrides':{k:env[k] for k in ('TMPDIR','TMP','TEMP','PYTHONDONTWRITEBYTECODE','XDG_CACHE_HOME','DOTNET_CLI_HOME')},'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr,'elapsed_seconds':time.time()-start}
(ev/(name+'.json')).write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
sys.exit(r.returncode)
