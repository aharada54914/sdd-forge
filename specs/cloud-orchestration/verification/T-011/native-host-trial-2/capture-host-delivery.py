from pathlib import Path
import json,hashlib,re,shutil,datetime
root=Path('/workspace/sdd-forge');public=root/'specs/cloud-orchestration/verification/T-011/native-host-trial-2';private=root/'.git/cloud-task-private/T011-native-host-trial-2';prep=Path('/tmp/cloud-T011-native-trial-2-inputs');setup=json.loads((prep/'setup.json').read_text());fixture=setup['fixture'];base=Path(fixture['bootstrap_root']).parents[2];cache=Path('/workspace/.tools/sdd-forge-dev/codex-verify/plugins/cache/sdd-plugins')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,value):
 with (public/name).open('x') as f:json.dump(value,f,indent=2);f.write('\n')
current_sources={}
for rel,digest in setup['sha256'].items():
 parts=Path(rel).parts;name=parts[0];suffix=Path(*parts[1:]);installed=base/'installed/plugins'/rel;cached=cache/name/setup['versions'][name]/suffix
 assert sha(installed)==sha(cached)==digest,rel
 source=root/'plugins'/rel
 if len(parts)>2 and parts[1]=='runtime':
  kind=parts[2];tail=Path(*parts[3:])
  source=root/'plugins/sdd-quality-loop'/kind/tail
  if kind=='contracts' and tail.name.startswith('cloud-'):source=root/'contracts'/tail
 assert sha(source)==digest,str(source)
 current_sources[str(source.relative_to(root))]=digest
save('current-source-binding.json',current_sources)
shutil.copyfile(prep/'setup.json',public/'setup.json');shutil.copyfile('/tmp/cloud-T011-host-rubric.md',public/'caller-rubric.md');shutil.copyfile('/tmp/cloud-native-host-trial-2.py',public/'launch-host-trial.py')
results=[]
for provider in ('azure','aws'):
 identity=json.loads((public/(provider+'-identity.json')).read_text());delivery=json.loads((public/(provider+'-delivery.json')).read_text());assert delivery['turn_status']=='completed' and delivery['error'] is None
 commands=json.loads((private/(provider+'-commands.json')).read_text());records=[];executions=[]
 for execution in commands:
  out=execution.get('aggregatedOutput','')
  try:value=json.loads(out)
  except (json.JSONDecodeError,TypeError):continue
  if isinstance(value,dict) and value.get('schema')=='cloud-operation-result/v1':
   records.append({'command':execution['command'],'exit_code':execution['exitCode'],'result':value})
   executions.append({'command':execution['command'],'exit_code':execution['exitCode'],'output':out})
 if provider=='aws':
  assert not records
  grouped=[c for c in commands if 'subprocess.run' in c['command']]
  assert len(grouped)==1 and grouped[0]['exitCode']==0
  group=grouped[0];out=group['aggregatedOutput']
  for match in re.finditer(r'^COMMAND: (.+)\nEXIT_CODE: (\d+)\nSTDOUT: (\{[^\n]+\})\nSTDERR: ([^\n]*)',out,re.M):
   assert match[4]==''
   value=json.loads(match[3]);assert value['schema']=='cloud-operation-result/v1'
   records.append({'command':match[1],'exit_code':int(match[2]),'result':value})
   executions.append({'command':match[1],'exit_code':int(match[2]),'output':match[3]+'\n'})
  assert 'REQUESTS_AND_DEPLOYMENT_INPUTS_BYTE_IDENTICAL: True' in out
  save(provider+'-actual-command-group.json',{'command':group['command'],'exit_code':group['exitCode'],'output':out})
 assert len(records)==5,(provider,len(records))
 save(provider+'-executed-command.json',{'executions':executions,'classification':'Actual CLI invocation evidence; Azure uses five direct host commands and AWS uses five subprocesses from one admitted host command. All results and exit codes are parsed from real stdout. Raw native transport stays private.'})
 save(provider+'-command-audit.json',{'commands':[{'command':c['command'],'sha256':hashlib.sha256(c['command'].encode()).hexdigest(),'exit_code':c.get('exitCode'),'status':c.get('status')} for c in commands],'inspection':'Root inspected every completed command execution body. Hook-denied proposals are recorded separately and are not completed command executions. Only installed skill/reference/schema reads, local hashes, installed CLI calls and local evidence capture; no provider API, credentials, governed wrapper or product modification. Denied attempts do not count as executed CLI checks.'})
 hooks=json.loads((public/(provider+'-hook-executions.json')).read_text())
 assert hooks and all(h['source']=='plugin' and h['handlerType']=='command' for h in hooks)
 assert any('sdd-quality-loop' in h['sourcePath'] for h in hooks)
 shutil.copyfile(prep/(provider+'-prompt.txt'),public/(provider+'-prompt.txt'))
 shutil.copyfile(private/(provider+'-final.txt'),public/(provider+'-final.txt'))
 request=next(x for x in fixture['fixtures'] if x['provider']==provider and x['variant']=='supported');rhash=request['request_sha256']
 for index,(record,expected_code,expected_state,expected_error) in enumerate(zip(records,[0,0,2,2,2],['ROUTED','ROUTED','BLOCKED','BLOCKED','BLOCKED'],[None,None,'OPERATION_UNIMPLEMENTED','OPERATION_UNIMPLEMENTED','OWNER_CONFLICT'])):
  value=record['result'];assert record['exit_code']==expected_code and value['state']==expected_state and value['error_code']==expected_error
  assert value['input_manifest_sha256']==rhash and value['provider']==provider and value['schema']=='cloud-operation-result/v1' and 'native_operation_id' not in value
  assert value['operation']==(['route','route','prepare','apply','route'][index])
 assert {k:v for k,v in records[0]['result'].items() if k!='evidence_manifest_path'}=={k:v for k,v in records[1]['result'].items() if k!='evidence_manifest_path'}
 for f in (x for x in fixture['fixtures'] if x['provider']==provider):
  workspace=Path(f['workspace']);assert sha(workspace/'request.json')==f['request_sha256']
  dest=public/'artifacts'/(provider+'-'+f['variant']);dest.mkdir(parents=True)
  shutil.copyfile(workspace/'request.json',dest/'request.json')
  for artifact in (workspace/f['evidence_directory']).iterdir():
   if artifact.is_file():shutil.copyfile(artifact,dest/artifact.name)
  captured = [];host_captured=[]
  named = list(zip(['bootstrap-route.json','direct-route.json','direct-prepare.json','direct-apply.json'],records[:4],executions[:4])) if f['variant']=='supported' else [('mixed-route.json',records[4],executions[4])]
  for filename, record, execution in named:
   if not (dest/filename).exists():
    assert record['exit_code']==2 and record['result']['evidence_manifest_path'] is None
    (dest/filename).write_text(execution['output'])
    captured.append(filename)
   elif record['exit_code']==2:
    assert (dest/filename).read_text()==execution['output']
    host_captured.append(filename)
  (dest/'capture-provenance.json').write_text(json.dumps({'root_captured_exact_cli_stdout':captured,'native_model_captured_exact_cli_stdout':host_captured,'provider_published_files':[p.name for p in (workspace/f['evidence_directory']).iterdir() if p.is_file() and p.name not in host_captured],'qualification':'Blocked CLI results do not publish provider evidence. Missing requested files are captured here by the root caller from exact native command stdout; never attributed to provider publication.'},indent=2)+'\n')
  if f['variant']=='supported':
   a=json.loads((dest/'bootstrap-route.json.manifest.json').read_text());b=json.loads((dest/'direct-route.json.manifest.json').read_text());assert a==b and a['classification']=='local' and a['cloud_validated'] is False
   for name,record in zip(['bootstrap-route.json','direct-route.json','direct-prepare.json','direct-apply.json'],records[:4]):assert json.loads((dest/name).read_text())==record['result']
  else:assert json.loads((dest/'mixed-route.json').read_text())==records[4]['result']
 results.append({'provider':provider,'run_id':identity['thread_id'],'model':identity['model'],'observed':records,'requests_unchanged':True,'route_manifest_parity':True,'result':'PASS','scope':'Actual native host invoking installed local CLI on synthetic fixture; no live cloud acceptance. Denial files are caller-captured exact CLI stdout, not provider-published evidence.'})
