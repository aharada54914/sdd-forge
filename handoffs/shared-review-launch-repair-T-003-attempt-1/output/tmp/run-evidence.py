import json,os,pathlib,subprocess,sys,time
out=pathlib.Path(__file__).resolve().parents[1]
ev=out/'work/specs/shared-review-launch-repair/verification/T-003'
name=sys.argv[1]; argv=['rtk','proxy',*sys.argv[2:]]
env={**os.environ,'TMPDIR':str(out/'tmp'),'TMP':str(out/'tmp'),'TEMP':str(out/'tmp'),'PYTHONDONTWRITEBYTECODE':'1'}
p=subprocess.run(argv,cwd=out,capture_output=True,text=True,env=env)
r={'command':argv,'cwd':str(out),'environment_overrides':{k:env[k] for k in ('TMPDIR','TMP','TEMP','PYTHONDONTWRITEBYTECODE')},'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr}
(ev/(name+'.json')).write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
sys.exit(p.returncode)
