#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$ROOT/plugins/sdd-implementation/scripts"
VALIDATOR="$SCRIPT_DIR/validate-task-input-manifest.sh"
SNAPSHOT="$SCRIPT_DIR/prepare-task-snapshot.sh"
SELECTOR="$SCRIPT_DIR/select-agent-model.sh"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

expect_diag() {
  expected="$1"
  shift
  output="$("$@" 2>&1)" && fail "expected $expected from $*"
  case "$output" in
    "$expected"*) ;;
    *) fail "expected $expected, got: $output" ;;
  esac
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

for required in "$VALIDATOR" "$SNAPSHOT" "$SELECTOR"; do
  [[ -f "$required" ]] || fail "missing script: $required"
done

WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null || true; rm -rf "$WORK"' EXIT
REPO="$WORK/repo"
mkdir -p "$REPO/specs/demo" "$REPO/contracts" "$WORK/manifests" "$WORK/snapshots"
printf 'requirement text\n' > "$REPO/specs/demo/requirements.md"
printf '{"contract":true}\n' > "$REPO/contracts/demo.json"
REQ_HASH="$(hash_file "$REPO/specs/demo/requirements.md")"
CONTRACT_HASH="$(hash_file "$REPO/contracts/demo.json")"
mkdir -p "$WORK/evidence/handoffs"
jq -n '{
  schema: "implementation-host-capability/v1",
  implementation_subagents_available: false,
  fallback_reason: "host-does-not-support-implementation-subagents",
  session_id: "shared-session",
  agent_instance_id: "shared-agent",
  task_runs: [
    {task_id: "T-010", run_id: "run-010"},
    {task_id: "T-011", run_id: "run-011"}
  ]
}' > "$WORK/evidence/handoffs/reload-evidence.txt"
RELOAD_HASH="$(hash_file "$WORK/evidence/handoffs/reload-evidence.txt")"

write_manifest() {
  file="$1"
  task_id="$2"
  run_id="$3"
  session_id="$4"
  agent_id="$5"
  mode="${6:-fresh-agent}"
  fallback_reason="${7:-}"
  handoff_hash="${8:-}"
  jq -n \
    --arg task "$task_id" \
    --arg run "$run_id" \
    --arg session "$session_id" \
    --arg agent "$agent_id" \
    --arg req "$REQ_HASH" \
    --arg contract "$CONTRACT_HASH" \
    --arg mode "$mode" \
    --arg fallback "$fallback_reason" \
    --arg handoff "$handoff_hash" '
    {
      schema: "task-input-manifest/v1",
      task_id: $task,
      run_id: $run,
      session_id: $session,
      agent_instance_id: $agent,
      model_tier: "standard",
      provider: "codex",
      model: "codex-general-medium",
      estimated_cost_per_attempt_usd: "0.125",
      cost_estimate_source: "fixture-2026-06-30",
      cost_estimate_timestamp: "2026-06-30T00:00:00Z",
      isolation_mode: $mode,
      fallback_reason: $fallback,
      handoff_reload_evidence_hash: $handoff,
      allowed_inputs: ([
        {path: "specs/demo/requirements.md", sha256: $req},
        {path: "contracts/demo.json", sha256: $contract}
      ] + if $handoff == "" then [] else [{
        path: "handoffs/reload-evidence.txt", sha256: $handoff
      }] end),
      allowed_outputs: [
        "reports/implementation/demo/T-002.md",
        "specs/demo/verification/"
      ]
    }' > "$file"
}

VALID="$WORK/manifests/valid.json"
write_manifest "$VALID" T-002 run-001 session-001 agent-001
VALID_SNAPSHOT="$WORK/snapshots/run-001"
bash "$SNAPSHOT" --manifest "$VALID" --repo-root "$REPO" --snapshot-root "$VALID_SNAPSHOT" >/dev/null
output="$(bash "$VALIDATOR" --manifest "$VALID" --snapshot-root "$VALID_SNAPSHOT")"
[[ "$output" == TASK_INPUT_OK* ]] || fail "valid manifest was not accepted: $output"
[[ ! -w "$VALID_SNAPSHOT" ]] || fail "published snapshot root is writable"
[[ ! -w "$VALID_SNAPSHOT/specs/demo" ]] || fail "published snapshot directory is writable"
[[ ! -w "$VALID_SNAPSHOT/specs/demo/requirements.md" ]] || fail "published snapshot file is writable"
if (printf 'changed\n' > "$VALID_SNAPSHOT/specs/demo/requirements.md") 2>/dev/null; then
  fail "published snapshot permitted post-publication mutation"
fi
if touch "$VALID_SNAPSHOT/specs/demo/new.md" 2>/dev/null; then
  fail "published snapshot permitted post-publication file creation"
fi
if rm "$VALID_SNAPSHOT/specs/demo/requirements.md" 2>/dev/null; then
  fail "published snapshot permitted post-publication deletion"
fi

for idx in 1 2 3; do
  write_manifest "$WORK/manifests/batch-$idx.json" "T-00$idx" "run-00$idx" "session-00$idx" "agent-00$idx"
