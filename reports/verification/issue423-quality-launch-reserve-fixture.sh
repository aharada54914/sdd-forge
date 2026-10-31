#!/usr/bin/env bash
# Run only after the human applies issue423-quality-launch-candidate.patch.
# Every --reserve call uses a disposable ledger, never the repository ledger.
set -euo pipefail

root=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
sh_validator=$root/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
ps_validator=$root/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
command -v pwsh >/dev/null || { printf 'pwsh unavailable; both-shell test incomplete\n' >&2; exit 2; }
fixture_tmp=${TMPDIR:-/tmp}
work=$(rtk proxy mktemp -d "${fixture_tmp%/}/issue423-reserve-fixture.XXXXXX")
printf 'DISPOSABLE_FIXTURES=%s\n' "$work"

sha_file() {
  local line
  line=$(rtk proxy shasum -a 256 "$1")
  printf '%s' "${line%% *}"
}
sha_text() {
  local line
  line=$(printf '%s' "$1" | rtk proxy shasum -a 256)
  printf '%s' "${line%% *}"
}

setup() {
  local name=$1 host_run=${2:-host-fixture} host_session=${3:-session-fixture}
  fixture=$work/$name
  rtk proxy mkdir -p "$fixture/reports/review-context" \
    "$fixture/reports/implementation/fixture" "$fixture/handoffs/fixture"
  ledger_hash=$(sha_text "1|spec|spec-reviewer-a|$host_run|$host_session|")
  rtk proxy jq -n --arg run "$host_run" --arg session "$host_session" --arg hash "$ledger_hash" \
    '{schema:"review-identity-ledger/v1",records:[{sequence:1,stage:"spec",role:"spec-reviewer-a",run_id:$run,host_session_id:$session,previous_record_sha256:"",record_sha256:$hash}]}' \
    > "$fixture/reports/review-context/identity-ledger.json"
  ledger_file_hash=$(sha_file "$fixture/reports/review-context/identity-ledger.json")
  rtk proxy jq -n '{schema:"task-input-manifest/v1",task_id:"T-001",run_id:"worker-run",session_id:"worker-session"}' \
    > "$fixture/handoffs/fixture/manifest.json"
  impl_hash=$(sha_file "$fixture/handoffs/fixture/manifest.json")
  report=$fixture/reports/implementation/fixture/T-001.md
  printf '# Implementation Report: T-001\n- Task ID: T-001\nRun ID: worker-run\n- **Run ID**: worker-run\n- **Session ID**: worker-session\n- **Scratch Root**: %s/implementation\nInput manifest: `handoffs/fixture/manifest.json`, SHA-256 `%s`\n' \
    "$fixture" "$impl_hash" > "$report"
  refresh_invocation
}

refresh_invocation() {
  local report_hash
  report_hash=$(sha_file "$report")
  rtk proxy jq -n --arg ledger "$ledger_file_hash" --arg previous "$ledger_hash" \
    --arg report "$report_hash" --arg implementation "$impl_hash" \
    --arg scratch "$fixture/evaluator" '
    {schema:"review-context-invocation/v2",stage:"quality",role:"sdd-evaluator",
     feature:"fixture",task_id:"T-001",run_id:"evaluator-run",host_session_id:"evaluator-session",
     read_only:true,input_mode:"file-manifest",fallback_mode:"none",
     identity_ledger_path:"reports/review-context/identity-ledger.json",
     identity_ledger_sha256:$ledger,previous_record_sha256:$previous,sequence:2,
     scratch_root:$scratch,
     implementation_manifest:{path:"handoffs/fixture/manifest.json",sha256:$implementation},
     allowed_input_manifest:[
       {path:"reports/implementation/fixture/T-001.md",sha256:$report},
       {path:"handoffs/fixture/manifest.json",sha256:$implementation}]}' > "$fixture/invocation.json"
}

