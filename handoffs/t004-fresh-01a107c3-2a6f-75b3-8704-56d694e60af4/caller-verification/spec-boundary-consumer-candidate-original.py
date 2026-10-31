#!/usr/bin/env python3
"""Prepare in memory; only a human may invoke --apply-human. No gate execution."""
import argparse
import hashlib
from pathlib import Path
import tempfile

ROOT = Path('/tmp/sdd-guard-main.3JEj4I/repo')
B = 'plugins/sdd-review-loop/references/review-context-boundary.md'
C = 'plugins/sdd-review-loop/references/spec-review-calibration.md'
PINS = {
 'plugins/sdd-review-loop/scripts/spec-review-precheck.sh': '81e345db1d1d96acec6a5ddd2159e01d6653cfb879ad2cf2a032e20b887b4c1b',
 'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1': 'ac2532f6450dde24b78e4ab7b577a04ef9b1e8d165a180152737789b5ac6fb85',
 'plugins/sdd-quality-loop/scripts/check-workflow-state.sh': '001f6962590b7d9dc9a831d8d90d7171174cca6d890e94b376881ab0193bd85f',
 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1': '13351170ba1284d2fa1eb0d096d6e5faf506e3ce0a3a22a3cb81d09b10a028db',
 'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md': 'b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9',
 'tests/spec-review-loop.tests.sh': '30fe033359d0660feaad0656581cdd5f60db09b76b52bf770703fae12d2fa602',
 'tests/lib/loop-driver.sh': 'fc75d56e0118099f553367adf042aa5865808f3ace2ad48ff403cff0e75ca9de',
 'tests/lib/loop-driver.ps1': '44283cc14f6377230bb4b9799585c8de6e364a4ce1ea1a4b2ba4454ffd0ed3f0',
}

def replace(text, old, new, count=1):
    if text.count(old) != count:
        raise ValueError('Unexpected anchor count: ' + repr(old[:100]))
    return text.replace(old, new)

