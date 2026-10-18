"""Retain exact deterministic UNKNOWN -> original archive replay -> GET-only recovery."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import tempfile

ROOT=Path(__file__).resolve().parents[6]
E=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',ROOT/'tests/cloud-orchestration-execution.tests.py')
t=importlib.util.module_from_spec(spec); spec.loader.exec_module(t)
x=t.AzureExecution(); x.setUp()
try:
    x.prepare()
    with tempfile.TemporaryDirectory(prefix='cloud-T012-history-capture-') as d:
        restored=Path(d)/'restored';shutil.copytree(x.root,restored)
        original=copy.deepcopy(x.auths[-1].run)
        x.arm.timeout=True;first=x.apply();assert first['result']=='UNKNOWN'
        x.root=restored;os.environ['CLOUD_WORKSPACE_ROOT']=str(restored)
        x.executor=x.stage('apply',x.preview_ref);auth=x.auths[-1]
        auth.claims['run_id']='456';auth.run['id']=456
        original.update(status='completed',conclusion='failure')
        auth.history=[original,auth.run]
        x.arm.timeout=False;x.arm.existing=False
        before=len(x.arm.calls);second=x.apply('cross-job.json')
        assert second['result']=='UNKNOWN' and x.arm.submissions==1
        assert len(x.arm.calls)==before
        manifest=json.loads((x.root/second['evidence_manifest_path']).read_bytes())
        fence=manifest['submission'];record=json.loads((x.root/fence['path']).read_bytes())
        assert record['history']['response_sha256']==hashlib.sha256(t.encode(dict(total_count=2,workflow_runs=auth.history))).hexdigest()
        assert record['prior_run_ids']==[123] and record['current_run_id']==456
        x.arm.existing=True
        result=x.executor.reconcile(fence,x.directory+'/history-reconcile.json')
        assert result['result']=='PASS' and x.arm.submissions==1
        assert all(row[0]=='GET' for row in x.arm.calls[before:])
        assert first['native_operation_id']==second['native_operation_id']==result['native_operation_id']
        for value in (first,second,result):x.e.c.parse_artifact(x.e.encode(value),'cloud-operation-result/v1')
        target=E/'fence-fixture';shutil.copytree(x.root,target)
        (E/'fence-capture.json').write_text(json.dumps(dict(
            classification='deterministic synthetic ARM/GitHub/OIDC/Entra; no cloud',
            first=first,replayed_original_prepare=second,reconciled=result,
            fence=record,deployment_submissions=x.arm.submissions,replay_mutations=0,
            recovery_methods=[row[0] for row in x.arm.calls[before:]],
            authenticated_list_sha256=record['history']['response_sha256']),indent=2)+'\n')
finally:x.doCleanups()
