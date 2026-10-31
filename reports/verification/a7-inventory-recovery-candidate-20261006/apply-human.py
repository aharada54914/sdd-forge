#!/usr/bin/env python3
"""Pinned two-target human adoption; no reservation, verdict or Git writes."""
import argparse
import hashlib
import pathlib
import tempfile

BASE = pathlib.Path(__file__).resolve().parent
ROOT = BASE.parents[2]
TARGETS = (
    ('plugins/sdd-review-loop/scripts/fresh-review-recovery.py',
     'fresh-review-recovery.candidate.py',
     '0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de',
     '88a2775809e587008d2aefdd9b05f1aaef1fde6b0a3e604b6249d4c2a3e1e037'),
    ('plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md',
     'SKILL.candidate.md',
     'f860a4449e7a2edfc35a61f17c88f62399a8bf425df2f3743356d08da6a2f4af',
     'eb1a7d506ee3308817aebb6f02b3b41e9562dc134347e3b1470fa7bcfca05d1b'),
)


def sha(value):
    return hashlib.sha256(value).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    prepared = []
    for rel, name, before_hash, after_hash in TARGETS:
        target, candidate = ROOT / rel, BASE / name
        for item in (target, candidate):
            if not item.is_file() or item.is_symlink() or item.resolve() != item:
                raise SystemExit('STOP: target is not a canonical regular file: ' + str(item))
        before, after = target.read_bytes(), candidate.read_bytes()
        if sha(before) != before_hash or sha(after) != after_hash:
            raise SystemExit('STOP: hash mismatch; nothing applied: ' + rel)
        if rel.endswith('.py'):
            compile(after, rel, 'exec')
        prepared.append((target, before, after))
        print('CHECKED', rel, after_hash)
    if not args.apply_human:
        print('CHECK ONLY: no writes. Human-only application uses --apply-human.')
        return
    backup = pathlib.Path(tempfile.mkdtemp(prefix='a7-transport-inventory-backup-')).resolve()
    for index, (target, before, after) in enumerate(prepared):
        saved = backup / (str(index) + '-' + target.name)
        saved.write_bytes(before)
        if saved.read_bytes() != before:
            raise SystemExit('STOP: backup readback failed: ' + str(backup))
    print('BACKUP:', backup)
    for target, before, after in prepared:
        if target.read_bytes() != before:
            raise SystemExit('STOP: target changed; backups retained: ' + str(backup))
    for target, before, after in prepared:
        target.write_bytes(after)
        if target.read_bytes() != after:
            raise SystemExit('STOP: readback failed; backups retained: ' + str(backup))
        print('APPLIED', target.relative_to(ROOT), sha(after))
    print('Two protected targets applied only. Original-path regressions, ordinary precheck,')
    print('formal review, CI and merge remain pending. No reservation or verdict changed.')


if __name__ == '__main__':
    main()
