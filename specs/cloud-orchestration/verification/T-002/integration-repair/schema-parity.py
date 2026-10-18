"""Supplemental installed Draft-07 oracle; local fixtures only, no schema fetching."""
from pathlib import Path
import copy
import hashlib
import importlib.metadata
import importlib.util
import json
import sys

import jsonschema

ROOT = Path(__file__).resolve().parents[5]
spec = importlib.util.spec_from_file_location("fixture", ROOT / "tests/cloud-orchestration-contracts.tests.py")
assert spec and spec.loader
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
contracts = fixture.load(ROOT / "plugins/sdd-quality-loop/scripts/cloud_contracts.py", "contracts")
count = 0

def check(value, expected):
    global count
    schema = json.loads((ROOT / "contracts" / (value['schema'].split('/')[0] + '.schema.json')).read_bytes())
    jsonschema.Draft7Validator.check_schema(schema)
    structural = jsonschema.Draft7Validator(schema).is_valid(value)
    try:
        contracts.parse_artifact(fixture.encode(value))
        runtime = True
    except contracts.ContractError:
        runtime = False
    assert structural == runtime == expected, (value['schema'], structural, runtime, expected)
    count += 1

import tempfile
with tempfile.TemporaryDirectory(prefix="cloud-schema-parity-") as temp:
    request = fixture.install_local_context(Path(temp), fixture.fixtures()['cloud-run-request/v1'])
    bodies = list(fixture.local_bodies().values()) + [request]
    for body in bodies:
        check(body, True)
        for path, node in fixture.nodes(body):
            if isinstance(node, dict):
                bad = copy.deepcopy(body)
                fixture.at(bad, path)['unknown'] = True
                check(bad, False)
                for key in node:
                    if key == 'schema' or (key == 'local_context' and not path):
                        continue
                    bad = copy.deepcopy(body)
                    del fixture.at(bad, path)[key]
                    check(bad, False)
            elif not isinstance(node, list) and path[-1] != 'schema':
                bad = copy.deepcopy(body)
                fixture.at(bad, path[:-1])[path[-1]] = {}
                check(bad, False)
        for path, node in fixture.nodes(body):
            if type(node) is int:
                for value in (0, -1, 2147483648, True):
                    bad = copy.deepcopy(body)
                    fixture.at(bad, path[:-1])[path[-1]] = value
                    check(bad, False)
    for path in [('local_context','unit_roots')]:
        bad = copy.deepcopy(request)
        fixture.at(bad,path).append(fixture.at(bad,path)[0])
        check(bad, False)
    for key in ('allowed_scopes','allowed_resource_types'):
        bad = fixture.local_bodies()['cloud-deployment-policy/v1']
        bad[key].append(copy.deepcopy(bad[key][0]))
        check(bad, False)
    for key, value in [('private_networking',False),('backup_required','true')]:
        bad = fixture.local_bodies()['cloud-deployment-policy/v1']
        bad[key] = value
        check(bad,False)
    for currency in ('usd','US','USD\n','123'):
        bad = fixture.local_bodies()['cloud-deployment-policy/v1']
        bad['budget']['currency'] = currency
        check(bad,False)
    for owner in (None,'terraform','sam','cloudformation','azd','bicep','cdk'):
        bad = dict(request, operation='route', owner=owner, route=None)
        check(bad,True)
        check(dict(bad,operation='apply'),False)
    base = fixture.fixtures()['cloud-operation-result/v1']
    for result,state in [('PASS','PLANNED'),('NO_CHANGE','NO_CHANGE'),('UNKNOWN','UNKNOWN'),('FAIL','FAILED'),('BLOCKED','BLOCKED')]:
        for native in (False,True):
            body=dict(base,result=result,state=state,evidence_manifest_path=None,error_code=None if result in ('PASS','NO_CHANGE') else 'STOP')
            if native:body['native_operation_id']='synthetic-native'
            check(body,result in ('FAIL','BLOCKED') and not native)

# Reproducible installed dependency identity; no dependency files copied or modified.
dependencies={}
for name in ('jsonschema','jsonschema-specifications','referencing','rpds-py','attrs'):
    dist=importlib.metadata.distribution(name)
    files={str(p):hashlib.sha256(Path(dist.locate_file(p)).read_bytes()).hexdigest()
           for p in dist.files or [] if str(p).endswith(('.py','.json','.so')) and Path(dist.locate_file(p)).is_file()}
    dependencies[name]=dict(version=dist.version,files=files)
print(json.dumps(dict(checks=count, result='PASS', python=sys.version, dependencies=dependencies),indent=2))
