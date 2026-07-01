#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMPLEMENT_TASKS="$ROOT/plugins/sdd-implementation/skills/implement-tasks/SKILL.md"
DELEGATION_POLICY="$ROOT/plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md"
VALIDATOR="$ROOT/plugins/sdd-implementation/scripts/validate-task-input-manifest.sh"
IMPLEMENTATION_REPORT_TEMPLATE="$ROOT/plugins/sdd-implementation/templates/implementation-report.template.md"
IMPLEMENTATION_REPORT_VALIDATOR="$ROOT/plugins/sdd-implementation/scripts/validate-implementation-report.sh"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

expect_identity_rejection() {
  output="$("$@" 2>&1)" && fail "expected identity reuse rejection from: $*"
  case "$output" in
    TASK_INPUT_IDENTITY:*) ;;
    *) fail "expected TASK_INPUT_IDENTITY, got: $output" ;;
  esac
}

write_manifest() {
  file="$1"
  task_id="$2"
  run_id="$3"
  session_id="$4"
  agent_id="$5"
  mode="${6:-fresh-agent}"
  fallback_reason="${7:-}"
  reload_hash="${8:-}"

  jq -n \
    --arg task "$task_id" \
    --arg run "$run_id" \
    --arg session "$session_id" \
    --arg agent "$agent_id" \
    --arg mode "$mode" \
    --arg reason "$fallback_reason" \
    --arg reload "$reload_hash" '
    {
      schema: "task-input-manifest/v1",
      task_id: $task,
      run_id: $run,
      session_id: $session,
      agent_instance_id: $agent,
      model_tier: "strong",
      provider: "openai",
      model: "gpt-5.2-codex",
      estimated_cost_per_attempt_usd: "0",
      cost_estimate_source: "test-host",
      cost_estimate_timestamp: "2026-06-30T00:00:00Z",
      isolation_mode: $mode,
      fallback_reason: $reason,
      handoff_reload_evidence_hash: $reload,
      allowed_inputs: ([
        {
          path: "specs/demo/requirements.md",
          sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        }
      ] + if $reload == "" then [] else [{
        path: "handoffs/reload-evidence.txt",
        sha256: $reload
      }] end),
      allowed_outputs: [
        ("reports/implementation/demo/" + $task + ".md")
      ]
    }' > "$file"
}

[[ -f "$IMPLEMENT_TASKS" ]] || fail "missing file: $IMPLEMENT_TASKS"
[[ -f "$DELEGATION_POLICY" ]] || fail "missing file: $DELEGATION_POLICY"
[[ -f "$VALIDATOR" ]] || fail "missing file: $VALIDATOR"
[[ -f "$IMPLEMENTATION_REPORT_TEMPLATE" ]] ||
  fail "missing file: $IMPLEMENTATION_REPORT_TEMPLATE"
[[ -x "$IMPLEMENTATION_REPORT_VALIDATOR" ]] ||
  fail "missing executable: $IMPLEMENTATION_REPORT_VALIDATOR"

for needle in \
  'launch exactly one fresh implementation agent' \
  'persisted manifest and immutable snapshot are the only task handoff' \
  'from any earlier batch task' \
  'same-session-file-reload' \
  'explicit host-capability fallback reason' \
  'Chat history or compaction summaries alone are forbidden handoff input' \
  'Reviewer and evaluator fallback is forbidden' \
  'performed by checked-in scripts'; do
  rg -Fq "$needle" "$IMPLEMENT_TASKS" || fail "implement-tasks omits policy text: $needle"
done
for needle in \
  'The sole exception is an implementation batch' \
  'same-session-file-reload' \
  'Fresh per-task contexts remain' \
  'mandatory on every capable host' \
  'reviewers/evaluators never receive this' \
  'exception.'; do
  rg -Fq "$needle" "$DELEGATION_POLICY" || fail "delegation policy omits exception boundary: $needle"
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/capable" "$WORK/fallback" "$WORK/evidence/handoffs" "$WORK/rollback"

# Arrange a capable-host batch of three tasks with distinct identities.
for index in 1 2 3; do
  write_manifest \
    "$WORK/capable/T-00$index.json" \
    "T-00$index" \
    "run-00$index" \
    "session-00$index" \
    "agent-00$index"
