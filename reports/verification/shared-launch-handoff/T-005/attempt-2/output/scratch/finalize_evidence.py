import datetime
import hashlib
import json
from pathlib import Path
import re
import shlex

output = Path(__file__).resolve().parents[1]
work = output / 'work'
evidence = work / 'specs/shared-review-launch-repair/verification/T-005/attempt-2'
manifest_file = output.parent / 'manifest.json'
manifest = json.loads(manifest_file.read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
commands = []
for path in sorted(evidence.glob('*.json')):
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or 'command' not in value or 'returncode' not in value:
        continue
    log = path.with_suffix('.log').read_text()
    commands.append(dict(label=path.stem,
        outer_command=shlex.join(['rtk', 'proxy', 'python3', '-B', 'scratch/run.py', path.stem] + value['command']),
        inner_command=value['command'], cwd=value['cwd'], returncode=value['returncode'],
        started_at=value['started_at'], ended_at=value['ended_at'],
        summary=re.findall(r'^.*(?:Ran [0-9]+ tests|PASS:|FAIL:|SKIP:|skipped=|anchors verified).*$', log, re.M)))
final = [row for row in commands if row['label'].startswith('final-')]
assert len(final) == 8 and all(row['returncode'] == 0 for row in final)
for case in json.loads((evidence / 'fixture-receipts.json').read_text()):
    calls = case['validators']
    assert len(calls) == 4
    assert [call['returncode'] for call in calls] == [0, 0, 0, 1]
    assert calls[0]['before_sha256'] == calls[1]['after_sha256'] == calls[2]['before_sha256']
    assert calls[2]['before_sha256'] != calls[2]['after_sha256']
    assert calls[2]['after_sha256'] == calls[3]['before_sha256'] == calls[3]['after_sha256']
    assert len(calls[2]['after']['records']) == 2
    assert 'wrapper.json' not in case['events']
    assert case['events'].count('reserved.txt') == 1
summary = dict(run_id=manifest['run_id'], task_attempt_count=2,
    manifest_sha256=sha(manifest_file), commands=commands,
    spec_revision={item['path']: item['sha256'] for item in manifest['allowed_inputs']
                   if item['path'].startswith('specs/shared-review-launch-repair/')},
    formal_quality_gate='NOT RUN', independent_review='NOT RUN', ci='NOT RUN',
    native_model_launch='NOT RUN', owner_apply='NOT RUN', windows_execution='NOT RUN')
(evidence / 'execution-summary.json').write_text(json.dumps(summary, indent=2) + '\n')

# Exclude unchanged disposable setup copies from the apply payload.
removed = []
for item in manifest['allowed_inputs']:
    path = work / item['path']
    assert sha(output.parent / 'snapshot' / item['path']) == item['sha256']
    if item['path'] == 'tests/unified-launch-order.tests.py':
        assert sha(path) == '612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e'
        continue
    assert sha(path) == item['sha256'], item['path']
    path.unlink()
    removed.append(item['path'])
for directory in sorted((p for p in work.rglob('*') if p.is_dir()), key=lambda p: len(p.parts), reverse=True):
    if not any(directory.iterdir()):
        directory.rmdir()
record = dict(timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    manifest_sha256=sha(manifest_file), snapshot_verified_files=606,
    changed_admitted_files=['tests/unified-launch-order.tests.py'],
    removed_unchanged_staged_files=len(removed),
    command='rtk proxy python3 -B scratch/finalize_evidence.py')
(evidence / 'delivery-shape.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
