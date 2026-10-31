#!/usr/bin/env python3
"""Hash-locked, one-target human apply. Default --check is read-only.

Only --apply-human requests normal guarded git apply. A protection refusal is
final; do not retry through another executor, tool, or write path.
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
PATCH_SHA = 'bd32eed89c566125e7fdcbfc186ab2cc04022d080dd293cfd1ca37c4eaf2f5a2'
TARGET = 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'
BEFORE = '8d95150acc8e0b539f3acba755e57fd402d315b0be7b591d9ec9c11f2732776e'
AFTER = '0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def regular(path):
    if not path.is_file() or path.is_symlink() or path.resolve() != path:
        raise RuntimeError('missing or unsafe regular file: ' + str(path))


def invoke(*args):
    result = subprocess.run(['rtk', 'proxy', *args], cwd=ROOT,
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError('command rejected/failed; no alternate route: '
                           + ' '.join(args) + '\n' + result.stdout + result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check', action='store_true')
    group.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    if HERE.parents[2] != ROOT or ROOT.resolve() != ROOT:
        raise RuntimeError('wrong owner checkout')
    regular(PATCH)
    regular(ROOT / TARGET)
    if sha(PATCH) != PATCH_SHA:
        raise RuntimeError('candidate patch hash changed')
    pairs = re.findall(r'^--- a/(\S+)\n\+\+\+ b/(\S+)$', PATCH.read_text(), re.M)
    if pairs != [(TARGET, TARGET)]:
        raise RuntimeError('candidate patch target inventory changed')
    current = sha(ROOT / TARGET)
    if current == AFTER:
        print('ALREADY_APPLIED: exact one-target readback; no change')
        return
    if current != BEFORE:
        raise RuntimeError('pre-apply hash mismatch; no write')
    invoke('git', 'apply', '--check', str(PATCH))
    if not args.apply_human:
        print('READY: old hash and patch hash match; git apply --check passed; no write')
        return
    backup = pathlib.Path(tempfile.mkdtemp(prefix='a7-attempt19-human-backup-')).resolve()
    destination = backup / TARGET
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / TARGET, destination)
    if sha(destination) != BEFORE:
        raise RuntimeError('backup readback mismatch; backup=' + str(backup))
    print('BACKUP: ' + str(backup), flush=True)
    if sha(ROOT / TARGET) != BEFORE or sha(PATCH) != PATCH_SHA:
        raise RuntimeError('bytes changed after backup; no apply; backup=' + str(backup))
    invoke('git', 'apply', str(PATCH))
    if sha(ROOT / TARGET) != AFTER:
        raise RuntimeError('post-apply readback mismatch; do not retry; backup=' + str(backup))
    print('APPLIED_ONCE: exact one-target readback; backup=' + str(backup))
    print('NOT VERIFIED: independent review and actual A19 precheck are pending')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
