import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

OUT = Path(__file__).resolve().parent
HELPER = OUT.parent / 'snapshot/handoffs/shared-review-launch-repair-T-005-attempt-6/prepare-fixture.cjs'
INVENTORY = 'handoffs/shared-review-launch-repair-T-005-attempt-6/source-modes.json'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


cases = {
    'absolute-path': 'duplicate/unsafe input',
    'parent-path': 'duplicate/unsafe input',
    'duplicate-path': 'duplicate/unsafe input',
    'out-of-range-mode': 'inventory entry',
    'fractional-mode': 'inventory entry',
    'changed-mode-unpinned': 'inventory hash',
    'source-hash-mismatch': 'snapshot mismatch',
    'external-root': 'external fixture roots',
}
for name, expected in cases.items():
    with tempfile.TemporaryDirectory(prefix='fixture-negative-', dir=OUT / 'tmp') as temp:
        root = Path(temp)
        snapshot, output = root / 'snapshot', root / 'output'
        snapshot.mkdir()
        output.mkdir()
        source = snapshot / 'fixture.txt'
        source.write_bytes(b'fixture\n')
        entry = dict(path='fixture.txt', sha256=sha(source.read_bytes()), mode=0o755)
        if name == 'out-of-range-mode':
            entry['mode'] = 512
        if name == 'fractional-mode':
            entry['mode'] = 1.5
        inventory = dict(schema='t005-fixture-modes/v1', entries=[entry])
        inventory_file = snapshot / INVENTORY
        inventory_file.parent.mkdir(parents=True)
        raw = json.dumps(inventory).encode()
        inventory_file.write_bytes(raw)
        allowed = [dict(path=INVENTORY, sha256=sha(raw)), dict(path=entry['path'], sha256=entry['sha256'])]
        if name == 'absolute-path':
            allowed.append(dict(path=str(output / 'escape'), sha256='0' * 64))
        if name == 'parent-path':
            allowed.append(dict(path='../escape', sha256='0' * 64))
        if name == 'duplicate-path':
            allowed.append(allowed[-1].copy())
        if name == 'changed-mode-unpinned':
            inventory['entries'][0]['mode'] = 0o644
            inventory_file.write_text(json.dumps(inventory))
        if name == 'source-hash-mismatch':
            source.write_bytes(b'changed fixture\n')
        manifest = root / 'manifest.json'
        manifest.write_text(json.dumps(dict(allowed_inputs=allowed)))
        target = output
        if name == 'external-root':
            target = root / 'wrong-output'
            target.mkdir()
        before = {p.relative_to(root).as_posix(): (sha(p.read_bytes()), p.stat().st_mode) for p in root.rglob('*') if p.is_file()}
        command = ['rtk', 'proxy', 'node', str(HELPER), str(manifest), str(snapshot), str(target)]
        result = subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True, text=True)
        print(json.dumps(dict(case=name, argv=command, exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)))
        assert result.returncode != 0 and expected in result.stderr, name
        assert not (output / 'work').exists() and not (output / 'git-history.git').exists(), name
        after = {p.relative_to(root).as_posix(): (sha(p.read_bytes()), p.stat().st_mode) for p in root.rglob('*') if p.is_file()}
        assert before == after, name
print('8 expected helper rejections verified; synthetic fixture bytes and modes unchanged')
