import hashlib
import json
from pathlib import Path

out = Path(__file__).resolve().parent
before = json.loads((out / 'comparison.json').read_text())
after = json.loads((out / 'comparison-after.json').read_text())
rows = {r['path']: r for r in after['rows']}
tests = json.loads((out / 'current-tests.json').read_text())
for test in tests:
    path = 'tests/' + test['suite'] + '.tests.py'
    test.update(source=path, source_sha256=rows[path]['current_owner_sha256'])
result = dict(schema='t005-parent-binding/v1', historical_count=620,
              historical_actual_copies_match=sum(r['historical_copy_actual_sha256'] == r['historical_copy_sha256'] for r in after['rows']),
              current_byte_matches=after['matching'], mismatches=after['mismatches'],
              mode_mismatches=sum(r['historical_mode'] != r['current_mode'] for r in after['rows']),
              compared_bytes_stable=before['rows'] == after['rows'],
              newly_executed_current_owner=tests,
              historical_execution_is_owner_execution=False,
              formal_quality_gate='NOT RUN', native_review='NOT RUN', ci='NOT RUN', windows='NOT RUN')
result['evidence_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
    for p in sorted(out.iterdir()) if p.is_file() and p.name != 'binding-summary.json'}
(out / 'binding-summary.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('mismatches','evidence_sha256')}, indent=2))
