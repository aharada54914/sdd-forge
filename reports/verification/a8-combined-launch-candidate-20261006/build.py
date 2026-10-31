"""Mechanically compose reviewed patches in a disposable tree; no owner apply."""
from pathlib import Path
import hashlib
import json
import difflib
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DIGEST = HERE.parent / 'a8-reviewer-digest-candidate-20261006'
IDLE = HERE.parent / 'a8-spec-idle-identity-candidate-20261006'
sha = lambda b: hashlib.sha256(b).hexdigest()
def run(*args, cwd=ROOT):
    return subprocess.check_output(['rtk', 'proxy', *args], cwd=cwd, text=True)
assert run('git', 'rev-parse', 'HEAD').strip() == '495c88d67af44530687ecea3ce9fb0a90a336539'
for folder, expected in ((DIGEST, 'f73564abaa6382d3a02e0198fd1f7eaed2bf5bc7f18fd42488a88c616bc6f8f7'), (IDLE, '2dd88a0a4e6eb5b8754a194b118ac8b6b4f6477a560660647a13038ae4cc5d0d')):
    assert sha((folder / 'candidate.patch').read_bytes()) == expected
baseline = json.loads((DIGEST / 'baseline-hashes.json').read_text())
new = 'plugins/sdd-quality-loop/scripts/reviewer-receipt.py'
skill = 'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md'
assert not (ROOT / new).exists() and not (ROOT / new).is_symlink()
for name, expected in baseline.items():
    assert sha((ROOT / name).read_bytes()) == expected
(HERE / 'dirty-before.txt').write_text(run('git', 'status', '--short'))
pins = {}
patch = ''
with tempfile.TemporaryDirectory(prefix='a8-combine-') as temp:
    fixture = Path(temp)
    for name in baseline:
        p = fixture / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((ROOT / name).read_bytes())
    run('git', 'apply', str(DIGEST / 'candidate.patch'), cwd=fixture)
    run('git', 'apply', str(IDLE / 'candidate.patch'), cwd=fixture)
    for name in [*baseline, new]:
        before = (ROOT / name).read_bytes() if name in baseline else None
        after = (fixture / name).read_bytes()
        if name != skill:
            assert after == (DIGEST / 'candidate' / name).read_bytes()
        else:
            assert after.count(b'## Required spec reviewer digest capability') == 1
            assert b'fresh orchestrator-issued per-reviewer run ID' in after
            assert b'Both IDs\nremain independently subject to ledger uniqueness' in after
        target = HERE / 'candidate' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(after)
        pins[name] = [sha(before) if before is not None else None, sha(after)]
        patch += ''.join(difflib.unified_diff((before or b'').decode().splitlines(True), after.decode().splitlines(True), fromfile='a/' + name if before is not None else '/dev/null', tofile='b/' + name))
(HERE / 'candidate.patch').write_text(patch)
(HERE / 'pins.json').write_text(json.dumps(pins, indent=2) + '\n')
# Reuse prior human helper; only generalize absent-file handling and fixed pins.
source = (IDLE / 'human_apply.py').read_text()
start = source.index('PATCH = ')
end = source.index('\n\n\ndef stop', start)
source = source[:start] + 'PATCH = ' + repr(str((HERE / 'candidate.patch').relative_to(ROOT))) + '\nPATCH_HASH = ' + repr(sha(patch.encode())) + '\nPINS = ' + repr({k: tuple(v) for k, v in pins.items()}) + source[end:]
source = source.replace('def read_regular(relative):', 'def read_regular(relative, absent=False):')
source = source.replace('    if path.resolve() != path or not stat.S_ISREG(path.lstat().st_mode):', "    if path.resolve() != path:\n        stop('unsafe path: ' + relative)\n    if absent:\n        if path.exists() or path.is_symlink():\n            stop('expected absent target: ' + relative)\n        return None\n    if not stat.S_ISREG(path.lstat().st_mode) or path.stat().st_nlink != 1:")
source = source.replace('hashlib.sha256(data).hexdigest()', 'hashlib.sha256(data).hexdigest() if data is not None else None')
source = source.replace('read_regular(name) for name in PINS', 'read_regular(name, PINS[name][0] is None) for name in PINS')
source = source.replace("APPLY A8 IDLE CONTRACT", "APPLY A8 COMBINED CONTRACT")
source = source.replace('reviewed one-file patch', 'reviewed eight-target patch')
source = source.replace('a8-spec-idle-backup-', 'a8-combined-launch-backup-')
source = source.replace('for name, data in originals.items():\n    target = backup', 'for name, data in originals.items():\n    if data is None:\n        continue  # Absence is recorded in the backup manifest.\n    target = backup')
source = source.replace('if read_regular(name) != data:', 'if read_regular(name, data is None) != data:')
source = source.replace('one-file readback matches', 'eight-target readback matches')
(HERE / 'human_apply.py').write_text(source)
print('COMPOSE OK: 8 targets; 7 unchanged from digest candidate; SKILL union only')
print('patch SHA256', sha(patch.encode()))
print('helper SHA256', sha(source.encode()))
