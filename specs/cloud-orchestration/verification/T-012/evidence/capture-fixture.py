"""Capture actual orchestrator output using labeled synthetic transport and schema oracle."""
from pathlib import Path
import importlib.util
import json
import shutil

ROOT=Path(__file__).resolve().parents[5]
EVIDENCE=Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
suite=load('cloud_execution_tests','tests/cloud-orchestration-execution.tests.py')
oracle=load('schema_oracle','plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py')
case=suite.AzureExecution('test_exact_manifest_native_incremental_single_submission_no_compiler')
case.setUp()
try:
    before=(case.root/case.request_ref['path']).read_bytes()
    prepare=case.prepare()
    apply=case.apply()
    assert prepare['result']==apply['result']=='PASS'
    assert (case.root/case.request_ref['path']).read_bytes()==before
    checks=[]
    for path in case.root.rglob('*.json'):
        value=json.loads(path.read_bytes())
        schema=value.get('schema')
        if schema in case.e.c.VALIDATORS:
            filename=schema.split('/')[0]+'.schema.json'
            errors=oracle._schema_validate(json.loads((ROOT/'contracts'/filename).read_bytes()),value)
            case.e.c.parse_artifact(path.read_bytes(),schema)
            assert not errors,(path,errors)
            checks.append(dict(path=path.relative_to(case.root).as_posix(),schema=schema,status='PASS'))
    target=EVIDENCE/'execution-fixture'
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(case.root,target)
    (EVIDENCE/'native-shape-parity.json').write_text(json.dumps(dict(
        classification='deterministic synthetic GitHub/OIDC/identity/ARM transports; NO live cloud',
        manifest_bytes_identical=True, deployment_submissions=case.arm.submissions,
        checks=checks, health_verified=False),indent=2)+'\n')
finally:
    case.doCleanups()