assert_rejected() {
  local name=$1 category=$2 output rc
  if output=$(rtk proxy bash "$sh_validator" "$fixture/invocation.json" "$fixture" --reserve 2>&1); then rc=0; else rc=$?; fi
  [[ "$rc" -ne 0 && "$output" == *"REVIEW_CONTEXT_$category"* ]] || {
    printf 'FAIL %s bash rc=%s output=%s\n' "$name" "$rc" "$output" >&2; exit 1;
  }
  if output=$(rtk proxy pwsh -NoProfile -File "$ps_validator" -Manifest "$fixture/invocation.json" -RepositoryRoot "$fixture" -Reserve 2>&1); then rc=0; else rc=$?; fi
  [[ "$rc" -ne 0 && "$output" == *"REVIEW_CONTEXT_$category"* ]] || {
    printf 'FAIL %s pwsh rc=%s output=%s\n' "$name" "$rc" "$output" >&2; exit 1;
  }
  printf 'PASS negative %s (bash,pwsh)\n' "$name"
}

setup missing_declaration
rtk proxy jq 'del(.implementation_manifest) | .allowed_input_manifest |= map(select(.path != "handoffs/fixture/manifest.json"))' \
  "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
assert_rejected missing_declaration IDENTITY

setup undeclared_handoff
rtk proxy jq 'del(.implementation_manifest)' "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
assert_rejected undeclared_handoff PATH

setup missing_pinned_input
rtk proxy jq '.allowed_input_manifest |= map(select(.path != "handoffs/fixture/manifest.json"))' \
  "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
assert_rejected missing_pinned_input IDENTITY

setup altered_manifest
printf '\n' >> "$fixture/handoffs/fixture/manifest.json"
assert_rejected altered_manifest HASH

setup mismatched_run
rtk proxy sed 's/^Run ID: worker-run$/Run ID: wrong-run/' "$report" > "$fixture/changed.md"
rtk proxy mv "$fixture/changed.md" "$report"
refresh_invocation
assert_rejected mismatched_run IDENTITY

setup conflicting_run_line
printf 'Run ID: other-run\n' >> "$report"
refresh_invocation
assert_rejected conflicting_run_line IDENTITY

setup conflicting_session_line
printf '%s\n' '- **Session ID**: other-session' >> "$report"
refresh_invocation
assert_rejected conflicting_session_line IDENTITY

setup duplicate_manifest_citation
printf 'Input manifest: `handoffs/fixture/manifest.json`, SHA-256 `%064d`\n' 0 >> "$report"
refresh_invocation
assert_rejected duplicate_manifest_citation IDENTITY

setup suffixed_manifest_citation
rtk proxy sed '/^Input manifest:/s/$/ extra/' "$report" > "$fixture/changed.md"
rtk proxy mv "$fixture/changed.md" "$report"
refresh_invocation
assert_rejected suffixed_manifest_citation IDENTITY

setup reused_implementation worker-run worker-session
assert_rejected reused_implementation IDENTITY

setup relative_scratch
rtk proxy sed 's@^- \*\*Scratch Root\*\*: .*@- **Scratch Root**: relative/unknown@' "$report" > "$fixture/changed.md"
rtk proxy mv "$fixture/changed.md" "$report"
refresh_invocation
assert_rejected relative_scratch PATH

setup overlapping_scratch
rtk proxy sed "s@^- \\*\\*Scratch Root\\*\\*: .*@- **Scratch Root**: $fixture/evaluator@" "$report" > "$fixture/changed.md"
rtk proxy mv "$fixture/changed.md" "$report"
refresh_invocation
assert_rejected overlapping_scratch PATH

setup evaluator_reuse
rtk proxy jq '.run_id = "worker-run"' "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
assert_rejected evaluator_reuse IDENTITY

setup supersession_archive_unlisted
archive_rel=reports/implementation/fixture/archive/T-001-original.md
archive=$fixture/$archive_rel
rtk proxy mkdir -p "$fixture/reports/implementation/fixture/archive"
printf '# Implementation Report: T-001\n- Task ID: T-001\n- **Scratch Root**: relative/unknown\n' > "$archive"
archive_hash=$(sha_file "$archive")
printf 'Supersedes: `%s`, SHA-256 `%s` (historical report; provenance incomplete).\n' \
  "$archive_rel" "$archive_hash" >> "$report"
refresh_invocation
rtk proxy jq --arg path "$archive_rel" --arg hash "$archive_hash" \
  '.allowed_input_manifest += [{path:$path,sha256:$hash}]' \
  "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
