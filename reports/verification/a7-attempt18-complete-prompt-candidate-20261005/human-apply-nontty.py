#!/usr/bin/env python3
"""Hash-locked two-target human apply; default --check makes no writes.

Only --apply-human requests the normal guarded git apply. If it refuses, stop;
do not retry through another write path.
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
PATCH = HERE / 'nontty-launch.patch'
PATCH_SHA = '5d4ea29338300e7e6c41c7c327187bf9702310781939b84744c78d695eb43dd6'
SKILL = 'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md'
HELPER = 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
OLD_SKILL_SHA = '25301e17e3069c26567e2b5ff107aafc46b824dde81a7e87f31533f57cd35227'
NEW_SKILL_SHA = 'f860a4449e7a2edfc35a61f17c88f62399a8bf425df2f3743356d08da6a2f4af'
NEW_HELPER_SHA = '1fa826ac3b8a336c3ee9badadd0002a5078c9a660dff30b83e44b81900a6f075'


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


def state():
    skill = ROOT / SKILL
    helper = ROOT / HELPER
    regular(skill)
    if helper.exists() or helper.is_symlink():
        regular(helper)
        return sha(skill), sha(helper)
    return sha(skill), None


def verify_patch():
    if HERE.parents[2] != ROOT or ROOT.resolve() != ROOT:
        fail('wrong owner checkout')
    regular(PATCH)
    if sha(PATCH) != PATCH_SHA:
        fail('candidate patch hash changed')
    content = PATCH.read_text()
    headers = re.findall(r'^diff --git a/(\S+) b/(\S+)$', content, re.M)
    if headers != [(SKILL, SKILL), (HELPER, HELPER)]:
        fail('patch target inventory changed')
    if content.count('--- /dev/null\n+++ b/' + HELPER) != 1:
        fail('new helper marker changed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check', action='store_true')
    group.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    verify_patch()
    current = state()
    after = (NEW_SKILL_SHA, NEW_HELPER_SHA)
    before = (OLD_SKILL_SHA, None)
    if current == after:
        print('ALREADY_APPLIED: two readback hashes match; no change')
        return
    if current != before:
        fail('pre-apply bytes or new-file absence mismatch; no write')
    invoke('git', 'apply', '--check', str(PATCH))
    if not args.apply_human:
        print('READY: old hash, new-file absence, patch hash and git apply --check match; no write')
        return
    backup = pathlib.Path(tempfile.mkdtemp(prefix='a7-nontty-human-backup-')).resolve()
    target = backup / SKILL
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / SKILL, target)
    if sha(target) != OLD_SKILL_SHA:
        fail('backup readback mismatch; backup=' + str(backup))
    print('BACKUP: ' + str(backup), flush=True)
    if state() != before or sha(PATCH) != PATCH_SHA:
        fail('owner bytes or patch changed after backup; no apply; backup=' + str(backup))
    invoke('git', 'apply', str(PATCH))
    if state() != after:
        fail('post-apply readback mismatch; do not retry; backup=' + str(backup))
    print('APPLIED_ONCE: two readback hashes match; backup=' + str(backup))
    print('NOT VERIFIED: live CLI diagnostic and formal reviewer launch remain')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
