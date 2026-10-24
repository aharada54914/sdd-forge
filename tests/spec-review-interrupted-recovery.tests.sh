#!/usr/bin/env bash
# Disposable synthetic source fixtures; never read a working repository ledger.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
python3 - "$ROOT" bash ${1+"$@"} <<'PY'
import copy, hashlib, json, os, pathlib, re, shlex, shutil, subprocess, sys, tempfile
ROOT=pathlib.Path(sys.argv[1]); RUNTIME=sys.argv[2]
PWSH=os.environ.get('SDD_TEST_PWSH','pwsh')
FEATURE='synthetic-a9-recovery'
SOURCE=f'reports/spec-review/{FEATURE}/attempt-3/round-3'
PRIOR=f'reports/spec-review/{FEATURE}/attempt-3/round-2'
INV=f'reports/review-context/{FEATURE}-spec-a3r3-a-invocation.json'
LEDGER='reports/review-context/identity-ledger.json'
CAL='plugins/sdd-review-loop/references/spec-review-calibration.md'
AUTH=f'specs/{FEATURE}/synthetic-authorization.md'
RECORD=f'specs/{FEATURE}/synthetic-recovery.json'

def sha(data): return hashlib.sha256(data).hexdigest()
def digest(p): return sha(p.read_bytes())
def canonical(value): return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()
def put(root,path,data):
 p=root/path;p.parent.mkdir(parents=True,exist_ok=True)
 p.write_bytes(data.encode() if isinstance(data,str) else data)
def dump(root,path,value): put(root,path,json.dumps(value,indent=2)+'\n')
def load(root,path): return json.loads((root/path).read_text())
def ref(root,path): return {'path':path,'sha256':digest(root/path)}
def snapshot(root):
 return [(str(p.relative_to(root)), 'link:'+os.readlink(p) if p.is_symlink() else digest(p)) for p in sorted(root.rglob('*')) if p.is_file() or p.is_symlink()]
def chain_record(seq,stage,role,run,session,previous,binding=None):
 record=dict(sequence=seq,stage=stage,role=role,run_id=run,host_session_id=session,previous_record_sha256=previous)
 payload=f'{seq}|{stage}|{role}|{run}|{session}|{previous}'
 if binding is not None: record['allowed_inputs_sha256']=binding;payload+='|allowed-inputs-v1|'+binding
 record['record_sha256']=sha(payload.encode());return record

