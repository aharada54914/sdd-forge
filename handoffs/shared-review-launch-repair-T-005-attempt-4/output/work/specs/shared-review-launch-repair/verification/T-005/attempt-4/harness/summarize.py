import hashlib
import json
from pathlib import Path
import re

EV = Path(__file__).resolve().parent.parent
WORK = EV.parents[4]
OUT = WORK.parent
BASE = OUT.parent
manifest = json.loads((BASE / 'manifest.json').read_text())
labels = ['unified-task-launch', 'task-structured-bindings', 'unified-quality-launch',
          'spec-review-verify-inputs', 'host-launch-profile', 'unified-launch-order',
          'review-conditional-inputs', 'review-context-boundary']
results = []
for label in labels:
    record = json.loads((EV / (label + '.json')).read_text())
    log = (EV / (label + '.log')).read_text()
    record['unittest_counts'] = [int(n) for n in re.findall(r'^Ran (\d+) tests?', log, re.M)]
    record['check_summaries'] = [line for line in log.splitlines()
                               if re.match(r'^(PASS:|FAIL:|SUMMARY|ok:|OK\b|Ran \d+)', line)]
    record['skip_lines'] = [line for line in log.splitlines()
                            if re.search(r'\bSKIP\b|\.\.\. skipped|^OK \(skipped=', line)]
    record['log_sha256'] = hashlib.sha256(log.encode()).hexdigest()
    results.append(record)
summary = dict(run_id=manifest['run_id'], task_attempt_count=4,
               manifest_sha256=hashlib.sha256((BASE / 'manifest.json').read_bytes()).hexdigest(),
               spec_revision={r['path']: r['sha256'] for r in manifest['allowed_inputs']
                              if r['path'].startswith('specs/shared-review-launch-repair/')},
               suites=results, production_source_changes=[],
               native_model_launch='NOT RUN', independent_review='NOT RUN',
               formal_quality_gate='NOT RUN', current_head_ci='NOT RUN',
               native_windows='NOT RUN')
(EV / 'execution-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
(EV / 'harness/revalidate.py').write_bytes((OUT / 'revalidate.py').read_bytes())
print(json.dumps([dict(label=r['label'], exit_code=r['exit_code'],
                       unittest_counts=r['unittest_counts'],
                       check_summaries=r['check_summaries'], skip_lines=r['skip_lines']) for r in results], indent=2))