done
CAPABLE_BATCH=(
  "$WORK/capable/T-001.json"
  "$WORK/capable/T-002.json"
  "$WORK/capable/T-003.json"
)

# Act/Assert: the valid batch passes, while adjacent and nonadjacent reuse of
# every launch identity fails through the deterministic batch validator.
bash "$VALIDATOR" --batch "${CAPABLE_BATCH[@]}" >/dev/null

for field in task_id run_id session_id agent_instance_id; do
  jq --arg field "$field" '.[$field] = input[$field]' \
    "$WORK/capable/T-002.json" "$WORK/capable/T-001.json" \
    > "$WORK/capable/adjacent-$field.json"
  expect_identity_rejection bash "$VALIDATOR" --batch \
    "$WORK/capable/T-001.json" \
    "$WORK/capable/adjacent-$field.json" \
    "$WORK/capable/T-003.json"

  jq --arg field "$field" '.[$field] = input[$field]' \
    "$WORK/capable/T-003.json" "$WORK/capable/T-001.json" \
    > "$WORK/capable/nonadjacent-$field.json"
  expect_identity_rejection bash "$VALIDATOR" --batch \
    "$WORK/capable/T-001.json" \
    "$WORK/capable/T-002.json" \
    "$WORK/capable/nonadjacent-$field.json"
done

# Arrange the unsupported-host fallback: logical task/run identities remain
# unique, physical session/agent identities are intentionally reused, and the
# reload evidence is bound to a saved artifact.
jq -n '{
  schema: "implementation-host-capability/v1",
  implementation_subagents_available: false,
  fallback_reason: "host-does-not-support-implementation-subagents",
  session_id: "shared-physical-session",
  agent_instance_id: "shared-physical-agent",
  task_runs: [
    {task_id: "T-011", run_id: "fallback-run-01"},
    {task_id: "T-012", run_id: "fallback-run-02"},
    {task_id: "T-013", run_id: "fallback-run-03"}
  ]
}' > "$WORK/evidence/handoffs/reload-evidence.txt"
RELOAD_HASH="$(hash_file "$WORK/evidence/handoffs/reload-evidence.txt")"
for index in 1 2 3; do
  write_manifest \
    "$WORK/fallback/T-01$index.json" \
    "T-01$index" \
    "fallback-run-0$index" \
    "shared-physical-session" \
    "shared-physical-agent" \
    "same-session-file-reload" \
    "host-does-not-support-implementation-subagents" \
    "$RELOAD_HASH"
done
FALLBACK_BATCH=(
  "$WORK/fallback/T-011.json"
  "$WORK/fallback/T-012.json"
  "$WORK/fallback/T-013.json"
)

# Act/Assert: reused physical IDs are accepted only with the explicit fallback
# records. Missing saved-file reload evidence (chat/compaction-only continuity)
# and reused run identity fail closed.
bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch "${FALLBACK_BATCH[@]}" >/dev/null

jq '.handoff_reload_evidence_hash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    | .allowed_inputs[-1].sha256 = .handoff_reload_evidence_hash' \
  "$WORK/fallback/T-012.json" > "$WORK/fallback/invented-evidence.json"
output="$(bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch \
  "$WORK/fallback/T-011.json" \
  "$WORK/fallback/invented-evidence.json" \
  "$WORK/fallback/T-013.json" 2>&1)" &&
  fail "fabricated fallback evidence unexpectedly passed"
case "$output" in
  TASK_INPUT_HANDOFF:*) ;;
  *) fail "expected TASK_INPUT_HANDOFF for fabricated evidence, got: $output" ;;
esac

output="$(bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch \
  "$WORK/capable/T-001.json" \
  "$WORK/fallback/T-012.json" 2>&1)" &&
  fail "mixed capable/fallback isolation modes unexpectedly passed"
case "$output" in
  TASK_INPUT_ISOLATION:*) ;;
  *) fail "expected TASK_INPUT_ISOLATION for mixed modes, got: $output" ;;
esac