def transform(rel, s):
    if rel.endswith('spec-review-precheck.sh'):
        anchor = '[[ -f "$calibration" && ! -L "$calibration" ]] || fail "spec review calibration reference must be a regular non-symlink file"'
        s = replace(s, anchor, anchor + '\nboundary="$repo_root/' + B + '"\n[[ -f "$boundary" && ! -L "$boundary" ]] || fail "review context boundary must be a regular non-symlink file"')
        anchor = '  # investigation.md is derived from the contract, exactly like calibration_hash'
        addition = '''  local boundary_hash
  boundary_hash="$(jq -r --arg repo "${repo_root}/" --arg alias "${repo_root_alias}/" --arg recorded "$recorded_prefix" "$jq_relative_path"'
    [.reviewers[].allowed_input_manifest[] | select((.path | relative_path) == "BOUNDARY") | .sha256] | unique | if length == 1 then .[0] else "" end' "$contract")"
  is_sha256 "$boundary_hash" || return 1
  expected_a="$(jq -cn --argjson manifest "$expected_a" --arg hash "$boundary_hash" '$manifest + [{path:"BOUNDARY",sha256:$hash}] | sort_by(.path)')"
'''.replace('BOUNDARY', B)
        return replace(s, anchor, addition + anchor)
    if rel.endswith('spec-review-precheck.ps1'):
        anchor = "if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Test-IsSymlink $calibration)) { Fail 'spec review calibration reference must be a regular non-symlink file' }"
        s = replace(s, anchor, anchor + "\n$boundary = Join-Path $root '" + B + "'\nif (-not (Test-Path -LiteralPath $boundary -PathType Leaf) -or (Test-IsSymlink $boundary)) { Fail 'review context boundary must be a regular non-symlink file' }")
        anchor = '  # investigation.md is derived from the contract, exactly like $calibrationHash'
        addition = '''  $boundaryHashes = @()
  foreach ($reviewer in $reviewers) {
    $entries = @($reviewer.allowed_input_manifest | Where-Object { Test-OrdinalEqual $_.path $boundary })
    if ($entries.Count -ne 1) { return $false }
    $boundaryHashes += [string]$entries[0].sha256
  }
  if ($boundaryHashes.Count -ne 2 -or -not (Test-IsSha256 $boundaryHashes[0]) -or
      -not (Test-OrdinalEqual $boundaryHashes[0] $boundaryHashes[1])) { return $false }
  $expectedAList.Add([pscustomobject]@{ path = $boundary; sha256 = $boundaryHashes[0] })
'''
        return replace(s, anchor, addition + anchor)
    if rel.endswith('check-workflow-state.sh'):
        anchor = '      ($path == (if $stage == "spec" then'
        s = replace(s, anchor, '      ($stage == "spec" and $path == "' + B + '") or\n' + anchor, 2)
        anchor = '  local calibration precheck'
        addition = '''  if [[ "$stage" == spec ]]; then
    local boundary="$REPO_ROOT/BOUNDARY"
    [[ -f "$boundary" && ! -L "$boundary" ]] || diagnostic "$feature" stage-provenance "spec review boundary is missing"
    manifest_has_hash_for_file "$contract" "/BOUNDARY" "$boundary" "$recorded_root" "$contract_identity" ||
      diagnostic "$feature" stage-provenance "spec reviewer boundary hash is missing or stale"
  fi
'''.replace('BOUNDARY', B)
        return replace(s, anchor, addition + anchor)
    if rel.endswith('check-workflow-state.ps1'):
        anchor = '            [void]$allowed.Add("' + C + '")'
        s = replace(s, anchor, anchor + '\n            [void]$allowed.Add("' + B + '")')
        anchor = '    $calibrationRelative = if ($Stage -eq "spec") {'
        addition = '''    if ($Stage -ceq 'spec') {
        $boundary = Join-Path $RepoRoot 'BOUNDARY'
        if (-not (Test-Path -LiteralPath $boundary -PathType Leaf) -or
            (Get-Item -LiteralPath $boundary -Force).LinkType) {
            Stop-WorkflowState $Feature 'stage-provenance' 'spec review boundary is missing'
        }
        if (-not (Test-ManifestHashForFile $contract '/BOUNDARY' $boundary $RepoRoot $contractPath)) {
            Stop-WorkflowState $Feature 'stage-provenance' 'spec reviewer boundary hash is missing or stale'
        }
    }
'''.replace('BOUNDARY', B)
        return replace(s, anchor, addition + anchor)
    if rel.endswith('SKILL.md'):
        s = replace(s, '`' + C + '`, and', '`' + C + '`,\n   `' + B + '`, and')
        return replace(s, 'canonical artifacts, calibration reference,', 'canonical artifacts, calibration and review-context-boundary references,')
    # Fixture publishers: derive the boundary entry next to calibration, only in spec publishers.
    if rel == 'tests/spec-review-loop.tests.sh':
        s = s.replace('--arg calibration_sha "${calibration_sha}"', '--arg boundary "${ROOT}/' + B + '" --arg boundary_sha "$(sha256sum "${ROOT}/' + B + '" | awk \'{print $1}\')" --arg calibration_sha "${calibration_sha}"')
        s = s.replace('{path:$calibration,sha256:$calibration_sha}', '{path:$calibration,sha256:$calibration_sha},{path:$boundary,sha256:$boundary_sha}')
        anchor = 'tmp_reviewer="${ROUND_ONE}/reviewer-a.tmp"'
        addition = '''# A sealed contract must bind the boundary exactly once for each reviewer.
write_contract "${ROUND_ONE}" NEEDS_WORK Major
for mutation in missing-a missing-b duplicate wrong-role-hash wrong-path; do
  write_contract "${ROUND_ONE}" NEEDS_WORK Major
  jq --arg suffix '/BOUNDARY' --arg mutation "$mutation" '
    if $mutation == "missing-a" then .reviewers[0].allowed_input_manifest |= map(select(.path | endswith($suffix) | not))
    elif $mutation == "missing-b" then .reviewers[1].allowed_input_manifest |= map(select(.path | endswith($suffix) | not))
    elif $mutation == "duplicate" then .reviewers[0].allowed_input_manifest += [.reviewers[0].allowed_input_manifest[] | select(.path | endswith($suffix))]
    elif $mutation == "wrong-role-hash" then (.reviewers[1].allowed_input_manifest[] | select(.path | endswith($suffix)) | .sha256) = ("0" * 64)
    else (.reviewers[0].allowed_input_manifest[] | select(.path | endswith($suffix)) | .path) += ".bak" end
  ' "${ROUND_ONE}/spec-review-contract.json" > "${ROUND_ONE}/boundary.tmp"
  mv "${ROUND_ONE}/boundary.tmp" "${ROUND_ONE}/spec-review-contract.json"
  expect_failure "${PRECHECK}" "${FEATURE}" 1 2 --edit-summary="boundary mutation"
  [[ ! -e "${REPORT_ROOT}/attempt-1/round-2/precheck-result.json" ]] || fail "boundary rejection wrote a new round"
done
write_contract "${ROUND_ONE}" NEEDS_WORK Major
'''.replace('BOUNDARY', B)
        return replace(s, anchor, addition + anchor)
    if rel == 'tests/lib/loop-driver.sh':
        # Restrict manifest edits to the section before implementation publishers.
        start = s.index('  local requirements_path acceptance_path investigation_path precheck_path calibration_path')
        end = s.index('  local requirements_path acceptance_path design_path precheck_path calibration_path', start)
        part = s[start:end]
        part = part.replace('--arg calibration_sha "$calibration_sha"', '--arg boundary "${LOOP_FIXTURE_ROOT}/' + B + '" --arg boundary_sha "$(_loop_sha256 "${LOOP_FIXTURE_ROOT}/' + B + '")" --arg calibration_sha "$calibration_sha"')
        part = part.replace('{path:$calibration,sha256:$calibration_sha}', '{path:$calibration,sha256:$calibration_sha},{path:$boundary,sha256:$boundary_sha}')
        s = s[:start] + part + s[end:]
        # Snapshot list and spec invocation manifests.
        lines = s.splitlines(keepends=True)
        out = []
        for line in lines:
            out.append(line)
            if line.strip() in (C + ' \\', '"' + C + '" \\'):
                out.append(line.replace(C, B))
        return ''.join(out)
    if rel == 'tests/lib/loop-driver.ps1':
        start = s.index('    $calibrationPath = Join-Path $script:LoopFixtureRoot "' + C + '"')
        end = s.index('function Publish-LoopImplRoundA', start)
        part = s[start:end]
        part = part.replace('--arg calibration_sha $calibrationSha', '--arg boundary (Join-Path $script:LoopFixtureRoot "' + B + '") --arg boundary_sha (Get-LoopSha256 (Join-Path $script:LoopFixtureRoot "' + B + '")) --arg calibration_sha $calibrationSha')
        part = part.replace('{path:$calibration,sha256:$calibration_sha}', '{path:$calibration,sha256:$calibration_sha},{path:$boundary,sha256:$boundary_sha}')
        # Append after any positional reconstruction, so investigation insertion cannot drop it.
        part = part.replace('return (Get-LoopManifestArray $rels)', '$rels += "' + B + '"\n    return (Get-LoopManifestArray $rels)')
        s = s[:start] + part + s[end:]
        anchor = '        "' + C + '",'
        # Only the snapshot list; manifest helpers append boundary explicitly above.
        first = s.index(anchor)
        s = s[:first] + s[first:].replace(anchor, anchor + '\n        "' + B + '",', 1)
        return s
    raise ValueError(rel)

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--apply-human', action='store_true')
    args = p.parse_args()
    changes = []
    for rel, expected in PINS.items():
        target = ROOT / rel
        if target.is_symlink() or not target.is_file():
            raise SystemExit('STOP: nonregular target: ' + rel)
        original = target.read_bytes()
        if hashlib.sha256(original).hexdigest() != expected:
            raise SystemExit('STOP: source changed; no application: ' + rel)
        candidate = transform(rel, original.decode()).encode()
        if candidate == original:
            raise SystemExit('STOP: empty change: ' + rel)
        changes.append((rel, original, candidate))
        print('PREPARED', rel, hashlib.sha256(candidate).hexdigest())
    if not args.apply_human:
        print('DRY_RUN_OK: candidates constructed in memory only. No files changed or candidate code executed.')
        return
    backup = Path(tempfile.mkdtemp(prefix='sdd-boundary-consumers-'))
    for rel, original, _ in changes:
        dst = backup / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(original)
    print('BACKUP:', backup, flush=True)
    # Recheck all sources before the first write.
    for rel, original, _ in changes:
        if (ROOT / rel).is_symlink() or (ROOT / rel).read_bytes() != original:
            raise SystemExit('STOP: source changed before application: ' + rel)
    for rel, _, candidate in changes:
        (ROOT / rel).write_bytes(candidate)
        if (ROOT / rel).read_bytes() != candidate:
            raise SystemExit('STOP: readback mismatch; restore from ' + str(backup))
        print('APPLIED', rel, flush=True)
    print('Application only. Syntax, regressions, independent review, CI and merge remain pending.')

if __name__ == '__main__':
    main()
