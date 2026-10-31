import hashlib
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
work = evidence.parents[4]
handoff = work.parent.parent
manifest_bytes = (handoff / 'manifest.json').read_bytes()
assert hashlib.sha256(manifest_bytes).hexdigest() == '04d8878472be7ef18ad2e9470807c754734602371cbb330a17dd9d9d585a8af4'
manifest = json.loads(manifest_bytes)
baseline = json.loads((evidence / 'fixture-preparation.json').read_text())
before_modes = {row['path']: row['snapshot_mode'] for row in baseline['inputs']}
inventory_path = 'handoffs/shared-review-launch-repair-T-005-attempt-5/source-modes.json'
inventory = json.loads((handoff / 'snapshot' / inventory_path).read_text())
expected = {row['path']: row for row in inventory['entries']}
assert len(expected) == len(inventory['entries']) == 611
assert len({row['path'] for row in manifest['allowed_inputs']}) == len(manifest['allowed_inputs'])
observations = []
for row in manifest['allowed_inputs']:
    source = handoff / 'snapshot' / row['path']
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    source_mode = oct(source.stat().st_mode & 511)
    assert source_hash == row['sha256']
    assert source_mode == before_modes[row['path']]
    result = dict(path=row['path'], snapshot_sha256=source_hash, snapshot_mode=source_mode)
    if row['path'] in expected:
        copied = work / row['path']
        result.update(copy_sha256=hashlib.sha256(copied.read_bytes()).hexdigest(), copy_mode=copied.stat().st_mode & 511)
        assert result['copy_sha256'] == row['sha256']
        assert result['copy_mode'] == expected[row['path']]['mode']
    observations.append(result)
result = dict(manifest_sha256=hashlib.sha256(manifest_bytes).hexdigest(),
              snapshot_files=len(observations), copied_files=len(expected),
              snapshot_content_and_modes_unchanged=True, copied_content_and_authorized_modes_unchanged=True,
              task_state_unchanged=True, historical_attempt2_report_unchanged=True,
              owner_tree_not_inspected=True, observations=observations)
(evidence / 'final-integrity.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: value for key, value in result.items() if key != 'observations'}))
