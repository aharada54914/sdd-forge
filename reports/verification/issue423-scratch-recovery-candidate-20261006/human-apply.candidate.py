"""Released three-target human application under RT-20261006-001.

Agents may run --dry-run only. Management release permits this bounded human
application, not receipt admission, formal evaluation or a task-state change.
"""
import argparse
import hashlib
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge')
HERE = ROOT / 'reports/verification/issue423-scratch-recovery-candidate-20261006'
HEAD = '3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9'
ROWS = (
    ('plugins/sdd-quality-loop/scripts/validate-review-context-set.sh', '134fd5fad980cdbfc08cb18126aea8b4f9f81c8a92e8036338d36609a9a18f6d', 'validator-bash.candidate.txt', 'e59da652db0accb86b93ef00ce763efc83dbc5d0443685d2e1473181d5365ab0'),
    ('plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1', '3f0d4a9d7f3d40c0ab2543d0b8b7a2397b0399429c46b38450a9183cb4ad65f1', 'validator-pwsh.candidate.txt', '9f7a259070605c0520eb48186fcb466d586cdc3f36d63617f17f794f86ecac03'),
    ('plugins/sdd-review-loop/references/review-context-boundary.md', '94cf8bf3ed973cc7240d3fa264b150f3f654642831095eb3d433cb4dc62baab4', 'contract-addendum.candidate.md', 'e72cc24c5fbfffd3668076cf2e374c733ff888dc06224ff2a1c9ce1c6dadfb50'),
)
ADDENDUM_SHA = 'b27f3acb96c21a168930480a873ec17e76beb58e238a67c944d7543286509c2f'
RELEASED = True  # Bounded management release; see bundle-readiness.md.


def sha(data):
    return hashlib.sha256(data).hexdigest()


def regular(path):
    if not path.is_file() or path.is_symlink() or path.resolve() != path:
        raise SystemExit('STOP: redirected or non-regular path: ' + str(path))
    return path


def prepare(rel, before, expected, candidate, after_hash):
    if sha(before) != expected:
        raise SystemExit('STOP: changed, already-applied or partial state: ' + rel)
    if rel.endswith('.md'):
        if sha(candidate) != ADDENDUM_SHA:
            raise SystemExit('STOP: addendum hash mismatch')
        anchor = b'## Same-task evaluator implementation binding\n'
        if before.count(anchor) != 1:
            raise SystemExit('STOP: non-unique contract anchor')
        body = candidate.split(b'\n\n', 2)[2]
        candidate = before.replace(anchor, b'### Same-checkout historical scratch declaration recovery\n\n' + body + b'\n' + anchor)
    if sha(candidate) != after_hash:
        raise SystemExit('STOP: candidate hash mismatch: ' + rel)
    return candidate


def syntax(rel, data):
    if rel.endswith('.md'):
        data.decode('utf-8')
        return
    command = ['rtk', 'proxy', 'bash', '-n']
    if rel.endswith('.ps1'):
        command = ['rtk', 'proxy', 'pwsh', '-NoProfile', '-Command', '$t=$null;$e=$null;[void][System.Management.Automation.Language.Parser]::ParseInput([Console]::In.ReadToEnd(),[ref]$t,[ref]$e);if($e.Count){$e|ForEach-Object{[Console]::Error.WriteLine($_)};exit 1}']
    result = subprocess.run(command, input=data, capture_output=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit('STOP: syntax check failed: ' + rel + '\n' + result.stderr.decode(errors='replace'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--dry-run', action='store_true')
    modes.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    if pathlib.Path.cwd().resolve() != ROOT:
        raise SystemExit('STOP: wrong owner checkout')
    head = subprocess.check_output(['rtk', 'proxy', 'git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if head != HEAD:
        raise SystemExit('STOP: HEAD mismatch; never refresh pins automatically')
    prepared = []
    for rel, old_hash, name, new_hash in ROWS:
        before = regular(ROOT / rel).read_bytes()
        after = prepare(rel, before, old_hash, regular(HERE / name).read_bytes(), new_hash)
        syntax(rel, after)
        prepared.append((rel, before, after))
        print('CHECKED', rel, 'before=' + sha(before), 'after=' + sha(after))
    if args.dry_run:
        print('DRY_RUN_OK: three targets; no application or product execution. Receipt admission and formal evaluation remain pending.')
        return
    # This preparation is deliberately not an application authorization token.
    if not RELEASED:
        raise SystemExit('STOP: bundle NOT RELEASED; complete independent review and formal contract adoption before issuing an application command')
    backup = pathlib.Path(tempfile.mkdtemp(prefix='human-backup-', dir=HERE))
    print('BACKUP', backup, flush=True)
    for rel, before, _ in prepared:
        source = regular(ROOT / rel)
        if source.read_bytes() != before:
            raise SystemExit('STOP: source changed before backup: ' + rel)
        saved = backup / rel
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, saved)
        if saved.read_bytes() != before:
            raise SystemExit('STOP: backup readback mismatch: ' + rel)
    for rel, before, _ in prepared:
        if regular(ROOT / rel).read_bytes() != before:
            raise SystemExit('STOP: source changed after backup: ' + rel)
    for rel, before, after in prepared:
        target = regular(ROOT / rel)
        if target.read_bytes() != before:
            raise SystemExit('STOP: concurrent change; earlier target may be applied: ' + rel)
        target.write_bytes(after)
        if target.read_bytes() != after:
            raise SystemExit('STOP: immediate readback mismatch; retain backup: ' + rel)
        print('READBACK', rel, sha(after), flush=True)
    for rel, _, after in prepared:
        if regular(ROOT / rel).read_bytes() != after:
            raise SystemExit('STOP: final readback mismatch; retain backup: ' + rel)
    print('APPLICATION ONLY. No receipt admission, reservation, review verdict, task status or Git operation.')


if __name__ == '__main__':
    main()
