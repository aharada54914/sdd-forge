#!/usr/bin/env python3
"""Hash-locked, three-target human apply; default --check is read-only.

Only --apply-human requests the normal guarded git apply. A protection refusal
is final: do not retry via another tool or write path.
"""
import argparse
import hashlib
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
HERE = pathlib.Path(__file__).resolve().parent
PATCH = HERE / 'recovery.patch'
PATCH_SHA = 'e29da29237393940a6427497e12c669ce31704d2c9aafb9ccf0981f901ff497c'
BEFORE = {
    'plugins/sdd-review-loop/scripts/fresh-review-recovery.py':
        'a276ae4fd2f8acb0bbe3e1898a6d53495cb113a300f3560f19e6d68e937478fc',
    'plugins/sdd-review-loop/scripts/failed-last-attempt.py':
        'f0172bcf8a5a4e1ae63741ab1566803075fc98ea782d2918469dbf5888cbf77a',
    'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md':
        'f11e6d93a45b3a43ac2b53075e50915d093bee24ce76e81b8f0591e3b6f5c323',
}
AFTER = {
    'plugins/sdd-review-loop/scripts/fresh-review-recovery.py':
        '8d95150acc8e0b539f3acba755e57fd402d315b0be7b591d9ec9c11f2732776e',
    'plugins/sdd-review-loop/scripts/failed-last-attempt.py':
        'e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f',
    'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md':
        '25301e17e3069c26567e2b5ff107aafc46b824dde81a7e87f31533f57cd35227',
}


def fail(message):
    raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def regular(path):
    if not path.is_file() or path.is_symlink() or path.resolve() != path:
        fail('missing or unsafe regular file: ' + str(path))


def invoke(*args):
    result = subprocess.run(['rtk', 'proxy', *args], cwd=ROOT,
                            capture_output=True, text=True)
    if result.returncode:
        fail('command rejected/failed (no alternate route): '
             + ' '.join(args) + '\n' + result.stdout + result.stderr)
    return result


def verify_patch():
    if HERE.parents[2] != ROOT or ROOT.resolve() != ROOT:
        fail('wrong owner checkout')
    regular(PATCH)
    if sha(PATCH) != PATCH_SHA:
        fail('candidate patch hash changed')
    pairs = re.findall(r'^--- a/(\S+)\n\+\+\+ b/(\S+)$', PATCH.read_text(), re.M)
    if len(pairs) != len(AFTER) or any(a != b for a, b in pairs) or \
            {a for a, _ in pairs} != set(AFTER):
        fail('candidate patch target inventory changed')


def state():
    values = {}
    for rel in AFTER:
        path = ROOT / rel
        regular(path)
        values[rel] = sha(path)
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check', action='store_true', help='read-only default')
    group.add_argument('--apply-human', action='store_true', help='human-only guarded apply')
    args = parser.parse_args()
    verify_patch()
    current = state()
    if current == AFTER:
        print('ALREADY_APPLIED: three readback hashes match; no change')
        return
    if current != BEFORE:
        mismatch = [rel for rel in BEFORE if current[rel] != BEFORE[rel]]
        fail('pre-apply hash mismatch; no write: ' + ', '.join(mismatch))
    invoke('git', 'apply', '--check', str(PATCH))
    if not args.apply_human:
        print('READY: three old hashes and patch hash match; git apply --check passed; no write')
        return
    backup = pathlib.Path(tempfile.mkdtemp(prefix='a7-attempt17-human-backup-')).resolve()
    for rel, old_hash in BEFORE.items():
        target = backup / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        if sha(target) != old_hash:
            fail('backup readback mismatch: ' + rel + '; backup=' + str(backup))
    print('BACKUP: ' + str(backup), flush=True)
    if state() != BEFORE or sha(PATCH) != PATCH_SHA:
        fail('owner bytes or patch changed after backup; no apply; backup=' + str(backup))
    invoke('git', 'apply', str(PATCH))
    if state() != AFTER:
        fail('post-apply readback mismatch; do not retry; backup=' + str(backup))
    print('APPLIED_ONCE: three readback hashes match; backup=' + str(backup))
    print('NOT VERIFIED: independent review and real attempt-17 admission remain')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
