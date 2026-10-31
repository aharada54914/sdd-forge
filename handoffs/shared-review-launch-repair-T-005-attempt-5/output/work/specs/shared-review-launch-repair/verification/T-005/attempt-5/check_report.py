import hashlib
import json
from pathlib import Path
import re

evidence = Path(__file__).resolve().parent
work = evidence.parents[4]
output = work.parent.resolve()
report_path = work / 'reports/implementation/shared-review-launch-repair/T-005.md'
report = report_path.read_text()
template = (output.parent / 'snapshot/plugins/sdd-implementation/templates/implementation-report.template.md').read_text()
assert re.findall(r'^## .+$', report, re.M) == re.findall(r'^## .+$', template, re.M)
for field in re.findall(r'^- (.*?): \{\{', template, re.M):
    assert re.search(r'^- ' + re.escape(field) + r': .+', report, re.M), field
assert '{{' not in report
assert report.count('\nRun ID: T-005-01a11d91-960e-7ac1-b455-e32576ea3fc3\n') == 1
assert report.count('\nTask Attempt Count: 5\n') == 1
binding = 'Input manifest: `handoffs/shared-review-launch-repair-T-005-attempt-5/manifest.json`, SHA-256 `04d8878472be7ef18ad2e9470807c754734602371cbb330a17dd9d9d585a8af4`'
assert report.count(binding) == 1
assert f'- **Scratch Root**: {output}\n' in report
for field in ('Fallback Reason', 'Handoff Reload Evidence Hash'):
    assert f'- **{field}**: None\n' in report
table = report.split('## Outputs\n', 1)[1].split('\n## ', 1)[0]
assert '| Path | SHA-256 |' in table
rows = re.findall(r'^\| `([^`]+)` \| `([0-9a-f]{64})` \|$', table, re.M)
assert rows and len({path for path, digest in rows}) == len(rows)
for path, digest in rows:
    assert not Path(path).is_absolute() and '\\' not in path
    assert all(part not in ('', '.', '..') for part in path.split('/'))
    target = work / path
    assert target != report_path
    assert hashlib.sha256(target.read_bytes()).hexdigest() == digest, path
assert {path for path, digest in rows} == {str(path.relative_to(work)) for path in evidence.iterdir() if path.is_file()}
print(json.dumps(dict(result='REPORT_SHAPE_AND_OUTPUT_HASHES_OK', output_rows=len(rows),
                      report_sha256=hashlib.sha256(report_path.read_bytes()).hexdigest(),
                      formal_review='NOT RUN', task_state_write=False)))
