"""Read-only public official API shape check; post-implementation research, not live execution."""
from pathlib import Path
import datetime
import hashlib
import json
import urllib.request
E=Path(__file__).resolve().parent
S=Path('/tmp/cloud-T012-01a14e03')
url='https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json'
with urllib.request.urlopen(url,timeout=30) as response:
    raw=response.read(20*1024*1024+1)
assert len(raw)<=20*1024*1024
(S/'github-openapi.json').write_bytes(raw)
spec=json.loads(raw)
endpoint=spec['paths']['/repos/{owner}/{repo}/actions/runs']['get']
response=endpoint['responses']['200']['content']['application/json']['schema']
run=spec['components']['schemas']['workflow-run']
assert set(response['properties'])>={'total_count','workflow_runs'}
assert response['properties']['workflow_runs']['items']['$ref']=='#/components/schemas/workflow-run'
used=['id','run_attempt','event','path','head_sha','display_title','repository','head_repository','status','conclusion']
assert set(used)<=set(run['properties'])
(E/'github-api-shape.json').write_text(json.dumps(dict(
 classification='read-only official OpenAPI research after implementation; not live GitHub run or immutable upstream Git pin',
 url=url,acquired_at=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
 full_snapshot_sha256=hashlib.sha256(raw).hexdigest(),operation_id=endpoint['operationId'],
 description=endpoint['description'],response=response,
 used_workflow_run_properties={k:run['properties'][k] for k in used}),indent=2)+'\n')
print('OFFICIAL_GITHUB_SHAPE_OK')
