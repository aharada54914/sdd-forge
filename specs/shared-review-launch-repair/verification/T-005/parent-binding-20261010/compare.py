"""Read-only owner comparison; write generated evidence only beside this script."""
import datetime
import hashlib
import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
SOURCE = OUT.parent / 'attempt-6/input-and-source-hashes.json'
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

data = json.loads(SOURCE.read_text())
rows = []
for entry in data['copies']:
    path = ROOT / entry['path']
    current = sha(path)
    historical = Path(data['scratch_root']) / 'work' / entry['path']
    kind = ('test-only' if entry['path'].startswith('tests/') else
            'output/evidence' if entry['path'].startswith(('reports/', 'specs/')) else
            'source/control')
    rows.append(dict(path=entry['path'], historical_copy_sha256=entry['sha256'],
                     current_owner_sha256=current, bytes_match=current == entry['sha256'],
                     historical_mode=entry.get('mode'),
                     historical_copy_present=historical.is_file(),
                     historical_copy_actual_sha256=sha(historical),
                     current_mode=oct(path.stat().st_mode & 0o777) if path.exists() else None,
                     classification=kind))
result = dict(checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              owner=str(ROOT), historical_index=str(SOURCE), historical_index_sha256=sha(SOURCE),
              count=len(rows), matching=sum(r['bytes_match'] for r in rows),
              mismatches=[r for r in rows if not r['bytes_match']], rows=rows,
              claim='Byte comparison only; historical staged execution is not owner execution.')
(OUT / ('comparison-after.json' if '--after' in sys.argv else 'comparison.json')).write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k != 'rows'}, indent=2))
