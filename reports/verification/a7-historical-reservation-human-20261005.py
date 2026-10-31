#!/usr/bin/env python3
"""Human-only, hash-pinned caller repair. Default: inspect without applying."""
import argparse
import difflib
import hashlib
from pathlib import Path
import tempfile

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
HELPER = ROOT / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'
HELPER_SHA = '2cff54f410ead4c1904808f97aaa8d8b852ee95cf37c95a45fad838ff84621a3'
CHANGES = [
    ('plugins/sdd-review-loop/scripts/spec-review-precheck.sh',
     '13edd6165b011ee877eadb84d4cc39b5a0243c24bfd37cfb1b9490d1781bac62', [
         ('  local result terminal_dir terminal_attempt terminal_round terminal_verdict invocation\n',
          '  local result terminal_dir terminal_attempt terminal_round terminal_verdict\n'),
         ('''  while IFS= read -r invocation; do
    "${repo_root}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh" "${repo_root}/${invocation}" "$repo_root" >/dev/null || fail "fresh-review reservation is invalid"
  done < <(jq -r '.invocations[]' <<< "$result")
''', '''  # The helper verifies historical reservations against their pinned inputs.
  # Ordinary launch validation would compare them with amended files.
''')]),
    ('plugins/sdd-review-loop/scripts/spec-review-precheck.ps1',
     'ca23b15becbf404038d3dca0b2ea407d96695fa74ee34af0febebe17938a9d08', [
         ('''  foreach ($invocation in $data.invocations) {
    $validator = Join-Path $root 'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1'
    $checked = & (Join-Path $PSHOME 'pwsh') -NoProfile -File $validator -Manifest (Join-Path $root $invocation) -RepositoryRoot $root 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (($checked -join "`n") -cmatch '^REVIEW_CONTEXT_OK ')) { Fail 'fresh-review reservation is invalid' }
  }
''', '''  # The helper verifies historical reservations against their pinned inputs.
  # Ordinary launch validation would compare them with amended files.
''')]),
    ('plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md',
     'd96ad1d3d09fea82b859e34b92ff46a910168f3c3148e0bb9a3c7fddfcc7e158', [
         ('''The precheck validates the historical terminal contract and every persisted
reservations, then repeats all admission checks under the transition lock.
These validators establish preserved-record integrity, not legality of the
intervening transitions. It does not reserve an identity or produce a verdict.
''', '''The recovery helper validates every historical reservation against its pinned
precheck, manifest and identity-ledger chain, not against amended current files.
The precheck validates the historical terminal contract and current input hashes,
then repeats all admission checks under the transition lock. These checks establish
preserved-record integrity, not legality of the intervening transitions. Ordinary
new-review launch validation remains unchanged. Recovery does not reserve an
identity or produce a verdict.
''')]),
]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    if (HELPER.is_symlink() or not HELPER.is_file() or HELPER.resolve() != HELPER
            or sha(HELPER.read_bytes()) != HELPER_SHA):
        raise SystemExit('STOP: historical helper mismatch; no apply')
    prepared = []
    for rel, expected, edits in CHANGES:
        target = ROOT / rel
        if target.is_symlink() or not target.is_file() or target.resolve() != target:
            raise SystemExit('STOP: noncanonical target: ' + rel)
        before = target.read_bytes()
        if sha(before) != expected:
            raise SystemExit('STOP: hash mismatch; no apply: ' + rel)
        after = before
        for old, new in edits:
            if after.count(old.encode()) != 1:
                raise SystemExit('STOP: anchor not unique: ' + rel)
            after = after.replace(old.encode(), new.encode(), 1)
        prepared.append((rel, target, before, after))
        print('CANDIDATE', rel, sha(after))
        if not args.apply_human:
            print(''.join(difflib.unified_diff(before.decode().splitlines(True),
                  after.decode().splitlines(True), fromfile=rel, tofile=rel)), end='')
    if not args.apply_human:
        print('DRY_RUN_OK; no files changed')
        return
    backup = Path(tempfile.mkdtemp(prefix='a7-history-caller-backup-'))
    for rel, target, before, after in prepared:
        saved = backup / rel
        saved.parent.mkdir(parents=True, exist_ok=True)
        saved.write_bytes(before)
        if saved.read_bytes() != before or target.read_bytes() != before:
            raise SystemExit('STOP: backup or target mismatch: ' + str(backup))
    print('BACKUP:', backup)
    if sha(HELPER.read_bytes()) != HELPER_SHA:
        raise SystemExit('STOP: historical helper changed; no apply')
    for rel, target, before, after in prepared:
        if target.read_bytes() != before:
            raise SystemExit('STOP: target changed; backup=' + str(backup))
        target.write_bytes(after)
        if target.read_bytes() != after:
            raise SystemExit('STOP: readback mismatch; backup=' + str(backup))
        print('APPLIED', rel, sha(after))
    print('Application only. Tests, formal review, CI and merge remain pending.')
    print('No reservation, review verdict, task status or Git operation performed.')

if __name__ == '__main__':
    main()