done
bash "$VALIDATOR" --batch "$WORK/manifests/batch-1.json" "$WORK/manifests/batch-2.json" "$WORK/manifests/batch-3.json" >/dev/null
jq '.session_id = "session-001"' "$WORK/manifests/batch-3.json" > "$WORK/manifests/batch-3-reuse.json"
expect_diag TASK_INPUT_IDENTITY bash "$VALIDATOR" --batch "$WORK/manifests/batch-1.json" "$WORK/manifests/batch-2.json" "$WORK/manifests/batch-3-reuse.json"

write_manifest "$WORK/manifests/fallback-a.json" T-010 run-010 shared-session shared-agent same-session-file-reload host-does-not-support-implementation-subagents "$RELOAD_HASH"
write_manifest "$WORK/manifests/fallback-b.json" T-011 run-011 shared-session shared-agent same-session-file-reload host-does-not-support-implementation-subagents "$RELOAD_HASH"
bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch "$WORK/manifests/fallback-a.json" "$WORK/manifests/fallback-b.json" >/dev/null
jq '.handoff_reload_evidence_hash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    | .allowed_inputs[-1].sha256 = .handoff_reload_evidence_hash' \
  "$WORK/manifests/fallback-a.json" > "$WORK/manifests/fallback-invented.json"
expect_diag TASK_INPUT_HANDOFF bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch \
  "$WORK/manifests/fallback-invented.json" "$WORK/manifests/fallback-b.json"
expect_diag TASK_INPUT_ISOLATION bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch \
  "$WORK/manifests/batch-1.json" "$WORK/manifests/fallback-b.json"
printf '{"schema":"fabricated"}\n' > "$WORK/evidence/handoffs/reload-evidence.txt"
expect_diag TASK_INPUT_HANDOFF bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch \
  "$WORK/manifests/fallback-a.json" "$WORK/manifests/fallback-b.json"
jq -n '{
  schema: "implementation-host-capability/v1",
  implementation_subagents_available: false,
  fallback_reason: "host-does-not-support-implementation-subagents",
  session_id: "shared-session",
  agent_instance_id: "shared-agent",
  task_runs: [
    {task_id: "T-010", run_id: "run-010"},
    {task_id: "T-011", run_id: "run-011"}
  ]
}' > "$WORK/evidence/handoffs/reload-evidence.txt"
bash "$VALIDATOR" --evidence-root "$WORK/evidence" --batch "$WORK/manifests/fallback-a.json" "$WORK/manifests/fallback-b.json" >/dev/null
jq '.handoff_reload_evidence_hash = ""' "$WORK/manifests/fallback-a.json" > "$WORK/manifests/chat-only.json"
expect_diag TASK_INPUT_HANDOFF bash "$VALIDATOR" --manifest "$WORK/manifests/chat-only.json"
jq '.fallback_reason = "operator-prefers-one-session"' "$WORK/manifests/fallback-a.json" > "$WORK/manifests/wrong-fallback-reason.json"
expect_diag TASK_INPUT_HANDOFF bash "$VALIDATOR" --evidence-root "$WORK/evidence" --manifest "$WORK/manifests/wrong-fallback-reason.json"

jq '.task_id = "T-999"' "$VALID" > "$WORK/manifests/bad-task.json"
expect_diag TASK_INPUT_IDENTITY bash "$VALIDATOR" --manifest "$WORK/manifests/bad-task.json" --expected-task T-002 --snapshot-root "$WORK/snapshots/run-001"
jq '.allowed_inputs[0].path = "../secrets.txt"' "$VALID" > "$WORK/manifests/bad-path.json"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/bad-path.json"
jq '.allowed_inputs[0].sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$VALID" > "$WORK/manifests/bad-sha.json"
expect_diag TASK_INPUT_HASH bash "$VALIDATOR" --manifest "$WORK/manifests/bad-sha.json" --snapshot-root "$VALID_SNAPSHOT"
jq 'del(.cost_estimate_source)' "$VALID" > "$WORK/manifests/missing-field.json"
expect_diag TASK_INPUT_COST bash "$VALIDATOR" --manifest "$WORK/manifests/missing-field.json"
jq '.estimated_cost_per_attempt_usd = "1.2.3"' "$VALID" > "$WORK/manifests/bad-cost.json"
expect_diag TASK_INPUT_COST bash "$VALIDATOR" --manifest "$WORK/manifests/bad-cost.json"
jq '.allowed_outputs += ["../outside"]' "$VALID" > "$WORK/manifests/bad-output.json"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/bad-output.json"
for field in allowed_inputs allowed_outputs; do
  jq --arg field "$field" '.[$field] = "not-an-array"' "$VALID" > "$WORK/manifests/scalar-$field.json"
  expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/scalar-$field.json"
