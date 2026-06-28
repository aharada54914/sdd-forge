#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SH="$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh"
PS="$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
rule_id() { sed -n 's/^workflow-state: [^:]*: \([^:]*\):.*/\1/p' | head -1; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
reviewed_sha() {
  local file="$1" stage="$2" output cr=$'\r'
  output="$TMP/normalized-$stage.md"
  case "$stage" in
    spec) sed "s/^Spec-Review-Status:[[:space:]]*.*/Spec-Review-Status: Pending${cr}/" "$file" > "$output" ;;
    impl) sed "s/^Impl-Review-Status:[[:space:]]*.*/Impl-Review-Status: Pending${cr}/" "$file" > "$output" ;;
    task)
      sed -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending${cr}/" \
          -e "s/^Approval:[[:space:]]*.*/Approval: Draft${cr}/" \
          -e "s/^Status:[[:space:]]*.*/Status: Planned${cr}/" "$file" > "$output" ;;
  esac
  sha "$output"
}
latest_task_contract() {
  local root="$1" path attempt round best="" best_attempt=-1 best_round=-1
  for path in "$root"/reports/task-review/workflow-state-integrity/attempt-*/round-*/task-review-contract.json; do
    [[ -f "$path" ]] || continue
    attempt="${path%/round-*}"
    attempt="${attempt##*/attempt-}"
    round="${path%/task-review-contract.json}"
    round="${round##*/round-}"
    [[ "$attempt" =~ ^[0-9]+$ && "$round" =~ ^[0-9]+$ ]] || continue
    if ((attempt > best_attempt || attempt == best_attempt && round > best_round)); then
      best="$path"
      best_attempt="$attempt"
      best_round="$round"
    fi
  done
  [[ -n "$best" ]] || fail "latest task-review contract was not found"
  printf '%s\n' "$best"
}

mkdir -p "$TMP/specs/sdd-lite"
printf '# Lite\r\n' > "$TMP/specs/sdd-lite/requirements.md"
jq '{schema_version, migration_baseline_commit,
     entries: [.entries[] | select(.feature == "sdd-lite")]}' \
  "$ROOT/specs/workflow-state-registry.json" |
  sed 's/$/\r/' > "$TMP/specs/workflow-state-registry.json"

set +e
sh_output="$(bash "$SH" --registry "$TMP/specs/workflow-state-registry.json" 2>&1)"
sh_status=$?
ps_output="$(pwsh -NoProfile -File "$PS" --registry "$TMP/specs/workflow-state-registry.json" 2>&1)"
ps_status=$?
set -e
[[ $sh_status -eq $ps_status ]] || fail "CRLF exit statuses diverged"
[[ "$(printf '%s\n' "$sh_output" | rule_id)" == "$(printf '%s\n' "$ps_output" | rule_id)" ]] ||
  fail "CRLF rule IDs diverged"
[[ $sh_status -eq 0 ]] || fail "valid CRLF lite fixture failed"

FULL="$TMP/full"
mkdir -p "$FULL/specs" "$FULL/reports/spec-review" "$FULL/reports/impl-review" "$FULL/reports/task-review"
FULL="$(cd "$FULL" && pwd -P)"
mkdir -p "$FULL/plugins/sdd-review-loop/references" "$FULL/plugins/sdd-quality-loop/references"
cp "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
  "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" \
  "$FULL/plugins/sdd-review-loop/references/"
cp "$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md" \
  "$ROOT/plugins/sdd-quality-loop/references/risk-classification-policy.md" \
  "$FULL/plugins/sdd-quality-loop/references/"
cp -R "$ROOT/specs/workflow-state-integrity" "$FULL/specs/"
cp -R "$ROOT/reports/spec-review/workflow-state-integrity" "$FULL/reports/spec-review/"
cp -R "$ROOT/reports/impl-review/workflow-state-integrity" "$FULL/reports/impl-review/"
cp -R "$ROOT/reports/task-review/workflow-state-integrity" "$FULL/reports/task-review/"
while IFS= read -r evidence; do
  sed -i.bak "s#$ROOT#$FULL#g" "$evidence"
  rm "$evidence.bak"
done < <(find "$FULL/reports" -type f \
  \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
jq '{schema_version, migration_baseline_commit,
     entries: [.entries[] | select(.feature == "workflow-state-integrity")]}' \
  "$ROOT/specs/workflow-state-registry.json" > "$FULL/specs/workflow-state-registry.json"
for artifact in requirements.md design.md acceptance-tests.md tasks.md; do
  awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' \
    "$FULL/specs/workflow-state-integrity/$artifact" > "$FULL/$artifact.tmp"
  mv "$FULL/$artifact.tmp" "$FULL/specs/workflow-state-integrity/$artifact"
