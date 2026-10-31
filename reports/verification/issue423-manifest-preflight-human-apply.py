"""Human-only protected apply for the Issue 423 preflight binding repair.

Agents may run --dry-run only. This helper checks syntax without executing the
candidate validators. It preserves exact dirty bytes before any protected write.
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
        '2d004b63ba7ec99fa109120c86f91bb7aed7f41b5a461e3b8538b890c7a6aaba',
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1':
        '84264f9eb02a25be788c3fe7660950f9a971d926ae5930089b0ea53746bb6bc7',
}
AFTER_PINS = {
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh':
        '134fd5fad980cdbfc08cb18126aea8b4f9f81c8a92e8036338d36609a9a18f6d',
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1':
        '3f0d4a9d7f3d40c0ab2543d0b8b7a2397b0399429c46b38450a9183cb4ad65f1',
}

OLD_SH = '''if $reserve && [[ "$stage:$role" == quality:sdd-evaluator ]]; then
  verify_implementation_binding
  if jq -e --arg run "$implementation_run" --arg session "$implementation_session" '
    any(.records[]; .run_id == $run or .host_session_id == $session)
  ' "$ledger" >/dev/null; then
    fail IDENTITY 'implementation run/session is reused in the canonical review ledger'
  fi
  [[ "$run_id" != "$implementation_run" && "$host_session_id" != "$implementation_session" ]] ||
    fail IDENTITY 'evaluator reuses implementation run/session'
fi
'''.encode()
NEW_SH = '''if [[ "$stage:$role" == quality:sdd-evaluator ]]; then
  if [[ -n "$implementation_manifest_path" ]] || $reserve; then
    verify_implementation_binding
  fi
  if $reserve; then
    if jq -e --arg run "$implementation_run" --arg session "$implementation_session" '
    any(.records[]; .run_id == $run or .host_session_id == $session)
    ' "$ledger" >/dev/null; then
      fail IDENTITY 'implementation run/session is reused in the canonical review ledger'
    fi
    [[ "$run_id" != "$implementation_run" && "$host_session_id" != "$implementation_session" ]] ||
      fail IDENTITY 'evaluator reuses implementation run/session'
  fi
fi
'''.encode()

OLD_PS = '''    if ($Reserve -and "$($document.stage):$($document.role)" -ceq 'quality:sdd-evaluator') {
        $implementation = Get-ImplementationBinding
        if (@($records | Where-Object {
            $_.run_id -ceq $implementation.run_id -or $_.host_session_id -ceq $implementation.session_id
        }).Count -gt 0) {
            Fail-ReviewContext 'IDENTITY' 'implementation run/session is reused in the canonical review ledger'
        }
        if ($document.run_id -ceq $implementation.run_id -or
            $document.host_session_id -ceq $implementation.session_id) {
            Fail-ReviewContext 'IDENTITY' 'evaluator reuses implementation run/session'
        }
    }
'''.encode()
NEW_PS = '''    if ("$($document.stage):$($document.role)" -ceq 'quality:sdd-evaluator') {
        if ($document.ContainsKey('implementation_manifest') -or $Reserve) {
            $implementation = Get-ImplementationBinding
        }
        if ($Reserve) {
            if (@($records | Where-Object {
                $_.run_id -ceq $implementation.run_id -or $_.host_session_id -ceq $implementation.session_id
            }).Count -gt 0) {
                Fail-ReviewContext 'IDENTITY' 'implementation run/session is reused in the canonical review ledger'
            }
            if ($document.run_id -ceq $implementation.run_id -or
                $document.host_session_id -ceq $implementation.session_id) {
                Fail-ReviewContext 'IDENTITY' 'evaluator reuses implementation run/session'
            }
        }
    }
'''.encode()

CHANGES = {
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh': (OLD_SH, NEW_SH),
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1': (OLD_PS, NEW_PS),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_path(rel):
    path = ROOT / rel
    if not path.is_file() or path.is_symlink() or path.resolve() != path:
        raise SystemExit('STOP: non-regular or redirected target: ' + rel)
    return path


def syntax_check(rel, candidate):
    if rel.endswith('.sh'):
        command = ['rtk', 'proxy', 'bash', '-n']
    else:
        parser = ('$t=$null;$e=$null;'
                  '[void][System.Management.Automation.Language.Parser]::ParseInput('
                  '[Console]::In.ReadToEnd(),[ref]$t,[ref]$e);'
                  'if($e.Count -ne 0){$e|ForEach-Object{'
                  '[Console]::Error.WriteLine($_.ToString())};exit 1}')
        command = ['rtk', 'proxy', 'pwsh', '-NoProfile', '-Command', parser]
    result = subprocess.run(command, input=candidate.decode(), text=True,
                            capture_output=True, cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit('STOP: candidate syntax failure: ' + rel + '\n' +
                         result.stdout + result.stderr)
    print('SYNTAX_OK', rel, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--dry-run', action='store_true')
    mode.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    if pathlib.Path.cwd().resolve() != ROOT:
        raise SystemExit('STOP: run from the exact owner checkout')
    head = subprocess.check_output(['rtk', 'proxy', 'git', 'rev-parse', 'HEAD'],
                                   cwd=ROOT, text=True).strip()
    if head != HEAD:
        raise SystemExit('STOP: HEAD mismatch; do not refresh pins automatically')
    prepared = []
    for rel, expected in PINS.items():
        path = checked_path(rel)
        before = path.read_bytes()
        if sha(before) != expected:
            raise SystemExit('STOP: base hash mismatch or repeat apply: ' + rel)
        old, new = CHANGES[rel]
        if before.count(old) != 1 or before.count(new) != 0:
            raise SystemExit('STOP: replacement anchor is not unique: ' + rel)
        after = before.replace(old, new, 1)
        if sha(after) != AFTER_PINS[rel]:
            raise SystemExit('STOP: candidate after hash mismatch: ' + rel)
        syntax_check(rel, after)
        prepared.append((rel, before, after))
        print('PIN', rel, 'before=' + sha(before), 'after=' + sha(after))
        print(''.join(difflib.unified_diff(before.decode().splitlines(True),
                                          after.decode().splitlines(True),
                                          fromfile='a/' + rel, tofile='b/' + rel)), end='')
    if args.dry_run:
        print('DRY_RUN_OK: exactly 2 targets; no protected files written or product code executed')
        return
    # Only a human may invoke this mode outside the agent executor.
    backup = pathlib.Path(tempfile.mkdtemp(prefix='issue423-manifest-preflight-backup-',
                                           dir=ROOT / 'reports/verification'))
    print('BACKUP', backup, flush=True)
    for rel, before, _ in prepared:
        path = checked_path(rel)
        if path.read_bytes() != before:
            raise SystemExit('STOP: source changed before backup: ' + rel)
        saved = backup / rel
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, saved)
        if saved.read_bytes() != before:
            raise SystemExit('STOP: backup readback mismatch: ' + rel)
    for rel, before, _ in prepared:
        if checked_path(rel).read_bytes() != before:
            raise SystemExit('STOP: source changed after backup: ' + rel)
    for rel, before, after in prepared:
        path = checked_path(rel)
        if path.read_bytes() != before:
            raise SystemExit('STOP: concurrent change; earlier target may be applied: ' + rel)
        path.write_bytes(after)
        if path.read_bytes() != after or sha(path.read_bytes()) != AFTER_PINS[rel]:
            raise SystemExit('STOP: immediate readback mismatch; retain backup: ' + rel)
        print('APPLIED_READBACK_OK', rel, sha(after), flush=True)
    for rel, _, after in prepared:
        current = checked_path(rel).read_bytes()
        if current != after or sha(current) != AFTER_PINS[rel]:
            raise SystemExit('STOP: final readback mismatch; retain backup: ' + rel)
    print('APPLIED_ONCE; NOT VERIFIED. Retain backup and run behavioral regressions.')


if __name__ == '__main__':
    main()
