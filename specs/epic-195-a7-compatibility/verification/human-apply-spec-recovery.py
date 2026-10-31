#!/usr/bin/env python3
"""Human-only, hash-fixed patch candidate for interrupted spec-review recovery.

The agent must not run --apply: the native PreToolUse gate denied edits to the
protected Bash precheck. --check reads target files and prints candidate diffs.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import pathlib
import shutil
import subprocess
import sys
import time


ROOT = pathlib.Path(__file__).resolve().parents[3]
TARGETS = {
    "plugins/sdd-review-loop/scripts/spec-review-precheck.sh": "81e345db1d1d96acec6a5ddd2159e01d6653cfb879ad2cf2a032e20b887b4c1b",
    "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1": "ac2532f6450dde24b78e4ab7b577a04ef9b1e8d165a180152737789b5ac6fb85",
    "plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md": "b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one exact anchor, found {count}")
    return text.replace(old, new, 1)


def patch_sh(text: str) -> str:
    text = replace_once(text,
        'spec-review-precheck.sh <feature-slug> <attempt> <round> [--edit-summary=<text>] [--reset]',
        'spec-review-precheck.sh <feature-slug> <attempt> <round> [--edit-summary=<text>] [--reset] [--recover-interrupted]',
        'sh usage')
    text = replace_once(text, 'edit_summary=""; reset=false\n',
        'edit_summary=""; reset=false; recover_interrupted=false\n', 'sh argument state')
    text = replace_once(text, '    --reset) reset=true ;;\n',
        '    --reset) reset=true ;;\n    --recover-interrupted) recover_interrupted=true ;;\n', 'sh argument')
    text = replace_once(text,
        'fi\n\nrepo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"',
        'fi\n[[ "$recover_interrupted" == false || "$reset" == true ]] || fail "--recover-interrupted requires --reset"\n\nrepo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"',
        'sh argument constraint')
    old = '''  previous_verdict="$(jq -r '.verdict // empty' "${previous_dir}/spec-review-contract.json" 2>/dev/null || true)"
  [[ "$previous_verdict" == "PASS" || "$previous_verdict" == "BLOCKED" ]] || fail "reset requires a terminal PASS or BLOCKED contract"
  validate_contract "${previous_dir}/spec-review-contract.json" "$((attempt - 1))" "$previous_round" "$previous_verdict" "${previous_dir}/precheck-result.json" \\
    || fail "previous terminal contract is invalid"
'''
    new = '''  if [[ "$recover_interrupted" == true ]]; then
    [[ "$previous_round" == 1 && "$attempt" -gt 2 ]] || fail "recovery requires one interrupted reset round after a terminal attempt"
    recover_dir="$previous_dir"
    recover_precheck="${recover_dir}/precheck-result.json"
    recover_allocation="${recover_dir}/reviewer-a-host-allocation.json"
    recover_note="${recover_dir}/launch-blocker-note.md"
    for source in "$recover_precheck" "$recover_allocation" "$recover_note"; do
      [[ -f "$source" && ! -L "$source" ]] || fail "interrupted source evidence is missing or non-regular"
    done
    recover_inventory="$(find "$recover_dir" -mindepth 1 -maxdepth 1 -print | sed "s#^${recover_dir}/##" | sort)"
    [[ "$recover_inventory" == $'launch-blocker-note.md\\nprecheck-result.json\\nreviewer-a-host-allocation.json' ]] \\
      || fail "interrupted source contains reviewer or unexpected evidence"
    jq -e --arg feature "$feature" --argjson attempt "$((attempt - 1))" '
      type == "object" and .schema == "spec-review-precheck/v1" and .stage == "spec" and
      .feature == $feature and .attempt == $attempt and .round == 1 and
      .reset == true and .spec_review_status_field == "Pending" and
      ([.requirements_sha256,.acceptance_sha256,.calibration_sha256,.input_sha256] |
        all(.[]; type == "string" and test("^[0-9a-f]{64}$"))) and
      (.investigation_sha256 == null or (.investigation_sha256 | type == "string" and test("^[0-9a-f]{64}$")))' \\
      "$recover_precheck" >/dev/null || fail "interrupted precheck is invalid"
    recover_precheck_sha="$(sha256 "$recover_precheck")"
    recover_invocation="${reports_root}/review-context/${feature}-spec-a$((attempt - 1))r1-a-invocation.json"
    [[ -f "$recover_invocation" && ! -L "$recover_invocation" ]] || fail "interrupted reviewer-A invocation is missing"
    [[ ! -e "${reports_root}/review-context/${feature}-spec-a$((attempt - 1))r1-b-invocation.json" ]] \\
      || fail "interrupted round already has reviewer-B invocation"
    jq -e --arg feature "$feature" --arg path "$(relative_to_repo "$recover_precheck")" --arg hash "$recover_precheck_sha" '
      type == "object" and .schema == "review-context-invocation/v2" and
      .stage == "spec" and .feature == $feature and .role == "spec-reviewer-a" and
      .read_only == true and
      ([.allowed_input_manifest[] | select(.path == $path and .sha256 == $hash)] | length) == 1' \\
      "$recover_invocation" >/dev/null || fail "interrupted invocation does not bind its precheck"
    "${repo_root}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh" "$recover_invocation" "$repo_root" >/dev/null \\
      || fail "interrupted invocation is not a valid persisted reservation"
    jq -e --arg feature "$feature" --argjson attempt "$((attempt - 1))" \\
      --arg run "$(jq -r .run_id "$recover_invocation")" --arg session "$(jq -r .host_session_id "$recover_invocation")" '
      .feature == $feature and .attempt == $attempt and .round == 1 and
      .role == "spec-reviewer-a" and .host_id == $run and .host_session_id == $session' \\
      "$recover_allocation" >/dev/null || fail "interrupted host receipt does not match reservation"
    recover_invocation_sha="$(sha256 "$recover_invocation")"
    recover_allocation_sha="$(sha256 "$recover_allocation")"
    previous_attempt="${report_root}/attempt-$((attempt - 2))"
    [[ -d "$previous_attempt" && ! -L "$previous_attempt" ]] || fail "recovery requires an earlier terminal attempt"
    previous_round="$(find "$previous_attempt" -maxdepth 1 -type d -name 'round-*' -print | sed -n 's#.*/round-\\([1-3]\\)$#\\1#p' | sort -n | tail -1)"
    [[ -n "$previous_round" ]] || fail "earlier attempt has no terminal round"
    previous_dir="${previous_attempt}/round-${previous_round}"
    previous_verdict="$(jq -r '.verdict // empty' "${previous_dir}/spec-review-contract.json" 2>/dev/null || true)"
    [[ "$previous_verdict" == "PASS" || "$previous_verdict" == "BLOCKED" ]] || fail "earlier attempt is not terminal"
    validate_contract "${previous_dir}/spec-review-contract.json" "$((attempt - 2))" "$previous_round" "$previous_verdict" "${previous_dir}/precheck-result.json" \\
      || fail "earlier terminal contract is invalid"
  else
    previous_verdict="$(jq -r '.verdict // empty' "${previous_dir}/spec-review-contract.json" 2>/dev/null || true)"
    [[ "$previous_verdict" == "PASS" || "$previous_verdict" == "BLOCKED" ]] || fail "reset requires a terminal PASS or BLOCKED contract"
    validate_contract "${previous_dir}/spec-review-contract.json" "$((attempt - 1))" "$previous_round" "$previous_verdict" "${previous_dir}/precheck-result.json" \\
      || fail "previous terminal contract is invalid"
  fi
'''
    text = replace_once(text, old, new, 'sh reset transition')
    text = replace_once(text,
        '[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"\nmkdir -p "$report_dir"',
        '''[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"
if [[ "$recover_interrupted" == true ]]; then
  [[ "$recover_precheck_sha" == "$(sha256 "$recover_precheck")" &&
     "$recover_invocation_sha" == "$(sha256 "$recover_invocation")" &&
     "$recover_allocation_sha" == "$(sha256 "$recover_allocation")" ]] || fail "interrupted evidence changed during recovery"
  [[ "$recover_inventory" == "$(find "$recover_dir" -mindepth 1 -maxdepth 1 -print | sed "s#^${recover_dir}/##" | sort)" ]] \\
    || fail "interrupted round changed during recovery"
fi
mkdir -p "$report_dir"''', 'sh locked recheck')
    return text


def patch_ps1(text: str) -> str:
    text = replace_once(text,
        '[-EditSummary <text>] [-Reset]',
        '[-EditSummary <text>] [-Reset] [-RecoverInterrupted]', 'ps1 usage')
    text = replace_once(text,
        "  [switch]$Reset\n)",
        "  [switch]$Reset,\n  [switch]$RecoverInterrupted\n)", 'ps1 parameter')
    text = replace_once(text,
        "if ($Reset) {\n  if (-not ($attemptInt -gt 1 -and $roundInt -eq 1)) { Fail '--reset starts only attempt N+1 round 1' }\n} else {\n  if (-not ($attemptInt -eq 1 -or $roundInt -gt 1)) { Fail 'a new attempt requires --reset' }\n}\n",
        "if ($Reset) {\n  if (-not ($attemptInt -gt 1 -and $roundInt -eq 1)) { Fail '--reset starts only attempt N+1 round 1' }\n} else {\n  if (-not ($attemptInt -eq 1 -or $roundInt -gt 1)) { Fail 'a new attempt requires --reset' }\n}\nif ($RecoverInterrupted -and -not $Reset) { Fail '-RecoverInterrupted requires -Reset' }\n",
        'ps1 argument constraint')
    old = '''  $previousVerdict = $null
  if (Test-Path -LiteralPath $previousContractPath -PathType Leaf) {
    try { $previousVerdict = (Get-Content -LiteralPath $previousContractPath -Raw | ConvertFrom-Json).verdict } catch { $previousVerdict = $null }
  }
  if (-not (Test-OrdinalEqual $previousVerdict 'PASS') -and -not (Test-OrdinalEqual $previousVerdict 'BLOCKED')) { Fail 'reset requires a terminal PASS or BLOCKED contract' }
  if (-not (Test-ValidateContract -ContractPath $previousContractPath -ExpectedAttempt ($attemptInt - 1) -ExpectedRound $previousRound -ExpectedVerdict $previousVerdict -PrecheckPath (Join-Path $previousDir 'precheck-result.json'))) {
    Fail 'previous terminal contract is invalid'
  }
'''
    new = '''  if ($RecoverInterrupted) {
    if ($previousRound -ne 1 -or $attemptInt -le 2) { Fail 'recovery requires one interrupted reset round after a terminal attempt' }
    $recoverDir = $previousDir
    $recoverPrecheck = Join-Path $recoverDir 'precheck-result.json'
    $recoverAllocation = Join-Path $recoverDir 'reviewer-a-host-allocation.json'
    $recoverNote = Join-Path $recoverDir 'launch-blocker-note.md'
    foreach ($source in @($recoverPrecheck, $recoverAllocation, $recoverNote)) {
      if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Test-IsSymlink $source)) { Fail 'interrupted source evidence is missing or non-regular' }
    }
    $recoverInventory = @((Get-ChildItem -LiteralPath $recoverDir -Force | ForEach-Object { $_.Name }) | Sort-Object -CaseSensitive)
    if (($recoverInventory -join ',') -cne 'launch-blocker-note.md,precheck-result.json,reviewer-a-host-allocation.json') {
      Fail 'interrupted source contains reviewer or unexpected evidence'
    }
    try { $recoverData = Get-Content -LiteralPath $recoverPrecheck -Raw | ConvertFrom-Json } catch { Fail 'interrupted precheck is invalid' }
    if (-not (Test-OrdinalEqual $recoverData.schema 'spec-review-precheck/v1') -or
        -not (Test-OrdinalEqual $recoverData.stage 'spec') -or
        -not (Test-OrdinalEqual $recoverData.feature $Feature) -or
        -not (Test-JsonIntegerEquals $recoverData.attempt ($attemptInt - 1)) -or
        -not (Test-JsonIntegerEquals $recoverData.round 1) -or
        $recoverData.reset -cne $true -or
        -not (Test-OrdinalEqual $recoverData.spec_review_status_field 'Pending')) { Fail 'interrupted precheck is invalid' }
    foreach ($hash in @($recoverData.requirements_sha256, $recoverData.acceptance_sha256, $recoverData.calibration_sha256, $recoverData.input_sha256)) {
      if ([string]$hash -cnotmatch '^[0-9a-f]{64}$') { Fail 'interrupted precheck hash is invalid' }
    }
    if ($null -ne $recoverData.investigation_sha256 -and [string]$recoverData.investigation_sha256 -cnotmatch '^[0-9a-f]{64}$') {
      Fail 'interrupted investigation hash is invalid'
    }
    $recoverPrecheckSha = Get-Sha256File $recoverPrecheck
    $recoverInvocation = Join-Path $reportsRoot "review-context/$Feature-spec-a$($attemptInt - 1)r1-a-invocation.json"
    $recoverBInvocation = Join-Path $reportsRoot "review-context/$Feature-spec-a$($attemptInt - 1)r1-b-invocation.json"
    if (-not (Test-Path -LiteralPath $recoverInvocation -PathType Leaf) -or (Test-IsSymlink $recoverInvocation)) { Fail 'interrupted reviewer-A invocation is missing' }
    if (Test-Path -LiteralPath $recoverBInvocation) { Fail 'interrupted round already has reviewer-B invocation' }
    try { $invocationData = Get-Content -LiteralPath $recoverInvocation -Raw | ConvertFrom-Json } catch { Fail 'interrupted invocation is invalid' }
    $recoverRelativePrecheck = "reports/spec-review/$Feature/attempt-$($attemptInt - 1)/round-1/precheck-result.json"
    $bound = @($invocationData.allowed_input_manifest | Where-Object {
      (Test-OrdinalEqual $_.path $recoverRelativePrecheck) -and (Test-OrdinalEqual $_.sha256 $recoverPrecheckSha)
    })
    if (-not (Test-OrdinalEqual $invocationData.schema 'review-context-invocation/v2') -or
        -not (Test-OrdinalEqual $invocationData.stage 'spec') -or
        -not (Test-OrdinalEqual $invocationData.feature $Feature) -or
        -not (Test-OrdinalEqual $invocationData.role 'spec-reviewer-a') -or
        $invocationData.read_only -cne $true -or $bound.Count -ne 1) {
      Fail 'interrupted invocation does not bind its precheck'
    }
    $validator = Join-Path $root 'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1'
    $contextResult = & $validator -Manifest $recoverInvocation -RepositoryRoot $root 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (($contextResult -join "`n") -cmatch '^REVIEW_CONTEXT_OK ')) {
      Fail 'interrupted invocation is not a valid persisted reservation'
    }
    try { $allocationData = Get-Content -LiteralPath $recoverAllocation -Raw | ConvertFrom-Json } catch { Fail 'interrupted host receipt is invalid' }
    if (-not (Test-OrdinalEqual $allocationData.feature $Feature) -or
        -not (Test-JsonIntegerEquals $allocationData.attempt ($attemptInt - 1)) -or
        -not (Test-JsonIntegerEquals $allocationData.round 1) -or
        -not (Test-OrdinalEqual $allocationData.role 'spec-reviewer-a') -or
        -not (Test-OrdinalEqual $allocationData.host_id $invocationData.run_id) -or
        -not (Test-OrdinalEqual $allocationData.host_session_id $invocationData.host_session_id)) {
      Fail 'interrupted host receipt does not match reservation'
    }
    $recoverInvocationSha = Get-Sha256File $recoverInvocation
    $recoverAllocationSha = Get-Sha256File $recoverAllocation
    $earlierAttempt = Join-Path $reportRoot "attempt-$($attemptInt - 2)"
    if (-not (Test-RealDirectory $earlierAttempt)) { Fail 'recovery requires an earlier terminal attempt' }
    $earlierRounds = @(Get-ChildItem -LiteralPath $earlierAttempt -Directory | Where-Object { $_.Name -cmatch '^round-[1-3]$' } |
      ForEach-Object { [int]($_.Name -creplace '^round-', '') } | Sort-Object)
    if ($earlierRounds.Count -eq 0) { Fail 'earlier attempt has no terminal round' }
    $earlierRound = $earlierRounds[-1]
    $earlierDir = Join-Path $earlierAttempt "round-$earlierRound"
    $earlierContractPath = Join-Path $earlierDir 'spec-review-contract.json'
    try { $earlierVerdict = (Get-Content -LiteralPath $earlierContractPath -Raw | ConvertFrom-Json).verdict } catch { Fail 'earlier attempt is not terminal' }
    if (-not (Test-OrdinalEqual $earlierVerdict 'PASS') -and -not (Test-OrdinalEqual $earlierVerdict 'BLOCKED')) { Fail 'earlier attempt is not terminal' }
    if (-not (Test-ValidateContract -ContractPath $earlierContractPath -ExpectedAttempt ($attemptInt - 2) -ExpectedRound $earlierRound -ExpectedVerdict $earlierVerdict -PrecheckPath (Join-Path $earlierDir 'precheck-result.json'))) {
      Fail 'earlier terminal contract is invalid'
    }
  } else {
    $previousVerdict = $null
    if (Test-Path -LiteralPath $previousContractPath -PathType Leaf) {
      try { $previousVerdict = (Get-Content -LiteralPath $previousContractPath -Raw | ConvertFrom-Json).verdict } catch { $previousVerdict = $null }
    }
    if (-not (Test-OrdinalEqual $previousVerdict 'PASS') -and -not (Test-OrdinalEqual $previousVerdict 'BLOCKED')) { Fail 'reset requires a terminal PASS or BLOCKED contract' }
    if (-not (Test-ValidateContract -ContractPath $previousContractPath -ExpectedAttempt ($attemptInt - 1) -ExpectedRound $previousRound -ExpectedVerdict $previousVerdict -PrecheckPath (Join-Path $previousDir 'precheck-result.json'))) {
      Fail 'previous terminal contract is invalid'
    }
  }
'''
    text = replace_once(text, old, new, 'ps1 reset transition')
    text = replace_once(text,
        "  if (Test-Path -LiteralPath $reportDir) { Fail 'round destination already exists (replay is forbidden)' }\n  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null",
        '''  if (Test-Path -LiteralPath $reportDir) { Fail 'round destination already exists (replay is forbidden' }\n  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null'''.replace("(replay is forbidden'", "(replay is forbidden)'").replace("  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null", '''  if ($RecoverInterrupted) {
    $currentInventory = @((Get-ChildItem -LiteralPath $recoverDir -Force | ForEach-Object { $_.Name }) | Sort-Object -CaseSensitive)
    if (-not (Test-OrdinalEqual $recoverPrecheckSha (Get-Sha256File $recoverPrecheck)) -or
        -not (Test-OrdinalEqual $recoverInvocationSha (Get-Sha256File $recoverInvocation)) -or
        -not (Test-OrdinalEqual $recoverAllocationSha (Get-Sha256File $recoverAllocation)) -or
        ($recoverInventory -join ',') -cne ($currentInventory -join ',')) { Fail 'interrupted evidence changed during recovery' }
    $contextResult = & $validator -Manifest $recoverInvocation -RepositoryRoot $root 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (($contextResult -join "`n") -cmatch '^REVIEW_CONTEXT_OK ')) { Fail 'interrupted reservation changed during recovery' }
  }
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null'''), 'ps1 locked recheck')
    return text


def patch_skill(text: str) -> str:
    text = replace_once(text,
        'spec-review-loop <feature-slug> [--edit-summary="..."] [--reset]',
        'spec-review-loop <feature-slug> [--edit-summary="..."] [--reset] [--recover-interrupted]',
        'skill invocation')
    text = replace_once(text,
        '''The precheck validates canonical paths, slug and positive counters, status,
input hashes, immutable destination, lock, and legal state transition. Stop on
any error; do not write a report or status field. It records canonical hashes
used by the shared review-contract validation foundation.
''',
        '''The precheck validates canonical paths, slug and positive counters, status,
input hashes, immutable destination, lock, and legal state transition. Stop on
any error; do not write a report or status field. It records canonical hashes
used by the shared review-contract validation foundation.

For a specifically authorized first-round launch interruption following a
validated reset, `--reset --recover-interrupted` may open only the next attempt's
round 1. It requires the interrupted prior round's original precheck, host
allocation, blocker note, reviewer-A invocation and valid persisted reservation,
with no reviewer or integrated output or reviewer-B invocation. It revalidates
the attempt *before* the interruption as terminal PASS/BLOCKED and preserves
all interrupted evidence. It does not grant a terminal verdict to the
interrupted attempt, release its reviewer identity, or permit a replay. An
attempt-1 interruption without an earlier terminal attempt is outside this
limited recovery path. New reviewers require fresh host-issued identities and
the ordinary manifest reservation sequence below.
''', 'skill recovery precondition')
    text = replace_once(text,
        '| Pending, blocked or completed attempt | `--reset`, next attempt round 1 | preserve prior evidence and retain Pending |\n',
        '| Pending, blocked or completed attempt | `--reset`, next attempt round 1 | preserve prior evidence and retain Pending |\n| Pending, specifically authorized interrupted reset round 1 with no reviewer output | `--reset --recover-interrupted`, next attempt round 1 | preserve the consumed identity and old evidence; rehash current inputs for a fresh attempt |\n',
        'skill transition table')
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true', help='human-only authorized apply')
    args = parser.parse_args()
    transforms = {
        'plugins/sdd-review-loop/scripts/spec-review-precheck.sh': patch_sh,
        'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1': patch_ps1,
        'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md': patch_skill,
    }
    originals = {}
    candidates = {}
    for relative, expected in TARGETS.items():
        path = ROOT / relative
        if path.is_symlink() or not path.is_file():
            raise RuntimeError(f'{relative}: target must be a regular non-symlink file')
        raw = path.read_bytes()
        if sha256(raw) != expected:
            raise RuntimeError(f'{relative}: old SHA-256 changed; stop and rebase')
        originals[relative] = raw
        candidates[relative] = transforms[relative](raw.decode('utf-8')).encode('utf-8')
    if not args.apply:
        for relative, candidate in candidates.items():
            diff = difflib.unified_diff(originals[relative].decode().splitlines(True),
                                        candidate.decode().splitlines(True),
                                        fromfile=f'a/{relative}', tofile=f'b/{relative}')
            sys.stdout.writelines(diff)
    else:
        for relative, candidate in candidates.items():
            print(f'CANDIDATE {relative} sha256={sha256(candidate)}')
    sh_candidate = candidates['plugins/sdd-review-loop/scripts/spec-review-precheck.sh']
    ps_candidate = candidates['plugins/sdd-review-loop/scripts/spec-review-precheck.ps1']
    sh_syntax = subprocess.run(['bash', '-n', '-'], input=sh_candidate, capture_output=True)
    if sh_syntax.returncode:
        raise RuntimeError(f'Bash candidate syntax failed: {sh_syntax.stderr.decode(errors="replace")}')
    ps_parse = '''$source = [Console]::In.ReadToEnd(); $tokens = $null; $errors = $null;
[System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors) | Out-Null;
if ($errors.Count -ne 0) { $errors | ForEach-Object { [Console]::Error.WriteLine($_.Message) }; exit 1 }'''
    ps_syntax = subprocess.run(['pwsh', '-NoProfile', '-Command', ps_parse],
                               input=ps_candidate, capture_output=True)
    if ps_syntax.returncode:
        raise RuntimeError(f'PowerShell candidate syntax failed: {ps_syntax.stderr.decode(errors="replace")}')
    print('CHECK OK: all old hashes, replacement anchors, and both candidate parsers')
    if not args.apply:
        return 0
    backup_dir = pathlib.Path(__file__).resolve().parent / f'human-apply-backup-{time.strftime("%Y%m%dT%H%M%S")}'
    backup_dir.mkdir(mode=0o700)
    for relative, original in originals.items():
        backup = backup_dir / pathlib.Path(relative).name
        backup.write_bytes(original)
        if sha256(backup.read_bytes()) != TARGETS[relative]:
            raise RuntimeError(f'backup readback mismatch: {relative}')
    for relative, original in originals.items():
        if sha256((ROOT / relative).read_bytes()) != sha256(original):
            raise RuntimeError(f'target changed before batch write: {relative}; backups at {backup_dir}')
    written = []
    try:
        for relative, candidate in candidates.items():
            path = ROOT / relative
            if sha256(path.read_bytes()) != TARGETS[relative]:
                raise RuntimeError(f'target changed after check: {relative}')
            written.append(relative)
            path.write_bytes(candidate)
            if sha256(path.read_bytes()) != sha256(candidate):
                raise RuntimeError(f'candidate readback mismatch: {relative}')
    except Exception:
        for relative in reversed(written):
            path = ROOT / relative
            current_hash = sha256(path.read_bytes())
            if current_hash == TARGETS[relative]:
                continue
            if current_hash == sha256(candidates[relative]):
                path.write_bytes(originals[relative])
            else:
                print(f'MANUAL RESTORE REQUIRED: {relative}; backup at {backup_dir}', file=sys.stderr)
        raise
    print(f'APPLIED: three targets; backups at {backup_dir}')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        raise SystemExit(1)
