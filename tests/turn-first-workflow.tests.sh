#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMPLEMENT_TASKS="$ROOT/plugins/sdd-implementation/skills/implement-tasks/SKILL.md"
DELEGATION_POLICY="$ROOT/plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md"
VALIDATOR="$ROOT/plugins/sdd-implementation/scripts/validate-task-input-manifest.sh"

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

printf 'ok: turn-first orchestration enforces three-task identity and fallback fixtures\n'
