"""Human-only protected apply. Agents may run --dry-run ONLY.

No product code is executed. No existing repair script is invoked.
Backups preserve the current dirty bytes; no automatic rollback overwrites work.
"""
import argparse
import difflib
import hashlib
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge')
HEAD = '3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9'
PINS = {
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh':
        '011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b',
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1':
        'e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925',
    'plugins/sdd-review-loop/references/review-context-boundary.md':
        '07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a',
}
OLD = b'^handoffs/[A-Za-z0-9._-]+/manifest[.]json$'
NEW = b'^handoffs/[A-Za-z0-9._-]+/manifest(-[A-Za-z0-9][A-Za-z0-9_-]*)?[.]json$'
ANCHOR = (b'The pinned implementation manifest binds task/run/session identity to the\n'
          b'implementation report; its allowed_inputs do not authorize evaluator inputs.\n')
ADDITION = (b'Its path is `handoffs/<directory>/manifest.json` or\n'
            b'`handoffs/<directory>/manifest-<version>.json`, where `<version>` starts with\n'
            b'an ASCII alphanumeric character and otherwise contains only ASCII alphanumeric\n'
            b'characters, `_`, or `-`. Versioned names preserve historical manifests during\n'
            b'approved recovery; they do not relax exact path/hash pins, report citation,\n'
            b'task/run/session binding, or input authorization. Never substitute an older\n'
            b'manifest merely because its basename is `manifest.json`.\n')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_path(rel):
    path = ROOT / rel
    if not path.is_file() or path.resolve() != path or path.is_symlink():
        raise SystemExit('STOP: non-regular or redirected target: ' + rel)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--dry-run', action='store_true')
    mode.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    if pathlib.Path.cwd().resolve() != ROOT:
        raise SystemExit('STOP: run from the exact owner checkout')
    head = subprocess.check_output(['rtk', 'proxy', 'git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if head != HEAD:
        raise SystemExit('STOP: HEAD mismatch; do not refresh pins automatically')
    prepared = []
    for rel, expected in PINS.items():
        path = checked_path(rel)
        before = path.read_bytes()
        if sha(before) != expected:
            raise SystemExit('STOP: base hash mismatch: ' + rel)
        old, new = (ANCHOR, ANCHOR + ADDITION) if rel.endswith('.md') else (OLD, NEW)
        if before.count(old) != 1:
            raise SystemExit('STOP: replacement anchor is not unique: ' + rel)
        after = before.replace(old, new, 1)
        prepared.append((rel, before, after))
        print('PIN', rel, 'before=' + sha(before), 'after=' + sha(after))
        print(''.join(difflib.unified_diff(before.decode().splitlines(True), after.decode().splitlines(True),
                                         fromfile='a/' + rel, tofile='b/' + rel)), end='')
    if args.dry_run:
        print('DRY_RUN_OK: exactly 3 targets; no files written; no product execution')
        return
    # Only a human may invoke this mode outside the agent executor.
    backup = pathlib.Path(tempfile.mkdtemp(prefix='issue423-manifest-binding-backup-',
                                         dir=ROOT / 'reports/verification'))
    print('BACKUP', backup, flush=True)
    for rel, before, after in prepared:
        path = checked_path(rel)
        if path.read_bytes() != before:
            raise SystemExit('STOP: source changed before backup: ' + rel)
        saved = backup / rel
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, saved)
        if saved.read_bytes() != before:
            raise SystemExit('STOP: backup readback mismatch: ' + rel)
    for rel, before, after in prepared:
        if checked_path(rel).read_bytes() != before:
            raise SystemExit('STOP: source changed after backup: ' + rel)
    for rel, before, after in prepared:
        path = checked_path(rel)
        if path.read_bytes() != before:
            raise SystemExit('STOP: concurrent change; earlier targets may be applied: ' + rel)
        path.write_bytes(after)
        if path.read_bytes() != after:
            raise SystemExit('STOP: readback mismatch; retain backup: ' + rel)
        print('APPLIED_READBACK_OK', rel, sha(after), flush=True)
    print('APPLIED_ONCE; NOT VERIFIED. Retain backup and run behavioral regressions.')


if __name__ == '__main__':
    main()
