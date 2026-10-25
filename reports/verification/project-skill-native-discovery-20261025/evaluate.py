import hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
BASE=Path('/workspace/.tools/sdd-forge-dev');ROOT=Path('/workspace/sdd-forge');OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE));from codex_rpc import CodexRpc
VERIFY=BASE/'verification-workspace';name='inspect-issue-602-fixture'
before=sorted(p.name for p in VERIFY.iterdir())
workspace=Path(tempfile.mkdtemp(prefix='issue-602-discovery-',dir=VERIFY))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
product=ROOT/'plugins/sdd-bootstrap/scripts/project-skill.py'
result=dict(schema='independent-project-skill-native-discovery/v1',host='Codex',profile='verify',model_invocation='not-run',authentication_scope='No account or model requests made. Prior explicit startup auth result was reauthentication_required; auth-sync current is not a model-access check.',source_sha256={str(p.relative_to(ROOT)):sha(p) for p in [product,ROOT/'plugins/sdd-quality-loop/scripts/validate-project-skill.py']},helper_sha256=sha(BASE/'codex_rpc.py'),rpc_methods=[],commands=[])
def discover(cwd,label):
 with (OUT/(label+'-app-server.log')).open('w') as log:
  with CodexRpc(dict(os.environ),stderr=log) as rpc:
   result['rpc_methods'].append('initialize')
   init=rpc.request('initialize',dict(clientInfo=dict(name='issue-602-native-discovery',version='1.0.0'),capabilities=dict(experimentalApi=True)))
   assert Path(init['codexHome'])==BASE/'codex-verify',init
   result['rpc_methods'].append('skills/list')
   packet=rpc.request('skills/list',{'cwds':[str(cwd)]})
  assert rpc.process.poll() is not None
 (OUT/(label+'-skills.json')).write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n')
 return packet['data'][0]
try:
 skill=workspace/'sdd/skills'/name;skill.mkdir(parents=True)
 (workspace/'notes.txt').write_text('Synthetic read-only project discovery fixture.\n')
 (skill/'SKILL.md').write_text('---\nname: '+name+'\ndescription: Read the synthetic project note without changing files.\n---\nRead notes.txt and describe its contents. This custom skill permits reading only; do not modify files, invoke network services, or interpret discovery as verification PASS.\n')
 (skill/'run.py').write_text('from pathlib import Path\nprint(Path("notes.txt").read_text())\n')
 for args in [['seal','--root',str(workspace),'--name',name,'--runtime','python3','--entry','run.py','--check','read-note'],['project','--root',str(workspace),'--name',name,'--host','codex']]:
  done=subprocess.run([sys.executable,str(product),*args],capture_output=True,text=True,timeout=30)
  result['commands'].append(dict(operation=args[0],exit_code=done.returncode,stdout=done.stdout,stderr=done.stderr))
  assert done.returncode==0,done.stderr
 wrapper=workspace/'.agents/skills'/name/'SKILL.md'
 result['wrapper_sha256']=sha(wrapper)
 for relative in ['sdd/skills/'+name+'/SKILL.md','sdd/skills/'+name+'/skill-manifest.json','.agents/skills/'+name+'/SKILL.md','sdd/skill-projections.json']:
  target=OUT/'generated'/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(workspace/relative,target)
 old=Path.cwd();os.chdir(workspace)
 try: packet=discover(workspace,'generated')
 finally:os.chdir(old)
 assert not packet.get('errors'),packet.get('errors')
 matches=[s for s in packet['skills'] if s.get('name')==name]
 assert len(matches)==1,matches
 result['discovered_skill']=matches[0]
 result['native_discovery']='passed'
 result['runner_or_model_execution']='not-run: projection and host discovery only'
finally:
 shutil.rmtree(workspace)
 result['fixture_removed']=not workspace.exists()
 result['workspace_entries_restored']=sorted(p.name for p in VERIFY.iterdir())==before
 cleaned=discover(VERIFY,'cleaned')
 result['skill_absent_after_cleanup']=not any(s.get('name')==name for s in cleaned['skills'])
 assert result['fixture_removed'] and result['workspace_entries_restored'] and result['skill_absent_after_cleanup']
 result['codex_version']=subprocess.check_output(['codex','--version'],text=True).strip()
 result['source_hashes_unchanged']=all(sha(ROOT/relative)==value for relative,value in result['source_sha256'].items())
 (OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['native_discovery','fixture_removed','workspace_entries_restored','skill_absent_after_cleanup','codex_version']}))