printf '{"schema":"fabricated"}\n' > "$WORK/evidence/handoffs/reload-evidence.txt"
output="$(bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch "${FALLBACK_BATCH[@]}" 2>&1)" &&
  fail "fallback passed without disk reread and hash revalidation"
case "$output" in
  TASK_INPUT_HANDOFF:*) ;;
  *) fail "expected TASK_INPUT_HANDOFF after evidence mutation, got: $output" ;;
esac
jq -n '{
  schema: "implementation-host-capability/v1",
  implementation_subagents_available: false,
  fallback_reason: "host-does-not-support-implementation-subagents",
  session_id: "shared-physical-session",
  agent_instance_id: "shared-physical-agent",
  task_runs: [
    {task_id: "T-011", run_id: "fallback-run-01"},
    {task_id: "T-012", run_id: "fallback-run-02"},
    {task_id: "T-013", run_id: "fallback-run-03"}
  ]
}' > "$WORK/evidence/handoffs/reload-evidence.txt"
bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch "${FALLBACK_BATCH[@]}" >/dev/null
jq '.handoff_reload_evidence_hash = ""' \
  "$WORK/fallback/T-012.json" > "$WORK/fallback/chat-only.json"
output="$(bash "$VALIDATOR" --manifest "$WORK/fallback/chat-only.json" 2>&1)" &&
  fail "chat-only fallback unexpectedly passed"
case "$output" in
  TASK_INPUT_HANDOFF:*) ;;
  *) fail "expected TASK_INPUT_HANDOFF for chat-only fallback, got: $output" ;;
esac

jq '.fallback_reason = ""' \
  "$WORK/fallback/T-012.json" > "$WORK/fallback/missing-reason.json"
output="$(bash "$VALIDATOR" --manifest "$WORK/fallback/missing-reason.json" 2>&1)" &&
  fail "fallback without an explicit reason unexpectedly passed"
case "$output" in
  TASK_INPUT_HANDOFF:*) ;;
  *) fail "expected TASK_INPUT_HANDOFF for missing fallback reason, got: $output" ;;
esac
jq '.fallback_reason = "operator-prefers-one-session"' \
  "$WORK/fallback/T-012.json" > "$WORK/fallback/wrong-reason.json"
output="$(bash "$VALIDATOR" --evidence-root "$WORK/evidence" --manifest "$WORK/fallback/wrong-reason.json" 2>&1)" &&
  fail "fallback with a non-capability reason unexpectedly passed"
case "$output" in
  TASK_INPUT_HANDOFF:*) ;;
  *) fail "expected TASK_INPUT_HANDOFF for wrong fallback reason, got: $output" ;;
esac

jq '.run_id = "fallback-run-01"' \
  "$WORK/fallback/T-013.json" > "$WORK/fallback/reused-run.json"
expect_identity_rejection bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch \
  "$WORK/fallback/T-011.json" \
  "$WORK/fallback/T-012.json" \
  "$WORK/fallback/reused-run.json"

# Restore only the 1.4.0 implementation loop from the pinned baseline into an
# isolated fixture. This is intentionally independent of T-008 rollback assets.
BASELINE_COMMIT="$(git -C "$ROOT" rev-parse '7df7318^{commit}')"
[[ "$BASELINE_COMMIT" == 7df7318* ]] || fail "unexpected 1.4.0 baseline identity: $BASELINE_COMMIT"
git -C "$ROOT" show \
  "7df7318:plugins/sdd-implementation/skills/implement-tasks/SKILL.md" \
  > "$WORK/rollback/implement-tasks-1.4.0.md"
BASELINE_BLOB="$(git -C "$ROOT" rev-parse '7df7318:plugins/sdd-implementation/skills/implement-tasks/SKILL.md')"
RESTORED_BLOB="$(git hash-object "$WORK/rollback/implement-tasks-1.4.0.md")"
[[ "$RESTORED_BLOB" == "$BASELINE_BLOB" ]] ||
  fail "isolated 1.4.0 implement-tasks restoration is not byte-identical"