done
for timestamp in \
  2026-02-29T00:00:00Z \
  2026-04-31T00:00:00Z \
  2026-12-31T24:00:00Z \
  2026-99-99T99:99:99Z \
  2026-06-30T00:00:00+00:00; do
  jq --arg timestamp "$timestamp" '.cost_estimate_timestamp = $timestamp' "$VALID" > "$WORK/manifests/bad-time.json"
  expect_diag TASK_INPUT_COST bash "$VALIDATOR" --manifest "$WORK/manifests/bad-time.json"
done
for outputs in \
  '["specs/demo"]' \
  '["specs"]' \
  '["specs/demo/requirements.md/child"]' \
  '["reports/","reports/out.md"]' \
  '["reports/out.md","reports"]'; do
  jq --argjson outputs "$outputs" '.allowed_outputs = $outputs' "$VALID" > "$WORK/manifests/overlap.json"
  expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/overlap.json"
done
ln -s "$REPO/specs/demo/requirements.md" "$REPO/specs/demo/link.md"
jq --arg h "$REQ_HASH" '.allowed_inputs[0] = {path: "specs/demo/link.md", sha256: $h}' "$VALID" > "$WORK/manifests/symlink.json"
expect_diag TASK_INPUT_PATH bash "$SNAPSHOT" --manifest "$WORK/manifests/symlink.json" --repo-root "$REPO" --snapshot-root "$WORK/snapshots/symlink"
mkdir -p "$WORK/external/specs"
cp "$REPO/specs/demo/requirements.md" "$WORK/external/specs/requirements.md"
mkdir -p "$WORK/snapshots/linked"
ln -s "$WORK/external/specs" "$WORK/snapshots/linked/specs"
jq --arg h "$REQ_HASH" '.allowed_inputs = [{path: "specs/requirements.md", sha256: $h}]' "$VALID" > "$WORK/manifests/snapshot-parent-link.json"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/snapshot-parent-link.json" --snapshot-root "$WORK/snapshots/linked"
mkdir -p "$WORK/snapshots/final-link/specs"
ln -s "$WORK/external/specs/requirements.md" "$WORK/snapshots/final-link/specs/requirements.md"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/snapshot-parent-link.json" --snapshot-root "$WORK/snapshots/final-link"
ln -s "$VALID_SNAPSHOT" "$WORK/snapshots/root-link"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$VALID" --snapshot-root "$WORK/snapshots/root-link"

mkdir -p "$REPO/linked-parent-target"
printf 'parent link input\n' > "$REPO/linked-parent-target/input.md"
PARENT_LINK_HASH="$(hash_file "$REPO/linked-parent-target/input.md")"
ln -s "$REPO/linked-parent-target" "$REPO/linked-parent"
jq --arg h "$PARENT_LINK_HASH" '.allowed_inputs = [{path: "linked-parent/input.md", sha256: $h}]' "$VALID" > "$WORK/manifests/source-parent-link.json"
expect_diag TASK_INPUT_PATH bash "$SNAPSHOT" --manifest "$WORK/manifests/source-parent-link.json" --repo-root "$REPO" --snapshot-root "$WORK/snapshots/source-parent-link"

chmod u+w "$VALID_SNAPSHOT/specs/demo/requirements.md"
printf 'tampered\n' > "$VALID_SNAPSHOT/specs/demo/requirements.md"
expect_diag TASK_INPUT_HASH bash "$VALIDATOR" --manifest "$VALID" --snapshot-root "$VALID_SNAPSHOT"

BARRIER="$WORK/publish-barrier"
BOUNDARY_SNAPSHOT="$WORK/snapshots/publication-boundary"
mkdir -p "$BARRIER"
SDD_TEST_SNAPSHOT_PUBLISH_BARRIER_DIR="$BARRIER" \
  bash "$SNAPSHOT" --manifest "$VALID" --repo-root "$REPO" --snapshot-root "$BOUNDARY_SNAPSHOT" \
  >"$WORK/boundary.out" 2>&1 &
builder_pid=$!
for _ in {1..200}; do
  [[ -f "$BARRIER/ready" ]] && break
  sleep 0.01
done
[[ -f "$BARRIER/ready" ]] || fail "snapshot builder did not reach publication boundary"
mkdir "$BOUNDARY_SNAPSHOT"
printf 'attacker-owned\n' > "$BOUNDARY_SNAPSHOT/marker"
: > "$BARRIER/continue"
if wait "$builder_pid"; then
  fail "snapshot builder overwrote destination injected at publication boundary"
fi
case "$(cat "$WORK/boundary.out")" in
  TASK_INPUT_PATH*) ;;
  *) fail "publication-boundary rejection lost TASK_INPUT_PATH diagnostic" ;;
esac
[[ "$(cat "$BOUNDARY_SNAPSHOT/marker")" == attacker-owned ]] || fail "publication boundary destination was replaced"

selection="$(bash "$SELECTOR" --risk high --candidate codex/fast:lightweight:0.010 --candidate codex/general:standard:0.030 --candidate codex/strong:strong:0.090)"
[[ "$selection" == "codex/strong strong" ]] || fail "unexpected selector output: $selection"

printf 'ok: task context isolation manifests, snapshots, fallback, and selector are deterministic\n'
