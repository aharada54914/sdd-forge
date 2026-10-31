"""Pinned, three-file postapply follow-up. Agents run --dry-run only.

--apply-human is reserved for the authorized human operator. This applies only
the reviewed citation/fixture patch; it does not admit evidence or set status.
"""

import argparse
import hashlib
import pathlib
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge')
HERE = ROOT / 'reports/verification/issue423-scratch-recovery-candidate-20261006'
PATCH = HERE / 'postapply-followup-v2.patch'
HEAD = '3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9'
PATCH_SHA = '7e8421bc0f0a19fcfa97b126f094ca4dbec594a16c90b35e2ced60490ed79e8d'
ROWS = (
    ('plugins/sdd-review-loop/references/review-context-boundary.md',
     'e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50',
     '47dde31388cd0ec008608397eb7ab0406329e8bd13cd2cf45c38cefed3e07f03'),
    ('tests/review-context-boundary.tests.sh',
     '34eb70012271e5f7f697a0c640fe1a4ce0f547f2ae92569beb5a532cba2e96ca',
     'f33b5df68333efbfe8e18e929a0e2d8a829967b9499808f01782eb26e73849af'),
    ('tests/review-agent-isolation.tests.sh',
     '7f8d15c2c95aafe4cfa5e812fb2f10c431d775ef0d35aecc72946e932f60c1b9',
     'c7277d756929bab28869a7b6caa88a8965714b5a47437a5397f48690601d226b'),
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def regular(path):
    if not path.is_file() or path.is_symlink() or path.resolve() != path:
        raise SystemExit('STOP: redirected or non-regular path: ' + str(path))
    return path


def run(*args, cwd):
    result = subprocess.run(['rtk', 'proxy', *args], cwd=cwd, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit('STOP: command failed: ' + ' '.join(args) + '\n' + result.stderr)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--dry-run', action='store_true')
    modes.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    if pathlib.Path.cwd().resolve() != ROOT:
        raise SystemExit('STOP: wrong owner checkout')
    if run('git', 'rev-parse', 'HEAD', cwd=ROOT).strip() != HEAD:
        raise SystemExit('STOP: HEAD mismatch')
    patch = regular(PATCH).read_bytes()
    if sha(patch) != PATCH_SHA:
        raise SystemExit('STOP: patch hash mismatch')
    names = [line.split()[2].decode() for line in patch.splitlines() if line.startswith(b'diff --git ')]
    if names != ['a/' + row[0] for row in ROWS]:
        raise SystemExit('STOP: patch target mismatch')
    before = {}
    after = {}
    with tempfile.TemporaryDirectory(prefix='sdd423-followup-check-') as staging_name:
        staging = pathlib.Path(staging_name).resolve()
        for rel, old_hash, _ in ROWS:
            data = regular(ROOT / rel).read_bytes()
            if sha(data) != old_hash:
                raise SystemExit('STOP: source changed, partial or already applied: ' + rel)
            before[rel] = data
            copied = staging / rel
            copied.parent.mkdir(parents=True, exist_ok=True)
            copied.write_bytes(data)
        run('git', 'apply', '--unidiff-zero', '--check', str(PATCH), cwd=staging)
        run('git', 'apply', '--unidiff-zero', str(PATCH), cwd=staging)
        for rel, _, new_hash in ROWS:
            data = regular(staging / rel).read_bytes()
            if sha(data) != new_hash:
                raise SystemExit('STOP: postimage mismatch: ' + rel)
            after[rel] = data
            print('CHECKED', rel, 'before=' + sha(before[rel]), 'after=' + sha(data))
    if args.dry_run:
        print('DRY_RUN_OK: three targets; no original files changed')
        return
    backup = pathlib.Path(tempfile.mkdtemp(prefix='postapply-followup-backup-', dir=HERE))
    print('BACKUP', backup, flush=True)
    for rel, _, _ in ROWS:
        source = regular(ROOT / rel)
        if source.read_bytes() != before[rel]:
            raise SystemExit('STOP: source changed before backup: ' + rel)
        saved = backup / rel
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, saved)
        if saved.read_bytes() != before[rel]:
            raise SystemExit('STOP: backup readback mismatch: ' + rel)
    for rel, _, _ in ROWS:
        if regular(ROOT / rel).read_bytes() != before[rel]:
            raise SystemExit('STOP: source changed after backup: ' + rel)
    for rel, _, _ in ROWS:
        target = regular(ROOT / rel)
        if target.read_bytes() != before[rel]:
            raise SystemExit('STOP: concurrent source change; earlier target may be applied: ' + rel)
        target.write_bytes(after[rel])
        if target.read_bytes() != after[rel]:
            raise SystemExit('STOP: immediate readback mismatch; retain backup: ' + rel)
        print('READBACK', rel, sha(after[rel]), flush=True)
    for rel, _, _ in ROWS:
        if regular(ROOT / rel).read_bytes() != after[rel]:
            raise SystemExit('STOP: final readback mismatch; retain backup: ' + rel)
    print('APPLICATION ONLY: no review verdict, evidence admission, task status or Git state change')


if __name__ == '__main__':
    main()