for needle in \
  'For each selected task:' \
  'Set the selected task to `In Progress`.' \
  'Re-evaluate the eligible set' \
  'loop back to step 1'; do
  rg -Fq "$needle" "$WORK/rollback/implement-tasks-1.4.0.md" ||
    fail "restored 1.4.0 loop omits: $needle"
done
if rg -Fq 'launch exactly one fresh implementation agent' "$WORK/rollback/implement-tasks-1.4.0.md"; then
  fail "restored 1.4.0 loop unexpectedly contains 1.5.0 launch orchestration"
fi

# Acceptance-first report contract: the current schema is complete and
# deterministic, while pre-schema reports stay readable byte-for-byte.
for needle in \
  'Report Schema: implementation-report/v2' \
  '## Output Paths And Hashes' \
  '**Test Command**' \
  '**Test Result**' \
  '**Test Evidence Path**' \
  '**Task Attempt Count**' \
  '**Escalation Prior Tier**' \
  '**Escalation Next Tier**' \
  '**Escalation Failure Class**' \
  '**Escalation Attempt Number**' \
  '**Escalation Reason**' \
  '**Run ID**' \
  '**Session ID**' \
  '**Agent Instance ID**' \
  '**Isolation Mode**' \
  '**Fallback Reason**' \
  '**Handoff Reload Evidence Hash**' \
  '## Unresolved Items' \
  '**Current Status**' \
  '**Next Action**' \
  '**Unresolved Items**'; do
  rg -Fq "$needle" "$IMPLEMENTATION_REPORT_TEMPLATE" ||
    fail "implementation report template omits: $needle"
done

REPORT_WORK="$WORK/implementation-reports"
mkdir -p "$REPORT_WORK/evidence"
printf 'green evidence\n' > "$REPORT_WORK/evidence/green.log"
cat > "$REPORT_WORK/current.md" <<'EOF'
# Implementation Report: T-006

Report Schema: implementation-report/v2

## Output Paths And Hashes

- **Path**: `plugins/example.md`; **SHA-256**: `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`

## Test Evidence

