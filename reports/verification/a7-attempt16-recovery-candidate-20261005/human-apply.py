#!/usr/bin/env python3
"""Hash-locked human apply for exactly the A7 five-path recovery candidate.

Default/--check never writes owner files. Only a human invoking --apply-human
can request the normal rtk-mediated git apply; repository protection remains in
force. A failed apply is not retried or routed through another write method.
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
PATCH = HERE / 'mechanical-integration.patch'
PATCH_SHA = 'c618f47d1ebcbd66f7c1580a28e7583c8c4c3b5311faf8399555097efdc39fbd'
BEFORE = {
    'plugins/sdd-review-loop/scripts/fresh-review-recovery.py':
        '2cff54f410ead4c1904808f97aaa8d8b852ee95cf37c95a45fad838ff84621a3',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.sh':
        '230feaa639b5931447f88d3e720d6d52fed15c697de7e19e5bbc6efdb277d8a4',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1':
        '9eb8111754b4a3b355da4d465eb53b369c9f2ef09e4d0d246bf2da1478e95ab8',
    'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md':
        '107dd754c3514a34fcba28a2b2bf18d35d004e1dd0a92599956906a9315b45e4',
}
NEW = 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'
AFTER = {
    'plugins/sdd-review-loop/scripts/fresh-review-recovery.py':
        'a276ae4fd2f8acb0bbe3e1898a6d53495cb113a300f3560f19e6d68e937478fc',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.sh':
        '0383b73b77cb9d0b9a0573c001f383b59cbafecb6283001231c6d6bd1ea11cf0',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1':
        '1996a519da1063770b3593b4f21bfb5e94a3bc926acc9ceb8d002d233202fe51',
    'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md':
        'f11e6d93a45b3a43ac2b53075e50915d093bee24ce76e81b8f0591e3b6f5c323',
    NEW: 'f0172bcf8a5a4e1ae63741ab1566803075fc98ea782d2918469dbf5888cbf77a',
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
    targets = re.findall(r'^diff --git a/(\S+) b/(\S+)$', PATCH.read_text(), re.M)
    if len(targets) != len(AFTER) or {a for a, b in targets if a == b} != set(AFTER):
        fail('candidate patch target inventory changed')


def state():
    values = {}
    for rel in AFTER:
        path = ROOT / rel
        if path.exists() or path.is_symlink():
            regular(path)
            values[rel] = sha(path)
        else:
            values[rel] = None
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check', action='store_true', help='read-only default')
    group.add_argument('--apply-human', action='store_true', help='human-only scoped apply')
    args = parser.parse_args()
    verify_patch()
    current = state()
    if current == AFTER:
        print('ALREADY_APPLIED: all five readback hashes match; no change')
        return
    expected = dict(BEFORE)
    expected[NEW] = None
    if current != expected:
        mismatch = [rel for rel in AFTER if current[rel] != expected[rel]]
        fail('pre-apply hash/existence mismatch; no write: ' + ', '.join(mismatch))
    invoke('git', 'apply', '--check', str(PATCH))
    if not args.apply_human:
        print('READY: five fixed targets and patch hash match; git apply --check passed; no write')
        return
    backup = pathlib.Path(tempfile.mkdtemp(prefix='a7-attempt16-human-backup-')).resolve()
    for rel, old_hash in BEFORE.items():
        target = backup / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        if sha(target) != old_hash:
            fail('backup readback mismatch: ' + rel + '; backup=' + str(backup))
    print('BACKUP: ' + str(backup), flush=True)
    if state() != expected or sha(PATCH) != PATCH_SHA:
        fail('owner bytes or patch changed after backup; no apply; backup=' + str(backup))
    invoke('git', 'apply', str(PATCH))
    if state() != AFTER:
        fail('post-apply readback mismatch; do not retry; backup=' + str(backup))
    print('APPLIED_ONCE: five readback hashes match; backup=' + str(backup))
    print('NOT VERIFIED: behavioral regression, independent review and real admission remain')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
