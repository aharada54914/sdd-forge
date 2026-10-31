#!/usr/bin/env python3
"""Four-target hash-locked human apply; default is read-only inspection.

Released after independent four-target package review PASS. Protected application
requires genuine human operation where required by docs/development-policy.md:38.
A rejected operation is final; never retry through another executor/write path.
"""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
HERE = Path(__file__).resolve().parent
RELEASE_READY = True
PATCH_SHA = '8359ff939c5da6fc5dfab435ebabb73097c62f7af1283debb1e90508277970ca'
TARGETS = (
    ('failed-last-attempt', 'e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f', '438431a8f75ff83d302413ed69c8d66bf0b44aab80d5d7c1ab72cb55b1e74dc5'),
    ('fresh-review-recovery', '88a2775809e587008d2aefdd9b05f1aaef1fde6b0a3e604b6249d4c2a3e1e037', '7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1'),
    ('validate-nontty-spec-launch', 'fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd', 'fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64'),
    ('spec-review-loop.SKILL', 'eb1a7d506ee3308817aebb6f02b3b41e9562dc134347e3b1470fa7bcfca05d1b', '2b7763cb3b49c5fad4a82b677b70a9d336f0edbd9ed9731e8cafb76584635e3b'),
)

def target_path(name):
    return ('plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md' if name == 'spec-review-loop.SKILL'
            else 'plugins/sdd-review-loop/scripts/' + name + '.py')

def candidate_path(name):
    return HERE / (name + ('.candidate.md' if name == 'spec-review-loop.SKILL' else '.candidate.py'))

def sha(path):
    if not path.is_file() or path.is_symlink() or path.resolve() != path:
        raise RuntimeError('unsafe or missing regular file: ' + str(path))
    return hashlib.sha256(path.read_bytes()).hexdigest()

def invoke(*args):
    result = subprocess.run(['rtk', 'proxy', *args], cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError('command refused/failed; no alternate route: ' + result.stdout + result.stderr)

def inspect():
    if ROOT.resolve() != ROOT or HERE.parents[2] != ROOT:
        raise RuntimeError('wrong owner checkout')
    patch = HERE / 'candidate.patch'
    if sha(patch) != PATCH_SHA:
        raise RuntimeError('patch hash mismatch')
    paths = [target_path(name) for name, _, _ in TARGETS]
    if re.findall(r'^--- a/(\S+)\n\+\+\+ b/(\S+)$', patch.read_text(), re.M) != [(p, p) for p in paths]:
        raise RuntimeError('patch target inventory mismatch')
    current = []
    for (name, before, after), rel in zip(TARGETS, paths):
        if sha(candidate_path(name)) != after:
            raise RuntimeError('candidate hash mismatch: ' + name)
        current.append(sha(ROOT / rel))
    if current == [after for _, _, after in TARGETS]:
        return patch, paths, 'applied'
    if current != [before for _, before, _ in TARGETS]:
        raise RuntimeError('source hash mismatch or partial application; no writes')
    return patch, paths, 'original'

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply-human', action='store_true')
    args = parser.parse_args(argv)
    patch, paths, state = inspect()
    if state == 'applied':
        print('ALREADY_APPLIED: all four exact readbacks; no writes')
        return
    invoke('git', 'apply', '--check', str(patch))
    if not args.apply_human:
        print('CHECK_OK: fixed patch/source/candidate hashes; no writes')
        return
    if not RELEASE_READY:
        raise RuntimeError('UNRELEASED: independent candidate review PASS required; no writes')
    backup = Path(tempfile.mkdtemp(prefix='a7-a21-human-backup-')).resolve()
    print('BACKUP: ' + str(backup), flush=True)
    for (_, before, _), rel in zip(TARGETS, paths):
        destination = backup / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, destination)
        if sha(destination) != before:
            raise RuntimeError('backup readback mismatch; no apply; preserve ' + str(backup))
    # Recheck all pins after backup/check; partial or concurrent changes are a stop.
    if inspect()[2] != 'original':
        raise RuntimeError('source changed before apply; preserve ' + str(backup))
    invoke('git', 'apply', str(patch))
    if inspect()[2] != 'applied':
        raise RuntimeError('post-apply readback mismatch; do not retry; preserve ' + str(backup))
    print('APPLIED_ONCE: all four exact readbacks; preserve backup ' + str(backup))
    print('NOT VERIFIED: application only; formal/native/CI gates remain separate')

if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
