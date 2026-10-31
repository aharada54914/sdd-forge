#!/usr/bin/env python3
"""Pinned human-only repair. Default is a read-only check."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply', action='store_true', help='human execution only')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
pins = {
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh':
        '3b780687498ce40f6d846934d2b05f24d994657480cbdd42d32ac2d4c0afcd5d',
    'plugins/sdd-review-loop/references/review-context-boundary.md':
        '360adaabc81656853b0cc2186330277a15dd74ec877d9713922f83d0a10f8652',
    'tests/review-context-boundary.tests.sh':
        'b50365f9db51329b39434e9835290442237e550554ee934caac8d5151f066d71',
}
citations = {':358': ':352', ':1179': ':1185', ':1167': ':1173',
             ':1189-1198': ':1195-1207'}
prepared = []
for rel, expected in pins.items():
    target = root / rel
    if target.is_symlink() or not target.is_file():
        raise SystemExit(f'STOP: not a regular target: {rel}')
    before = target.read_bytes()
    if hashlib.sha256(before).hexdigest() != expected:
        raise SystemExit(f'STOP: hash changed; nothing applied: {rel}')
    after = before
    if rel.endswith('validate-review-context-set.sh'):
        old = b'admission_json_members < "$implementation_manifest"'
        if before.count(old) != 1:
            raise SystemExit('STOP: call is not unique')
        after = before.replace(old, b'admission_json_members "$implementation_manifest"')
    else:
        for old, new in citations.items():
            count = 2 if rel.endswith('.md') and old == ':1179' else 1
            if after.count(old.encode()) != count:
                raise SystemExit(f'STOP: citation count changed: {rel}: {old}')
            after = after.replace(old.encode(), new.encode())
    prepared.append((rel, target, before, after))
    print('CHECKED', rel, 'candidate_sha256=' + hashlib.sha256(after).hexdigest())
if not args.apply:
    print('CHECK_ONLY: no files changed. --apply is human-only.')
    raise SystemExit(0)
backup = Path(tempfile.mkdtemp(prefix='sdd423-launch-repair-'))
for rel, target, before, after in prepared:
    saved = backup / rel
    saved.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target, saved)
print('BACKUP:', backup, flush=True)
for rel, target, before, after in prepared:
    if target.is_symlink() or target.read_bytes() != before:
        raise SystemExit(f'STOP: target changed during application: {rel}; backup={backup}')
    target.write_bytes(after)
    if target.read_bytes() != after:
        raise SystemExit(f'STOP: readback failed: {rel}; backup={backup}')
    print('APPLIED', rel, hashlib.sha256(after).hexdigest())
print('Three-file repair only. Tests, review, CI and merge remain pending.')
print('No reservation, verdict, task status, commit, push or merge changed.')