def fixture(root):
 for ext in ("sh","ps1"):
  path=f"plugins/sdd-quality-loop/scripts/validate-review-context-set.{ext}"
  put(root,path,(ROOT/path).read_bytes())
 for name in ('requirements.md','acceptance-tests.md','investigation.md'):
  put(root,f'specs/{FEATURE}/{name}',('Spec-Review-Status: Pending\n' if name=='requirements.md' else '')+'Synthetic disposable fixture.\n')
 put(root,CAL,(ROOT/CAL).read_bytes())
 pins=sorted([ref(root,f'specs/{FEATURE}/{n}') for n in ('requirements.md','acceptance-tests.md','investigation.md')]+[ref(root,CAL)],key=lambda r:r['path'])
 hashes={pathlib.PurePosixPath(p['path']).name:p['sha256'] for p in pins}
 pre=dict(schema='spec-review-precheck/v1',stage='spec',feature=FEATURE,attempt=3,round=2,spec_review_status_field='Pending',requirements_sha256=hashes['requirements.md'],acceptance_sha256=hashes['acceptance-tests.md'],investigation_sha256=hashes['investigation.md'],calibration_sha256=hashes['spec-review-calibration.md'],input_sha256=sha(':'.join(hashes[n] for n in ('requirements.md','acceptance-tests.md','investigation.md')).encode()),edit_summary='Synthetic prior correction',reset=False,generated_at='2026-10-24T00:00:00Z')
 dump(root,PRIOR+'/precheck-result.json',pre)
 ids_a=['REQ-TESTABILITY','GOAL-AC-TRACE','AC-OBSERVABLE','SCOPE-BOUNDARY','CONSTRAINTS-EXPLICIT','RISK-VALIDATION-SURFACE','DOMAIN-CONFORMANCE']
 ids_b=['AMBIGUITY','CONTRADICTION','EDGE-CASE-COVERAGE','ASSUMPTIONS-RESOLVABLE','APPROVAL-BOUNDARY','DOWNSTREAM-READINESS','DOMAIN-CONFORMANCE']
 checks=[dict(id=id,result='FAIL' if i==0 else 'PASS',severity='Major' if i==0 else 'Minor',finding='Synthetic finding' if i==0 else 'Synthetic pass') for i,id in enumerate(ids_a)]
 summary=dict(schema='integrated-summary/v1',attempt=3,round=2,reviewer_a_checks=[{k:c[k] for k in ('id','result','severity')} for c in checks],reviewer_a_fail_count=1,reviewer_a_pass_count=6,reviewer_a_skip_count=0,generated_at='2026-10-24T00:00:00Z')
 dump(root,PRIOR+'/integrated-summary.json',summary)
 manifests=[sorted(pins+[ref(root,PRIOR+'/precheck-result.json')],key=lambda x:x['path'])]
 manifests.append(sorted(manifests[0]+[ref(root,PRIOR+'/integrated-summary.json')],key=lambda x:x['path']))
 reviewers=[]
 for i,role in enumerate(('a','b')):
  identity=dict(role='spec-reviewer-'+role,run_id='synthetic-prior-'+role,host_session_id='synthetic-prior-session-'+role,allowed_input_manifest=manifests[i]);reviewers.append(identity)
  dump(root,PRIOR+'/reviewer-'+role+'.json',dict(schema='spec-reviewer-'+role+'/v1',stage='spec',**identity,verdict='NEEDS_WORK' if i==0 else 'PASS',checks=checks if i==0 else [dict(id=id,result='PASS',severity='Minor',finding='Synthetic pass') for id in ids_b]))
 dump(root,PRIOR+'/integrated-verdict.json',dict(schema='spec-review-integrated-verdict/v1',stage='spec',feature=FEATURE,attempt=3,round=2,reviewer_a_run_id=reviewers[0]['run_id'],reviewer_b_run_id=reviewers[1]['run_id'],reviewer_a_host_session_id=reviewers[0]['host_session_id'],reviewer_b_host_session_id=reviewers[1]['host_session_id'],finding_counts=dict(critical=0,major=1,minor=0),verdict='NEEDS_WORK',warningCount=0))
 dump(root,PRIOR+'/spec-review-contract.json',dict(schema='spec-review-contract/v1',stage='spec',feature=FEATURE,attempt=3,round=2,requirements_sha256=pre['requirements_sha256'],acceptance_sha256=pre['acceptance_sha256'],investigation_sha256=pre['investigation_sha256'],reviewers=reviewers,run_id='synthetic-prior-orchestrator',verdict='NEEDS_WORK',warningCount=0))
 investigation_path=f'specs/{FEATURE}/investigation.md'
 put(root,investigation_path,(root/investigation_path).read_bytes()+b'Synthetic correction after NEEDS_WORK.\n')
 pins=sorted([ref(root,f'specs/{FEATURE}/{name}') for name in ('requirements.md','acceptance-tests.md','investigation.md')]+[ref(root,CAL)],key=lambda pin:pin['path'])
 pre['investigation_sha256']=digest(root/investigation_path)
 pre['input_sha256']=sha(':'.join(pre[key] for key in ('requirements_sha256','acceptance_sha256','investigation_sha256')).encode())
 pre['round']=3;pre['edit_summary']='Synthetic source correction';dump(root,SOURCE+'/precheck-result.json',pre)
 genesis=chain_record(1,'host','orchestrator','synthetic-host','synthetic-host-session','')
 dump(root,LEDGER,dict(schema='review-identity-ledger/v1',records=[genesis]))
 inputs=sorted(pins+[ref(root,SOURCE+'/precheck-result.json')],key=lambda p:p['path'])
 invocation=dict(schema='review-context-invocation/v2',input_mode='file-manifest',fallback_mode='none',read_only=True,stage='spec',role='spec-reviewer-a',feature=FEATURE,run_id='synthetic-interrupted-a',host_session_id='synthetic-interrupted-session-a',sequence=2,identity_ledger_path=LEDGER,identity_ledger_sha256=digest(root/LEDGER),previous_record_sha256=genesis['record_sha256'],allowed_input_manifest=inputs)
 dump(root,INV,invocation)
 binding=sha('\n'.join(p['path']+'\t'+p['sha256'] for p in inputs).encode())
 reserved=chain_record(2,'spec','spec-reviewer-a',invocation['run_id'],invocation['host_session_id'],genesis['record_sha256'],binding)
 dump(root,LEDGER,dict(schema='review-identity-ledger/v1',records=[genesis,reserved]))
 put(root,SOURCE+'/reviewer-a-reservation.txt',f"REVIEW_CONTEXT_OK {reserved['record_sha256']} sequence=2 previous_record_sha256={genesis['record_sha256']} pre_append_tip_sequence=1 identity_unique=yes\n")
 dump(root,SOURCE+'/reviewer-a-host-receipt.json',dict(host='Synthetic disposable host',rpc='thread/start',threadId=invocation['host_session_id'],sessionId=invocation['host_session_id'],review_execution_started=False))
 dump(root,SOURCE+'/reviewer-a.json',dict(schema='spec-reviewer-a/v1',stage='spec',role='spec-reviewer-a',run_id=invocation['run_id'],host_session_id=invocation['host_session_id'],allowed_input_manifest=inputs,verdict='BLOCKED',checks=[dict(id=id,result='SKIP' if id=='DOMAIN-CONFORMANCE' else 'FAIL',severity='Major',finding='Explicit skip condition supplied: the domain directory is absent.' if id=='DOMAIN-CONFORMANCE' else 'Review blocked before substantive reading because manifest hash verification was denied.') for id in ids_a]))
 put(root,SOURCE+'/spec-review-report.md','# Synthetic interruption diagnostic\n\nExecution: BLOCKED before substantive review\n\nReviewer B was not launched following the launch-boundary stop.\n')
 inventory=sorted([ref(root,SOURCE+'/'+n) for n in ('precheck-result.json','reviewer-a.json','reviewer-a-reservation.txt','reviewer-a-host-receipt.json','spec-review-report.md')]+[ref(root,INV)],key=lambda x:x['path'])
 record=dict(schema='spec-review-interrupted-recovery/v1',feature=FEATURE,source=dict(attempt=3,round=3),target=dict(attempt=4,round=1),authorization=dict(path=AUTH,sha256='0'*64),previous_contract=ref(root,PRIOR+'/spec-review-contract.json'),interrupted_precheck=ref(root,SOURCE+'/precheck-result.json'),pinned_inputs=pins,interrupted_artifacts=inventory,reviewer_a=dict(invocation=ref(root,INV),sequence=2,stage='spec',role='spec-reviewer-a',run_id=invocation['run_id'],host_session_id=invocation['host_session_id'],record_sha256=reserved['record_sha256']))
 authorize(root,record);return record

def authorize(root,record):
 body={k:v for k,v in record.items() if k!='authorization'}
 put(root,AUTH,'# Fictional synthetic authorization; never human-origin proof.\n\n'+f'Feature: {FEATURE}\nSource Attempt: 3\nSource Round: 3\nTarget Attempt: 4\nTarget Round: 1\nMaximum Rounds: 3\nDecision: Authorize interrupted A-before-B recovery\nRecovery Binding SHA256: {sha(canonical(body))}\n')
 record['authorization']=ref(root,AUTH);dump(root,RECORD,record)

def functions_bash():
 source=(ROOT/'plugins/sdd-review-loop/scripts/spec-review-precheck.sh').read_text()
 # Only top-level function declarations are evaluated, never CLI/publication code.
 functions=re.findall(r'^[a-zA-Z_][a-zA-Z_0-9]*\(\) \{[^\n]*\}\s*$|^[a-zA-Z_][a-zA-Z_0-9]*\(\) \{\n.*?^\}',source,re.M|re.S)
 relative=re.search(r"^jq_relative_path='.*?^.*?;'",source,re.M|re.S)
 assert relative,'production manifest normalization definition is missing'
 return '\n'.join(functions)+'\n'+relative.group(0)+'\n'