assert_rejected supersession_archive_unlisted PATH

setup supersession_archive_pinned
archive_rel=reports/implementation/fixture/archive/T-001-original.md
archive=$fixture/$archive_rel
rtk proxy mkdir -p "$fixture/reports/implementation/fixture/archive"
printf '# Implementation Report: T-001\n- Task ID: T-001\n- **Scratch Root**: relative/unknown\n' > "$archive"
archive_hash=$(sha_file "$archive")
printf 'Supersedes: `%s`, SHA-256 `%s` (historical report; provenance incomplete).\n' \
  "$archive_rel" "$archive_hash" >> "$report"
printf '\n## Outputs\n\n| Path | SHA-256 |\n|---|---|\n| `%s` | `%s` |\n' \
  "$archive_rel" "$archive_hash" >> "$report"
refresh_invocation
rtk proxy jq --arg path "$archive_rel" --arg hash "$archive_hash" \
  '.allowed_input_manifest += [{path:$path,sha256:$hash}]' \
  "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
output=$(rtk proxy bash "$sh_validator" "$fixture/invocation.json" "$fixture" --reserve)
[[ "$output" == REVIEW_CONTEXT_OK* ]] || { printf 'FAIL Bash supersession control\n' >&2; exit 1; }
setup supersession_archive_pinned_pwsh
archive_rel=reports/implementation/fixture/archive/T-001-original.md
archive=$fixture/$archive_rel
rtk proxy mkdir -p "$fixture/reports/implementation/fixture/archive"
printf '# Implementation Report: T-001\n- Task ID: T-001\n- **Scratch Root**: relative/unknown\n' > "$archive"
archive_hash=$(sha_file "$archive")
printf 'Supersedes: `%s`, SHA-256 `%s` (historical report; provenance incomplete).\n' \
  "$archive_rel" "$archive_hash" >> "$report"
printf '\n## Outputs\n\n| Path | SHA-256 |\n|---|---|\n| `%s` | `%s` |\n' \
  "$archive_rel" "$archive_hash" >> "$report"
refresh_invocation
rtk proxy jq --arg path "$archive_rel" --arg hash "$archive_hash" \
  '.allowed_input_manifest += [{path:$path,sha256:$hash}]' \
  "$fixture/invocation.json" > "$fixture/changed.json"
rtk proxy mv "$fixture/changed.json" "$fixture/invocation.json"
output=$(rtk proxy pwsh -NoProfile -File "$ps_validator" -Manifest "$fixture/invocation.json" -RepositoryRoot "$fixture" -Reserve)
[[ "$output" == REVIEW_CONTEXT_OK* ]] || { printf 'FAIL PowerShell supersession control\n' >&2; exit 1; }
printf 'PASS supersession archive authorization controls (bash,pwsh)\n'

setup positive_control
rtk proxy sed '/^Input manifest:/s/$/. Snapshot prepared./' "$report" > "$fixture/changed.md"
rtk proxy mv "$fixture/changed.md" "$report"
refresh_invocation
output=$(rtk proxy bash "$sh_validator" "$fixture/invocation.json" "$fixture" --reserve)
[[ "$output" == REVIEW_CONTEXT_OK* ]] || { printf 'FAIL bash positive control\n' >&2; exit 1; }
[[ "$(rtk proxy jq '.records | length' "$fixture/reports/review-context/identity-ledger.json")" == 2 ]] || exit 1
setup positive_control_pwsh
rtk proxy sed '/^Input manifest:/s/$/. Snapshot prepared./' "$report" > "$fixture/changed.md"
rtk proxy mv "$fixture/changed.md" "$report"
refresh_invocation
output=$(rtk proxy pwsh -NoProfile -File "$ps_validator" -Manifest "$fixture/invocation.json" -RepositoryRoot "$fixture" -Reserve)
[[ "$output" == REVIEW_CONTEXT_OK* ]] || { printf 'FAIL pwsh positive control\n' >&2; exit 1; }
[[ "$(rtk proxy jq '.records | length' "$fixture/reports/review-context/identity-ledger.json")" == 2 ]] || exit 1
printf 'PASS positive controls (bash,pwsh); production ledger untouched\n'
