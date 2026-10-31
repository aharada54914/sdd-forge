"""Copy verified execution evidence, retaining the previous canonical report."""
import hashlib
import json
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[3]
feature = 'shared-review-launch-repair'
base = root / f'handoffs/{feature}-T-005-attempt-6'
work = base / 'output/work'
index = json.loads((base / 'output/delivery-index.json').read_bytes())

def digest(path):
    assert path.is_file() and not path.is_symlink(), path
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest = base / 'manifest.json'
assert digest(manifest) == index['input_manifest_sha256'] == '7679d7aab07fe28595f547688ed71688845eddab7d01cbd815b07234ddf9ac6a'
inputs = {e['path']: e['sha256'] for e in json.loads(manifest.read_bytes())['allowed_inputs']}
for name, expected in inputs.items():
    assert digest(root / name) == expected, name
rows = [index['report'], *index['outputs']]
assert len(rows) == 33 and len({e['path'] for e in rows}) == 33
assert index['report']['sha256'] == '4095966cd13d398adfc8db6d396b13a085f64d6c18612b7029af88f35edd41f1'
for entry in rows:
    name = entry['path']
    assert not Path(name).is_absolute() and '..' not in Path(name).parts
    assert name == index['report']['path'] or name.startswith(f'specs/{feature}/verification/T-005/attempt-6/')
    assert digest(work / name) == entry['sha256'], name
    if name != index['report']['path'] and (root / name).exists():
        assert digest(root / name) == entry['sha256'], name
old = json.loads((root / f'specs/{feature}/verification/T-005/supplemental-delivery-closure.json').read_bytes())
for entry in old['artifacts']:
    assert inputs.get(entry['path']) == digest(root / entry['path']), entry['path']
history = root / f'reports/verification/shared-launch-handoff/T-005/prior-report-{digest(root / index["report"]["path"])}.md'
history.parent.mkdir(parents=True, exist_ok=True)
if history.exists():
    assert digest(history) == digest(root / index['report']['path'])
else:
    shutil.copy2(root / index['report']['path'], history)
for entry in rows:
    target = root / entry['path']
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(work / entry['path'], target)
    assert digest(target) == entry['sha256']
declaration = root / f'specs/{feature}/verification/T-005/supplemental-delivery-attempt-6.json'
value = dict(old, implementation_report=index['report'], artifacts=[dict(e, sha256=inputs[e['path']]) for e in old['artifacts']])
with declaration.open('x') as stream:
    json.dump(value, stream, indent=2)
    stream.write('\n')
print(f'PROMOTED: 33 verified artifacts; prior report retained at {history}')
print(f'DECLARATION: {declaration}; formal evaluation remains NOT RUN')