def drivers(scratch):
 bash=scratch/'admission-driver.sh'
 bash.write_text('set -euo pipefail\n'+functions_bash()+r'''
repo_root=$1; repo_root_alias=$1; feature=$2; attempt=4; round=1
spec_dir="$repo_root/specs/$feature"
requirements="$spec_dir/requirements.md"; acceptance="$spec_dir/acceptance-tests.md"
investigation="$spec_dir/investigation.md"
calibration="$repo_root/plugins/sdd-review-loop/references/spec-review-calibration.md"
report_root="$repo_root/reports/spec-review/$feature"
if [[ $3 == prior ]]; then
  validate_contract "$report_root/attempt-3/round-2/spec-review-contract.json" 3 2 NEEDS_WORK "$report_root/attempt-3/round-2/precheck-result.json"
else
  declare -F validate_interrupted_recovery >/dev/null || { echo 'ADMISSION_NOT_IMPLEMENTED' >&2; exit 90; }
  validate_interrupted_recovery "$spec_dir/synthetic-recovery.json"
fi
''')
 ps=scratch/'admission-driver.ps1'
 ps.write_text(r'''param([string]$Repository,[string]$Feature,[string]$Mode,[string]$Source)
$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($Source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Cannot parse production precheck'}
foreach($node in $ast.EndBlock.Statements){
 if($node -is [Management.Automation.Language.FunctionDefinitionAst]){. ([scriptblock]::Create($node.Extent.Text))}
}
$root=$Repository;$specDir=Join-Path $root "specs/$Feature"
$requirements=Join-Path $specDir 'requirements.md';$acceptance=Join-Path $specDir 'acceptance-tests.md'
$investigation=Join-Path $specDir 'investigation.md'
$calibration=Join-Path $root 'plugins/sdd-review-loop/references/spec-review-calibration.md'
$reportRoot=Join-Path $root "reports/spec-review/$Feature";$attemptInt=4;$roundInt=1
if($Mode -ceq 'prior'){
 if(-not(Test-ValidateContract "$reportRoot/attempt-3/round-2/spec-review-contract.json" 3 2 NEEDS_WORK "$reportRoot/attempt-3/round-2/precheck-result.json")){exit 1}
}else{
 if(-not(Get-Command Test-InterruptedRecovery -ErrorAction SilentlyContinue)){[Console]::Error.WriteLine('ADMISSION_NOT_IMPLEMENTED');exit 90}
 if(-not(Test-InterruptedRecovery "$specDir/synthetic-recovery.json")){exit 1}
}
''')
 return bash,ps

def run_child(root,cmd):
 if RUNTIME=='bash' or os.name=='nt':
  return subprocess.run(cmd,capture_output=True,text=True)
 # Parallel pwsh startup profiles share mutable cache files (PowerShell#26528).
 with tempfile.TemporaryDirectory(prefix='pwsh-cache-',dir=root.parent) as cache:
  env=os.environ.copy();env['XDG_CACHE_HOME']=cache
  return subprocess.run(cmd,capture_output=True,text=True,env=env)

def run_driver(root,mode,paths):
 if RUNTIME=='bash':cmd=['bash',str(paths[0]),str(root),FEATURE,mode]
 else:cmd=[PWSH,'-NoLogo','-NoProfile','-File',str(paths[1]),str(root),FEATURE,mode,str(ROOT/'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1')]
 return run_child(root,cmd)

def run_identity(root):
 base=ROOT/'plugins/sdd-quality-loop/scripts'
 cmd=['bash',str(base/'validate-review-context-set.sh'),str(root/INV),str(root)] if RUNTIME=='bash' else [PWSH,'-NoLogo','-NoProfile','-File',str(base/'validate-review-context-set.ps1'),'-Manifest',str(root/INV),'-RepositoryRoot',str(root)]
 return run_child(root,cmd)


def at(value,path):
 for part in path:value=value[part]
 return value

