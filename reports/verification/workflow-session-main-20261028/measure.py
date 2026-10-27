"""Compare real ordinary and optional sealed checks on a synthetic fixture."""
import hashlib
import json
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GATE = ROOT / 'plugins/sdd-quality-loop/scripts/check-workflow-state.sh'
HELPER = ROOT / 'plugins/sdd-quality-loop/scripts/workflow-state-session.py'
with tempfile.TemporaryDirectory(prefix='sdd-workflow-measure-') as directory:
    base = Path(directory)
    repo = base / 'fixture'
    spec = repo / 'specs/sample'
    spec.mkdir(parents=True)
    (spec / 'requirements.md').write_text('Spec-Review-Status: Pending\n')
    (spec / 'design.md').write_text('Impl-Review-Status: Pending\n')
    (spec / 'acceptance-tests.md').write_text('# Acceptance\n')
    registry = repo / 'specs/workflow-state-registry.json'
    registry.write_text(json.dumps({'schema_version': 1,
        'migration_baseline_commit': '0369c8c96de2eb3179868d1949d66644488f65aa',
        'entries': [{'feature': 'sample', 'profile': 'full'}]}))
    rows = []
    for count in (2, 5):
        request = base / ('requests-' + str(count) + '.json')
        request.write_text(json.dumps({'schema': 'workflow-state-batch/v1',
                                      'requests': [f'item-{i}' for i in range(count)]}))
        for repeat in range(3):
            start = time.monotonic()
            for _ in range(count):
                subprocess.run(['bash', str(GATE), '--registry', str(registry)],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            ordinary = time.monotonic() - start
            start = time.monotonic()
            run = subprocess.run(['bash', str(GATE), '--registry', str(registry), '--batch', str(request)],
                                 check=True, capture_output=True, text=True)
            batch = time.monotonic() - start
            result = json.loads(run.stdout)
            assert result['complete'] and len(result['results']) == count
            assert sum(item['executed'] for item in result['results']) == 1
            rows.append({'requests': count, 'repeat': repeat + 1,
                         'ordinary_seconds': round(ordinary, 4), 'batch_seconds': round(batch, 4),
                         'executions': 1})
print(json.dumps({'scope': 'synthetic one-feature pending fixture; not a full lifecycle measurement',
                  'gate_sha256': hashlib.sha256(GATE.read_bytes()).hexdigest(),
                  'helper_sha256': hashlib.sha256(HELPER.read_bytes()).hexdigest(), 'results': rows}, indent=2))
