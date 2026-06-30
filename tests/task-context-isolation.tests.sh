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
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"
mkdir -p "$REPO/specs/demo" "$REPO/contracts" "$WORK/manifests" "$WORK/snapshots"
printf 'requirement text\n' > "$REPO/specs/demo/requirements.md"
printf '{"contract":true}\n' > "$REPO/contracts/demo.json"
REQ_HASH="$(hash_file "$REPO/specs/demo/requirements.md")"
CONTRACT_HASH="$(hash_file "$REPO/contracts/demo.json")"
RELOAD_HASH="$(printf 'handoff\n' | shasum -a 256 | awk '{print $1}')"

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
      allowed_inputs: [
        {path: "specs/demo/requirements.md", sha256: $req},
        {path: "contracts/demo.json", sha256: $contract}
      ],
      allowed_outputs: [
        "reports/implementation/demo/T-002.md",
        "specs/demo/verification/"
      ]
    }' > "$file"
}

VALID="$WORK/manifests/valid.json"
write_manifest "$VALID" T-002 run-001 session-001 agent-001
bash "$SNAPSHOT" --manifest "$VALID" --repo-root "$REPO" --snapshot-root "$WORK/snapshots/run-001" >/dev/null
output="$(bash "$VALIDATOR" --manifest "$VALID" --snapshot-root "$WORK/snapshots/run-001")"
[[ "$output" == TASK_INPUT_OK* ]] || fail "valid manifest was not accepted: $output"

for idx in 1 2 3; do
  write_manifest "$WORK/manifests/batch-$idx.json" "T-00$idx" "run-00$idx" "session-00$idx" "agent-00$idx"
done
bash "$VALIDATOR" --batch "$WORK/manifests/batch-1.json" "$WORK/manifests/batch-2.json" "$WORK/manifests/batch-3.json" >/dev/null
jq '.session_id = "session-001"' "$WORK/manifests/batch-3.json" > "$WORK/manifests/batch-3-reuse.json"
expect_diag TASK_INPUT_IDENTITY bash "$VALIDATOR" --batch "$WORK/manifests/batch-1.json" "$WORK/manifests/batch-2.json" "$WORK/manifests/batch-3-reuse.json"

write_manifest "$WORK/manifests/fallback-a.json" T-010 run-010 shared-session shared-agent same-session-file-reload same-session-file-reload "$RELOAD_HASH"
write_manifest "$WORK/manifests/fallback-b.json" T-011 run-011 shared-session shared-agent same-session-file-reload same-session-file-reload "$RELOAD_HASH"
bash "$VALIDATOR" --batch "$WORK/manifests/fallback-a.json" "$WORK/manifests/fallback-b.json" >/dev/null
jq '.handoff_reload_evidence_hash = ""' "$WORK/manifests/fallback-a.json" > "$WORK/manifests/chat-only.json"
expect_diag TASK_INPUT_HANDOFF bash "$VALIDATOR" --manifest "$WORK/manifests/chat-only.json"

jq '.task_id = "T-999"' "$VALID" > "$WORK/manifests/bad-task.json"
expect_diag TASK_INPUT_IDENTITY bash "$VALIDATOR" --manifest "$WORK/manifests/bad-task.json" --expected-task T-002 --snapshot-root "$WORK/snapshots/run-001"
jq '.allowed_inputs[0].path = "../secrets.txt"' "$VALID" > "$WORK/manifests/bad-path.json"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/bad-path.json"
jq '.allowed_inputs[0].sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$VALID" > "$WORK/manifests/bad-sha.json"
expect_diag TASK_INPUT_HASH bash "$VALIDATOR" --manifest "$WORK/manifests/bad-sha.json" --snapshot-root "$WORK/snapshots/run-001"
jq 'del(.cost_estimate_source)' "$VALID" > "$WORK/manifests/missing-field.json"
expect_diag TASK_INPUT_COST bash "$VALIDATOR" --manifest "$WORK/manifests/missing-field.json"
jq '.estimated_cost_per_attempt_usd = "1.2.3"' "$VALID" > "$WORK/manifests/bad-cost.json"
expect_diag TASK_INPUT_COST bash "$VALIDATOR" --manifest "$WORK/manifests/bad-cost.json"
jq '.allowed_outputs += ["../outside"]' "$VALID" > "$WORK/manifests/bad-output.json"
expect_diag TASK_INPUT_PATH bash "$VALIDATOR" --manifest "$WORK/manifests/bad-output.json"
ln -s "$REPO/specs/demo/requirements.md" "$REPO/specs/demo/link.md"
jq --arg h "$REQ_HASH" '.allowed_inputs[0] = {path: "specs/demo/link.md", sha256: $h}' "$VALID" > "$WORK/manifests/symlink.json"
expect_diag TASK_INPUT_PATH bash "$SNAPSHOT" --manifest "$WORK/manifests/symlink.json" --repo-root "$REPO" --snapshot-root "$WORK/snapshots/symlink"
printf 'tampered\n' > "$WORK/snapshots/run-001/specs/demo/requirements.md"
expect_diag TASK_INPUT_HASH bash "$VALIDATOR" --manifest "$VALID" --snapshot-root "$WORK/snapshots/run-001"

selection="$(bash "$SELECTOR" --risk high --candidate codex/fast:lightweight:0.010 --candidate codex/general:standard:0.030 --candidate codex/strong:strong:0.090)"
[[ "$selection" == "codex/strong strong" ]] || fail "unexpected selector output: $selection"

printf 'ok: task context isolation manifests, snapshots, fallback, and selector are deterministic\n'