def mutations(record):
 cases=[]
 def add(name,edit,reauthorize=True,accept=False):cases.append((name,edit,reauthorize,accept))
 def setfield(path,value):return lambda root,rec:at(rec,path[:-1]).__setitem__(path[-1],value)
 def delete(path):return lambda root,rec:at(rec,path[:-1]).__delitem__(path[-1])
 fields=[('schema',),('feature',),('source',),('source','attempt'),('source','round'),('target',),('target','attempt'),('target','round'),('authorization',),('previous_contract',),('interrupted_precheck',),('pinned_inputs',),('interrupted_artifacts',),('reviewer_a',),('reviewer_a','invocation'),('reviewer_a','sequence'),('reviewer_a','stage'),('reviewer_a','role'),('reviewer_a','run_id'),('reviewer_a','host_session_id'),('reviewer_a','record_sha256')]
 references=[('authorization',),('previous_contract',),('interrupted_precheck',)]
 for filename in ('requirements.md','acceptance-tests.md','investigation.md','spec-review-calibration.md'):
  references.append(('pinned_inputs',next(i for i,pin in enumerate(record['pinned_inputs']) if pin['path'].endswith('/'+filename))))
 for filename in ('precheck-result.json','reviewer-a.json','reviewer-a-reservation.txt','reviewer-a-host-receipt.json','spec-review-report.md',pathlib.PurePosixPath(INV).name):
  references.append(('interrupted_artifacts',next(i for i,pin in enumerate(record['interrupted_artifacts']) if pin['path'].endswith('/'+filename))))
 references.append(('reviewer_a','invocation'))
 for index,path in enumerate(fields,1):
  label='.'.join(map(str,path));current=at(record,path)
  add(f'TEST-050-F{index:02}::{label}::missing',delete(path),False)
  values=[('null',None)]
  if type(current)is int:values += [('string',str(current)),('boolean',True),('fractional',current+.5)]
  elif type(current)is dict:values += [('array',[])]
  elif type(current)is list:values += [('object',{})]
  for name,value in values:add(f'TEST-051-F{index:02}::{label}::{name}',setfield(path,value),False)
  if type(current)is str:
   for name,value in [('boolean-true',True),('array-value',[current]),('object-value',{'value':current}),('number',1)]:
    add(f'TEST-051-F{index:02}::{label}::{name}',setfield(path,value))
 for index,path in enumerate(references,1):
  for field in ('path','sha256'):
   add(f'TEST-050::reference-{index:02}.{field}::missing',delete(path+(field,)),False)
   add(f'TEST-051::reference-{index:02}.{field}::null',setfield(path+(field,),None),False)
  for name,value in [('null',None),('uppercase','A'*64),('nonhex','g'*64),('short','a'*63),('incorrect','0'*64)]:
   add(f'TEST-057-H{index:02}::{name}',setfield(path+('sha256',),value),index!=1)
  add(f'TEST-057-H{index:02}::missing',delete(path+('sha256',)),index!=1)
  for name,value in [('empty',''),('absolute','/tmp/synthetic'),('drive','C:/synthetic'),('traversal','../synthetic'),('dot','./synthetic'),('empty-segment','synthetic//file'),('backslash','synthetic\\file'),('tab','synthetic\tfile'),('newline','synthetic\nfile'),('nul','synthetic\0file'),('control','synthetic\x1ffile'),('del','synthetic\x7ffile')]:
   add(f'TEST-083-P{index:02}::{name}',setfield(path+('path',),value),index!=1)
 for name,value in [('uppercase','A'*64),('nonhex','g'*64),('short','a'*63)]:
  add('TEST-057::reviewer_a.record_sha256::'+name,setfield(('reviewer_a','record_sha256'),value))
 # Every closed object, including every distinct reference occurrence.
 objects=[(),('source',),('target',),('reviewer_a',)]+references
 for path in objects:
  label='.'.join(map(str,path)) or 'root';key=next(iter(at(record,path)))
  add('TEST-052::'+label+'::unknown',setfield(path+('unexpected',),True),False)
  def case_key(root,rec,path=path,key=key):
   obj=at(rec,path);obj[key.upper()]=obj.pop(key)
  add('TEST-055::'+label+'::uppercase-key',case_key,False)
  # Serialize a selected object with one duplicate member; tokens preserve nested location.
  for escaped in (False,True):
   def duplicate(root,rec,path=path,key=key,escaped=escaped):
    target=at(rec,path);token='SYNTHETIC_DUPLICATE_OBJECT'
    if path: at(rec,path[:-1])[path[-1]]=token
    else: rec.clear();rec[token]=True
    key_literal=json.dumps(key)
    if escaped:key_literal='"\\u%04x%s"'%(ord(key[0]),key[1:])
    obj=json.dumps(target) if path else json.dumps(record)
    replacement=obj[:-1]+','+key_literal+':'+json.dumps(target.get(key,record.get(key)))+'}'
    raw=json.dumps(rec).replace(json.dumps(token),replacement) if path else replacement
    put(root,RECORD,raw);return 'raw'
   add('TEST-053::'+label+('::escaped-duplicate' if escaped else '::duplicate'),duplicate,False)
 for test,path,value in [('044',('schema',),'wrong/v1'),('054',('schema',),'SPEC-review-interrupted-recovery/v1'),('045',('feature',),'other-feature'),('046',('source','attempt'),2),('047',('source','round'),2),('048',('target','attempt'),5),('049',('target','round'),2),('009',('source','attempt'),2),('010',('target','attempt'),5),('011',('target','round'),2)]:
  add('TEST-'+test+'::value',setfield(path,value))

 for encoding in ('utf-16','utf-16-be','utf-8-sig'):
  def record_encoding(root,rec,encoding=encoding):
   raw=json.dumps(rec).encode(encoding)
   if encoding=='utf-16-be':raw=b'\xfe\xff'+raw
   put(root,RECORD,raw);return 'raw'
  add('TEST-056::record-encoding::'+encoding,record_encoding,False)
 def authorization_utf16(root,rec):
  put(root,AUTH,(root/AUTH).read_text().encode('utf-16'));rec['authorization']=ref(root,AUTH)
 add('TEST-035::authorization-UTF16',authorization_utf16,False)
 def corrupt(root,rec):put(root,RECORD,'{ malformed');return 'raw'
 add('TEST-056::malformed',corrupt,False)
 def status(value):
  def edit(root,rec):put(root,f'specs/{FEATURE}/requirements.md',value+'\nSynthetic disposable fixture.\n')
  return edit
 for test,value in [('012','Spec-Review-Status: Passed'),('013',''),('014','Spec-Review-Status: Unknown'),('015','Spec-Review-Status: pending')]:add('TEST-'+test+'::status',status(value),False)
 for test,path in [('058',f'specs/{FEATURE}/requirements.md'),('059',f'specs/{FEATURE}/acceptance-tests.md'),('060',f'specs/{FEATURE}/investigation.md'),('061',CAL)]:
  add('TEST-'+test+'::changed-live',lambda root,rec,path=path:put(root,path,(root/path).read_bytes()+b'changed\n'),False)
 # Re-pin the mutated sibling so semantic tests cannot pass solely on outer hash rejection.
 def change_file(path,key,value):
  def edit(root,rec):
   obj=load(root,path);obj[key]=value;dump(root,path,obj)
   for pin in rec['interrupted_artifacts']+[rec['previous_contract'],rec['interrupted_precheck'],rec['reviewer_a']['invocation']]:
    if pin['path']==path:pin['sha256']=digest(root/path)
  return edit
 for test,path,key,value in [('017',PRIOR+'/spec-review-contract.json','schema','wrong'),('018',PRIOR+'/spec-review-contract.json','verdict','PASS'),('019',PRIOR+'/spec-review-contract.json','verdict','BLOCKED'),('021',PRIOR+'/integrated-summary.json','reviewer_a_fail_count',0),('023',PRIOR+'/integrated-verdict.json','verdict','PASS'),('033',SOURCE+'/reviewer-a-host-receipt.json','review_execution_started',True),('034',SOURCE+'/reviewer-a.json','verdict','PASS'),('082',SOURCE+'/precheck-result.json','input_sha256','0'*64)]:
  add('TEST-'+test+'::semantic',change_file(path,key,value))
 for test,path in [('016',PRIOR+'/spec-review-contract.json'),('020',PRIOR+'/integrated-summary.json'),('035',AUTH)]:
  add('TEST-'+test+'::missing',lambda root,rec,path=path:(root/path).unlink(),False)
 for test,name in [('026','reviewer-b-reservation.txt'),('027','reviewer-b.json'),('028','reviewer-b-host-receipt.json'),('029','integrated-summary.json'),('030','integrated-verdict.json'),('031','spec-review-contract.json'),('032','extra-complete-round.json')]:
  add('TEST-'+test+'::extra-source',lambda root,rec,name=name:put(root,SOURCE+'/'+name,'{}\n'))
 for test,path in [('062',SOURCE+'/precheck-result.json'),('063',SOURCE+'/reviewer-a.json'),('064',SOURCE+'/reviewer-a-host-receipt.json'),('065',SOURCE+'/reviewer-a-reservation.txt'),('066',INV),('067',SOURCE+'/spec-review-report.md')]:
  add('TEST-'+test+'::missing',lambda root,rec,path=path:(root/path).unlink(),False)
  add('TEST-'+test+'::altered',lambda root,rec,path=path:put(root,path,(root/path).read_bytes()+b'altered\n'),False)
 for test,key,value in [('069','sequence',3),('070','run_id','synthetic-wrong-run'),('071','host_session_id','synthetic-wrong-session'),('072','stage','impl'),('073','role','spec-reviewer-b'),('074','record_sha256','0'*64)]:add('TEST-'+test+'::identity',setfield(('reviewer_a',key),value))
 for mutation in ('missing','extra','duplicate'):
  def inventory(root,rec,mutation=mutation):
   a=rec['interrupted_artifacts']
   if mutation=='missing':a.pop()
   elif mutation=='duplicate':a.append(copy.deepcopy(a[0]))
   else:a.append(ref(root,AUTH))
  add('TEST-068::'+mutation,inventory)
 for number,key in enumerate(('Feature','Source Attempt','Source Round','Target Attempt','Target Round','Maximum Rounds','Decision','Recovery Binding SHA256'),1):
  for kind in ('missing','duplicate','changed'):
   def auth_line(root,rec,key=key,kind=kind):
    lines=(root/AUTH).read_text().splitlines();index=next(i for i,l in enumerate(lines) if l.startswith(key+':'))
    if kind=='missing':lines.pop(index)
    elif kind=='duplicate':lines.append(lines[index])
    else:lines[index]=key+': invalid'
    put(root,AUTH,'\n'.join(lines)+'\n');rec['authorization']=ref(root,AUTH)
   add(f'TEST-050-A{number:02}::{kind}',auth_line,False)
 def later(root,rec):
  ledger=load(root,LEDGER);ledger['records'].append(chain_record(3,'host','orchestrator','synthetic-later','synthetic-later-session',ledger['records'][-1]['record_sha256']));dump(root,LEDGER,ledger)
 add('TEST-079::later-valid-record',later,False,True)
 def reorder(root,rec):put(root,RECORD,json.dumps(dict(reversed(list(rec.items()))),ensure_ascii=False,separators=(', ',': '))+'\n');return 'raw'
 add('CONTROL::canonical-binding-key-order-and-whitespace',reorder,False,True)

 def escaped_equivalent(root,rec):
  put(root,RECORD,json.dumps(rec).replace('spec-review-interrupted-recovery/v1',r'\u0073pec-review-interrupted-recovery/v1'));return 'raw'
 add('TEST-043::canonical-binding-unicode-escaped-equivalent',escaped_equivalent,False,True)
 for kind in ('extra-final-newline','omit-target','reorder-array'):
  def wrong_canonical(root,rec,kind=kind):
   body=copy.deepcopy({k:v for k,v in rec.items() if k!='authorization'})
   if kind=='omit-target':del body['target']
   if kind=='reorder-array':body['interrupted_artifacts'].reverse()
   raw=canonical(body)+(b'\n' if kind=='extra-final-newline' else b'')
   text=re.sub(r'^Recovery Binding SHA256:.*$', 'Recovery Binding SHA256: '+sha(raw),(root/AUTH).read_text(),flags=re.M)
   put(root,AUTH,text);rec['authorization']=ref(root,AUTH)
  add('TEST-043::canonical-binding-'+kind,wrong_canonical,False)

 # Exact source/identity sibling mutations: update raw enclosing references and the
 # authorization digest, leaving only the intended semantic counterpart wrong.
 def repin(root,rec,path):
  for pin in rec['interrupted_artifacts']+[rec['previous_contract'],rec['interrupted_precheck'],rec['reviewer_a']['invocation']]:
   if pin['path']==path:pin['sha256']=digest(root/path)
 def nested_file(path,field,value,remove=False):
  def edit(root,rec):
   obj=load(root,path);target=at(obj,field[:-1])
   if remove:target.pop(field[-1],None)
   else:target[field[-1]]=value
   dump(root,path,obj);repin(root,rec,path)
   if path==PRIOR+'/integrated-summary.json':
    # Refresh both owning manifests and the contract reference so the chosen
    # summary inconsistency reaches own-stage semantics, not an old hash.
    contract=load(root,PRIOR+'/spec-review-contract.json')
    raw_b=load(root,PRIOR+'/reviewer-b.json')
    for manifest in (contract['reviewers'][1]['allowed_input_manifest'],raw_b['allowed_input_manifest']):
     for pin in manifest:
      if pin['path']==path:pin['sha256']=digest(root/path)
    dump(root,PRIOR+'/reviewer-b.json',raw_b)
    dump(root,PRIOR+'/spec-review-contract.json',contract)
    repin(root,rec,PRIOR+'/spec-review-contract.json')
  return edit
 for field,value in [('schema','wrong/v1'),('stage','impl'),('feature','other-feature'),('attempt',2),('round',1),('run_id',''),('warningCount',1),('requirements_sha256','0'*64),('acceptance_sha256','0'*64),('investigation_sha256','0'*64)]:
  add('TEST-017::prior-contract::'+field,nested_file(PRIOR+'/spec-review-contract.json',(field,),value))
 for field,value in [('schema','wrong/v1'),('attempt',1),('round',1),('generated_at',None),('reviewer_a_fail_count',0),('reviewer_a_pass_count',0),('reviewer_a_skip_count',1)]:
  add('TEST-021::summary::'+field,nested_file(PRIOR+'/integrated-summary.json',(field,),value))
 for field,value in [('id','wrong-check'),('result','SKIP'),('severity','Critical')]:
  add('TEST-021::summary-check::'+field,nested_file(PRIOR+'/integrated-summary.json',('reviewer_a_checks',0,field),value))
 for index,role in enumerate(('a','b')):
  for field,value in [('role','wrong-role'),('run_id','synthetic-wrong'),('host_session_id','synthetic-wrong-session')]:
   add('TEST-022::prior-reviewer-'+role+'::'+field,nested_file(PRIOR+'/spec-review-contract.json',('reviewers',index,field),value))
  for field,value in [('path','specs/other-feature/requirements.md'),('sha256','0'*64)]:
   add('TEST-022::prior-reviewer-'+role+'::manifest-'+field,nested_file(PRIOR+'/spec-review-contract.json',('reviewers',index,'allowed_input_manifest',0,field),value))
  for field,value in [('role','wrong-role'),('run_id','synthetic-wrong'),('host_session_id','synthetic-wrong-session'),('verdict','UNKNOWN')]:
   add('TEST-022::prior-raw-'+role+'::'+field,nested_file(PRIOR+'/reviewer-'+role+'.json',(field,),value))
 for field,value in [('schema','wrong/v1'),('stage','impl'),('feature','other-feature'),('attempt',1),('round',1),('reviewer_a_run_id','wrong'),('reviewer_b_run_id','wrong'),('reviewer_a_host_session_id','wrong'),('reviewer_b_host_session_id','wrong'),('warningCount',1),('verdict','BLOCKED')]:
  add('TEST-023::integrated-verdict::'+field,nested_file(PRIOR+'/integrated-verdict.json',(field,),value))
 for field in ('critical','major','minor'):
  add('TEST-023::integrated-verdict::finding_counts.'+field,nested_file(PRIOR+'/integrated-verdict.json',('finding_counts',field),9))

 def rebound_precheck_type(root,rec,key):
  path=SOURCE+'/precheck-result.json';pre=load(root,path);pre[key]=True;dump(root,path,pre)
  inv=load(root,INV)
  for pin in inv['allowed_input_manifest']:
   if pin['path']==path:pin['sha256']=digest(root/path)
  dump(root,INV,inv)
  raw=load(root,SOURCE+'/reviewer-a.json');raw['allowed_input_manifest']=inv['allowed_input_manifest'];dump(root,SOURCE+'/reviewer-a.json',raw)
  ledger=load(root,LEDGER);binding=sha('\n'.join(pin['path']+'\t'+pin['sha256'] for pin in inv['allowed_input_manifest']).encode())
  old=ledger['records'][1];new=chain_record(old['sequence'],old['stage'],old['role'],old['run_id'],old['host_session_id'],old['previous_record_sha256'],binding);ledger['records'][1]=new;dump(root,LEDGER,ledger)
  rec['reviewer_a']['record_sha256']=new['record_sha256']
  receipt=SOURCE+'/reviewer-a-reservation.txt';put(root,receipt,(root/receipt).read_text().replace(old['record_sha256'],new['record_sha256']))
  for changed in (path,INV,SOURCE+'/reviewer-a.json',receipt):repin(root,rec,changed)
 for key in ('schema','stage','feature','spec_review_status_field','requirements_sha256','acceptance_sha256','investigation_sha256','calibration_sha256','input_sha256'):
  add('TEST-062::rebound-precheck-boolean::'+key,lambda root,rec,key=key:rebound_precheck_type(root,rec,key))
 for field,value in [('schema','wrong/v1'),('stage','impl'),('feature','other-feature'),('attempt',2),('round',2),('spec_review_status_field','Passed'),('requirements_sha256','0'*64),('acceptance_sha256','0'*64),('investigation_sha256','0'*64),('calibration_sha256','0'*64),('input_sha256','0'*64)]:
  add('TEST-062::precheck::'+field,nested_file(SOURCE+'/precheck-result.json',(field,),value))
 for field,value in [('schema','wrong/v1'),('stage','impl'),('role','spec-reviewer-b'),('run_id','wrong'),('host_session_id','wrong'),('verdict','PASS')]:
  add('TEST-063::raw::'+field,nested_file(SOURCE+'/reviewer-a.json',(field,),value))
 for field,value in [('result','PASS'),('id','UNKNOWN-CHECK'),('severity','Unknown'),('finding','Completed substantive review: requirement is ambiguous.')]:
  add('TEST-034::substantive-check::'+field,nested_file(SOURCE+'/reviewer-a.json',('checks',0,field),value))
 for field in ('id','result','severity'):
  add('TEST-034::diagnostic-boolean::'+field,nested_file(SOURCE+'/reviewer-a.json',('checks',0,field),True))
 add('TEST-034::domain-skip-without-unreadability',nested_file(SOURCE+'/reviewer-a.json',('checks',),[dict(id='DOMAIN-CONFORMANCE',result='SKIP',severity='Major',finding='Explicit skip condition supplied: no domain directory.')]))
 for field,value in [('review_execution_started',None),('review_execution_started','false'),('sessionId','wrong'),('threadId','wrong')]:
  add('TEST-064::host::'+field+'::'+str(value),nested_file(SOURCE+'/reviewer-a-host-receipt.json',(field,),value))

 for field in ('sessionId','threadId'):
  add('TEST-064::host-boolean::'+field,nested_file(SOURCE+'/reviewer-a-host-receipt.json',(field,),True))
 for field in ('schema','stage','role','run_id','host_session_id','verdict'):
  add('TEST-063::raw-boolean::'+field,nested_file(SOURCE+'/reviewer-a.json',(field,),True))
 add('TEST-066::invocation-boolean-feature',nested_file(INV,('feature',),True))
 def overflow_json(root,rec):
  path=SOURCE+'/reviewer-a-host-receipt.json';raw=(root/path).read_text().rstrip();put(root,path,raw[:-1]+',"unexpected_number":1e999}');repin(root,rec,path)
 add('TEST-064::host-nonstandard-JSON-overflow',overflow_json)
 for name,value in [('NaN',float('nan')),('Infinity',float('inf'))]:
  add('TEST-064::host-nonstandard-JSON-'+name,nested_file(SOURCE+'/reviewer-a-host-receipt.json',('unexpected_number',),value))
 for field,value in [('schema','wrong/v1'),('input_mode','inline'),('fallback_mode','inline'),('read_only',False),('feature','other-feature'),('identity_ledger_path','reports/other-ledger.json'),('identity_ledger_sha256','INVALID'),('sequence',3),('stage','impl'),('role','spec-reviewer-b'),('run_id','wrong'),('host_session_id','wrong'),('previous_record_sha256','0'*64)]:
  add('TEST-066::invocation::'+field,nested_file(INV,(field,),value))
 for field,value in [('path','specs/other-feature/requirements.md'),('sha256','0'*64)]:
  add('TEST-076::invocation-input::'+field,nested_file(INV,('allowed_input_manifest',0,field),value))
 for key in ('record_sha256','sequence','previous_record_sha256','pre_append_tip_sequence','identity_unique'):
  def receipt(root,rec,key=key):
   path=SOURCE+'/reviewer-a-reservation.txt';text=(root/path).read_text()
   if key=='record_sha256':text=text.replace(rec['reviewer_a']['record_sha256'],'0'*64)
   else:text=re.sub(key+r'=[^\s]+',key+'=invalid',text)
   put(root,path,text);repin(root,rec,path)
  add('TEST-065::receipt::'+key,receipt)
 def changed_report(root,rec):
  path=SOURCE+'/spec-review-report.md';put(root,path,'Execution: BLOCKED before substantive review\nReviewer B was not launched\nVERDICT: PASS\n');repin(root,rec,path)
 add('TEST-030::final-report-verdict',changed_report)
 for field,value in [('sequence',3),('stage','impl'),('role','spec-reviewer-b'),('run_id','wrong'),('host_session_id','wrong'),('record_sha256','0'*64),('previous_record_sha256','0'*64),('allowed_inputs_sha256','0'*64)]:
  add('TEST-'+{'sequence':'069','stage':'072','role':'073','run_id':'070','host_session_id':'071','record_sha256':'074','previous_record_sha256':'075','allowed_inputs_sha256':'076'}[field]+'::persisted::'+field,nested_file(LEDGER,('records',1,field),value),False)
 add('TEST-075::broken-prefix',nested_file(LEDGER,('records',0,'run_id'),'changed-genesis'),False)
 def append_reviewer(root,rec,role='b',run='synthetic-b',session='synthetic-session-b',bound=True,manifest=True,other_round=False):
  ledger=load(root,LEDGER);inv=load(root,INV);inv.update(sequence=3,run_id=run,host_session_id=session,role='spec-reviewer-'+role,previous_record_sha256=ledger['records'][-1]['record_sha256'])
  if other_round:
   for pin in inv['allowed_input_manifest']:
    if pin['path']==SOURCE+'/precheck-result.json':pin.update(ref(root,PRIOR+'/precheck-result.json'))
  binding=sha('\n'.join(p['path']+'\t'+p['sha256'] for p in inv['allowed_input_manifest']).encode()) if bound else None
  ledger['records'].append(chain_record(3,'spec','spec-reviewer-'+role,run,session,ledger['records'][-1]['record_sha256'],binding));dump(root,LEDGER,ledger)
  if manifest:dump(root,f'reports/review-context/{FEATURE}-spec-a3r{2 if other_round else 3}-{role}-invocation.json',inv)
 def b_invocation(root,rec):
  inv=load(root,INV);inv.update(role='spec-reviewer-b',run_id='synthetic-b',host_session_id='synthetic-b-session');dump(root,f'reports/review-context/{FEATURE}-spec-a3r3-b-invocation.json',inv)
 add('TEST-024::B-invocation',b_invocation)
 for kind in ('omitted-source-pin','misdeclared-feature'):
  def ambiguous_invocation(root,rec,kind=kind):
   b_invocation(root,rec);path=f'reports/review-context/{FEATURE}-spec-a3r3-b-invocation.json';inv=load(root,path)
   if kind=='omitted-source-pin':inv['allowed_input_manifest']=[p for p in inv['allowed_input_manifest'] if p['path']!=SOURCE+'/precheck-result.json']
   else:inv['feature']='other-feature'
   dump(root,path,inv)
  add('TEST-080::canonical-B-'+kind,ambiguous_invocation)

 for label,prefix in [('dot','./'),('historical-absolute','/historical/checkout/'),('historical-relative','historical/checkout/'),('missing-precheck','__omit__'),('miscased-precheck','__case__'),('newline-precheck','__newline__'),('selfdeclared-domain','__domain__')]:
  def aliased_b(root,rec,prefix=prefix):
   ledger=load(root,LEDGER);inv=load(root,INV)
   inv.update(sequence=3,role='spec-reviewer-b',run_id='synthetic-aliased-b',host_session_id='synthetic-aliased-b-session',previous_record_sha256=ledger['records'][-1]['record_sha256'])
   for pin in inv['allowed_input_manifest']:
    if pin['path']==SOURCE+'/precheck-result.json':
     pin['path']=(pin['path'] if prefix=='__domain__' else pin['path'].replace('precheck-result','Precheck-result') if prefix=='__case__' else pin['path']+'\n' if prefix=='__newline__' else prefix+pin['path'])
   if prefix=='__domain__':inv['stage']='domain'
   if prefix=='__omit__':inv['allowed_input_manifest']=[p for p in inv['allowed_input_manifest'] if not p['path'].startswith('__omit__')]
   binding=sha('\n'.join(pin['path']+'\t'+pin['sha256'] for pin in inv['allowed_input_manifest']).encode())
   ledger['records'].append(chain_record(3,'spec','spec-reviewer-b',inv['run_id'],inv['host_session_id'],ledger['records'][-1]['record_sha256'],binding))
   dump(root,LEDGER,ledger);dump(root,'reports/review-context/synthetic-other-round-b-invocation.json',inv)
  add('TEST-080::aliased-B-source-'+label,aliased_b)

 add('TEST-025::orphan-bound-B',lambda root,rec:append_reviewer(root,rec,manifest=False))
 add('TEST-080::orphan-unbound-B',lambda root,rec:append_reviewer(root,rec,bound=False,manifest=False))
 add('TEST-080::unbound-correlated-B',lambda root,rec:append_reviewer(root,rec,bound=False))
 add('TEST-077::duplicate-persisted-identity',lambda root,rec:append_reviewer(root,rec,role='a',run=rec['reviewer_a']['run_id'],session=rec['reviewer_a']['host_session_id'],manifest=False))
 add('TEST-078::partial-run-collision',lambda root,rec:append_reviewer(root,rec,run=rec['reviewer_a']['run_id'],manifest=False))
 add('TEST-078::partial-session-collision',lambda root,rec:append_reviewer(root,rec,session=rec['reviewer_a']['host_session_id'],manifest=False))
 add('TEST-079::later-valid-other-round-reviewer',lambda root,rec:append_reviewer(root,rec,other_round=True),False,True)
 def unrelated_b(root,rec):
  other='synthetic-unrelated-feature';prepath=f'reports/spec-review/{other}/attempt-1/round-1/precheck-result.json'
  pre=load(root,SOURCE+'/precheck-result.json');pre.update(feature=other,attempt=1,round=1);dump(root,prepath,pre)
  for name in ('requirements.md','acceptance-tests.md','investigation.md'):
   put(root,f'specs/{other}/{name}',(root/f'specs/{FEATURE}/{name}').read_bytes())
  inputs=sorted([ref(root,f'specs/{other}/{name}') for name in ('requirements.md','acceptance-tests.md','investigation.md')]+[ref(root,CAL),ref(root,prepath)],key=lambda pin:pin['path'])
  ledger=load(root,LEDGER);inv=load(root,INV);inv.update(feature=other,role='spec-reviewer-b',run_id='synthetic-unrelated-b',host_session_id='synthetic-unrelated-b-session',sequence=3,previous_record_sha256=ledger['records'][-1]['record_sha256'],allowed_input_manifest=inputs)
  dump(root,f'reports/review-context/{other}-spec-a1r1-b-invocation.json',inv)
  binding=sha('\n'.join(pin['path']+'\t'+pin['sha256'] for pin in inputs).encode())
  ledger['records'].append(chain_record(3,'spec','spec-reviewer-b',inv['run_id'],inv['host_session_id'],ledger['records'][-1]['record_sha256'],binding))
  ledger['records'].append(chain_record(4,'host','orchestrator','synthetic-unrelated-host','synthetic-unrelated-host-session',ledger['records'][-1]['record_sha256']))
  dump(root,LEDGER,ledger)
 add('TEST-079::later-unrelated-B-shared-calibration-and-host',unrelated_b,False,True)
 def unrelated_domain(root,rec):
  path='reports/domain-review/attempt-1/round-1/precheck-result.json';dump(root,path,{'schema':'synthetic-domain-precheck','stage':'domain'})
  ledger=load(root,LEDGER);inv=load(root,INV)
  inv.update(stage='domain',role='domain-reviewer-a',sequence=3,run_id='synthetic-unrelated-domain',host_session_id='synthetic-unrelated-domain-session',previous_record_sha256=ledger['records'][-1]['record_sha256'],identity_ledger_sha256=digest(root/LEDGER),allowed_input_manifest=[ref(root,path)])
  binding=sha('\n'.join(p['path']+'\t'+p['sha256'] for p in inv['allowed_input_manifest']).encode())
  ledger['records'].append(chain_record(3,'domain','domain-reviewer-a',inv['run_id'],inv['host_session_id'],ledger['records'][-1]['record_sha256'],binding));dump(root,LEDGER,ledger)
  manifest=root/'reports/review-context/synthetic-domain-a-invocation.json';dump(root,str(manifest.relative_to(root)),inv)
  scripts=ROOT/'plugins/sdd-quality-loop/scripts'
  command=['bash',str(scripts/'validate-review-context-set.sh'),str(manifest),str(root)] if RUNTIME=='bash' else [PWSH,'-NoLogo','-NoProfile','-File',str(scripts/'validate-review-context-set.ps1'),'-Manifest',str(manifest),'-RepositoryRoot',str(root)]
  verified=run_child(root,command)
  assert verified.returncode==0,verified.stderr
 add('TEST-079::later-unrelated-domain-real-verifier',unrelated_domain,False,True)


 add('TEST-008::source-not-latest',setfield(('source','round'),2))
 add('TEST-036::authorization-raw-hash',setfield(('authorization','sha256'),'0'*64),False)
 for test,key,value in [('037','Feature','other-feature'),('038','Source Attempt','2'),('039','Target Attempt','5'),('040','Maximum Rounds','4'),('043','Recovery Binding SHA256','0'*64)]:
  def binding_line(root,rec,key=key,value=value):
   text=re.sub('^'+key+':.*$',key+': '+value,(root/AUTH).read_text(),flags=re.M);put(root,AUTH,text);rec['authorization']=ref(root,AUTH)
  add('TEST-'+test+'::binding',binding_line,False)
 add('TEST-081::prior-contract-raw-hash',setfield(('previous_contract','sha256'),'0'*64),False)
 return cases

