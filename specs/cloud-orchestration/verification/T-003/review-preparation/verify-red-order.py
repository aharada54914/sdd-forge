"""Caller-run Git and native-command ordering proof; no working-tree mutation."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
COMMITS = ('a604a0f0836f90eae493db82b8b35749177d3412',)
SOURCE = 'plugins/sdd-quality-loop/scripts/cloud_authorization.py'
TEST = 'tests/cloud-orchestration-execution.tests.py'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

rows = []
for name in COMMITS:
    commit = git('rev-parse', name).decode().strip()
    absent = git('ls-tree', '-r', '--name-only', commit, SOURCE).decode()
    assert absent == '', 'implementation unexpectedly present in Red commit'
    rows.append({'commit': commit, 'metadata_and_changed_paths': git('show', '--format=fuller', '--stat', commit).decode(),
                 'test_blob_sha256': hashlib.sha256(git('show', commit+':'+TEST)).hexdigest(),
                 'production_path_absent': True})
for parent, child in zip(rows, rows[1:]):
    subprocess.run(['git', 'merge-base', '--is-ancestor', parent['commit'], child['commit']], cwd=ROOT, check=True)
raw = ROOT/'specs/cloud-orchestration/verification/T-003/native-events.jsonl'
events = [json.loads(line) for line in raw.read_text().splitlines()]
commands = [(n, e['params']['item']) for n, e in enumerate(events)
            if e.get('method') == 'item/completed' and e['params']['item'].get('type') == 'commandExecution']
red = next((n, item) for n, item in commands if 'git commit' in item.get('command', '')
           and rows[0]['commit'][:8] in str(item.get('aggregatedOutput', '')))
creation = next((n, item) for n, item in commands if 'cat > '+SOURCE in item.get('command', ''))
assert red[0] < creation[0]
with tempfile.TemporaryDirectory(prefix='cloud-committed-red-') as temporary:
    checkout = Path(temporary)
    test = checkout/TEST
    test.parent.mkdir()
    test.write_bytes(git('show', rows[0]['commit']+':'+TEST))
    dependency = checkout/'plugins/sdd-quality-loop/scripts/cloud_contracts.py'
    dependency.parent.mkdir(parents=True)
    pinned = Path('/tmp/cloud-T-003-01a14d65/inputs/plugins/sdd-quality-loop/scripts/cloud_contracts.py')
    dependency.write_bytes(pinned.read_bytes())
    run = subprocess.run(['python3', '-B', str(test)], cwd=checkout, capture_output=True, text=True)
    assert run.returncode == 1 and 'Ran 15 tests' in run.stderr and 'failures=15' in run.stderr
    (HERE/'committed-red-rerun.log').write_text(run.stdout+run.stderr)
    fixture = {'commit': rows[0]['commit'], 'test_sha256': hashlib.sha256(test.read_bytes()).hexdigest(),
               'command': ['python3', '-B', TEST], 'exit_code': run.returncode,
               'preimplementation_dependency_sha256': hashlib.sha256(dependency.read_bytes()).hexdigest(),
               'dependency_source': 'Original T-003 input snapshot; production auth module absent in committed tree',
               'result': '15 committed tests fail with their implementation absent; no live cloud calls'}
proof = {'schema': 'cloud-task-red-order-evidence/v1', 'task_id': 'T-003',
         'classification': 'actual caller Git inspection, native command event ordering and isolated committed-test execution',
         'commits': rows, 'isolated_red_execution': fixture,
         'native_transcript_sha256': hashlib.sha256(raw.read_bytes()).hexdigest(),
         'native_order': [{'kind': kind, 'event_index': n, 'command_sha256': hashlib.sha256(item['command'].encode()).hexdigest(),
                           'exit_code': item.get('exitCode'), 'command_prefix': item['command'][:150]}
                          for kind, (n, item) in [('red_commit', red), ('first_production_creation', creation)]],
         'limit': 'Git alone proves committed tree contents/ancestry; the separate native event ordering supplies working-session sequence. Raw native sessions are not evaluator inputs.'}
(HERE/'red-order-proof.json').write_text(json.dumps(proof, indent=2)+'\n')
print('RED_COMMIT_ORDER_VERIFIED: committed Red fixture fails 15 cases; native first source creation follows initial Red commit')
