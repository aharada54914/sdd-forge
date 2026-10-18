from pathlib import Path
import importlib.util,inspect,textwrap,hashlib,json,copy,datetime,dataclasses
from unittest.mock import patch
from urllib.parse import parse_qs
import xml.etree.ElementTree as ET
root=Path('/workspace/sdd-forge')
paths=['tests/cloud-orchestration-verification.tests.py','tests/cloud-orchestration-execution.tests.py','plugins/sdd-aws-cloud/scripts/aws_observation.py','plugins/sdd-aws-cloud/scripts/aws_execution.py','plugins/sdd-quality-loop/scripts/cloud_verification.py']
before={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}
spec=importlib.util.spec_from_file_location('root_probe_verification',root/paths[0]);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
source=textwrap.dedent(inspect.getsource(m.AwsObservationOrchestration.setup_execution))
source=source.replace('case.setUp()','case.setUp()\n    case.native.existing = True\n    case.native.control = dataclasses.replace(case.native.control, existing_stack_id=case.native.stack)')
namespace=dict(vars(m),dataclasses=dataclasses);exec(source,namespace)
case=m.AwsObservationOrchestration('test_unknown_create_ids_resolved_without_request_edits')
try:
 fixture,wire=namespace['setup_execution'](case)
 assert wire.native.create['ChangeSetType']=='UPDATE'
 old_id=wire.health.cfg['instance_id'];wire.health.cfg['instance_id']='i-fedcba98765432100'
 original=wire.request
 def newer(method,url,headers,body=None):
  response=original(method,url,headers,body)
  if 'cloudformation.' in url and parse_qs(body.decode()).get('Action')==['DescribeStackEvents']:
   doc=ET.fromstring(response.body);container=next(n for n in doc.iter() if n.tag.endswith('}StackEvents'))
   new=copy.deepcopy(list(container)[0])
   for n in new:
    if n.tag.endswith('}ClientRequestToken'):n.text='another-newer-update-token'
    if n.tag.endswith('}Timestamp'):n.text='2026-10-18T06:00:30Z'
   container.insert(0,new);response=dataclasses.replace(response,body=ET.tostring(doc))
  return response
 writes=list(wire.writes)
 with patch.object(wire,'request',side_effect=newer):
  result=fixture.executor.observe(fixture.directory+'/newer-stack-probe.json','verify')
 verification=json.loads((fixture.root/(fixture.directory+'/newer-stack-probe.json.verification.json')).read_bytes())
 context=json.loads((fixture.root/(fixture.directory+'/newer-stack-probe.json.context.json')).read_bytes())
 after={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths};assert before==after,'Source changed during probe; discard result'
 output={'recorded_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'classification':'actual production observe over explicitly synthetic local transports; not live cloud or independent review','sources':before,'scenario':'Original UPDATE succeeded; current stack history has a newer other-token UPDATE_COMPLETE; current stack resource lookup resolves a different valid EC2 physical ID; all current read-only health fixture responses are healthy','old_instance_id':old_id,'current_instance_id':wire.health.cfg['instance_id'],'verification':verification,'public_operation':result,'context_resource_ids':context['resource_ids'],'native_write_count_unchanged':wire.writes==writes}
 (root/'specs/cloud-orchestration/verification/T-006/attempt-3/root-newer-stack-probe.json').write_text(json.dumps(output,indent=2)+'\n')
 print(json.dumps({k:output[k] for k in ['scenario','old_instance_id','current_instance_id','context_resource_ids','native_write_count_unchanged']}));print('verification',verification['overall_result'],'evidence_complete',verification['evidence_complete'],'public',result['result'])
finally:case.doCleanups()
