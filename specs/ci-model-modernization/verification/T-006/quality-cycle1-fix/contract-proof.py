"""Actual schema/adapter proof; deterministic fixtures, no native provider execution."""
import ast
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from unittest.mock import patch
import jsonschema

ROOT=Path('/workspace/sdd-forge');OUT=ROOT/'specs/ci-model-modernization/verification/T-006/quality-cycle1-fix'

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module);return module

fixture=load('t006_proof_fixture',ROOT/'tests/model-policy.tests.py')
observation_fixture=load('t006_proof_observation',ROOT/'tests/model-observation.tests.py')
helper=observation_fixture.MP
records=[]
case=fixture.PolicySelection('test_wrapper_policy_smoke');case.setUp()
old=Path.cwd()
case.request['budget']={'amount':10,'unit':'USD'}
case.request['estimates']=[{'catalog_id':fixture.CURRENT,'amount':1,'unit':'USD','source_url':'https://example.invalid/fixture-price','source_date':fixture.SOURCE_DATE}]
case.project['roles']['implementer']={'model_id':None,'policy':None}
try:
 schemas={}
 for filename in ['model-policy','model-policy-request','model-role-config','model-selection','model-observation','model-policy-error']:
  schema=json.loads((ROOT/'contracts'/(filename+'.schema.json')).read_text())
  jsonschema.Draft202012Validator.check_schema(schema)
  schemas[filename]=jsonschema.Draft202012Validator(schema,format_checker=jsonschema.FormatChecker())
  records.append({'check':'actual-schema-meta:'+filename,'result':'PASS'})
 pairs=[('model-policy',case.policy),('model-policy-request',case.request),('model-role-config',case.project)]
 for name,value in pairs:
  schemas[name].validate(value)
  for field in schemas[name].schema['required']:
   mutated=copy.deepcopy(value);del mutated[field]
   assert not schemas[name].is_valid(mutated),(name,field)
   records.append({'check':name+':missing:'+field,'result':'PASS'})
  mutated=copy.deepcopy(value);mutated['unexpected']=True
  assert not schemas[name].is_valid(mutated)
  records.append({'check':name+':unknown-field','result':'PASS'})
 # Nested persisted fields each have an actual schema mismatch; runtime paths are checked independently.
 nested=[('model-policy',['roles','implementer'],case.policy),('model-policy',['models',0],case.policy),
         ('model-policy',['models',0,'adoption',0],case.policy),('model-policy-request',['cli'],case.request),
         ('model-policy-request',['budget'],case.request),('model-policy-request',['estimates',0],case.request),
         ('model-role-config',['roles','implementer'],case.project)]
 for name,path,original in nested:
  target=original
  for part in path:target=target[part]
  for field in target:
   mutated=copy.deepcopy(original);node=mutated
   for part in path:node=node[part]
   del node[field]
   assert not schemas[name].is_valid(mutated),(name,path,field)
   records.append({'check':name+':missing:'+str(path)+'.'+field,'result':'PASS'})
 schemas['model-policy'].validate(json.loads((ROOT/'contracts/model-policy.v1.json').read_text()))
 case.save();os.chdir(case.work)
 context=helper.prepare_policy('request.json','registry.json',options={},environment={})
 winner={'model':fixture.CURRENT,'canonical_tier':'strong','effort':'high','effort_control':'flag'}
 selection=helper.complete_policy(context,winner)
 schemas['model-selection'].validate(selection);schemas['model-observation'].validate(case.observation)
 records.append({'check':'actual-schema-positive-selection-and-observation','result':'PASS'})
 for name,original,attribute in [('model-policy',case.policy,'policy'),('model-policy-request',case.request,'request'),('model-role-config',case.project,'project')]:
  baseline=copy.deepcopy(original)
  for field in schemas[name].schema['required']:
   mutated=copy.deepcopy(baseline);del mutated[field];setattr(case,attribute,mutated)
   if name=='model-role-config':case.request['project_config_path']='project.json'
   case.save()
   try:helper.prepare_policy('request.json','registry.json',options={},environment={})
   except helper.PolicyError as failure:assert failure.reason=='config-invalid',(name,field,failure.reason)
   else:raise AssertionError(('runtime accepted missing',name,field))
   records.append({'check':'runtime:'+name+':missing:'+field,'result':'PASS'})
  setattr(case,attribute,baseline)
 case.request['project_config_path']=None
 case.save()
 # Each new nested persisted field also reaches the actual runtime parser independently.
 for name,path,original in nested:
  attribute={'model-policy':'policy','model-policy-request':'request','model-role-config':'project'}[name]
  baseline=copy.deepcopy(getattr(case,attribute));target=baseline
  for part in path:target=target[part]
  for field in target:
   mutated=copy.deepcopy(baseline);node=mutated
   for part in path:node=node[part]
   del node[field];setattr(case,attribute,mutated)
   if attribute=='project':case.request['project_config_path']='project.json'
   case.save()
   try:helper.prepare_policy('request.json','registry.json',options={},environment={})
   except helper.PolicyError as failure:assert failure.reason=='config-invalid',(name,path,field,failure.reason)
   else:raise AssertionError(('runtime accepted missing nested',name,path,field))
   records.append({'check':'runtime:'+name+':missing:'+str(path)+'.'+field,'result':'PASS'})
  setattr(case,attribute,baseline)
 case.request['project_config_path']=None;case.save()
 # Exercise the original T-004 transport with a fake native server, and the REAL fixed selection engine.
 native=observation_fixture.NativeFake(case,[observation_fixture.page([
     observation_fixture.native_model('fixture-current','native-current',fixture.EFFORTS)])])
 actual_popen=subprocess.Popen;actual_which=shutil.which
 def route_popen(argv,*args,**kwargs):
  if any(str(arg).endswith(('select-agent-model.sh','select-agent-model.ps1')) for arg in argv):
   return actual_popen(argv,*args,**kwargs)
  return native.popen(argv,*args,**kwargs)
 with patch.object(subprocess,'Popen',route_popen),patch('shutil.which',lambda name,*args,**kwargs:sys.executable if 'codex' in str(name) else actual_which(name,*args,**kwargs)):
  with helper.CodexClient('t006-positive-adapter') as client:
   capture=client.capture(purpose='launch')
   case.observation=capture.observation;case.save()
   prepared=helper.prepare_policy('request.json','registry.json',options={},environment={},capture=capture)
   sealed=helper.complete_policy(prepared,winner,capture=capture)
   schemas['model-selection'].validate(sealed)
   assert sealed['observation_sha256']==capture.observation['observation_sha256']
   assert 'live-discovery' in sealed['reason']
   records.append({'check':'genuine-active-launch-Capture-plus-real-selector-replay','result':'PASS','scope':'T-004 NativeFake adapter only; no real provider/model invocation'})
  try:helper.complete_policy(prepared,winner,capture=capture)
  except helper.PolicyError:records.append({'check':'closed-Capture-rejected','result':'PASS'})
  else:raise AssertionError('Closed native context reused')
 # The same real native PowerShell path covers price permutations, not only Python/Bash sorting.
 os.chdir(old)
 extra=fixture.PolicySelection('test_mixed_known_unknown_costs_have_total_order_for_every_permutation');extra.setUp()
 try:
  invoke=extra.invoke
  extra.invoke=lambda backend='bash',**kwargs:invoke('powershell',**kwargs)
  extra.test_mixed_known_unknown_costs_have_total_order_for_every_permutation()
  records.append({'check':'PowerShell-three-price-all-permutations','result':'PASS'})
 finally:extra.doCleanups()
finally:
 os.chdir(old);case.doCleanups()
(OUT/'contract-proof-results.json').write_text(json.dumps({'validator':'jsonschema.Draft202012Validator','checks':records},indent=2)+'\n')
print(str(len(records))+' actual schema/runtime/adapter checks PASS')
