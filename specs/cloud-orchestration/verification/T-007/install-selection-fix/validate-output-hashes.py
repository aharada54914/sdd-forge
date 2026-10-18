"""Verify the stable report output inventory against current repository bytes."""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[5]
report = root / 'reports/implementation/cloud-orchestration/T-007-install-selection-fix.md'
text = report.read_text()
block = text.split('## Outputs\n', 1)[1].split('\n## ', 1)[0]
rows = re.findall(r'^\| `([^`]+)` \| `([a-f0-9]{64})` \|$', block, re.M)
assert rows
assert len({p for p, _ in rows}) == len(rows)
for path, expected in rows:
    assert path != str(report.relative_to(root))
    assert Path(path).name not in ('native-events.jsonl', 'native-stderr.log')
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == expected, path
print('OUTPUT_HASHES_OK')
