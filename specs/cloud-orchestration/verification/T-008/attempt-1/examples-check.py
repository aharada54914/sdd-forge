"""Execute documented routing examples and schema checks, with no credentials."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location('cloud_contracts', repo / 'plugins/sdd-quality-loop/scripts/cloud_contracts.py')
assert spec and spec.loader
contracts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contracts)
oracle_spec = importlib.util.spec_from_file_location('schema_oracle', repo / 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py')
assert oracle_spec and oracle_spec.loader
oracle = importlib.util.module_from_spec(oracle_spec)
oracle_spec.loader.exec_module(oracle)
with tempfile.TemporaryDirectory(prefix='T008-examples-') as tmp:
    for provider in ('azure', 'aws'):
        workspace = Path(tmp).resolve() / provider
        command = [sys.executable, '-B', str(repo / 'plugins/sdd-azure-cloud/examples/local-route-example.py'), str(workspace), '--provider', provider]
        subprocess.run(command, check=True, capture_output=True)
        request = workspace / 'request.json'
        original = request.read_bytes()
        for path in workspace.rglob('*.json'):
            if path.name == 'config.json':
                schema = json.loads((repo / f'plugins/sdd-{provider}-cloud/references/{provider}-local-config.schema.json').read_bytes())
                assert not oracle._schema_validate(schema, json.loads(path.read_bytes()))
            elif path.name != 'cdk.json':
                contracts.parse_artifact(path.read_bytes())
        env = {'PATH': os.defpath, 'HOME': str(workspace), 'CLOUD_WORKSPACE_ROOT': str(workspace),
               'CLOUD_SHARED_RUNTIME_ROOT': str(repo / 'plugins/sdd-quality-loop/scripts')}
        cli = str(repo / f'plugins/sdd-{provider}-cloud/scripts/cloud.py')
        base = 'specs/cloud-example/verification/T-001/cloud/example-run/example-unit/'
        for phase, expected in [('route', 0), ('prepare', 2), ('apply', 2)]:
            args = [sys.executable, '-B', cli, phase, '--request', str(request), '--output', base + phase + '.json']
            proc = subprocess.run(args, env=env, cwd=workspace, capture_output=True, timeout=30)
            result = json.loads(proc.stdout)
            assert proc.returncode == expected, (provider, phase, proc.stdout, proc.stderr)
            contracts.parse_artifact(proc.stdout, 'cloud-operation-result/v1')
            assert result['result'] == ('PASS' if phase == 'route' else 'BLOCKED'), result
            assert 'native_operation_id' not in result
            assert request.read_bytes() == original
            print(provider, phase, 'exit', proc.returncode, result['result'])
        # No overwrite, unknown fields and actual digest mismatch are rejected.
        proc = subprocess.run([sys.executable, '-B', cli, 'route', '--request', str(request), '--output', base + 'route.json'], env=env, cwd=workspace, capture_output=True, timeout=30)
        assert proc.returncode == 2
        data = json.loads(original)
        data['unexpected'] = True
        try:
            contracts.parse_artifact(json.dumps(data).encode(), 'cloud-run-request/v1')
        except ValueError:
            pass
        else:
            raise AssertionError('unknown field accepted')
        config = workspace / 'bundle/config.json'
        config.write_bytes(config.read_bytes() + b' ')
        proc = subprocess.run([sys.executable, '-B', cli, 'route', '--request', str(request), '--output', base + 'mutated.json'], env=env, cwd=workspace, capture_output=True, timeout=30)
        assert proc.returncode == 2, proc.stdout
        print(provider, 'overwrite/unknown-field/digest negatives: rejected')
print('PASS: synthetic local examples; no compiler or live acceptance claim')
