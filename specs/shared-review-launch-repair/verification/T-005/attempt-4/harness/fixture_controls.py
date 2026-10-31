"""Exercise the admitted preparation helper using only output-owned fixture data."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

helper, scratch, evidence = map(Path, sys.argv[1:])
inventory_path = 'handoffs/shared-review-launch-repair-T-005-attempt-4/source-modes.json'
records = []
cases = [
    ('restores-executable-copy', None),
    ('unsafe-input', 'duplicate/unsafe input'),
    ('duplicate-input', 'duplicate/unsafe input'),
    ('unsafe-inventory', 'inventory entry'),
    ('duplicate-inventory', 'inventory entry'),
    ('mode-out-of-range', 'inventory entry'),
    ('mode-noninteger', 'inventory entry'),
    ('inventory-pin-mismatch', 'inventory hash'),
    ('source-hash-mismatch', 'snapshot mismatch'),
    ('external-roots', 'external fixture roots'),
    ('existing-work', 'output work already exists'),
]
for label, expected in cases:
    base = scratch / 'fixture-controls' / label
    source = base / 'snapshot'
    output = base / 'output'
    source.mkdir(parents=True)
    output.mkdir()
    original = b'#!/bin/sh\nexit 0\n'
    source_file = source / 'sample.sh'
    source_file.write_bytes(original)
    original_mode = source_file.stat().st_mode & 0o777
    digest = hashlib.sha256(original).hexdigest()
    row = dict(path='sample.sh', sha256=digest, mode=0o755)
    entries = [row]
    if label == 'unsafe-inventory':
        row['path'] = '../escape.sh'
    if label == 'duplicate-inventory':
        entries.append(dict(row))
    if label == 'mode-out-of-range':
        row['mode'] = 512
    if label == 'mode-noninteger':
        row['mode'] = '0755'
    inventory = source / inventory_path
    inventory.parent.mkdir(parents=True)
    inventory.write_text(json.dumps(dict(schema='t005-fixture-modes/v1', entries=entries)))
    allowed = [dict(path='sample.sh', sha256=digest),
               dict(path=inventory_path, sha256=hashlib.sha256(inventory.read_bytes()).hexdigest())]
    if label == 'unsafe-input':
        allowed.append(dict(path='../escape.sh', sha256=digest))
    if label == 'duplicate-input':
        allowed.append(dict(allowed[0]))
    if label == 'inventory-pin-mismatch':
        allowed[1]['sha256'] = '0' * 64
    if label == 'source-hash-mismatch':
        source_file.write_bytes(b'changed fixture\n')
    if label == 'existing-work':
        (output / 'work').mkdir()
    manifest = base / 'manifest.json'
    manifest.write_text(json.dumps(dict(allowed_inputs=allowed)))
    source_arg = source
    if label == 'external-roots':
        source_arg = base / 'other-source'
        source_arg.mkdir()
    before = {str(p.relative_to(base)): (hashlib.sha256(p.read_bytes()).hexdigest(), p.stat().st_mode)
              for p in base.rglob('*') if p.is_file()}
    command = ['rtk', 'proxy', 'node', str(helper), str(manifest), str(source_arg), str(output)]
    result = subprocess.run(command, stdin=subprocess.DEVNULL, text=True, capture_output=True)
    after = {p: (hashlib.sha256((base / p).read_bytes()).hexdigest(), (base / p).stat().st_mode)
             for p in before}
    assert before == after, label
    if expected is None:
        assert result.returncode == 0, result.stderr
        copy = output / 'work/sample.sh'
        assert copy.read_bytes() == original and copy.stat().st_mode & 0o777 == 0o755
        assert source_file.stat().st_mode & 0o777 == original_mode
    else:
        assert result.returncode != 0 and expected in result.stderr, result.stderr
        assert not (output / 'work/sample.sh').exists()
    records.append(dict(case=label, command=command, stdin='DEVNULL', exit_code=result.returncode,
                        expected_rejection=expected, assertion='matched',
                        stdout=result.stdout, stderr=result.stderr, fixture_inputs_unchanged=True))
    print(f'{label}: exit={result.returncode}; expected outcome matched', flush=True)
(evidence / 'fixture-control-results.json').write_text(json.dumps(records, indent=2) + '\n')
print(f'{len(records)} controls matched; actual admitted inventory and snapshot were not modified')