def main():
 failed=0;passed=0
 scratch_parent=ROOT/'specs/a9-interrupted-review-recovery/verification/T-001'
 scratch_parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='synthetic-',dir=scratch_parent) as tmp:
  scratch=pathlib.Path(tmp)
  if RUNTIME!='bash':
   probe=run_child(scratch/'runtime-probe',[PWSH,'-NoLogo','-NoProfile','-Command',
    '[ordered]@{executable=(Get-Process -Id $PID).Path;version=$PSVersionTable.PSVersion.ToString();runtime=[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription;os=[System.Runtime.InteropServices.RuntimeInformation]::OSDescription;architecture=[System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()} | ConvertTo-Json -Compress'])
   if probe.returncode!=0:
    print('FAIL powershell runtime-probe exit='+str(probe.returncode)+' '+probe.stdout+probe.stderr,flush=True);return 1
   print('RUNTIME powershell '+json.dumps(json.loads(probe.stdout),sort_keys=True),flush=True)
  base=scratch/'fixture';record=fixture(base);paths=drivers(scratch)
  before=snapshot(base)
  for name,runner in [('CONTROL::prior-own-stage-NEEDS_WORK',lambda:run_driver(base,'prior',paths)),('CONTROL::persisted-A-real-verifier',lambda:run_identity(base)),('CONTROL::valid-interrupted-admission',lambda:run_driver(base,'recovery',paths))]:
   result=runner();unchanged=snapshot(base)==before
   ok=result.returncode==0 and unchanged
   print(('PASS' if ok else 'FAIL')+' '+RUNTIME+' '+name+' exit='+str(result.returncode)+' immutable='+str(unchanged),flush=True)
   if not ok:failed+=1;print((result.stdout+result.stderr).strip(),flush=True)
   else:passed+=1
  cases=mutations(record)
  selected=os.environ.get('SDD_RECOVERY_TEST_FILTER')
  if selected:cases=[case for case in cases if selected in case[0]]
  # An absent predicate is Red, never negative-case success. Preserve designed names,
  # but do not execute hundreds of identical missing-function failures as coverage.
  if result.returncode==90:
   for name,*_ in cases:print('NOT_RUN '+RUNTIME+' '+name+' admission absent',flush=True)
  elif failed==0:
   from concurrent.futures import ThreadPoolExecutor
   def execute_case(item):
    number,(name,edit,reauthorize,accept)=item
    target=scratch/('mutation-'+str(number));shutil.copytree(base,target)
    rec=copy.deepcopy(record);raw=edit(target,rec)
    if raw!='raw':
     if reauthorize:authorize(target,rec)
     else:dump(target,RECORD,rec)
    before_case=snapshot(target);result=run_driver(target,'recovery',paths)
    unchanged=snapshot(target)==before_case
    no_target=not os.path.lexists(target/f'reports/spec-review/{FEATURE}/attempt-4')
    ok=(result.returncode==0 if accept else result.returncode==1) and unchanged and no_target
    line=('PASS' if ok else 'FAIL')+' '+RUNTIME+' '+name+' exit='+str(result.returncode)+' immutable='+str(unchanged)+' no_target='+str(no_target)
    detail=(result.stdout+result.stderr).strip()
    shutil.rmtree(target)
    return ok,line,detail
   # Independent disposable roots; ordered output retains every named outcome.
   with ThreadPoolExecutor(max_workers=4) as pool:
    for ok,line,detail in pool.map(execute_case,enumerate(cases)):
     print(line,flush=True)
     if not ok:failed+=1;print(detail,flush=True)
     else:passed+=1
 print('RESULT '+RUNTIME+' passed='+str(passed)+' failures='+str(failed)+' designed='+str(len(cases)),flush=True)
 return int(failed>0)
if __name__=='__main__':sys.exit(main())
PY
