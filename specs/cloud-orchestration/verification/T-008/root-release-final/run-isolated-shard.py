from pathlib import Path
import subprocess,sys,json,os,datetime,hashlib
root=Path('/workspace/sdd-forge');revision,profile,idx,basearg=sys.argv[1:];base=Path(basearg);name=profile+'-'+idx;clone=base/name;logpath=base/(name+'.log');receipt=base/(name+'.receipt.json');base.mkdir(parents=True,exist_ok=True)
assert not clone.exists() and not logpath.exists();log=logpath.open('x')
def run(argv,cwd=root):
 print(json.dumps(argv),file=log,flush=True);p=subprocess.run(argv,cwd=cwd,stdout=log,stderr=subprocess.STDOUT);assert p.returncode==0,(argv,p.returncode)
run(['git','clone','--shared','--no-checkout',str(root),str(clone)])
run(['git','checkout','--detach',revision],clone)
main_ref='fcb8275a42061b8132ea88a36e69b02f4487be71'
assert subprocess.check_output(['git','rev-parse','refs/remotes/origin/main'],cwd=root,text=True).strip()==main_ref
run(['git','merge-base','--is-ancestor',main_ref,revision],clone)
run(['git','update-ref','refs/remotes/origin/main',main_ref],clone)
assert subprocess.check_output(['git','rev-parse','origin/main'],cwd=clone,text=True).strip()==main_ref
run(['/workspace/.tools/sdd-forge-dev/bin/pwsh','-NoProfile','-File','tests/cross-runtime-handoff.tests.ps1','-SelfTestActivation'],clone)
for package in ('sdd-forge-mcp','ci-mcp','local-env-mcp'):run(['npm','ci','--prefix','mcp/'+package,'--ignore-scripts','--no-audit','--no-fund'],clone)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=clone,text=True).strip()==revision
assert not subprocess.check_output(['git','status','--porcelain'],cwd=clone,text=True)
cmd=['python3','-B','tests/verification.py','--profile',profile,'--run','--shard-count','4','--shard-index',idx,'--receipt',str(receipt),'--powershell','/workspace/.tools/sdd-forge-dev/bin/pwsh']
print(json.dumps(cmd),file=log,flush=True);start=datetime.datetime.now(datetime.timezone.utc).isoformat();p=subprocess.run(cmd,cwd=clone,stdout=log,stderr=subprocess.STDOUT);end=datetime.datetime.now(datetime.timezone.utc).isoformat();log.close()
data=json.loads(receipt.read_text()) if receipt.exists() else None
result=dict(main_ref=main_ref,main_ref_after=subprocess.check_output(['git','rev-parse','origin/main'],cwd=clone,text=True).strip(),revision=revision,profile=profile,shard_index=int(idx),shard_count=4,clone=str(clone),started_at=start,finished_at=end,exit_code=p.returncode,receipt=str(receipt),log=str(logpath),receipt_sha256=hashlib.sha256(receipt.read_bytes()).hexdigest() if receipt.exists() else None,source_status=subprocess.check_output(['git','status','--porcelain'],cwd=clone,text=True))
(base/(name+'.result.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));sys.exit(p.returncode)