done
req_raw="$(sha "$FULL/specs/workflow-state-integrity/requirements.md")"
req_spec="$(reviewed_sha "$FULL/specs/workflow-state-integrity/requirements.md" spec)"
design_impl="$(reviewed_sha "$FULL/specs/workflow-state-integrity/design.md" impl)"
accept_raw="$(sha "$FULL/specs/workflow-state-integrity/acceptance-tests.md")"
tasks_reviewed="$(reviewed_sha "$FULL/specs/workflow-state-integrity/tasks.md" task)"
spec_contract="$FULL/reports/spec-review/workflow-state-integrity/attempt-1/round-2/spec-review-contract.json"
impl_contract="$FULL/reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json"
task_contract="$(latest_task_contract "$FULL")"
jq --arg req "$req_spec" --arg accept "$accept_raw" '
  .requirements_sha256 = $req |
  .acceptance_sha256 = $accept |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/requirements.md")) | .sha256) = $req |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/acceptance-tests.md")) | .sha256) = $accept
' "$spec_contract" > "$FULL/contract.tmp" && mv "$FULL/contract.tmp" "$spec_contract"
jq --arg req "$req_raw" --arg accept "$accept_raw" --arg design "$design_impl" '
  .requirements_sha256 = $req |
  .acceptance_sha256 = $accept |
  .design_sha256 = $design |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/requirements.md")) | .sha256) = $req |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/acceptance-tests.md")) | .sha256) = $accept |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/design.md")) | .sha256) = $design
' "$impl_contract" > "$FULL/contract.tmp" && mv "$FULL/contract.tmp" "$impl_contract"
jq --arg req "$req_raw" --arg accept "$accept_raw" --arg tasks "$tasks_reviewed" '
  .requirements_sha256 = $req |
  .acceptance_sha256 = $accept |
  .tasks_sha256 = $tasks |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/requirements.md")) | .sha256) = $req |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/acceptance-tests.md")) | .sha256) = $accept |
  (.reviewers[].allowed_input_manifest[] |
    select(.path | endswith("/tasks.md")) | .sha256) = $tasks
' "$task_contract" > "$FULL/contract.tmp" && mv "$FULL/contract.tmp" "$task_contract"
for stage in spec impl; do
  contract="$FULL/reports/$stage-review/workflow-state-integrity/attempt-1/round-2/$stage-review-contract.json"
  for reviewer in a b; do
    jq --slurpfile contract "$contract" --arg role "$stage-reviewer-$reviewer" '
      .allowed_input_manifest =
        ($contract[0].reviewers[] | select(.role == $role) | .allowed_input_manifest)
    ' "$(dirname "$contract")/reviewer-$reviewer.json" > "$FULL/reviewer.tmp"
    mv "$FULL/reviewer.tmp" "$(dirname "$contract")/reviewer-$reviewer.json"
  done
done
jq --slurpfile contract "$task_contract" '
  .manifest = (($contract[0].reviewers[] | select(.role == "task-reviewer-a") |
    .allowed_input_manifest) | map(. + {verified:true}))
' "$(dirname "$task_contract")/reviewer-a.json" > "$FULL/reviewer.tmp"
mv "$FULL/reviewer.tmp" "$(dirname "$task_contract")/reviewer-a.json"
jq --slurpfile contract "$task_contract" '
  .manifest.allowed_inputs =
    ($contract[0].reviewers[] | select(.role == "task-reviewer-b") | .allowed_input_manifest)
' "$(dirname "$task_contract")/reviewer-b.json" > "$FULL/reviewer.tmp"
mv "$FULL/reviewer.tmp" "$(dirname "$task_contract")/reviewer-b.json"

set +e
sh_output="$(bash "$SH" --registry "$FULL/specs/workflow-state-registry.json" 2>&1)"
sh_status=$?
ps_output="$(pwsh -NoProfile -File "$PS" --registry "$FULL/specs/workflow-state-registry.json" 2>&1)"
ps_status=$?
set -e
[[ $sh_status -eq 0 && $ps_status -eq 0 ]] ||
  fail "valid full CRLF provenance failed: Shell=$sh_output PowerShell=$ps_output"

printf '{bad json\r\n' > "$TMP/specs/workflow-state-registry.json"
set +e
sh_output="$(bash "$SH" --registry "$TMP/specs/workflow-state-registry.json" 2>&1)"
sh_status=$?
ps_output="$(pwsh -NoProfile -File "$PS" --registry "$TMP/specs/workflow-state-registry.json" 2>&1)"
ps_status=$?
set -e
[[ $sh_status -eq $ps_status && $sh_status -ne 0 ]] || fail "malformed exit statuses diverged"
[[ "$(printf '%s\n' "$sh_output" | rule_id)" == "registry-malformed" ]] ||
  fail "Shell malformed rule ID changed"
[[ "$(printf '%s\n' "$ps_output" | rule_id)" == "registry-malformed" ]] ||
  fail "PowerShell malformed rule ID changed"

printf 'ok: workflow-state adapter parity passed\n'