save('acceptance.json',{'verified_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'result':'PASS','cases':results,'source_bindings':len(current_sources),'native_identity_distinct':results[0]['run_id']!=results[1]['run_id'],'limitation':'One actual native trial per provider; no statistical comparison. Windows/macOS and live cloud acceptance remain separate.'})
profile=Path('/workspace/.tools/sdd-forge-dev/codex-verify');backup=root/'.git/cloud-task-private/T011-host-profile-backup-2'
def fingerprints(p):return {str(x.relative_to(p)):('symlink:'+str(x.readlink())) if x.is_symlink() else sha(x) for x in p.rglob('*') if x.is_file() or x.is_symlink()}
before=fingerprints(backup/'plugins');shutil.rmtree(profile/'plugins');shutil.copytree(backup/'plugins',profile/'plugins',symlinks=True);shutil.copy2(backup/'config.toml',profile/'config.toml');assert fingerprints(profile/'plugins')==before and sha(profile/'config.toml')==sha(backup/'config.toml')
save('profile-restoration.json',{'restored_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'profile':str(profile),'config_sha256':sha(profile/'config.toml'),'plugin_files':len(before),'exact_backup_restored':True,'native_history':'Retained; no history or unrelated profile restored/deleted.'})
assets={str(p.relative_to(public)):sha(p) for p in public.rglob('*') if p.is_file()};save('asset-hashes.json',assets)
print(json.dumps({'result':'PASS','native_cases':2,'cli_invocations':10,'artifacts':len(assets),'source_files':len(current_sources),'verify_profile_restored':True}))