- **Test Command**: `bash tests/example.tests.sh`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/example/verification/T-006/green.log`

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: run-006
- **Session ID**: session-006
- **Agent Instance ID**: agent-006
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Unresolved Items

None.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality review
- **Unresolved Items**: None
EOF

current_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$REPORT_WORK/current.md")" ||
  fail "complete current-schema implementation report was rejected"
[[ "$current_output" == "IMPLEMENTATION_REPORT_OK" ]] ||
  fail "unexpected current-schema success diagnostic: $current_output"

cat > "$REPORT_WORK/legacy.md" <<'EOF'
# Implementation Report: T-001

## Summary

Historical report written before implementation-report/v2.
EOF
legacy_hash_before="$(hash_file "$REPORT_WORK/legacy.md")"
legacy_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$REPORT_WORK/legacy.md")" ||
  fail "legacy implementation report was rejected"
legacy_hash_after="$(hash_file "$REPORT_WORK/legacy.md")"
[[ "$legacy_output" == "IMPLEMENTATION_REPORT_LEGACY_OK" ]] ||
  fail "unexpected legacy success diagnostic: $legacy_output"
[[ "$legacy_hash_before" == "$legacy_hash_after" ]] ||
  fail "legacy validation fabricated fields or otherwise modified the report"

remove_report_text() {
  source_file="$1"
  destination_file="$2"
  text_to_remove="$3"
  python3 - "$source_file" "$destination_file" "$text_to_remove" <<'PY'
import sys

source, destination, needle = sys.argv[1:]
with open(source, encoding="utf-8") as handle:
    text = handle.read()
if needle not in text:
    raise SystemExit(f"fixture needle not found: {needle}")
with open(destination, "w", encoding="utf-8") as handle:
    handle.write(text.replace(needle, "", 1))
PY
}

replace_report_text() {
  source_file="$1"
  destination_file="$2"
  old_text="$3"
  new_text="$4"
  python3 - "$source_file" "$destination_file" "$old_text" "$new_text" <<'PY'
import sys

source, destination, old, new = sys.argv[1:]
with open(source, encoding="utf-8") as handle:
    text = handle.read()
if old not in text:
    raise SystemExit(f"fixture needle not found: {old}")
with open(destination, "w", encoding="utf-8") as handle:
    handle.write(text.replace(old, new, 1))
PY
}

expect_report_rejection() {
  expected_prefix="$1"
  fixture="$2"
  description="$3"
  rejection_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$fixture" 2>&1)" &&
    fail "$description unexpectedly passed"
  case "$rejection_output" in
    "$expected_prefix"*) ;;
    *) fail "unexpected diagnostic for $description: $rejection_output" ;;
  esac
}

missing_cases=(
  '- **Path**: `plugins/example.md`; **SHA-256**: `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`'
  '- **Test Command**: `bash tests/example.tests.sh`'
  '- **Test Result**: PASS'
  '- **Test Evidence Path**: `specs/example/verification/T-006/green.log`'
  '- **Task Attempt Count**: 1'
  '- **Escalation Prior Tier**: None'
  '- **Escalation Next Tier**: None'
  '- **Escalation Failure Class**: None'
  '- **Escalation Attempt Number**: None'
  '- **Escalation Reason**: None'
  '- **Run ID**: run-006'
  '- **Session ID**: session-006'
  '- **Agent Instance ID**: agent-006'
  '- **Isolation Mode**: fresh-agent'
  '- **Fallback Reason**: None'
  '- **Handoff Reload Evidence Hash**: None'
  'None.'
  '- **Current Status**: Implementation Complete'
  '- **Next Action**: Independent quality review'
  '- **Unresolved Items**: None'
)
case_index=0
for missing_text in "${missing_cases[@]}"; do
  case_index=$((case_index + 1))
  invalid_report="$REPORT_WORK/missing-$case_index.md"
  remove_report_text "$REPORT_WORK/current.md" "$invalid_report" "$missing_text"
  invalid_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$invalid_report" 2>&1)" &&
    fail "current-schema report passed with a missing required field: $missing_text"
  case "$invalid_output" in
    IMPLEMENTATION_REPORT_FIELD:*) ;;
    *) fail "unexpected missing-field diagnostic: $invalid_output" ;;
  esac
done

# Boundary cases cover partial escalation records and isolation-mode-specific
# fallback evidence rather than merely checking for non-empty labels.
replace_report_text \
  "$REPORT_WORK/current.md" \
  "$REPORT_WORK/partial-escalation.md" \
  '- **Escalation Prior Tier**: None' \
  '- **Escalation Prior Tier**: lightweight'
boundary_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$REPORT_WORK/partial-escalation.md" 2>&1)" &&
  fail "partial escalation record unexpectedly passed"
[[ "$boundary_output" == IMPLEMENTATION_REPORT_FIELD:* ]] ||
  fail "unexpected partial-escalation diagnostic: $boundary_output"

replace_report_text \
  "$REPORT_WORK/current.md" \
  "$REPORT_WORK/fallback-without-evidence.md" \
  '- **Isolation Mode**: fresh-agent' \
  '- **Isolation Mode**: same-session-file-reload'
boundary_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$REPORT_WORK/fallback-without-evidence.md" 2>&1)" &&
  fail "same-session fallback without evidence unexpectedly passed"
[[ "$boundary_output" == IMPLEMENTATION_REPORT_FIELD:* ]] ||
  fail "unexpected fallback-evidence diagnostic: $boundary_output"

# A current/v2-shaped report cannot downgrade to unchecked legacy handling by
# deleting or damaging its schema marker.
remove_report_text \
  "$REPORT_WORK/current.md" \
  "$REPORT_WORK/missing-schema.md" \
  'Report Schema: implementation-report/v2'
expect_report_rejection \
  'IMPLEMENTATION_REPORT_SCHEMA:' \
  "$REPORT_WORK/missing-schema.md" \
  "v2-shaped report without a schema"
replace_report_text \
  "$REPORT_WORK/current.md" \
  "$REPORT_WORK/empty-schema.md" \
  'Report Schema: implementation-report/v2' \
  'Report Schema: '
expect_report_rejection \
  'IMPLEMENTATION_REPORT_SCHEMA:' \
  "$REPORT_WORK/empty-schema.md" \
  "v2-shaped report with an empty schema"
replace_report_text \
  "$REPORT_WORK/current.md" \
  "$REPORT_WORK/malformed-schema.md" \
  'Report Schema: implementation-report/v2' \
  'Report Schema implementation-report/v2'
expect_report_rejection \
  'IMPLEMENTATION_REPORT_SCHEMA:' \
  "$REPORT_WORK/malformed-schema.md" \
  "v2-shaped report with a malformed schema"

# Closed domains prevent free-form test outcomes and lifecycle states.
for invalid_result in DEFINITELY-NOT-A-RESULT pass 'PASS — probably'; do
  fixture="$REPORT_WORK/invalid-result-${invalid_result//[^A-Za-z0-9]/-}.md"
  replace_report_text \
    "$REPORT_WORK/current.md" \
    "$fixture" \
    '- **Test Result**: PASS' \
    "- **Test Result**: $invalid_result"
  expect_report_rejection \
    'IMPLEMENTATION_REPORT_FIELD:' \
    "$fixture" \
    "invalid Test Result $invalid_result"
done
for invalid_status in BANANA Done Approved Draft; do
  fixture="$REPORT_WORK/invalid-status-$invalid_status.md"
  replace_report_text \
    "$REPORT_WORK/current.md" \
    "$fixture" \
    '- **Current Status**: Implementation Complete' \
    "- **Current Status**: $invalid_status"
  expect_report_rejection \
    'IMPLEMENTATION_REPORT_FIELD:' \
    "$fixture" \
    "invalid Current Status $invalid_status"
done

# Every report path field uses the same repository-relative canonical form.
invalid_paths=(
  '../../outside.log'
  '/absolute/outside.log'
  'C:/outside.log'
  'specs\outside.log'
  'specs//outside.log'
  'specs/./outside.log'
  'specs/../outside.log'
)
path_index=0
for invalid_path in "${invalid_paths[@]}"; do
  path_index=$((path_index + 1))
  output_fixture="$REPORT_WORK/invalid-output-path-$path_index.md"
  replace_report_text \
    "$REPORT_WORK/current.md" \
    "$output_fixture" \
    'plugins/example.md' \
    "$invalid_path"
  expect_report_rejection \
    'IMPLEMENTATION_REPORT_FIELD:' \
    "$output_fixture" \
    "non-canonical output path $invalid_path"

  evidence_fixture="$REPORT_WORK/invalid-evidence-path-$path_index.md"
  replace_report_text \
    "$REPORT_WORK/current.md" \
    "$evidence_fixture" \
    'specs/example/verification/T-006/green.log' \
    "$invalid_path"
  expect_report_rejection \
    'IMPLEMENTATION_REPORT_FIELD:' \
    "$evidence_fixture" \
    "non-canonical Test Evidence Path $invalid_path"
done

# The unsupported-host exception has one exact reason and hash-bound evidence.
replace_report_text \
  "$REPORT_WORK/current.md" \
  "$REPORT_WORK/valid-fallback.md" \
  '- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None' \
  '- **Isolation Mode**: same-session-file-reload
- **Fallback Reason**: host-does-not-support-implementation-subagents
- **Handoff Reload Evidence Hash**: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
fallback_output="$(bash "$IMPLEMENTATION_REPORT_VALIDATOR" "$REPORT_WORK/valid-fallback.md")" ||
  fail "documented host-capability fallback was rejected"
[[ "$fallback_output" == "IMPLEMENTATION_REPORT_OK" ]] ||
  fail "unexpected valid-fallback diagnostic: $fallback_output"
replace_report_text \
  "$REPORT_WORK/valid-fallback.md" \
  "$REPORT_WORK/wrong-fallback-reason.md" \
  'host-does-not-support-implementation-subagents' \
  'operator-prefers-one-session'
expect_report_rejection \
  'IMPLEMENTATION_REPORT_FIELD:' \
  "$REPORT_WORK/wrong-fallback-reason.md" \
  "fallback with a non-capability reason"

printf 'ok: turn-first orchestration enforces three-task identity and fallback fixtures\n'
printf 'ok: implementation report v2 enforces complete file-backed handoff fields with legacy compatibility\n'
